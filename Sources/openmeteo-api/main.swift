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

// Use only 1 thread for NIO, to maybe reduce download issues in gfs/hrrrr
let cores = env.arguments.count >= 2 && env.arguments[1].starts(with: "download") ? 1 : System.coreCount

let app = Application(env, .shared(MultiThreadedEventLoopGroup(numberOfThreads: cores)))
defer { app.shutdown() }
try configure(app)
try app.run()
