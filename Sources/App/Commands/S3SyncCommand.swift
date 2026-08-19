import Foundation
import Vapor

/// Synchronize a local directory to an S3-compatible server.
struct S3SyncCommand: AsyncCommand {
    var help: String {
        "Synchronize a local directory to an S3-compatible server."
    }

    struct Signature: CommandSignature {
        @Argument(name: "local-dir", help: "Local directory to upload recursively.")
        var localDirectory: String

        @Argument(name: "remote-server", help: "S3-compatible server or bucket URL.")
        var remoteServer: String

        @Argument(name: "base-path", help: "Remote object prefix for the local directory.")
        var basePath: String
    }

    func run(using context: CommandContext, signature: Signature) async throws {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: signature.localDirectory, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw S3SyncCommandError.localDirectoryNotFound(signature.localDirectory)
        }

        let remoteServer = signature.remoteServer.s3UploadUrlPrefix
        context.application.logger.info(
            "Synchronizing \(signature.localDirectory) to \(remoteServer.stripHttpPassword()) with base path \(signature.basePath)"
        )

        disableIdleSleep()
        try await S3Uploader.uploadSync(
            client: context.application.http1Client,
            localDirectory: signature.localDirectory,
            server: remoteServer,
            basePath: signature.basePath
        )
    }
}

private enum S3SyncCommandError: Error, CustomStringConvertible {
    case localDirectoryNotFound(String)

    var description: String {
        switch self {
        case .localDirectoryNotFound(let path):
            return "Local directory does not exist or is not a directory: \(path)"
        }
    }
}
