import Vapor

struct VersionCommand: Command {
    struct Signature: CommandSignature {}

    var help: String {
        "Print the Open-Meteo build version"
    }

    func run(using context: CommandContext, signature: Signature) throws {
        let branch = BuildInfo.gitBranch ?? "unknown"
        let tag = BuildInfo.gitTag ?? "none"
        print("openmeteo-api sha=\(BuildInfo.gitSHA) branch=\(branch) tag=\(tag)")
    }
}
