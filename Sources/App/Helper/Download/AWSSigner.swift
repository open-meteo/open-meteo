import Foundation
import AsyncHTTPClient
import Vapor

extension CharacterSet {
    static let awsUriAllowed: CharacterSet = {
        var allowed = CharacterSet()

        // Add unreserved characters: A-Z a-z 0-9
        allowed.formUnion(.alphanumerics)

        // Add '-', '_', '.', '~'
        allowed.insert(charactersIn: "-_.~")

        return allowed
    }()
}

extension String {
    /// Add Percentage encoding, but keep alphanumerics and -_.~
    var awsPercentEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .awsUriAllowed) ?? self
    }
}

/// Sign AWS URLs with AWS4-HMAC-SHA256
public struct AWSSigner {
    public let accessKey: String
    public let secretKey: String
    public let region: String
    public let service: String

    public init(accessKey: String, secretKey: String, region: String, service: String) {
        self.accessKey = accessKey
        self.secretKey = secretKey
        self.region = region
        self.service = service
    }

    /// If `request.body` contains payload, please set header `x-amz-content-sha256` before
    public func sign(request: inout HTTPClientRequest, now: Date = Date()) throws {
        guard let components = URLComponents(string: request.url),
              let host = components.encodedHost else {
            throw SigningError.invalidURL
        }

        let method = request.method.rawValue
        let path = components.percentEncodedPath.isEmpty ? "/" : components.percentEncodedPath
        
        let canonicalQueryString = components.queryItems?
            .map({ "\($0.name)\($0.value.map{"=\($0.addingPercentEncoding(withAllowedCharacters: .awsUriAllowed)!)"} ?? "=")" })
            .sorted()
            .joined(separator: "&") ?? ""

        let amzDate = now.iso8601DateTime
        let dateStamp = now.shortDate
        
        request.headers.add(name: "Host", value: host)
        
        let payloadHash: String
        if let hash = request.headers.first(name: "x-amz-content-sha256") {
            payloadHash = hash
        } else {
            payloadHash = Data().sha256Hex
            request.headers.add(name: "x-amz-content-sha256", value: payloadHash)
        }
        
        request.headers.add(name: "x-amz-date", value: amzDate)
        
        let headersSorted = request.headers.sorted(by: {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        })
        let canonicalHeaders = headersSorted.map({
            (name,value) in "\(name.localizedLowercase):\(value.trimmingCharacters(in: .whitespaces))\n"
        }).joined()
        let signedHeaders = headersSorted.map(\.name.localizedLowercase).joined(separator: ";")

        let canonicalRequest = [
            method,
            path,
            canonicalQueryString,
            canonicalHeaders,
            signedHeaders,
            payloadHash
        ].joined(separator: "\n")

        let credentialScope = "\(dateStamp)/\(region)/\(service)/aws4_request"
        let stringToSign = [
            "AWS4-HMAC-SHA256",
            amzDate,
            credentialScope,
            (canonicalRequest.data(using: .utf8) ?? Data()).sha256Hex
        ].joined(separator: "\n")

        let signingKey = getSignatureKey(date: dateStamp)
        let signature = stringToSign.hmacSHA256(key: signingKey).hex

        let authorizationHeader = """
        AWS4-HMAC-SHA256 Credential=\(accessKey)/\(credentialScope), SignedHeaders=\(signedHeaders), Signature=\(signature)
        """

        request.headers.add(name: "Authorization", value: authorizationHeader)
    }
    
    public func verify(url: String, method: HTTPMethod, headers: HTTPHeaders, payloadHashSha256: String, now: Date = Date()) throws {
        guard let components = URLComponents(string: url),
              let host = components.encodedHost else {
            throw SigningError.invalidURL
        }

        guard let authorization = headers.first(name: "Authorization") else {
            throw SigningError.missingAuthorization
        }
        guard authorization.hasPrefix("AWS4-HMAC-SHA256 ") else {
            throw SigningError.unsupportedAuthorizationType
        }

        let authPayload = String(authorization.dropFirst("AWS4-HMAC-SHA256 ".count))
        var authFields: [String: String] = [:]
        for pair in authPayload.split(separator: ",") {
            let trimmed = pair.trimmingCharacters(in: .whitespaces)
            let parts = trimmed.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else {
                throw SigningError.invalidAuthorizationHeader
            }
            authFields[String(parts[0])] = String(parts[1])
        }

        guard let credential = authFields["Credential"],
              let signedHeadersString = authFields["SignedHeaders"],
              let expectedSignature = authFields["Signature"] else {
            throw SigningError.invalidAuthorizationHeader
        }

        let credentialParts = credential.split(separator: "/")
        guard credentialParts.count == 5 else {
            throw SigningError.invalidCredentialScope
        }
        guard String(credentialParts[0]) == accessKey else {
            throw SigningError.invalidAccessKey
        }
        let dateStamp = String(credentialParts[1])
        guard String(credentialParts[2]) == region,
              String(credentialParts[3]) == service,
              String(credentialParts[4]) == "aws4_request" else {
            throw SigningError.invalidCredentialScope
        }

        guard let amzDate = headers.first(name: "x-amz-date") else {
            throw SigningError.missingXAmzDate
        }
        guard amzDate.count >= 8, String(amzDate.prefix(8)) == dateStamp else {
            throw SigningError.invalidCredentialScope
        }
        guard let requestDate = Date.awsIso8601DateTime(amzDate) else {
            throw SigningError.invalidXAmzDate
        }
        if abs(requestDate.timeIntervalSince(now)) > 15 * 60 {
            throw SigningError.requestDateOutOfRange
        }

        guard let headerPayloadHash = headers.first(name: "x-amz-content-sha256") else {
            throw SigningError.missingPayloadHash
        }
        guard headerPayloadHash.lowercased() == payloadHashSha256.lowercased() else {
            throw SigningError.payloadHashMismatch
        }

        let path = components.percentEncodedPath.isEmpty ? "/" : components.percentEncodedPath
        let canonicalQueryString = components.queryItems?
            .map({ "\($0.name)\($0.value.map{"=\($0.addingPercentEncoding(withAllowedCharacters: .awsUriAllowed)!)"} ?? "=")" })
            .sorted()
            .joined(separator: "&") ?? ""

        let signedHeaderNames = signedHeadersString
            .split(separator: ";")
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }

