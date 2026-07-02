import PackagePlugin
import Foundation

@main
struct GitVersionPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
        let generator = try context.tool(named: "GitVersionGenerator")
        let packageDirectory = context.package.directoryURL
        let outputFile = context.pluginWorkDirectoryURL.appendingPathComponent("BuildInfo.generated.swift")
        let inputFiles = gitInputFiles(packageDirectory: packageDirectory)

        return [
            .buildCommand(
                displayName: "Generate Git build version",
                executable: generator.url,
                arguments: [
                    packageDirectory.path(percentEncoded: false),
                    outputFile.path(percentEncoded: false)
                ],
                inputFiles: inputFiles,
                outputFiles: [
                    outputFile
                ]
            )
        ]
    }

    private func gitInputFiles(packageDirectory: URL) -> [URL] {
        let gitDirectory = packageDirectory.appendingPathComponent(".git")
        var inputFiles: [URL] = []

        appendIfFileExists(gitDirectory.appendingPathComponent("HEAD"), to: &inputFiles)
        appendIfFileExists(gitDirectory.appendingPathComponent("logs/HEAD"), to: &inputFiles)
        appendIfFileExists(gitDirectory.appendingPathComponent("packed-refs"), to: &inputFiles)

        appendGitRefFiles(gitDirectory.appendingPathComponent("refs/tags"), to: &inputFiles)

        return inputFiles
    }

    private func appendIfFileExists(_ url: URL, to inputFiles: inout [URL]) {
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else {
            return
        }
        inputFiles.append(url)
    }

    private func appendGitRefFiles(_ directory: URL, to inputFiles: inout [URL]) {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        for case let url as URL in enumerator {
            let resourceValues = try? url.resourceValues(forKeys: [.isRegularFileKey])
            if resourceValues?.isRegularFile == true {
                inputFiles.append(url)
            }
        }
    }
}
