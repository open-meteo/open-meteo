import Foundation
import Vapor

/**
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
        let domains: [String]?
        let newerThan: Int?
        let apikey: String
    }
    
    struct DownloadParams: Content {
        let file: String
        let apikey: String
    }
    
    func listHandler(_ req: Request) throws -> [SyncFileAttributes] {
        let params = try req.query.decode(ListParams.self)
        // TODO: apikey check
        return SyncFileAttributes.list(path: OpenMeteo.dataDictionary, filterDomains: params.domains, filterVariables: params.variables, newerThan: params.newerThan)
    }
    
    /// Serve files via nginx X-Accel using sendfile zero copy
    func downloadHandler(_ req: Request) throws -> Response {
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
    
    static func list(path: String, filterDomains: [String]?, filterVariables: [String]?, newerThan: Int?) -> [SyncFileAttributes] {
        let pathUrl = URL(fileURLWithPath: path, isDirectory: true)
        let resourceKeys = Set<URLResourceKey>([.nameKey, .isDirectoryKey, .contentModificationDateKey, .fileSizeKey])
        
        let filterDomains = filterDomains.map {
            $0.filter { $0 != "" && !$0.contains(".") }
        }
        
        let filterVariables = filterVariables.map {
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
                if !name.starts(with: "omfile-") {
                    directoryEnumerator.skipDescendants()
                }
                // Domain is not in the filtered listt
                if let filterDomains, !filterDomains.contains(where: { name.contains($0) }) {
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
            
            if let filterVariables, !filterVariables.contains(where: { name.contains($0) }) {
                // skip variable
                // always include HSURF?
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

struct SyncCommand: AsyncCommandFix {
    var help: String {
        return "Synchronise weather database from a remote server"
    }
    
    struct Signature: CommandSignature {
        @Option(name: "domains", help: "Model domains separated by coma")
        var domains: String?
        
        @Option(name: "variables", help: "Weather variables, separated by coma")
        var variables: String?
        
        @Option(name: "apikey", help: "API key for access")
        var apikey: String?
        
        // check-every-x-seconds
    }
    
    func run(using context: CommandContext, signature: Signature) async throws {
        let logger = context.application.logger
        
        let domains = signature.domains.map {
            $0.split(separator: ",").map(String.init)
        }
        
        let variables = signature.variables.map {
            $0.split(separator: ",").map(String.init)
        }
        
        let locals = SyncFileAttributes.list(path: OpenMeteo.dataDictionary, filterDomains: domains, filterVariables: variables, newerThan: nil)
        logger.info("Found \(locals.count) local files (\(locals.fileSize) MB)")
        
        guard let apikey = signature.apikey else {
            fatalError("Parameter apikey required")
        }
        
        let server = "http://api.open-meteo.com/"
        
        let response = try await context.application.client.get(URI("\(server)sync/list"), beforeSend: {
            try $0.query.encode(SyncController.ListParams(variables: variables, domains: domains, newerThan: nil, apikey: apikey))
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
    }
}

extension Array where Element == SyncFileAttributes {
    var fileSize: String {
        let totalSize = reduce(0, {$0 + $1.size}) / 1024 / 1024
        return "\(totalSize) MB"
    }
}
