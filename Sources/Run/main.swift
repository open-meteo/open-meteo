import App
import Vapor

/// Increase open file limit
Process.setOpenFileLimitto64k()

/// Xcode sets current working directory to something in derived data
#if Xcode
let projectHome = String(#file[...#file.range(of: "/Sources/")!.lowerBound])
FileManager.default.changeCurrentDirectoryPath(projectHome)
#endif


var env = try Environment.detect()
try LoggingSystem.bootstrap(from: &env)
let app = Application(env)
defer { app.shutdown() }
try configure(app)
try app.run()
