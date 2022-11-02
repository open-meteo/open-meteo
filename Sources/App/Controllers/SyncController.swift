import Foundation
import Vapor

/**
 TODO
 - hash verification, xattr vs .sha256 files -> .sha files might work better
 - case: file is modified while downloading... get hash again?
 */
struct SyncController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let group = routes.grouped("sync")
        group.get("list", use: self.listHandler)
        group.get("download", use: self.downloadHandler)
    }
    
    struct Params: Content {
        let variables: String?
        let domains: String?
        let newerThan: Double?
        let apikey: String
    }
    
    func listHandler(_ req: Request) throws -> [SyncFileAttributes] {
        let params = try req.query.decode(Params.self)
        return SyncFileAttributes.list(path: OpenMeteo.dataDictionary, filterDomains: params.domains, filterVariables: params.variables, newerThan: params.newerThan)
    }
    
    func downloadHandler(_ req: Request) throws -> Response {
        fatalError()
    }
}

struct SyncFileAttributes: Content {
    let directory: String
    let name: String
    let time: Double
    
    static func list(path: String, filterDomains: String?, filterVariables: String?, newerThan: Double?) -> [SyncFileAttributes] {
        
        let pathUrl = URL(fileURLWithPath: path, isDirectory: true)
        let resourceKeys = Set<URLResourceKey>([.nameKey, .isDirectoryKey, .contentModificationDateKey])
        
        let filterDomains = filterDomains.map {
            $0.split(separator: ",").filter {
                $0 != "" && !$0.contains(".")
            }
        }
        
        let filterVariables = filterVariables.map {
            $0.split(separator: ",").filter {
                $0 != "" && !$0.contains(".")
            }
        }
        
        guard let directoryEnumerator = FileManager.default.enumerator(at: pathUrl, includingPropertiesForKeys: Array(resourceKeys), options: .skipsHiddenFiles) else {
            fatalError("No files in \(path)")
        }
        
        var directory = ""
        var files: [Self] = []
        
        for case let fileURL as URL in directoryEnumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: resourceKeys),
                let isDirectory = resourceValues.isDirectory,
                let name = resourceValues.name else {
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
                let modificationTime = resourceValues.contentModificationDate?.timeIntervalSince1970 else {
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
            files.append(SyncFileAttributes(directory: directory, name: name, time: modificationTime))
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
        let local = SyncFileAttributes.list(path: OpenMeteo.dataDictionary, filterDomains: signature.domains, filterVariables: signature.variables, newerThan: nil)
        
        guard let apikey = signature.apikey else {
            fatalError("Parameter apikey required")
        }
                
        let query = SyncController.Params(variables: signature.variables, domains: signature.domains, newerThan: nil, apikey: apikey)
        
        let response = try await context.application.client.get(URI("http://api.open-meteo.com/sync/list"), beforeSend: { try $0.query.encode(query) })
        
        let remote = try response.content.decode([SyncFileAttributes].self)
        
        // compare remote to local
        
        // download differences
        // download hash, download file (use content-length + modification time)
    }
}
