import Foundation
import Vapor

/**
 Expose file `list` and `download` API to download weather database from another node.
 This is used generate time-series files on one node and run the API on another node.
 
 TODO
 - hash verification, xattr vs .sha256 files -> .sha files might work better
 - case: file is modified while downloading... get hash again?
 
 Nginx setting:
 ```
 location /data {
   internal;
   alias /var/lib/openmeteo-api/data;
 }
 ```
 */
struct SyncController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let group = routes.grouped("sync")
        group.get("list", use: self.listHandler)
        group.get("download", use: self.downloadHandler)
    }
    
    struct ListParams: Content {
        let variables: [String]?
        let domains: [String]
        let newerThan: Int?
        let apikey: String
    }
    
    struct DownloadParams: Content {
        let file: String
        let apikey: String
    }
    
    func listHandler(_ req: Request) throws -> [SyncFileAttributes] {
        // API should only be used on the subdomain
        if req.headers[.host].contains(where: { $0.contains("open-meteo.com") && !$0.starts(with: "api.") }) {
            throw Abort.init(.notFound)
        }
        
        let params = try req.query.decode(ListParams.self)
        // TODO: apikey check
        return SyncFileAttributes.list(path: OpenMeteo.dataDictionary, directories: params.domains, matchFilename: params.variables, newerThan: params.newerThan)
    }
    
    /// Serve files via nginx X-Accel using sendfile zero copy
    func downloadHandler(_ req: Request) throws -> Response {
        // API should only be used on the subdomain
        if req.headers[.host].contains(where: { $0.contains("open-meteo.com") && !$0.starts(with: "api.") }) {
            throw Abort.init(.notFound)
        }
        
        let params = try req.query.decode(DownloadParams.self)
        // TODO: apikey check
        let response = Response()
        if params.file.contains("..") {
            throw Abort(.forbidden)
        }
        response.headers.add(name: "X-Accel-Redirect", value: "/data/\(params.file)")
        // Bytes per second download speed limit. Set to 50 MB/s.
        response.headers.add(name: "X-Accel-Limit-Rate", value: "\(50*1024*1024)")
        return response
    }
}

struct SyncFileAttributes: Content {
    /// relative file with path `omfile-era5/temperature_234.om`
    let file: String
    let size: Int
    let time: Int
    
    static func list(path: String, directories: [String], matchFilename: [String]?, newerThan: Int?, alwaysInclude: [String] = ["HSURF.om", "init.txt"]) -> [SyncFileAttributes] {
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
                if !directories.contains(name) {
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
struct SyncCommand: AsyncCommandFix {
    var help: String {
        return "Synchronise weather database from a remote server"
    }
    
    struct Signature: CommandSignature {
        @Argument(name: "domains", help: "Model domains directories separated by coma")
        var domains: String
        
        @Option(name: "variables", help: "Weather variables, separated by coma")
        var variables: String?
        
        @Option(name: "apikey", help: "API key for access")
        var apikey: String?
        
        @Option(name: "server", help: "Server base URL. Default http://api.open-meteo.com/")
        var server: String?
        
        @Option(name: "max-age-days", help: "Maximum age of synchronised files. Default 7 days.")
        var maxAgeDays: Int?
        
        @Option(name: "repreat-interval", help: "If set, check for new files every specified amount of seconds.")
        var repeatInterval: Int?
    }
    
    func run(using context: CommandContext, signature: Signature) async throws {
        let logger = context.application.logger
        
        let server = signature.server ?? "http://api.open-meteo.com/"
        let maxAgeDays = signature.maxAgeDays ?? 7
        var newerThan = Timestamp.now().add(-24 * 3600 * maxAgeDays).timeIntervalSince1970
        
        while true {
            let domains = signature.domains.split(separator: ",").map(String.init)
            
            let variables = signature.variables.map {
                $0.split(separator: ",").map(String.init)
            }
            
            let locals = SyncFileAttributes.list(path: OpenMeteo.dataDictionary, directories: domains, matchFilename: variables, newerThan: newerThan)
            logger.info("Found \(locals.count) local files (\(locals.fileSize) MB)")
            
            guard let apikey = signature.apikey else {
                fatalError("Parameter apikey required")
            }
            
            let response = try await context.application.client.get(URI("\(server)sync/list"), beforeSend: {
                try $0.query.encode(SyncController.ListParams(variables: variables, domains: domains, newerThan: newerThan, apikey: apikey))
            })
            
            let remotes = try response.content.decode([SyncFileAttributes].self)
            logger.info("Found \(remotes.count) remote files (\(remotes.fileSize) MB)")
            
            // compare remote file to local files
            let toDownload = remotes.filter { remote in
                let hasUpToDateFile = locals.contains(where: { $0.file == remote.file && $0.time >= remote.time })
                return !hasUpToDateFile
            }
            
            logger.info("Downloading \(toDownload.count) files (\(toDownload.fileSize) MB)")
            
            let curl = Curl(logger: logger)
            for download in toDownload {
                var client = ClientRequest()
                try client.query.encode(SyncController.DownloadParams(file: download.file, apikey: apikey))
                let localFile = "\(OpenMeteo.dataDictionary)/\(download.file)"
                let localFileTemp = "\(localFile)~"
                let localDir = String(localFile[localFile.startIndex ..< localFile.lastIndex(of: "/")!])
                try FileManager.default.createDirectory(atPath: localDir, withIntermediateDirectories: true)
                // TODO sha256 hash integration check
                
                try await curl.download(url: client.url.string, toFile: localFileTemp, client: context.application.http.client.shared)
                try FileManager.default.moveFileOverwrite(from: localFileTemp, to: localFile)
            }
            
            newerThan = toDownload.max(by: { $0.time > $1.time })?.time ?? newerThan
            guard let repeatInterval = signature.repeatInterval else {
                break
            }
            try await Task.sleep(nanoseconds: UInt64(repeatInterval * 1_000_000_000))
        }
    }
}

extension Array where Element == SyncFileAttributes {
    var fileSize: String {
        let totalSize = reduce(0, {$0 + $1.size}) / 1024 / 1024
        return "\(totalSize) MB"
    }
}
