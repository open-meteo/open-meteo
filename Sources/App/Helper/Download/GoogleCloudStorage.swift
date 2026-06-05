import Foundation
import Vapor
import AsyncHTTPClient
import NIOCore
import JWT

enum GoogleCloudStorageError: Error {
    case invalidGcsPath(String)
    case missingGoogleCredentials(String)
    case invalidGoogleCredentials(String)
    case httpError(status: Int, message: String)
    case couldNotDecode
}

actor GoogleCloudStorageAuth {
    private let client: HTTPClient
    private let logger: Logger
    private var cachedToken: CachedToken?

    init(client: HTTPClient, logger: Logger) {
        self.client = client
        self.logger = logger
    }

    func getAccessToken() async throws -> String {
        if let cachedToken, cachedToken.expiry > Date().addingTimeInterval(60) {
            return cachedToken.token
        }

        let credentialsPath = try getCredentialsPath()
        let credentials = try readCredentials(path: credentialsPath)
        let jwt = try await makeSignedJwt(credentials: credentials)
        let token = try await exchangeJwtForAccessToken(jwt: jwt, tokenUri: credentials.token_uri)

        self.cachedToken = token
        return token.token
    }

    private func getCredentialsPath() throws -> String {
        guard let path = Environment.get("GOOGLE_APPLICATION_CREDENTIALS"), !path.isEmpty else {
            throw GoogleCloudStorageError.missingGoogleCredentials(
                "Set GOOGLE_APPLICATION_CREDENTIALS to a Google service account JSON file"
            )
        }
        return path
    }

    private func readCredentials(path: String) throws -> ServiceAccountCredentials {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let decoder = JSONDecoder()
        let credentials = try decoder.decode(ServiceAccountCredentials.self, from: data)
        guard credentials.type == "service_account" else {
            throw GoogleCloudStorageError.invalidGoogleCredentials(
                "GOOGLE_APPLICATION_CREDENTIALS must point to a service account JSON file"
            )
        }
        return credentials
    }

    private func makeSignedJwt(credentials: ServiceAccountCredentials) async throws -> String {
        let payload = GoogleServiceAccountPayload(
            iss: IssuerClaim(value: credentials.client_email),
            scope: "https://www.googleapis.com/auth/devstorage.read_only",
            aud: AudienceClaim(value: credentials.token_uri),
            exp: ExpirationClaim(value: Date().addingTimeInterval(3600)),
            iat: IssuedAtClaim(value: Date())
        )

        let key = try Insecure.RSA.PrivateKey(pem: credentials.private_key)
        let keys = JWTKeyCollection()
        await keys.add(rsa: key, digestAlgorithm: .sha256)

        return try await keys.sign(payload)
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

    private struct GoogleServiceAccountPayload: JWTPayload {
        let iss: IssuerClaim
        let scope: String
        let aud: AudienceClaim
        let exp: ExpirationClaim
        let iat: IssuedAtClaim

        func verify(using algorithm: some JWTAlgorithm) async throws {
            try exp.verifyNotExpired()
        }
    }
}
