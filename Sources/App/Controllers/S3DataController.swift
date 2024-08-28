import Foundation
import Vapor

/**
 Expose database as S3 endpoint. This can be used to pull data from one server to another. It is used only internally to transfer data between Open-Meteo API nodes. Note: This is only a limited implementation and not fully compatible.
 
 List example:
 `http://127.0.0.1:8080/?list-type=2&delimiter=/&prefix=data/cmc_gem_gdps/shortwave_radiation/&apikey=123`
 
 Download exmaple
 `http://127.0.0.1:8080/data/cmc_gem_gdps/shortwave_radiation/chunk_1430.om?apikey=123`
 
 TODO:
 - Actual S3 authentication with signatures instead of simple apikeys as URL query parameter. Not required at this stage.
 
 Nginx setting:
 ```
 location /data-internal {
   internal;
   alias /var/lib/openmeteo-api/data;
 }
 ```
 */
struct S3DataController: RouteCollection {
    static var syncApiKeys: [String.SubSequence] = Environment.get("API_SYNC_APIKEYS")?.split(separator: ",") ?? []
    static var nginxSendfilePrefix = Environment.get("NGINX_SENDFILE_PREFIX")
    
    func boot(routes: RoutesBuilder) throws {
        if Self.syncApiKeys.isEmpty {
            return
        }
        routes.get("", use: self.list)
        routes.get("data", "**", use: self.get)
    }
    
    /// https://docs.aws.amazon.com/AmazonS3/latest/API/API_ListObjectsV2.html
    struct S3ListV2: Codable {
        let list_type: Int
        let delimiter: String
        let prefix: String
        let apikey: String?
        
        enum CodingKeys: String, CodingKey {
            case list_type = "list-type"
            case delimiter
            case prefix
            case apikey
        }
    }
    
    struct S3ListV2File {
        let name: String
        let modificationTime: Date
        let fileSize: Int
    }
    
    struct DownloadParams: Codable {
        let apikey: String?
        /// in megabytes per second
        let rate: Int?
    }
    
    /// List all files in a specified directory
    func list(_ req: Request) async throws -> Response {
        let params = try req.query.decode(S3ListV2.self)
        guard let apikey = params.apikey, Self.syncApiKeys.contains(where: {$0 == apikey}) else {
            throw SyncError.invalidApiKey
        }
        
        let path = params.prefix.sanitisedPath
        guard params.list_type == 2, params.delimiter == "/",
              path.last == "/", path.starts(with: "data/") else {
            throw Abort(.forbidden)
        }
        
        let pathNoData = path[path.index(path.startIndex, offsetBy: 5)..<path.endIndex]
        let pathUrl = URL(fileURLWithPath: "\(OpenMeteo.dataDirectory)\(pathNoData)", isDirectory: true)
        let resourceKeys = Set<URLResourceKey>([.nameKey, .isDirectoryKey, .contentModificationDateKey, .fileSizeKey])
        
        guard let directoryEnumerator = FileManager.default.enumerator(at: pathUrl, includingPropertiesForKeys: Array(resourceKeys), options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]) else {
            throw Abort(.forbidden)
        }
        
        var files = [S3ListV2File]()
        var directories = [String]()
        for case let fileURL as URL in directoryEnumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: resourceKeys),
                  let isDirectory = resourceValues.isDirectory,
                  let name = resourceValues.name,
                  !name.contains("~")
            else {
                continue
            }
            if isDirectory {
                directories.append(name)
            } else {
                guard let modificationTime = resourceValues.contentModificationDate,
                      let fileSize = resourceValues.fileSize
                else {
                    continue
                }
                files.append(S3ListV2File(name: name, modificationTime: modificationTime, fileSize: fileSize))
            }
            
        }
        
        let dateFormat = DateFormatter.awsS3DateTime
        let filesXml = files.map {
            """
            <Contents>
                <Key>\(path)\($0.name)</Key>
                <LastModified>\(dateFormat.string(from: $0.modificationTime))</LastModified>
                <Size>\($0.fileSize)</Size>
                <StorageClass>STANDARD</StorageClass>
            </Contents>
            """
        }.joined(separator: "\n")
        let directoriesXml = directories.map {
            """
            <CommonPrefixes>
            <Prefix>\(path)\($0)/</Prefix>
            </CommonPrefixes>
            """
        }.joined(separator: "\n")
        
        var headers = HTTPHeaders()
        headers.add(name: .contentType, value: "application/xml")
        return Response(status: .ok, headers: headers, body: .init(string: """
        <?xml version="1.0" encoding="UTF-8"?>
        <ListBucketResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
            <Name>openmeteo</Name>
            <Prefix>\(path)</Prefix>
            <KeyCount>\(files.count + directories.count)</KeyCount>
            <MaxKeys>1000</MaxKeys>
            <Delimiter>/</Delimiter>
            <IsTruncated>false</IsTruncated>
            \(directoriesXml)
            \(filesXml)
        </ListBucketResult>
        """))
    }
    
    /// Serve file through nginx send file
    func get(_ req: Request) async throws -> Response {
        let params = try req.query.decode(DownloadParams.self)
        let path = req.url.path.sanitisedPath
        let isJson = path.hasSuffix(".json")
        if !isJson {
            /// Only require API keys for non-json calls
            guard let apikey = params.apikey, Self.syncApiKeys.contains(where: {$0 == apikey}) else {
                throw SyncError.invalidApiKey
            }
        }
        
        guard path.last != "/", path.starts(with: "/data/") else {
            throw Abort(.forbidden)
        }
        let pathNoData = path[path.index(path.startIndex, offsetBy: 6)..<path.endIndex]
        
        if let nginxSendfilePrefix = Self.nginxSendfilePrefix {
            let response = Response()
            //let response = req.fileio.streamFile(at: abspath)
            response.headers.add(name: "X-Accel-Redirect", value: "/\(nginxSendfilePrefix)/\(pathNoData)")
            if let rate = params.rate {
                // Bytes per second download speed limit
                response.headers.add(name: "X-Accel-Limit-Rate", value: "\((rate)*1024*1024)")
            }
            return response
        }
        let response = req.fileio.streamFile(at: "\(OpenMeteo.dataDirectory)\(pathNoData)")
        return response
    }
}


enum SyncError: AbortError {
    case invalidApiKey
    
    var status: NIOHTTP1.HTTPResponseStatus {
        switch self {
        case .invalidApiKey:
            return .unauthorized
        }
    }
}

fileprivate extension String {
    static var sanitisedPathCharacterSet = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890-_/").inverted
    
    /// Allow only alpha numerics, dash, underscore and slash
    var sanitisedPath: String {
        return trimmingCharacters(in: Self.sanitisedPathCharacterSet)
    }
}

extension DateFormatter {
    /// Format dates like `2023-11-14T04:32:17.000Z`
    static var awsS3DateTime = {
        let dateFormat = DateFormatter()
        dateFormat.dateFormat = "y-MM-dd'T'HH:mm:ss.SSS'Z'"
        return dateFormat
    }()
}
