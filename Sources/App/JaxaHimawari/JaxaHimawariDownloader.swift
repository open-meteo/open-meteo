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
            let timerange = try Timestamp.parseRange(yyyymmdd: timeinterval).toRange(dt: 86400)
            for (_, runs) in timerange.groupedPreservedOrder(by: {$0.timeIntervalSince1970 / chunkDt}) {
                logger.info("Downloading runs \(runs.iso8601_YYYYMMdd)")
                let handles = try await runs.asyncFlatMap { run in
                    return try await downloadRun(application: context.application, run: run, domain: domain, variables: variables, downloader: downloader)
                }
                try await GenericVariableHandle.convert(logger: logger, domain: domain, createNetcdf: signature.createNetcdf, run: runs[0], handles: handles, concurrent: nConcurrent, writeUpdateJson: false, uploadS3Bucket: nil, uploadS3OnlyProbabilities: false)
            }
            return
        }
        
        let run = try signature.run.flatMap(Timestamp.fromRunHourOrYYYYMMDD) ?? Timestamp.now().with(hour: 0).subtract(days: 2)
        let handles = try await downloadRun(application: context.application, run: run, domain: domain, variables: variables, downloader: downloader)
        try await GenericVariableHandle.convert(logger: logger, domain: domain, createNetcdf: signature.createNetcdf, run: run, handles: handles, concurrent: nConcurrent, writeUpdateJson: true, uploadS3Bucket: signature.uploadS3Bucket, uploadS3OnlyProbabilities: false)
    }
    
    fileprivate func downloadRun(application: Application, run: Timestamp, domain: JaxaHimawariDomain, variables: [JaxaHimawariVariable], downloader: JaxaFtpDownloader) async throws -> [GenericVariableHandle] {
        //let logger = application.logger
        
        return try await variables.asyncMap({ variable -> GenericVariableHandle in
            let c = run.toComponents()
            // ftp://ftp.ptree.jaxa.jp/pub/himawari/L3/PAR/021/202501/31/H09_20250131_0200_1H_RFL021_FLDK.02401_02401.nc
            let data = try downloader.get(path: "/pub/himawari/L3/PAR/021/\(c.year)\(c.mm)/\(c.dd)/H09_\(run.format_YYYYMMdd)_\(run.hh)00_1H_RFL021_FLDK.02401_02401.nc")
            let sw = try data.readNetcdf(name: "SWR")
            
            let writer = OmFileSplitter.makeSpatialWriter(domain: domain, nTime: 1)
            let fn = try writer.writeTemporary(compressionType: .pfor_delta2d_int16, scalefactor: variable.scalefactor, all: sw)
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
    
    public func get(path: String) throws -> Data {
        let shared = CURLSH()
        let req = CURL(method: "GET", url: "ftp://\(auth)@ftp.ptree.jaxa.jp\(path)")
        let response = try shared.perform(curl: req)
        return response.body
    }
}


fileprivate extension Data {
    func readNetcdf(name: String) throws -> [Float] {
        return try withUnsafeBytes { memory in
            guard let nc = try NetCDF.open(memory: memory) else {
                fatalError("Could not open netcdf from memory")
            }
            if let ncvar = nc.getVariable(name: name),
               let scaleFactor: Float = try ncvar.getAttribute("scale_factor")?.read(),
               let addOffset: Float = try ncvar.getAttribute("add_offset")?.read(),
               let data = try ncvar.asType(Int16.self)?.read().map({
                   return $0 <= -999 ? Float.nan : Float($0) * scaleFactor + addOffset
            }) {
                return data
            }
            fatalError("Could not open variable \(name)")
        }
    }
}
