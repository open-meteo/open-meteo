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
}

struct GoogleCloudStoragePath: Sendable {
    let bucket: String
    let object: String

    init(_ gsPath: String) throws {
        guard gsPath.hasPrefix("gs://") else {
            throw GoogleCloudStorageError.invalidGcsPath("Expected gs:// path, got \(gsPath)")
        }
        let withoutScheme = String(gsPath.dropFirst("gs://".count))
        let parts = withoutScheme.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false)
        guard let bucket = parts.first, !bucket.isEmpty else {
            throw GoogleCloudStorageError.invalidGcsPath("Missing bucket in \(gsPath)")
        }
        self.bucket = String(bucket)
        self.object = parts.count > 1 ? String(parts[1]) : ""
    }

    var authenticatedDownloadUrl: String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        let encodedObject = object.addingPercentEncoding(withAllowedCharacters: allowed) ?? object
        return "https://storage.googleapis.com/download/storage/v1/b/\(bucket)/o/\(encodedObject)?alt=media"
    }
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

enum GoogleCloudStorage {
    static func download(
        client: HTTPClient,
        logger: Logger,
        remotePath: String,
        localFile: String
    ) async throws {
        logger.info("Fetching \(remotePath) -> \(localFile)")

        let token = try await GoogleCloudStorageAuth(
            client: client,
            logger: logger
        ).getAccessToken()

        let url = try GoogleCloudStoragePath(remotePath).authenticatedDownloadUrl
        var request = HTTPClientRequest(url: url)
        request.method = .GET
        request.headers.add(name: "Authorization", value: "Bearer \(token)")

        let response = try await client.execute(request, timeout: .seconds(300))
        guard response.status == .ok else {
            let error = try await response.readStringImmutable() ?? ""
            throw GoogleCloudStorageError.httpError(
                status: Int(response.status.code),
                message: "Could not download \(remotePath): \(error)"
            )
        }

        try FileManager.default.createDirectory(
            atPath: URL(fileURLWithPath: localFile).deletingLastPathComponent().path,
            withIntermediateDirectories: true
        )

        let fileHandle = try FileHandle.createNewFile(file: localFile, overwrite: true, temporary: true)
        do {
            for try await chunk in response.body {
                try Task.checkCancellation()
                try fileHandle.write(contentsOf: Data(buffer: chunk))
            }
            try fileHandle.linkTemporary(file: localFile)
        } catch {
            try? fileHandle.close()
            throw error
        }
        try fileHandle.close()
    }

    /// Read a small file from GCS and return its contents as a String.
    /// Used for marker/control files that contain plain text.
    static func readFileAsString(
        client: HTTPClient,
        logger: Logger,
        remotePath: String
    ) async throws -> String {
        let token = try await GoogleCloudStorageAuth(
            client: client,
            logger: logger
        ).getAccessToken()

        let url = try GoogleCloudStoragePath(remotePath).authenticatedDownloadUrl
        var request = HTTPClientRequest(url: url)
        request.method = .GET
        request.headers.add(name: "Authorization", value: "Bearer \(token)")

        let response = try await client.execute(request, timeout: .seconds(60))
        guard response.status == .ok else {
            let error = try await response.readStringImmutable() ?? ""
            throw GoogleCloudStorageError.httpError(
                status: Int(response.status.code),
                message: "Could not read \(remotePath): \(error)"
            )
        }

        let body = try await response.body.collect(upTo: 1024 * 1024)
        return String(buffer: body)
    }
}
