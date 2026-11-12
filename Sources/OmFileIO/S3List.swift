import AsyncHTTPClient
import Foundation
import Logging
import NIOCore
import OmTime

public enum S3List {
    /// https://docs.aws.amazon.com/AmazonS3/latest/API/API_ListObjectsV2.html
    public struct ListV2Query: Codable {
        public let list_type: Int
        public let delimiter: String
        public let prefix: String
        public let apikey: String?
        public let continuation_token: String?

        enum CodingKeys: String, CodingKey {
            case list_type = "list-type"
            case delimiter
            case prefix
            case apikey
            case continuation_token = "continuation-token"
        }
    }

    public struct ListV2File: Sendable {
        public let name: String
        public let modificationTime: Timestamp
        public let fileSize: Int
        public let eTag: String
    }

    /// List files and directories with AWS ListObjectsV2, following all continuation pages.
    /// Pass an empty delimiter to list all objects recursively under the prefix.
    /// The retry deadline is shared across all pages; an in-flight attempt may finish after it.
    public static func s3list(server: String, client: HTTPClient, logger: Logger, prefix: String, apikey: String?, deadLineHours: Double, delimiter: String = "/", timeoutPerRequest: TimeAmount = .seconds(90)) async throws -> (files: [S3List.ListV2File], directories: [String]) {
        let deadline = Date.hours(deadLineHours)
        var allFiles: [S3List.ListV2File] = []
        var allDirectories: [String] = []
        var continuation: String? = nil
        while true {
            try Task.checkCancellation()
            guard Date() < deadline else {
                throw CurlError.timeoutReached
            }
            var url = "\(server)?list-type=2&delimiter=\(delimiter.awsPercentEncoded)&prefix=\(prefix.awsPercentEncoded)"
            if let continuation {
                url += "&continuation-token=\(continuation.awsPercentEncoded)"
            }
            if let apikey {
                url += "&apikey=\(apikey.awsPercentEncoded)"
            }
            let request = HTTPClientRequest(url: url)

            var response = try await client.executeRetryAndCollect(request, logger: logger, upTo: 50 * 1024 * 1024, deadline: deadline, timeoutPerRequest: timeoutPerRequest)
            guard let body = response.readString(length: response.readableBytes) else {
                return (allFiles, allDirectories)
            }

            let files = try body.xmlSection("Contents").map {
                guard let name = $0.xmlFirst("Key") else {
                    fatalError("Failed to get <Key>")
                }
                guard let modificationTime = try $0.xmlFirst("LastModified")?.parseXmlS3Date() else {
                    fatalError("Failed to get LastModified date")
                }
                guard let fileSizeString = $0.xmlFirst("Size"), let fileSize = Int(fileSizeString) else {
                    fatalError("Failed to get Size")
                }
                /// eTags are quoted like `<ETag>&quot;705802db9a8f7523eef48c8752b6ae39&quot;</ETag>`
                guard let eTag = $0.xmlFirst("ETag")?.dropFirst(6).dropLast(6) else {
                    fatalError("Failed to get ETag")
                }
                return S3List.ListV2File(name: String(name), modificationTime: modificationTime, fileSize: fileSize, eTag: "\"\(eTag)\"")
            }
            let directories = body.xmlSection("CommonPrefixes").map {
                guard let prefix = $0.xmlFirst("Prefix") else {
                    fatalError()
                }
                return String(prefix)
            }
            allFiles.append(contentsOf: files)
            allDirectories.append(contentsOf: directories)

            // Check if more files are available
            if body.contains("<IsTruncated>true</IsTruncated>"),
                let token = body.xmlFirst("NextContinuationToken") {
                continuation = String(token)
            } else {
                break
            }
        }
        return (allFiles, allDirectories)
    }
}


public extension StringProtocol {
    /// Interpret the given string as XML and iterate over a list of keys
    func xmlSection(_ section: StaticString) -> AnySequence<SubSequence> {
        return AnySequence<SubSequence> { () -> AnyIterator<SubSequence> in
            var pos = startIndex
            return AnyIterator<SubSequence> {
                guard let start = range(of: "<\(section)>", range: pos..<endIndex) else {
                    return nil
                }
                guard let end = range(of: "</\(section)>", range: start.upperBound..<endIndex) else {
                    return nil
                }
                let substr = self[start.upperBound..<end.lowerBound]
                pos = end.upperBound
                return substr
            }
        }
    }

    /// Interpret the given string as XML and get the first key
    func xmlFirst(_ section: StaticString) -> SubSequence? {
        guard let start = range(of: "<\(section)>", range: startIndex..<endIndex) else {
            return nil
        }
        guard let end = range(of: "</\(section)>", range: start.upperBound..<endIndex) else {
            return nil
        }
        return self[start.upperBound..<end.lowerBound]
    }
}
