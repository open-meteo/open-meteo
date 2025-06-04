import Vapor
import OmFileFormat
// import Leaf

enum OpenMeteo {
    /// Data directory with trailing slash
    static let dataDirectory = {
        if let dir = Environment.get("DATA_DIRECTORY") {
            guard dir.last == "/" else {
                fatalError("DATA_DIRECTORY must end with a trailing slash")
            }
            return dir
        }
        return  "./data/"
    }()
    
    /// Remote data directory like `https://openmeteo.s3.amazonaws.com/data/`
    static let remoteDataDirectory: String? = {
        if let dir = Environment.get("REMOTE_DATA_DIRECTORY") {
            guard dir.starts(with: "http") else {
                fatalError("REMOTE_DATA_DIRECTORY must start with 'http'")
            }
            guard dir.last == "/" else {
                fatalError("REMOTE_DATA_DIRECTORY must end with a trailing slash")
            }
            return dir
        }
        return nil
    }()
    
    /// Cache remote data if `REMOTE_DATA_DIRECTORY` is set. Default 10GB stored in `cache.bin` inside the data directory.
    static let dataBlockCache: AtomicCacheCoordinator<MmapFile> = { () -> AtomicCacheCoordinator<MmapFile> in
        let cacheFile = Environment.get("CACHE_FILE") ?? "\(dataDirectory)/cache.bin"
        let cacheSize = try! ByteSizeParser.parseSizeStringToBytes(Environment.get("CACHE_SIZE") ?? "10GB")
        let blockSize = try! ByteSizeParser.parseSizeStringToBytes(Environment.get("BLOCK_SIZE") ?? "64KB")
        let blockCount = cacheSize / (blockSize + 2 * MemoryLayout<Int64>.size)
        return AtomicCacheCoordinator(cache: try! AtomicBlockCache(file: cacheFile, blockSize: blockSize, blockCount: blockCount))
    }()
    
    /// Data directory with trailing slash
    static let dataSpatialDirectory: String? = {
        if let dir = Environment.get("DATA_SPATIAL_DIRECTORY") {
            guard dir.last == "/" else {
                fatalError("DATA_SPATIAL_DIRECTORY must end with a trailing slash")
            }
            return dir
        }
        return nil
    }()

    /// Temporary directory with trailing slash
    static let tempDirectory = {
        if let dir = Environment.get("TEMP_DIRECTORY") {
            guard dir.last == "/" else {
                fatalError("TEMP_DIRECTORY must end with a trailing slash")
            }
            return dir
        }
        return dataDirectory
    }()

    /// Maximum number of locations for multi point requests
    static let numberOfLocationsMaximum: Int = {
        return (Environment.get("LOCATIONS_LIMIT").map(Int.init) ?? 1000) ?? 1000
    }()

