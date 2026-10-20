import Foundation
import AsyncHTTPClient
import Vapor
import OmFileIO

/// Endpoints published by the ECMWF Open Data client.
enum EcmwfOpenDataSource: String, CaseIterable {
    case ecmwf, aws, azure, google

    var baseURL: String {
        switch self {
        case .ecmwf: return "https://data.ecmwf.int/forecasts/"
        case .aws: return "https://ecmwf-forecasts.s3.eu-central-1.amazonaws.com/"
        case .azure: return "https://ai4edataeuwest.blob.core.windows.net/ecmwf/"
        case .google: return "https://storage.googleapis.com/ecmwf-open-data/"
        }
    }

    static func baseURL(source: String?, server: String?) throws -> String {
        guard source == nil || server == nil else {
            throw Abort(.badRequest, reason: "Use either --source or --server, not both")
        }
        if let server {
            return server.hasSuffix("/") ? server : server + "/"
        }
        guard let selected = Self(rawValue: source ?? "ecmwf") else {
            throw Abort(.badRequest, reason: "Unknown ECMWF source. Choose ecmwf, aws, azure or google")
        }
        return selected.baseURL
    }

    static func supportsMultipleRanges(url: String) -> Bool {
        return URLComponents(string: url)?.host?.lowercased() == "data.ecmwf.int"
    }

    /// Keep URLs unsigned: Curl signs each HTTP request, including chunk retries.
    static func prepareDownload(url: String) throws -> (url: String, indexURL: String, allowMultipleRanges: Bool) {
        return (url, try indexURL(url: url), supportsMultipleRanges(url: url))
    }

    static func indexURL(url: String) throws -> String {
        guard var components = URLComponents(string: url), components.path.hasSuffix(".grib2") else {
            throw CurlError.invalidURL(url)
        }
        components.path = String(components.path.dropLast(6)) + ".index"
        guard let index = components.string else { throw CurlError.invalidURL(url) }
        return index
    }
}

/// Azure's public ECMWF container uses renewable Planetary Computer SAS tokens.
actor EcmwfAzureAccess {
    static let shared = EcmwfAzureAccess()
    private struct Token: Sendable {
        let token: String
        let expiry: Date
    }

    private var cached: Token?
    private var refresh: (id: UUID, task: Task<Token, Error>)?

    nonisolated static func prepareRequest(base: String, client: HTTPClient) -> Curl.PrepareRequest? {
        guard base.hasPrefix(EcmwfOpenDataSource.azure.baseURL) else { return nil }
        return { request in
            request.url = try await shared.sign(url: request.url, client: client)
        }
    }

    private struct TokenResponse: Decodable {
        let token: String
        let expiry: String

        enum CodingKeys: String, CodingKey {
            case token
            case expiry = "msft:expiry"
        }
    }

    func sign(url: String, client: HTTPClient) async throws -> String {
        guard url.hasPrefix(EcmwfOpenDataSource.azure.baseURL),
              let components = URLComponents(string: url),
              !(components.queryItems ?? []).contains(where: { $0.name == "sig" }) else {
            return url
        }
        let token: Token
        if let cached, cached.expiry > Date().addingTimeInterval(300) {
            token = cached
        } else {
            // Share a refresh across all concurrent chunk requests.
            let pending: (id: UUID, task: Task<Token, Error>)
            if let refresh {
                pending = refresh
            } else {
                pending = (UUID(), Task {
                    // Use the HTTP client directly: token requests must not pass through
                    // the signed-download hook or the file download cache.
                    let request = HTTPClientRequest(url: "https://planetarycomputer.microsoft.com/api/sas/v1/token/ai4edataeuwest/ecmwf")
                    let response = try await client.execute(request, timeout: .seconds(30))
                    try await response.throwOnError()
                    let buffer = try await response.body.collect(upTo: 64 * 1024)
                    guard let response = try buffer.readJSONDecodable(TokenResponse.self),
                          !response.token.isEmpty,
                          let expiry = ISO8601DateFormatter().date(from: response.expiry), expiry > Date() else {
                        throw Abort(.badGateway, reason: "Invalid ECMWF Azure SAS token response")
                    }
                    return Token(token: response.token, expiry: expiry)
                })
                refresh = pending
            }
            do {
                token = try await pending.task.value
                if refresh?.id == pending.id {
                    cached = token
                    refresh = nil
                }
            } catch {
                if refresh?.id == pending.id { refresh = nil }
                throw error
            }
        }
        // Preserve the token's percent encoding, including its signature.
        return url + (components.percentEncodedQuery == nil ? "?" : "&") + token.token
    }
}
