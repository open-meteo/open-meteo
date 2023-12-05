import Foundation
import Vapor

/**
 Expose file `list` and `download` API to download weather database from another node.
 This is used generate time-series files on one node and run the API on another node.
 
 TODO
 - hash verification with .sha256 files (need to modify all downloader to generate hash files)
 - cleanup old files or set target size and delete all older files (different retention for pressure levels?)
 
 Nginx setting:
 ```
 location /data {
   internal;
   alias /var/lib/openmeteo-api/data;
 }
 ```
 */
struct SyncController: RouteCollection {
    static var syncApiKeys: [String.SubSequence] = Environment.get("API_SYNC_APIKEYS")?.split(separator: ",") ?? []
    
    func boot(routes: RoutesBuilder) throws {
        if Self.syncApiKeys.isEmpty {
            return
        }
        
        let group = routes.grouped("sync")
        group.get("list", use: self.listHandler)
        group.get("download", use: self.downloadHandler)
    }
    
    struct ListParams: Content {
        let filenames: [String]?
        let directories: [String]
        let newerThan: Int?
        let apikey: String
    }
    
    struct DownloadParams: Content {
        let file: String
        let apikey: String
        
        /// in megabytes per second
        let rate: Int?
    }
    
    func listHandler(_ req: Request) throws -> [SyncFileAttributes] {
        // API should only be used on the subdomain
        if req.headers[.host].contains(where: { $0.contains("open-meteo.com") && !$0.contains("api") }) {
            throw Abort.init(.notFound)
        }
        
        let params = try req.query.decode(ListParams.self)
        if !Self.syncApiKeys.contains(where: {$0 == params.apikey}) {
            throw SyncError.invalidApiKey
        }
        return SyncFileAttributes.list(path: OpenMeteo.dataDirectory, directories: params.directories, matchFilename: params.filenames, newerThan: params.newerThan)
    }
    
    /// Serve files via nginx X-Accel using sendfile zero copy
    func downloadHandler(_ req: Request) throws -> Response {
        // API should only be used on the subdomain
        if req.headers[.host].contains(where: { $0.contains("open-meteo.com") && !$0.contains("api") }) {
            throw Abort.init(.notFound)
        }
        
        let params = try req.query.decode(DownloadParams.self)
        if !Self.syncApiKeys.contains(where: {$0 == params.apikey}) {
            throw SyncError.invalidApiKey
        }
        let response = Response()
        if params.file.contains("..") {
            throw Abort(.forbidden)
        }
        response.headers.add(name: "X-Accel-Redirect", value: "/data/\(params.file)")
        // Bytes per second download speed limit. Set to 50 MB/s.
        response.headers.add(name: "X-Accel-Limit-Rate", value: "\((params.rate ?? 50)*1024*1024)")
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

struct SyncFileAttributes: Content {
    /// relative file with path `omfile-era5/temperature_234.om`
    let file: String
    let size: Int
    let time: Int
    
    /// Iterate through data directory and find all matching files
    static func list(path: String, directories: [String], matchFilename: [String]?, newerThan: Int?, alwaysInclude: [String] = ["HSURF.om", "soil_type.om"]) -> [SyncFileAttributes] {
        let pathUrl = URL(fileURLWithPath: path, isDirectory: true)
        let resourceKeys = Set<URLResourceKey>([.nameKey, .isDirectoryKey, .contentModificationDateKey, .fileSizeKey])
        
        let directories = directories.filter { $0 != "" && !$0.contains(".") }
        
        let matchFilename = matchFilename.map {
            $0.filter { $0 != "" && !$0.contains(".") }
        }
        
        guard let directoryEnumerator = FileManager.default.enumerator(at: pathUrl, includingPropertiesForKeys: Array(resourceKeys), options: .skipsHiddenFiles) else {
            fatalError("No files in \(path)")
        }
        
        var directory = ""
        var files: [Self] = []
        
        for case let fileURL as URL in directoryEnumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: resourceKeys),
                let isDirectory = resourceValues.isDirectory,
                let name = resourceValues.name, !name.contains("~") else {
                    continue
            }
            
            if isDirectory {
                directory = name
                // Domain is not in the filtered listt
                if !directories.contains(where: {
                    if $0.hasSuffix("*") {
                        return name.starts(with: $0.dropLast(1))
                    }
                    if $0.hasPrefix("*") {
                        return name.hasSuffix($0.dropFirst(1))
                    }
                    return $0 == name
                }) {
                    directoryEnumerator.skipDescendants()
                }
                continue
            }
                        
            guard
                directoryEnumerator.level == 2,
                let size = resourceValues.fileSize,
                let modificationTime = (resourceValues.contentModificationDate?.timeIntervalSince1970).map(Int.init) else {
                continue
            }
            
            if alwaysInclude.contains(name) {
                files.append(SyncFileAttributes(file: "\(directory)/\(name)", size: size, time: modificationTime))
                continue
            }
            
            if let matchFilename, !matchFilename.contains(where: { name.contains($0) }) {
                continue
            }
            
            if let newerThan, modificationTime < newerThan {
                continue
            }
            files.append(SyncFileAttributes(file: "\(directory)/\(name)", size: size, time: modificationTime))
        }
        return files
    }
}

