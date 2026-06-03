import AsyncHTTPClient
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
        let modificationTime: Date
        let fileSize: Int
    }
}


extension Curl {
    /// Use the AWS ListObjectsV2 to list files and directories inside a bucket with a prefix. No support more than 1000 objects yet
    func s3list(server: String, prefix: String, apikey: String?, deadLineHours: Double) async throws -> (files: [S3List.ListV2File], directories: [String]) {
        var allFiles: [S3List.ListV2File] = []
        var allDirectories: [String] = []
        var continuation: String? = nil
        while true {
            var request = ClientRequest(method: .GET, url: URI("\(server)"))
            let params = S3List.ListV2Query(list_type: 2, delimiter: "/", prefix: prefix, apikey: apikey, continuation_token: continuation)
            try request.query.encode(params)
            var response = try await downloadInMemoryAsync(url: request.url.string, minSize: nil, deadLineHours: deadLineHours, quiet: true)
            guard let body = response.readString(length: response.readableBytes) else {
                return (allFiles, allDirectories)
            }
            
            let files = body.xmlSection("Contents").map {
                guard let name = $0.xmlFirst("Key"),
                      let modificationTimeString = $0.xmlFirst("LastModified"),
                      let modificationTime = DateFormatter.awsS3DateTime.date(from: String(modificationTimeString)),
                      let fileSizeString = $0.xmlFirst("Size"),
                      let fileSize = Int(fileSizeString)
                else {
                    fatalError()
                }
                return S3List.ListV2File(name: String(name), modificationTime: modificationTime, fileSize: fileSize)
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
    func xmlSection(_ section: String) -> AnySequence<SubSequence> {
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
    func xmlFirst(_ section: String) -> SubSequence? {
        guard let start = range(of: "<\(section)>", range: startIndex..<endIndex) else {
            return nil
        }
        guard let end = range(of: "</\(section)>", range: start.upperBound..<endIndex) else {
            return nil
        }
        return self[start.upperBound..<end.lowerBound]
    }
}
