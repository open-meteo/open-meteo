import App
import Vapor

/// Increase open file limit
Process.setOpenFileLimitto64k()

/// Xcode sets current working directory to something in derived data
#if Xcode
let projectHome = String(#filePath[...#filePath.range(of: "/Sources/")!.lowerBound])
FileManager.default.changeCurrentDirectoryPath(projectHome)
#endif

var env = try Environment.detect()
try LoggingSystem.bootstrap(from: &env)
let app = try await Application.make(env)
try configure(app)
try await app.execute()
try await app.asyncShutdown()