    /// Cache all data access using spare files in this directory
    /*static var cacheDirectory = {
        return Environment.get("CACHE_DIRECTORY")
    }()*/
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
        let new = makeNewHttpClient()
        self.storage.set(HttpClientKey.self, to: new) {
            try $0.syncShutdown()
        }
        return new
    }

    /// Create a new HTTP client instance. `shutdown` must be called after using it
    func makeNewHttpClient(httpVersion: HTTPClient.Configuration.HTTPVersion = .automatic, redirectConfiguration: HTTPClient.Configuration.RedirectConfiguration? = nil) -> HTTPClient {
        // try again with very high timeouts, so only the curl internal timers are used
        var configuration = HTTPClient.Configuration(
            redirectConfiguration: redirectConfiguration ?? .follow(max: 5, allowCycles: false),
            timeout: .init(connect: .seconds(30), read: .minutes(5)),
            connectionPool: .init(idleTimeout: .minutes(10)))
        configuration.httpVersion = httpVersion

        return HTTPClient(
            eventLoopGroupProvider: .shared(eventLoopGroup),
            configuration: configuration,
            backgroundActivityLogger: logger)
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
    app.asyncCommands.use(MigrationCommand(), as: "migration")
    app.asyncCommands.use(DownloadIconCommand(), as: "download")
    app.asyncCommands.use(DownloadCmaCommand(), as: "download-cma")
    app.asyncCommands.use(DownloadBomCommand(), as: "download-bom")
    app.asyncCommands.use(DownloadIconWaveCommand(), as: "download-iconwave")
    app.asyncCommands.use(DownloadEcmwfCommand(), as: "download-ecmwf")
    app.asyncCommands.use(DownloadEra5Command(), as: "download-era5")
    app.asyncCommands.use(MfWaveDownload(), as: "download-mfwave")
    app.asyncCommands.use(DownloadDemCommand(), as: "download-dem")
    app.asyncCommands.use(DownloadCamsCommand(), as: "download-cams")
    app.asyncCommands.use(MeteoFranceDownload(), as: "download-meteofrance")
    app.asyncCommands.use(KnmiDownload(), as: "download-knmi")
    app.asyncCommands.use(DmiDownload(), as: "download-dmi")
    app.asyncCommands.use(UkmoDownload(), as: "download-ukmo")
    app.asyncCommands.use(EumetsatSarahDownload(), as: "download-eumetsat-sarah")
    app.asyncCommands.use(EumetsatLsaSafDownload(), as: "download-eumetsat-lsa-saf")
    app.asyncCommands.use(JaxaHimawariDownload(), as: "download-jaxa-himawari")
    app.asyncCommands.use(SeasonalForecastDownload(), as: "download-seasonal-forecast")
    app.asyncCommands.use(ItaliaMeteoArpaeDownload(), as: "download-italia-meteo-arpae")
    app.asyncCommands.use(GfsDownload(), as: "download-gfs")
    app.asyncCommands.use(GfsGraphCastDownload(), as: "download-gfs-graphcast")
    app.asyncCommands.use(NbmDownload(), as: "download-nbm")
    app.asyncCommands.use(JmaDownload(), as: "download-jma")
    app.asyncCommands.use(MetNoDownloader(), as: "download-metno")
    app.asyncCommands.use(KmaDownload(), as: "download-kma")
    app.asyncCommands.use(GloFasDownloader(), as: "download-glofas")
    app.asyncCommands.use(GemDownload(), as: "download-gem")
    app.asyncCommands.use(DownloadCmipCommand(), as: "download-cmip6")
    app.asyncCommands.use(SatelliteDownloadCommand(), as: "download-satellite")
    app.asyncCommands.use(SyncCommand(), as: "sync")
    app.asyncCommands.use(ExportCommand(), as: "export")
    app.asyncCommands.use(MergeYearlyCommand(), as: "merge-yearly")
    app.asyncCommands.use(ConvertOmCommand(), as: "convert-om")

    app.http.server.configuration.hostname = "0.0.0.0"

    // https://github.com/vapor/vapor/pull/2677
    app.http.server.configuration.supportPipelining = false

    app.http.server.configuration.responseCompression = .enabled(initialByteBufferCapacity: 4096)

    // Higher backlog value to handle more connections
    app.http.server.configuration.backlog = 4096

    if let defaultMaxBodySize = Environment.get("MAX_BODY_SIZE") {
        app.routes.defaultMaxBodySize = ByteCount(stringLiteral: defaultMaxBodySize)
    }

    // app.logger.logLevel = .debug

    // app.views.use(.leaf)

    app.lifecycle.repeatedTask(
        initialDelay: .seconds(0),
        delay: .seconds(10),
        ApiKeyManager.update
    )
    app.lifecycle.repeatedTask(
        initialDelay: .seconds(0),
        delay: .seconds(2),
        MetaFileManager.instance.backgroundTask
    )
    app.lifecycle.repeatedTask(
        initialDelay: .seconds(0),
        delay: .seconds(10),
        RemoteOmFileManager.instance.backgroundTask
    )

    app.lifecycle.repeatedTask(
        initialDelay: .seconds(Int64(60 - Timestamp.now().second)),
        delay: .seconds(60)
    ) { _ in
        await RateLimiter.instance.minutelyCallback()
    }

    // register routes
    try routes(app)
}
