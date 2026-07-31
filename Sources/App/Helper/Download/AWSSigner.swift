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

extension HMAC {
    mutating func update<T: StringProtocol>(_ string: T) {
        string.withContiguousStorageIfAvailable({
            $0.withMemoryRebound(to: UInt8.self) {
                update(data: $0)
            }
        }) ?? update(data: string.data(using: .utf8) ?? Data())
    }
}

extension SHA256 {
    mutating func update<T: StringProtocol>(_ string: T) {
        string.withContiguousStorageIfAvailable({
            $0.withMemoryRebound(to: UInt8.self) {
                update(data: $0)
            }
        }) ?? update(data: string.data(using: .utf8) ?? Data())
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

        let hostHeaderValue: String = {
            guard let port = components.port,
                  let scheme = components.scheme?.lowercased(),
                  !((scheme == "http" && port == 80) || (scheme == "https" && port == 443))
            else {
                return host
            }
            return "\(host):\(port)"
        }()

        let method = request.method.rawValue
        let path = components.percentEncodedPath.isEmpty ? "/" : components.percentEncodedPath
        
        let canonicalQueryString = components.queryItems?
            .map({ "\($0.name)\($0.value.map{"=\($0.addingPercentEncoding(withAllowedCharacters: .awsUriAllowed)!)"} ?? "=")" })
            .sorted()
            .joined(separator: "&") ?? ""

        let amzDate = now.iso8601DateTime
        let dateStamp = now.shortDate
        
        request.headers.replaceOrAdd(name: "Host", value: hostHeaderValue)
        
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
        
        let canonicalRequest = "\(method)\n\(path)\n\(canonicalQueryString)\n\(canonicalHeaders)\n\(signedHeaders)\n\(payloadHash)"

        let credentialScope = "\(dateStamp)/\(region)/\(service)/aws4_request"
        
        let stringToSign = "AWS4-HMAC-SHA256\n\(amzDate)\n\(credentialScope)\n\((canonicalRequest.data(using: .utf8) ?? Data()).sha256Hex)"

        let signingKey = getSignatureKey(date: dateStamp)
        let signature = stringToSign.hmacSHA256(key: signingKey).hex

        let authorizationHeader = """
        AWS4-HMAC-SHA256 Credential=\(accessKey)/\(credentialScope), SignedHeaders=\(signedHeaders), Signature=\(signature)
        """

        request.headers.add(name: "Authorization", value: authorizationHeader)
    }
    
