import Foundation
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

    /// Resolve source-specific authentication and capabilities before handing off to the downloader.
    static func prepareDownload(url: String, curl: Curl) async throws -> (url: String, indexURL: String, allowMultipleRanges: Bool) {
        let signedURL = try await EcmwfAzureAccess.shared.sign(url: url, curl: curl)
        return (signedURL, try indexURL(url: signedURL), supportsMultipleRanges(url: url))
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
    private var cached: (token: String, expiry: Date)?

    struct TokenResponse: Decodable {
        let token: String
        let expiry: String

        enum CodingKeys: String, CodingKey {
            case token
            case expiry = "msft:expiry"
        }
    }

    func sign(url: String, curl: Curl) async throws -> String {
        guard url.hasPrefix(EcmwfOpenDataSource.azure.baseURL),
              let components = URLComponents(string: url),
              !(components.queryItems ?? []).contains(where: { $0.name == "sig" }) else {
            return url
        }
        let token: String
        if let cached, cached.expiry > Date().addingTimeInterval(300) {
            token = cached.token
        } else {
            let buffer = try await curl.downloadInMemoryAsync(
                url: "https://planetarycomputer.microsoft.com/api/sas/v1/token/ai4edataeuwest/ecmwf",
                minSize: nil
            )
            guard let response = try buffer.readJSONDecodable(TokenResponse.self),
                  !response.token.isEmpty,
                  let expiry = ISO8601DateFormatter().date(from: response.expiry), expiry > Date() else {
                throw Abort(.badGateway, reason: "Invalid ECMWF Azure SAS token response")
            }
            cached = (response.token, expiry)
            token = response.token
        }
        // Preserve the token's percent encoding, including its signature.
        return url + (components.percentEncodedQuery == nil ? "?" : "&") + token
    }
}