/**
 Command to download weather database fom another node
 */
struct SyncCommand: AsyncCommand {
    var help: String {
        return "Synchronise weather database from a remote server"
    }
    
    struct Signature: CommandSignature {
        @Argument(name: "domains", help: "Model domains directories separated by coma. Supports multiple servers separated by semicolon;")
        var domains: String
        
        @Option(name: "variables", help: "Weather variables, separated by coma")
        var variables: String?
        
        @Option(name: "apikey", help: "API key for access")
        var apikey: String?
        
        @Option(name: "server", help: "Server base URL. Default http://api.open-meteo.com/. Supports multiple servers separated by semicolon;")
        var server: String?
        
        @Option(name: "rate", help: "Transferrate in megabytes per second")
        var rate: Int?
        
        @Option(name: "max-age-days", help: "Maximum age of synchronised files. Default unlimited.")
        var maxAgeDays: Int?
        
        @Option(name: "repeat-interval", help: "If set, check for new files every specified amount of seconds.")
        var repeatInterval: Int?
    }
    
    func run(using context: CommandContext, signature: Signature) async throws {
        let logger = context.application.logger
        
        disableIdleSleep()
        
        let serverSet = (signature.server ?? "http://api.open-meteo.com/").split(separator: ";")
        for server in serverSet {
            guard server.last == "/" else {
                fatalError("Server URL must end with a '/'.")
            }
        }
        let maxAgeDays = signature.maxAgeDays ?? 9000
        var newerThan = [Int](repeating: Timestamp.now().add(-24 * 3600 * maxAgeDays).timeIntervalSince1970, count: serverSet.count)
        
        let curl = Curl(logger: logger, client: context.application.dedicatedHttpClient, retryError4xx: false)
        
        let domainSet = signature.domains.split(separator: ";").map(
            {$0.split(separator: ",").map(String.init)}
        )
        let variableSet = signature.variables.map {
            $0.split(separator: ";").map(
                {$0.split(separator: ",").map(String.init)}
            )
        }
        guard serverSet.count == domainSet.count else {
            fatalError("number of servers and domain sets must be the same")
        }
        
        while true {
            for i in serverSet.indices {
                let server = serverSet[i]
                let domains = domainSet[i]
                let variables = variableSet.map { $0[i] }
                
                let locals = SyncFileAttributes.list(path: OpenMeteo.dataDirectory, directories: domains, matchFilename: variables, newerThan: newerThan[i])
                logger.info("Found \(locals.count) local files (\(locals.fileSize))")
                
                guard let apikey = signature.apikey else {
                    fatalError("Parameter apikey required")
                }
                curl.setDeadlineIn(minutes: 30)
                
                var request = ClientRequest(method: .GET, url: URI("\(server)sync/list"))
                let params = SyncController.ListParams(filenames: variables, directories: domains, newerThan: newerThan[i], apikey: apikey)
                try request.query.encode(params)
                let response = try await curl.downloadInMemoryAsync(url: request.url.string, minSize: nil)
                let decoder = try ContentConfiguration.global.requireDecoder(for: .jsonAPI)
                let remotes = try decoder.decode([SyncFileAttributes].self, from: response, headers: [:])
                logger.info("Found \(remotes.count) remote files (\(remotes.fileSize))")
                
                // compare remote file to local files
                let toDownload = remotes.filter { remote in
                    let hasUpToDateFile = locals.contains(where: { $0.file == remote.file && $0.time >= remote.time })
                    return !hasUpToDateFile
                }
                
                logger.info("Downloading \(toDownload.count) files (\(toDownload.fileSize))")
                let progress = TransferAmountTracker(logger: logger, totalSize: toDownload.reduce(0, {$0 + $1.size}))
                for download in toDownload {
                    curl.setDeadlineIn(minutes: 30)
                    let startBytes = curl.totalBytesTransfered
                    var client = ClientRequest(url: URI("\(server)sync/download"))
                    try client.query.encode(SyncController.DownloadParams(file: download.file, apikey: apikey, rate: signature.rate))
                    let localFile = "\(OpenMeteo.dataDirectory)/\(download.file)"
                    let localDir = String(localFile[localFile.startIndex ..< localFile.lastIndex(of: "/")!])
                    try FileManager.default.createDirectory(atPath: localDir, withIntermediateDirectories: true)
                    // TODO sha256 hash integration check
                    
                    try await curl.download(url: client.url.string, toFile: localFile, bzip2Decode: false)
                    progress.add(curl.totalBytesTransfered - startBytes)
                }
                newerThan[i] = toDownload.max(by: { $0.time > $1.time })?.time ?? newerThan[i]
            }
            guard let repeatInterval = signature.repeatInterval else {
                break
            }
            try await Task.sleep(nanoseconds: UInt64(repeatInterval * 1_000_000_000))
        }
        curl.printStatistics()
    }
}

extension Array where Element == SyncFileAttributes {
    var fileSize: String {
        let totalSize = reduce(0, {$0 + $1.size})
        return totalSize.bytesHumanReadable
    }
}