        var headerLookup: [String: String] = [:]
        for header in headers {
            let name = header.name.lowercased()
            if headerLookup[name] == nil {
                headerLookup[name] = header.value
            }
        }
        headerLookup["host"] = host

        let canonicalHeaders = try signedHeaderNames.map { name in
            guard let value = headerLookup[name] else {
                throw SigningError.missingSignedHeader(name)
            }
            return "\(name):\(value.trimmingCharacters(in: .whitespaces))\n"
        }.joined()

        let canonicalRequest = [
            method.rawValue,
            path,
            canonicalQueryString,
            canonicalHeaders,
            signedHeadersString,
            headerPayloadHash
        ].joined(separator: "\n")

        let credentialScope = "\(dateStamp)/\(region)/\(service)/aws4_request"
        let stringToSign = [
            "AWS4-HMAC-SHA256",
            amzDate,
            credentialScope,
            (canonicalRequest.data(using: .utf8) ?? Data()).sha256Hex
        ].joined(separator: "\n")

        let signingKey = getSignatureKey(date: dateStamp)
        let computedSignature = stringToSign.hmacSHA256(key: signingKey).hex
        guard computedSignature == expectedSignature else {
            throw SigningError.invalidSignature
        }
    }

    public enum SigningError: Error, Equatable {
        case invalidURL
        case missingAuthorization
        case unsupportedAuthorizationType
        case invalidAuthorizationHeader
        case invalidCredentialScope
        case invalidAccessKey
        case missingXAmzDate
        case invalidXAmzDate
        case requestDateOutOfRange
        case missingPayloadHash
        case payloadHashMismatch
        case missingSignedHeader(String)
        case invalidSignature
    }

    func getSignatureKey(date: String) -> HashedAuthenticationCode<SHA256> {
        let kDate = date.hmacSHA256(key: Data("AWS4\(secretKey)".utf8))
        let kRegion = region.hmacSHA256(key: kDate)
        let kService = service.hmacSHA256(key: kRegion)
        let kSigning = "aws4_request".hmacSHA256(key: kService)
        return kSigning
    }
}

fileprivate extension Date {
    static func awsIso8601DateTime(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        return formatter.date(from: value)
    }

    var iso8601DateTime: String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        return formatter.string(from: self)
    }
    
    var shortDate: String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: self)
    }
}

extension DataProtocol {
    var sha256Hex: String {
        let hash = SHA256.hash(data: self)
        return hash.map { String(format: "%02x", $0) }.joined()
    }
    
    var hex: String {
        return map { String(format: "%02x", $0) }.joined()
    }
}

fileprivate extension String {
    func hmacSHA256<D: ContiguousBytes>(key: D) -> HashedAuthenticationCode<SHA256> {
        let key = SymmetricKey(data: key)
        return self.withContiguousStorageIfAvailable({
            $0.withMemoryRebound(to: UInt8.self) {
                HMAC<SHA256>.authenticationCode(for: $0, using: key)
            }
        }) ?? HMAC<SHA256>.authenticationCode(for: Data(self.utf8), using: key)
    }
}

extension URLComponents {
    var withoutCredentials: URLComponents {
        var result = self
        result.user = nil
        result.password = nil
        return result
    }
}

extension HTTPClientRequest {
    /// Check for basic auth or S3 auth
    mutating func applyS3Credentials() throws {
        guard
            let components = URLComponents(string: url),
            let username = components.user,
            let password = components.password
        else {
            return
        }
        self.url = components.withoutCredentials.url!.absoluteString
        let signer = AWSSigner(accessKey: String(username), secretKey: String(password), region: "us-west-2", service: "s3")
        try signer.sign(request: &self)
    }
}
