import PackagePlugin

@main
struct GitVersionPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
        let generator = try context.tool(named: "GitVersionGenerator")
        let packageDirectory = context.package.directoryURL
        let outputFile = context.pluginWorkDirectoryURL.appendingPathComponent("BuildInfo.generated.swift")

        return [
            .buildCommand(
                displayName: "Generate Git build version",
                executable: generator.url,
                arguments: [
                    packageDirectory.path(percentEncoded: false),
                    outputFile.path(percentEncoded: false)
                ],
                inputFiles: [
                    packageDirectory.appendingPathComponent(".git/HEAD"),
                    packageDirectory.appendingPathComponent(".git/logs/HEAD")
                ],
                outputFiles: [
                    outputFile
                ]
            )
        ]
    }
}
