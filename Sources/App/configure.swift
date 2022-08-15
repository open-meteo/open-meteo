import Vapor
import Leaf
import IkigaJSON

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
    app.commands.use(CronjobCommand(), as: "cronjob")
    app.commands.use(SeasonalForecastDownload(), as: "download-seasonal-forecast")
    app.commands.use(NcepDownload(), as: "download-ncep")

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
