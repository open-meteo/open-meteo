import Vapor

struct VersionCommand: Command {
    struct Signature: CommandSignature {}

    var help: String {
        "Print the Open-Meteo build version"
    }

    func run(using context: CommandContext, signature: Signature) throws {
        print("openmeteo-api \(BuildInfo.gitSHA)")
    }
}
