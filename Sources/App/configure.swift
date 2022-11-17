import Vapor
import Leaf
import IkigaJSON

struct OpenMeteo {
    /// Data directory with trailing slash
    static var dataDictionary = {
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
        var configuration = HTTPClient.Configuration(
            timeout: .init(connect: .hours(24), read: .hours(24)),
            connectionPool: .init(idleTimeout: .hours(24)))
        configuration.httpVersion = .http1Only
        
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

    
    let decoder = IkigaJSONDecoder()
    decoder.settings.dateDecodingStrategy = .iso8601
    ContentConfiguration.global.use(decoder: decoder, for: .json)

    var encoder = IkigaJSONEncoder()
    encoder.settings.dateDecodingStrategy = .iso8601
    ContentConfiguration.global.use(encoder: encoder, for: .json)
    
    
    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    app.commands.use(BenchmarkCommand(), as: "benchmark")
    app.commands.use(DownloadIconCommand(), as: "download")
    app.commands.use(DownloadIconWaveCommand(), as: "download-iconwave")
    app.commands.use(DownloadEcmwfCommand(), as: "download-ecmwf")
    app.commands.use(DownloadEra5Command(), as: "download-era5")
    app.commands.use(DownloadDemCommand(), as: "download-dem")
    app.commands.use(DownloadCamsCommand(), as: "download-cams")
    app.commands.use(MeteoFranceDownload(), as: "download-meteofrance")
    app.commands.use(CronjobCommand(), as: "cronjob")
    app.commands.use(SeasonalForecastDownload(), as: "download-seasonal-forecast")
    app.commands.use(GfsDownload(), as: "download-gfs")
    app.commands.use(JmaDownload(), as: "download-jma")
    app.commands.use(MetNoDownloader(), as: "download-metno")
    app.commands.use(GloFasDownloader(), as: "download-glofas")
    app.commands.use(SyncCommand(), as: "sync")

    app.http.server.configuration.hostname = "0.0.0.0"
    
    // https://github.com/vapor/vapor/pull/2677
    app.http.server.configuration.supportPipelining = false
    
    app.http.server.configuration.responseCompression = .enabled(initialByteBufferCapacity: 4096)

    app.logger.logLevel = .debug

    app.views.use(.leaf)
    
    app.lifecycle.use(OmFileManager.instance)

    // register routes
    try routes(app)
}


extension IkigaJSONEncoder: ContentEncoder {
    public func encode<E: Encodable>(
        _ encodable: E,
        to body: inout ByteBuffer,
        headers: inout HTTPHeaders
    ) throws {
        headers.contentType = .json
        try self.encodeAndWrite(encodable, into: &body)
    }
}

extension IkigaJSONDecoder: ContentDecoder {
    public func decode<D: Decodable>(
        _ decodable: D.Type,
        from body: ByteBuffer,
        headers: HTTPHeaders
    ) throws -> D {
        guard headers.contentType == .json || headers.contentType == .jsonAPI else {
            throw Abort(.unsupportedMediaType)
        }
        
        return try self.decode(D.self, from: body)
    }
}


extension Application {
  public static func testable() throws -> Application {
    let app = Application(.testing)
    try configure(app)

    return app
  }
}
