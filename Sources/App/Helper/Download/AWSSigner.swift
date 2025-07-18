import Foundation
import AsyncHTTPClient
import Vapor

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

    public func sign(request: inout HTTPClientRequest, body: Data?, now: Date = Date()) throws {
        guard let url = URL(string: request.url),
              let host = url.host else {
            throw SigningError.invalidURL
        }

        let method = request.method.rawValue
        let path = url.path(percentEncoded: true).isEmpty ? "/" : url.path(percentEncoded: true)
        let query = url.query(percentEncoded: true) ?? ""
        let canonicalQueryString = query.split(separator: "&")
            .sorted()
            .joined(separator: "&")

        let amzDate = now.iso8601DateTime
        let dateStamp = now.shortDate

        let payloadHash = (body ?? Data()).sha256Hex
        
        request.headers.add(name: "Host", value: host)
        request.headers.add(name: "x-amz-content-sha256", value: payloadHash)
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

    enum SigningError: Error {
        case invalidURL
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

fileprivate extension DataProtocol {
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
