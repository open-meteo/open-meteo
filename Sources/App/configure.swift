import Vapor
//import Leaf

struct OpenMeteo {
    /// Data directory with trailing slash
    static var dataDirectory = {
        if let dir = Environment.get("DATA_DIRECTORY") {
            return dir
        }
        return  "./data/"
    }()
    
    /// Temporary directory with trailing slash
    static var tempDirectory = {
        if let dir = Environment.get("TEMP_DIRECTORY") {
            return dir
        }
        if let dir = Environment.get("DATA_DIRECTORY") {
            return dir
        }
        return  "./data/"
    }()
}

extension Application {
    fileprivate struct HttpClientKey: StorageKey, LockKey {
        typealias Value = HTTPClient
    }
    
    /// Get dedicated HTTPClient instance with a dedicated threadpool
    var dedicatedHttpClient: HTTPClient {
        let lock = self.locks.lock(for: HttpClientKey.self)
        lock.lock()
        defer { lock.unlock() }
        if let existing = self.storage[HttpClientKey.self] {
            return existing
        }
        // try again with very high timeouts, so only the curl internal timers are used
        let configuration = HTTPClient.Configuration(
            redirectConfiguration: .follow(max: 5, allowCycles: false),
            timeout: .init(connect: .seconds(30), read: .minutes(5)),
            connectionPool: .init(idleTimeout: .minutes(10)))
        
        let new = HTTPClient(
            eventLoopGroupProvider: .shared(MultiThreadedEventLoopGroup(numberOfThreads: 1)),
            configuration: configuration,
            backgroundActivityLogger: logger)
        self.storage.set(HttpClientKey.self, to: new) {
            try $0.syncShutdown()
        }
        return new
    }
}

// configures your application
public func configure(_ app: Application) throws {
    TimeZone.ReferenceType.default = TimeZone(abbreviation: "GMT")!
    
    let corsConfiguration = CORSMiddleware.Configuration(
        allowedOrigin: .all,
        allowedMethods: [.GET, .POST, /*.PUT,*/ .OPTIONS /*, .DELETE, .PATCH*/],
        allowedHeaders: [.accept, .authorization, .contentType, .origin, .xRequestedWith, .userAgent, .accessControlAllowOrigin]
    )
    app.middleware.use(CORSMiddleware(configuration: corsConfiguration))
    app.middleware.use(ErrorMiddleware.default(environment: try .detect()))
    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    app.commands.use(BenchmarkCommand(), as: "benchmark")
    app.asyncCommands.use(DownloadIconCommand(), as: "download")
    app.asyncCommands.use(DownloadIconWaveCommand(), as: "download-iconwave")
    app.asyncCommands.use(DownloadEcmwfCommand(), as: "download-ecmwf")
    app.asyncCommands.use(DownloadEra5Command(), as: "download-era5")
    app.asyncCommands.use(DownloadDemCommand(), as: "download-dem")
    app.asyncCommands.use(DownloadCamsCommand(), as: "download-cams")
    app.asyncCommands.use(MeteoFranceDownload(), as: "download-meteofrance")
    app.commands.use(CronjobCommand(), as: "cronjob")
    app.asyncCommands.use(SeasonalForecastDownload(), as: "download-seasonal-forecast")
    app.asyncCommands.use(GfsDownload(), as: "download-gfs")
    app.asyncCommands.use(JmaDownload(), as: "download-jma")
    app.asyncCommands.use(MetNoDownloader(), as: "download-metno")
    app.asyncCommands.use(GloFasDownloader(), as: "download-glofas")
    app.asyncCommands.use(GemDownload(), as: "download-gem")
    app.asyncCommands.use(DownloadCmipCommand(), as: "download-cmip6")
    app.asyncCommands.use(SatelliteDownloadCommand(), as: "download-satellite")
    app.asyncCommands.use(SyncCommand(), as: "sync")
    app.asyncCommands.use(ExportCommand(), as: "export")
    app.commands.use(ConvertOmCommand(), as: "convert-om")

    app.http.server.configuration.hostname = "0.0.0.0"
    
    // https://github.com/vapor/vapor/pull/2677
    app.http.server.configuration.supportPipelining = false
    
    app.http.server.configuration.responseCompression = .enabled(initialByteBufferCapacity: 4096)
    
    // Higher backlog value to handle more connections
    app.http.server.configuration.backlog = 4096

    //app.logger.logLevel = .debug

    //app.views.use(.leaf)
    
    app.lifecycle.use(OmFileManager.instance)
    app.lifecycle.use(RateLimiter.instance)

    // register routes
    try routes(app)
}


extension Application {
  public static func testable() throws -> Application {
    let app = Application(.testing)
    try configure(app)

    return app
  }
}
