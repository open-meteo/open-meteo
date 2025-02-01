import Vapor
import SwiftNetCDF
import AsyncHTTPClient
import curl_swift


struct JaxaHimawariDownload: AsyncCommand {
    struct Signature: CommandSignature {
        @Argument(name: "domain")
        var domain: String
        
        @Option(name: "run")
        var run: String?
        
        @Flag(name: "create-netcdf")
        var createNetcdf: Bool
        
        @Option(name: "only-variables")
        var onlyVariables: String?
        
        @Option(name: "timeinterval", short: "t", help: "Timeinterval to download past forecasts. Format 20220101-20220131")
        var timeinterval: String?
        
        @Option(name: "username", help: "FTP username")
        var username: String?
        
        @Option(name: "password", help: "FTP password")
        var password: String?
        
        @Option(name: "concurrent", short: "c", help: "Number of concurrent download/conversion jobs")
        var concurrent: Int?
        
        @Option(name: "upload-s3-bucket", help: "Upload open-meteo database to an S3 bucket after processing")
        var uploadS3Bucket: String?
    }
    
    var help: String {
        "Download Jaxa Himawari satellite data download"
    }
    
    func run(using context: CommandContext, signature: Signature) async throws {
        let logger = context.application.logger
        let domain = try JaxaHimawariDomain.load(rawValue: signature.domain)
        let nConcurrent = signature.concurrent ?? 1
        
        guard let username = signature.username, let password = signature.password else {
            fatalError("Parameter api key and secret required")
        }
        let downloader = JaxaFtpDownloader(username: username, password: password)
        let variables = JaxaHimawariVariable.allCases
        
        if let timeinterval = signature.timeinterval {
            let chunkDt = domain.omFileLength * domain.dtSeconds
            let timerange = try Timestamp.parseRange(yyyymmdd: timeinterval).toRange(dt: 86400).with(dtSeconds: domain.dtSeconds)
            for (_, runs) in timerange.groupedPreservedOrder(by: {$0.timeIntervalSince1970 / chunkDt}) {
                logger.info("Downloading runs \(runs.iso8601_YYYYMMdd)")
                let handles = try await runs.asyncFlatMap { run in
                    return try await downloadRun(application: context.application, run: run, domain: domain, variables: variables, downloader: downloader)
                }
                try await GenericVariableHandle.convert(logger: logger, domain: domain, createNetcdf: signature.createNetcdf, run: runs[0], handles: handles, concurrent: nConcurrent, writeUpdateJson: false, uploadS3Bucket: nil, uploadS3OnlyProbabilities: false, interpolation: false)
            }
            return
        }
        
        let run = try signature.run.flatMap(Timestamp.fromRunHourOrYYYYMMDD) ?? Timestamp.now().with(hour: 0).subtract(days: 2)
        let handles = try await downloadRun(application: context.application, run: run, domain: domain, variables: variables, downloader: downloader)
        try await GenericVariableHandle.convert(logger: logger, domain: domain, createNetcdf: signature.createNetcdf, run: run, handles: handles, concurrent: nConcurrent, writeUpdateJson: true, uploadS3Bucket: signature.uploadS3Bucket, uploadS3OnlyProbabilities: false, interpolation: false)
    }
    
    fileprivate func downloadRun(application: Application, run: Timestamp, domain: JaxaHimawariDomain, variables: [JaxaHimawariVariable], downloader: JaxaFtpDownloader) async throws -> [GenericVariableHandle] {
        let logger = application.logger
        
        return try await variables.asyncCompactMap({ variable -> GenericVariableHandle? in
            logger.info("Downloading \(variable) \(run.iso8601_YYYY_MM_dd_HH_mm)")
            let c = run.toComponents()
            let path: String
            switch domain {
            case .himawari_10min:
                path = "/pub/himawari/L2/PAR/021/\(c.year)\(c.mm)/\(c.dd)/\(run.hh)/H09_\(run.format_YYYYMMdd)_\(run.hh)\(run.mm)_RFL021_FLDK.02401_02401.nc"
            case .himawari_hourly:
                path = "/pub/himawari/L3/PAR/021/\(c.year)\(c.mm)/\(c.dd)/H09_\(run.format_YYYYMMdd)_\(run.hh)00_1H_RFL021_FLDK.02401_02401.nc"
            }
            
            guard let data = try await downloader.get(logger: logger, path: path) else {
                logger.warning("File missing")
                return nil
            }
            let sw = try data.readNetcdf(name: "SWR")
            
            let writer = OmFileSplitter.makeSpatialWriter(domain: domain, nTime: 1)
            let fn = try writer.writeTemporary(compressionType: .pfor_delta2d_int16, scalefactor: variable.scalefactor, all: sw.data)
            return GenericVariableHandle(
                variable: variable,
                time: run,
                member: 0,
                fn: fn
            )
        })
    }
}

fileprivate struct JaxaFtpDownloader {
    let shared = CURLSH()
    let auth: String
    
    public init(username: String, password: String) {
        self.auth = "\(username):\(password)"
    }
    
    public func get(logger: Logger, path: String) async throws -> Data? {
        let url = "ftp://\(auth)@ftp.ptree.jaxa.jp\(path)"
        let cacheFile = Curl.cacheDirectory.map { "\($0)/\(url.sha256))" }
        if let cacheFile, FileManager.default.fileExists(atPath: cacheFile) {
            logger.info("Using cached file for \(path)")
            return try Data(contentsOf: URL(fileURLWithPath: cacheFile))
        }
        logger.info("Downloading \(path)")
        let req = CURL(method: "GET", url: url, verbose: false)
        req.connectTimeout = 60
        req.resourceTimeout = 300
        let progress = TimeoutTracker(logger: logger, deadline: Date().addingTimeInterval(1*3600))
        while true {
            do {
                let response = try shared.perform(curl: req)
                let data = response.body
                if let cacheFile {
                    try data.write(to: URL(fileURLWithPath: cacheFile), options: .atomic)
                }
                return data
            } catch CURLError.internal(code: let code, str: let str) {
                if code == 78 && str == "Remote file not found" {
                    return nil
                }
                logger.warning("CURLError \(code): \(str)")
                let error = CURLError.internal(code: code, str: str)
                try await progress.check(error: error, delay: 5)
            } catch {
                try await progress.check(error: error, delay: 5)
            }
        }
    }
}


fileprivate extension Data {
    func readNetcdf(name: String) throws -> Array2D {
        return try withUnsafeBytes { memory in
            guard let nc = try NetCDF.open(memory: memory) else {
                fatalError("Could not open netcdf from memory")
            }
            if let ncvar = nc.getVariable(name: name),
               ncvar.dimensionsFlat.count == 2,
               let scaleFactor: Float = try ncvar.getAttribute("scale_factor")?.read(),
               let addOffset: Float = try ncvar.getAttribute("add_offset")?.read(),
               let data = try ncvar.asType(Int16.self)?.read().map({
                   return $0 <= -999 ? Float.nan : Float($0) * scaleFactor + addOffset
            }) {
                var array2d = Array2D(data: data, nx: ncvar.dimensionsFlat[1], ny: ncvar.dimensionsFlat[0])
                array2d.flipLatitude()
                return array2d
            }
            fatalError("Could not open variable \(name)")
        }
    }
}
