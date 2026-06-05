import Foundation
import Vapor
import AsyncHTTPClient
import NIOCore
import Crypto
import CryptoExtras

enum GoogleCloudStorageError: Error {
    case missingGoogleCredentials(String)
    case invalidGoogleCredentials(String)
    case httpError(status: Int, message: String)
}

actor GoogleCloudStorageAuth {
    private let client: HTTPClient
    private let logger: Logger
    private var cachedToken: CachedToken?

    init(client: HTTPClient, logger: Logger) {
        self.client = client
        self.logger = logger
    }

    /// returns an access token which is valid at least 5 more minutes, if not a fresh token is requested
    func getAccessToken() async throws -> String {
        if let cachedToken, cachedToken.expiry > Date().addingTimeInterval(300) {
            return cachedToken.token
        }

        let credentials = try readCredentials()
        let jwt = try makeSignedJwt(credentials: credentials)
        let token = try await exchangeJwtForAccessToken(jwt: jwt, tokenUri: credentials.token_uri)

        self.cachedToken = token
        return token.token
    }

    private func readCredentials() throws -> ServiceAccountCredentials {
        guard let path = Environment.get("GOOGLE_APPLICATION_CREDENTIALS"), !path.isEmpty else {
            throw GoogleCloudStorageError.missingGoogleCredentials(
                "Set GOOGLE_APPLICATION_CREDENTIALS to a Google service account JSON file"
            )
        }
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let credentials = try JSONDecoder().decode(ServiceAccountCredentials.self, from: data)
        guard credentials.type == "service_account" else {
            throw GoogleCloudStorageError.invalidGoogleCredentials(
                "GOOGLE_APPLICATION_CREDENTIALS must point to a service account JSON file"
            )
        }
        return credentials
    }

    /// Build and RS256-sign a JWT using the service account's private key.
    /// This is pure CPU work, so the function is synchronous.
    private func makeSignedJwt(credentials: ServiceAccountCredentials) throws -> String {
        let now = Date()
        let encoder = JSONEncoder()

        let headerData = try encoder.encode(JwtHeader())
        let claimsData = try encoder.encode(JwtClaims(
            iss: credentials.client_email,
            scope: "https://www.googleapis.com/auth/devstorage.read_only",
            aud: credentials.token_uri,
            exp: Int(now.addingTimeInterval(3600).timeIntervalSince1970),
            iat: Int(now.timeIntervalSince1970)
        ))

        let signingInput = "\(base64url(headerData)).\(base64url(claimsData))"

        // _RSA and .insecurePKCS1v1_5 are the actual swift-crypto API names for
        // RS256 (RSASSA-PKCS1-v1_5 with SHA-256). The "insecure" label refers to
        // PKCS#1 v1.5 being unsuitable for *encryption*; it is the correct and
        // required padding for JWT RS256 signing per RFC 7518 §3.3.
        let key = try _RSA.Signing.PrivateKey(pemRepresentation: credentials.private_key)
        let signature = try key.signature(for: Data(signingInput.utf8), padding: .insecurePKCS1v1_5)

        return "\(signingInput).\(base64url(signature.rawRepresentation))"
    }

    private func exchangeJwtForAccessToken(jwt: String, tokenUri: String) async throws -> CachedToken {
        var request = HTTPClientRequest(url: tokenUri)
        request.method = .POST
        request.headers.add(name: "Content-Type", value: "application/x-www-form-urlencoded")
        let body = "grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=\(jwt)"
        request.body = .bytes(ByteBuffer(string: body))

        let response = try await client.execute(request, timeout: .seconds(60))
        guard response.status == .ok else {
            let error = try await response.readStringImmutable() ?? ""
            throw GoogleCloudStorageError.httpError(
                status: Int(response.status.code),
                message: "Could not obtain Google OAuth token: \(error)"
            )
        }

        guard let tokenResponse = try await response.readJSONDecodable(GoogleAccessTokenResponse.self) else {
            throw GoogleCloudStorageError.invalidGoogleCredentials("Could not decode Google OAuth token response")
        }

        return CachedToken(
            token: tokenResponse.access_token,
            expiry: Date().addingTimeInterval(TimeInterval(tokenResponse.expires_in))
        )
    }

    private struct CachedToken {
        let token: String
        let expiry: Date
    }

    private struct JwtHeader: Encodable {
        let alg = "RS256"
        let typ = "JWT"
    }

    private struct JwtClaims: Encodable {
        let iss: String
        let scope: String
        let aud: String
        let exp: Int
        let iat: Int
    }

    private struct ServiceAccountCredentials: Decodable {
        let type: String
        let private_key: String
        let client_email: String
        let token_uri: String
    }

    private struct GoogleAccessTokenResponse: Decodable {
        let access_token: String
        let expires_in: Int
        let token_type: String
    }
}

/// Base64url encoding without padding, as required by the JWT spec (RFC 7515).
private func base64url(_ data: some DataProtocol) -> String {
    Data(data).base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}
