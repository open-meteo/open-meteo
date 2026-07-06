import PackagePlugin
import Foundation

@main
struct GitVersionPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
        let generator = try context.tool(named: "GitVersionGenerator")
        let outputFile = context.pluginWorkDirectoryURL.appendingPathComponent("BuildInfo.generated.swift")

        return [
            .buildCommand(
                displayName: "Generate Git build version",
                executable: generator.url,
                arguments: [
                    outputFile.path(percentEncoded: false),
                    environment("GITHUB_SHA"),
                    environment("GITHUB_REF_TYPE"),
                    environment("GITHUB_REF_NAME"),
                    environment("GITHUB_HEAD_REF")
                ],
                inputFiles: [
                    context.package.directoryURL.appendingPathComponent("Package.swift")
                ],
                outputFiles: [
                    outputFile
                ]
            )
        ]
    }

    private func environment(_ key: String) -> String {
        ProcessInfo.processInfo.environment[key] ?? ""
    }
}
