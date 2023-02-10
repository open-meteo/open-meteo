import Foundation
import Vapor


enum ExportDomain: String, CaseIterable {
    case CMCC_CM2_VHR4
}

struct ExportCommand: AsyncCommandFix {
    var help: String {
        return "Export to dataset to NetCDF"
    }
    
    struct Signature: CommandSignature {
        @Argument(name: "domains", help: "Model domain")
        var domain: String
    }
    
    func run(using context: CommandContext, signature: Signature) async throws {
        let domain = try ExportDomain.load(rawValue: signature.domain)
    }
}
