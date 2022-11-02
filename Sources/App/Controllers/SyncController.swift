import Foundation
import Vapor

struct SyncController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let group = routes.grouped("sync")
        group.get("list", use: self.listHandler)
        group.get("download", use: self.downloadHandler)
    }
    
    func listHandler(req _: Request) throws -> Response {
        fatalError()
    }
    
    func downloadHandler(req _: Request) throws -> Response {
        fatalError()
    }
}

struct SyncCommand: Command {
    var help: String {
        return "Synchronise weather database from a remote server"
    }
    
    struct Signature: CommandSignature {
        @Argument(name: "domains", help: "Model domains separated by coma")
        var domains: String
        
        @Argument(name: "variables", help: "Weather variables, separated by coma")
        var variables: String
    }
    
    func run(using context: CommandContext, signature: Signature) throws {
        
    }
}
