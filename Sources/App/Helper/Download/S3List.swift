import AsyncHTTPClient
import Foundation
import Vapor


enum S3List {
    /// https://docs.aws.amazon.com/AmazonS3/latest/API/API_ListObjectsV2.html
    struct ListV2Query: Codable {
        let list_type: Int
        let delimiter: String
        let prefix: String
        let apikey: String?
        let continuation_token: String?

        enum CodingKeys: String, CodingKey {
            case list_type = "list-type"
            case delimiter
            case prefix
            case apikey
            case continuation_token = "continuation-token"
        }
    }

    struct ListV2File {
        let name: String
        let modificationTime: Timestamp
        let fileSize: Int
        let eTag: String
    }

    /// Use the AWS ListObjectsV2 to list files and directories inside a bucket with a prefix. No support more than 1000 objects yet
    static func s3list(context: OmFileSystemS3.ServerContext, prefix: String, apikey: String?, deadLineHours: Double) async throws -> (files: [S3List.ListV2File], directories: [String]) {
        var allFiles: [S3List.ListV2File] = []
        var allDirectories: [String] = []
        var continuation: String? = nil
        let logger = context.logger
        while true {
            var url = "\(context.server)?list-type=2&delimiter=%2F&prefix=\(prefix.awsPercentEncoded)"
            if let continuation {
                url += "&continuation-token=\(continuation.awsPercentEncoded)"
            }
            if let apikey {
                url += "&apikey=\(apikey.awsPercentEncoded)"
            }
            let request = HTTPClientRequest(url: url)

            var response = try await context.client.executeRetryAndCollect(request, logger: logger, upTo: 50 * 1024 * 1024, timeoutPerRequest: .seconds(90))
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
                return S3List.ListV2File(name: String(name), modificationTime: modificationTime, fileSize: fileSize, eTag: String(eTag))
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


extension StringProtocol {
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
    
    /// Interpret the given string as XML and get the first key
    func xmlFirstIgnoreAttributes(_ section: StaticString) -> SubSequence? {
        guard let startTag = range(of: "<\(section)", range: startIndex..<endIndex), let start = self[startTag.upperBound...].firstIndex(of: ">"), self.index(after: start) <= endIndex else {
            return nil
        }
        guard let end = range(of: "</\(section)>", range: self.index(after: start)..<endIndex) else {
            return nil
        }
        return self[self.index(after: start)..<end.lowerBound]
    }
}