    public func verify(url: String, method: HTTPMethod, headers: HTTPHeaders, payloadHashSha256: String, now: Date = Date()) throws {
        guard let parsedURL = ParsedVerificationURL(url: url) else {
            throw SigningError.invalidURL
        }

        guard let authorization = headers.first(name: "Authorization") else {
            throw SigningError.missingAuthorization
        }
        guard authorization.hasPrefix("AWS4-HMAC-SHA256 ") else {
            throw SigningError.unsupportedAuthorizationType
        }
        
        var canonicalRequestHash = SHA256()
        canonicalRequestHash.update(method.rawValue)
        canonicalRequestHash.update("\n")

        let authPayload = authorization.dropFirst("AWS4-HMAC-SHA256 ".count)
        guard let parsedAuth = Self.parseAuthorizationFields(authPayload) else {
            throw SigningError.invalidAuthorizationHeader
        }
        let credential = parsedAuth.credential
        let signedHeadersString = parsedAuth.signedHeadersString
        let expectedSignature = parsedAuth.expectedSignature

        guard let accessKeyEnd = credential.firstIndex(of: "/") else {
            throw SigningError.invalidCredentialScope
        }
        guard credential[..<accessKeyEnd] == accessKey else {
            throw SigningError.invalidAccessKey
        }

        let dateStart = credential.index(after: accessKeyEnd)
        guard dateStart < credential.endIndex,
              let dateEnd = credential[dateStart...].firstIndex(of: "/") else {
            throw SigningError.invalidCredentialScope
        }
        let dateStamp = credential[dateStart..<dateEnd]

        let regionStart = credential.index(after: dateEnd)
        guard regionStart < credential.endIndex,
              let regionEnd = credential[regionStart...].firstIndex(of: "/") else {
            throw SigningError.invalidCredentialScope
        }
        guard credential[regionStart..<regionEnd] == region else {
            throw SigningError.invalidCredentialScope
        }

        let serviceStart = credential.index(after: regionEnd)
        guard serviceStart < credential.endIndex,
              let serviceEnd = credential[serviceStart...].firstIndex(of: "/") else {
            throw SigningError.invalidCredentialScope
        }
        guard credential[serviceStart..<serviceEnd] == service else {
            throw SigningError.invalidCredentialScope
        }

        let terminalStart = credential.index(after: serviceEnd)
        guard terminalStart < credential.endIndex,
              credential[terminalStart...] == "aws4_request" else {
            throw SigningError.invalidCredentialScope
        }

        guard let amzDate = headers.first(name: "x-amz-date") else {
            throw SigningError.missingXAmzDate
        }
        guard amzDate.count >= 8, amzDate.prefix(8) == dateStamp else {
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
        guard headerPayloadHash.caseInsensitiveCompare(payloadHashSha256) == .orderedSame else {
            throw SigningError.payloadHashMismatch
        }

        let path = parsedURL.path
        canonicalRequestHash.update(path)
        canonicalRequestHash.update("\n")
        
        ParsedVerificationURL.updateCanonicalizeQueryHash(parsedURL.query, hash: &canonicalRequestHash)

        canonicalRequestHash.update("\n")
        
        try Self.updateCanonicalHeadersHash(
            signedHeadersString: signedHeadersString,
            headers: headers,
            host: parsedURL.host,
            hash: &canonicalRequestHash
        )
        canonicalRequestHash.update("\n")
        canonicalRequestHash.update(signedHeadersString)
        canonicalRequestHash.update("\n")
        canonicalRequestHash.update(headerPayloadHash)
        let canonicalRequestHashHex = canonicalRequestHash.finalize().hex

        let signingKey = getSignatureKey(date: dateStamp)
        var stringToSignHmac = HMAC<SHA256>(key: SymmetricKey(data: signingKey))
        stringToSignHmac.update("AWS4-HMAC-SHA256\n")
        stringToSignHmac.update(amzDate)
        stringToSignHmac.update("\n")
        stringToSignHmac.update(dateStamp)
        stringToSignHmac.update("/")
        stringToSignHmac.update(region)
        stringToSignHmac.update("/")
        stringToSignHmac.update(service)
        stringToSignHmac.update("/aws4_request\n")
        stringToSignHmac.update(canonicalRequestHashHex)
        let computedSignature = stringToSignHmac.finalize().hex
        guard computedSignature == expectedSignature else {
            throw SigningError.invalidSignature
        }
    }

    private static func parseAuthorizationFields(_ authPayload: Substring) -> (credential: Substring, signedHeadersString: Substring, expectedSignature: Substring)? {
        var credential: Substring?
        var signedHeadersString: Substring?
        var expectedSignature: Substring?

        var start = authPayload.startIndex
        while start < authPayload.endIndex {
            let comma = authPayload[start...].firstIndex(of: ",")
            let end = comma ?? authPayload.endIndex
            let pair = authPayload[start..<end].trimmingWhitespaceSubstring
            guard !pair.isEmpty, let equals = pair.firstIndex(of: "=") else {
                return nil
            }

            let key = pair[..<equals].trimmingWhitespaceSubstring
            let valueStart = pair.index(after: equals)
            let value = pair[valueStart...].trimmingWhitespaceSubstring
            guard !key.isEmpty else {
                return nil
            }

            if key == "Credential" {
                guard credential == nil else { return nil }
                credential = value
            } else if key == "SignedHeaders" {
                guard signedHeadersString == nil else { return nil }
                signedHeadersString = value
            } else if key == "Signature" {
                guard expectedSignature == nil else { return nil }
                expectedSignature = value
            } else {
                return nil
            }

            if let comma {
                start = authPayload.index(after: comma)
            } else {
                break
            }
        }

        guard let credential,
              let signedHeadersString,
              let expectedSignature else {
            return nil
        }
        return (credential, signedHeadersString, expectedSignature)
    }

    private static func updateCanonicalHeadersHash(signedHeadersString: Substring, headers: HTTPHeaders, host: Substring, hash: inout SHA256) throws {
        var start = signedHeadersString.startIndex
        while start < signedHeadersString.endIndex {
            let separator = signedHeadersString[start...].firstIndex(of: ";")
            let end = separator ?? signedHeadersString.endIndex
            let name = signedHeadersString[start..<end].trimmingWhitespaceSubstring
            let isHostHeader = name == "host"

            guard let value: Substring = (headers.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame })?.value).map({ Substring($0) })
                ?? (isHostHeader ? host : nil) else {
                throw SigningError.missingSignedHeader(String(name))
            }

            hash.update(name)
            hash.update(":")
            hash.update(value.trimmingWhitespaceSubstring)
            hash.update("\n")

            if let separator {
                start = signedHeadersString.index(after: separator)
            } else {
                break
            }
        }
    }

    private struct ParsedVerificationURL {
        let path: Substring
        let query: Substring?
        let host: Substring

        private static let rootPath: Substring = "/"[...]

        init?(url: String) {
            guard let schemeSeparator = url.range(of: "://") else {
                return nil
            }

            let authorityStart = schemeSeparator.upperBound
            let authorityEnd = url[authorityStart...].firstIndex(where: { $0 == "/" || $0 == "?" || $0 == "#" }) ?? url.endIndex
            guard authorityStart < authorityEnd else {
                return nil
            }

            let authority = url[authorityStart..<authorityEnd]
            host = authority.lastIndex(of: "@").map { authority[authority.index(after: $0)..<authority.endIndex] } ?? authority
            guard !host.isEmpty else {
                return nil
            }

            let pathAndQuery = url[authorityEnd..<url.endIndex]
            let fragmentStart = pathAndQuery.firstIndex(of: "#") ?? pathAndQuery.endIndex
            let withoutFragment = pathAndQuery[pathAndQuery.startIndex..<fragmentStart]

            if let queryStart = withoutFragment.firstIndex(of: "?") {
                let rawPath = withoutFragment[withoutFragment.startIndex..<queryStart]
                self.path = rawPath.isEmpty ? ParsedVerificationURL.rootPath : rawPath
                let queryStartIndex = withoutFragment.index(after: queryStart)
                self.query = queryStartIndex <= withoutFragment.endIndex ? withoutFragment[queryStartIndex..<withoutFragment.endIndex] : nil
            } else {
                self.path = withoutFragment.isEmpty ? ParsedVerificationURL.rootPath : withoutFragment
                self.query = nil
            }
        }

        /// TODO can be further optimised
        static func updateCanonicalizeQueryHash(_ query: Substring?, hash: inout SHA256) {
            guard let query else {
                return
            }

            var items: [String] = []
            items.reserveCapacity(8)

            for pair in query.split(separator: "&", omittingEmptySubsequences: false) {
                var item = String()
                item.reserveCapacity(pair.count + 2)

                if let equals = pair.firstIndex(of: "=") {
                    let rawName = pair[pair.startIndex..<equals]
                    let rawValue = pair[pair.index(after: equals)..<pair.endIndex]
                    appendCanonicalComponent(rawName, to: &item)
                    item.append("=")
                    appendCanonicalComponent(rawValue, to: &item)
                } else {
                    appendCanonicalComponent(pair, to: &item)
                    item.append("=")
                }

                items.append(item)
            }

            items.sort()
            let canonicalizeQuery = items.joined(separator: "&")
            hash.update(canonicalizeQuery)
        }

        private static func appendCanonicalComponent(_ component: Substring, to output: inout String) {
            let bytes = component.utf8
            var index = bytes.startIndex
            while index < bytes.endIndex {
                let byte = bytes[index]

                if byte == 37 { // %
                    let b1Index = bytes.index(after: index)
                    if b1Index < bytes.endIndex {
                        let b2Index = bytes.index(after: b1Index)
                        if b2Index < bytes.endIndex,
                           let hi = hexNibble(bytes[b1Index]),
                           let lo = hexNibble(bytes[b2Index]) {
                            let decoded = (hi << 4) | lo
                            appendCanonicalByte(decoded, to: &output)
                            index = bytes.index(after: b2Index)
                            continue
                        }
                    }
                }

                appendCanonicalByte(byte, to: &output)
                index = bytes.index(after: index)
            }
        }

        private static func appendCanonicalByte(_ byte: UInt8, to output: inout String) {
            let isUpperAZ = byte >= 65 && byte <= 90
            let isLowerAZ = byte >= 97 && byte <= 122
            let isDigit = byte >= 48 && byte <= 57
            let isAllowedSymbol = byte == 45 || byte == 95 || byte == 46 || byte == 126 // -_.~
            if isUpperAZ || isLowerAZ || isDigit || isAllowedSymbol {
                output.unicodeScalars.append(UnicodeScalar(Int(byte))!)
                return
            }

            output.append("%")
            output.unicodeScalars.append(UnicodeScalar(Int(upperHexDigit(byte >> 4)))!)
            output.unicodeScalars.append(UnicodeScalar(Int(upperHexDigit(byte & 0x0F)))!)
        }

        private static func hexNibble(_ byte: UInt8) -> UInt8? {
            switch byte {
            case 48...57: return byte - 48       // 0-9
            case 65...70: return byte - 55       // A-F
            case 97...102: return byte - 87      // a-f
            default: return nil
            }
        }

        private static func upperHexDigit(_ nibble: UInt8) -> UInt8 {
            return nibble < 10 ? (48 + nibble) : (55 + nibble)
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

    func getSignatureKey<T: StringProtocol>(date: T) -> HashedAuthenticationCode<SHA256> {
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

fileprivate extension StringProtocol {
    func hmacSHA256<D: ContiguousBytes>(key: D) -> HashedAuthenticationCode<SHA256> {
        let key = SymmetricKey(data: key)
        return self.withContiguousStorageIfAvailable({
            $0.withMemoryRebound(to: UInt8.self) {
                HMAC<SHA256>.authenticationCode(for: $0, using: key)
            }
        }) ?? HMAC<SHA256>.authenticationCode(for: Data(self.utf8), using: key)
    }
}

fileprivate extension StringProtocol {
    var trimmingWhitespaceSubstring: SubSequence {
        var start = startIndex
        var end = endIndex

        while start < end, self[start].isWhitespace {
            formIndex(after: &start)
        }

        while start < end {
            let beforeEnd = index(before: end)
            if self[beforeEnd].isWhitespace {
                end = beforeEnd
            } else {
                break
            }
        }

        return self[start..<end]
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
