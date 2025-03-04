import Foundation
import OmFileFormat
import Vapor


struct MergeYearlyCommand: Command {
    var help: String {
        return "Merge database chunks into yearly files"
    }
    
    struct Signature: CommandSignature {
        @Argument(name: "domain", help: "Domain e.g. ")
        var domain: String
        
        @Argument(name: "years", help: "A singe year or a range of years. E.g. 2017-2020")
        var years: String
        
        @Flag(name: "force", help: "Generate yearly file, even if it already exists")
        var force: Bool
        
        @Flag(name: "delete", help: "Delete the underlaying chunks")
        var delete: Bool
    }
    
    func run(using context: CommandContext, signature: Signature) throws {
        
    }
}
