import App
import Vapor

/// Xcode sets current working directory to something in derived data
#if Xcode
let projectHome = String(#filePath[...#filePath.range(of: "/Sources/")!.lowerBound])
FileManager.default.changeCurrentDirectoryPath(projectHome)
#endif

do {
    var env = try Environment.detect()
    try LoggingSystem.bootstrap(from: &env)
    let app = try await Application.make(env)
    Process.increaseOpenFileLimit(logger: app.logger)
    try configure(app)
    try await app.execute()
    try await app.asyncShutdown()
} catch let error as CommandError {
    fputs("\(error)\n", stderr)
} catch {
    let logger = Logger(label: "TopLevelError")
    logger.critical("Uncaught top-level error", metadata: [
        "type": "\(type(of: error))",
        "message": "\(error)"
    ])
    exit(1)
}
