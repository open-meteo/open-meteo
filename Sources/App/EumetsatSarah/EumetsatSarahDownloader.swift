import Vapor
import SwiftNetCDF
import AsyncHTTPClient

/**
 Important: SARAH-3 data originally uses instantaneous solar radiation values. However, each line has a scan time offset of 0-15 minutes.
 In Europe the offset is closer to 15 minutes.
 
 OpenMeteo corrects this scan time offset and stores backwards averaged 30 minutes values.
 */
struct EumetsatSarahDownload: AsyncCommand {
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
        
        @Option(name: "api-key", help: "Consumer api key for EUMETSAT API")
        var apiKey: String?
        
        @Option(name: "api-secret", help: "Consumer api secret for EUMETSAT API")
        var apiSecret: String?
        
        @Option(name: "concurrent", short: "c", help: "Number of concurrent download/conversion jobs")
        var concurrent: Int?
        
        @Option(name: "upload-s3-bucket", help: "Upload open-meteo database to an S3 bucket after processing")
        var uploadS3Bucket: String?
    }
    
    var help: String {
        "Download Eumetsat Sarah data"
    }
    
    func run(using context: CommandContext, signature: Signature) async throws {
        let logger = context.application.logger
        let domain = try EumetsatSarahDomain.load(rawValue: signature.domain)
        let nConcurrent = signature.concurrent ?? 1
        
        guard let apiKey = signature.apiKey, let apiSecret = signature.apiSecret else {
            fatalError("Parameter api key and secret required")
        }
        
        let variables = EumetsatSarahVariable.allCases
        
        if let timeinterval = signature.timeinterval {
            let api = EumetsatApiDownloader(application: context.application, key: apiKey, secret: apiSecret, deadLineHours: 30*24)
            let chunkDt = domain.omFileLength * domain.dtSeconds
            let timerange = try Timestamp.parseRange(yyyymmdd: timeinterval).toRange(dt: 86400)
            for (_, runs) in timerange.groupedPreservedOrder(by: {$0.timeIntervalSince1970 / chunkDt}) {
                logger.info("Downloading runs \(runs.iso8601_YYYYMMdd)")
                let handles = try await runs.asyncFlatMap { run in
                    return try await downloadRun(application: context.application, run: run, domain: domain, api: api, variables: variables)
                }
                try await GenericVariableHandle.convert(logger: logger, domain: domain, createNetcdf: signature.createNetcdf, run: runs[0], handles: handles, concurrent: nConcurrent, writeUpdateJson: false, uploadS3Bucket: nil, uploadS3OnlyProbabilities: false)
            }
            return
        }
        
        let api = EumetsatApiDownloader(application: context.application, key: apiKey, secret: apiSecret, deadLineHours: 3)
        let run = try signature.run.flatMap(Timestamp.fromRunHourOrYYYYMMDD) ?? Timestamp.now().with(hour: 0).subtract(days: 2)
        let handles = try await downloadRun(application: context.application, run: run, domain: domain, api: api, variables: variables)
        try await GenericVariableHandle.convert(logger: logger, domain: domain, createNetcdf: signature.createNetcdf, run: run, handles: handles, concurrent: nConcurrent, writeUpdateJson: true, uploadS3Bucket: signature.uploadS3Bucket, uploadS3OnlyProbabilities: false)
    }
    
    fileprivate func downloadRun(application: Application, run: Timestamp, domain: EumetsatSarahDomain, api: EumetsatApiDownloader, variables: [EumetsatSarahVariable]) async throws -> [GenericVariableHandle] {
        let logger = application.logger
        
        // Download meta data for elevation and scan time offsets
        let metaDataFile = "\(domain.downloadDirectory)/AuxilaryData_SARAH-3.nc"
        if !FileManager.default.fileExists(atPath: metaDataFile) {
            try FileManager.default.createDirectory(atPath: domain.downloadDirectory, withIntermediateDirectories: true)
            let url = "https://public.cmsaf.dwd.de/data/perm/auxilliary_data/AuxilaryData_SARAH-3.nc"
            try await api.curl.download(url: url, toFile: metaDataFile, bzip2Decode: false)
        }
        guard let meta: (elevation: [Float], landMask: [Int8], timeDifference: [Double]) = try NetCDF.open(path: metaDataFile, allowUpdate: false).map ({ nc in
            guard let elevation = try nc.getVariable(name: "altitude")?.asType(Float.self)?.read() else {
                fatalError("Could not read altitude")
            }
            /// land mask (0==sea, any other value==land)
            guard let landMask = try nc.getVariable(name: "land_mask")?.asType(Int8.self)?.read() else {
                fatalError("Could not read land_mask")
            }
            /// time difference of the acquisition time since 2006 onwards (SEVIRI) to the time provided in the instantaneous data files
            /// time difference of the acquisition time during 1983-2005 (MVIRI) to the time provided in the instantaneous data files
            let timeDifferenceKey = run >= Timestamp(2006, 1, 1) ? "time_difference_SEVIRI" : "time_difference_MVIRI"
            guard let timeDifference = try nc.getVariable(name: timeDifferenceKey)?.asType(Double.self)?.read().map({ $0 <= -999 ? Double.nan : $0 }) else {
                fatalError("Could not read \(timeDifferenceKey)")
            }
            return (elevation, landMask, timeDifference)
        }) else {
            fatalError("Could not read metadata")
        }
        let elevationFile = domain.surfaceElevationFileOm
        if !FileManager.default.fileExists(atPath: elevationFile.getFilePath()) {
            try elevationFile.createDirectory()
            let elevation: [Float] = meta.elevation.enumerated().map { (i, value) in
                return meta.timeDifference[i].isNaN ? .nan : meta.landMask[i] == 0 ? -999 : Float(value)
            }
            try elevation.writeOmFile2D(file: elevationFile.getFilePath(), grid: domain.grid, createNetCdf: false)
        }
        
        return try await variables.asyncMap({ variable -> GenericVariableHandle in
            let wiredNumber = run >= Timestamp(2021, 1, 1) ? "I" : "0"
            let id = "\(variable.eumetsatApiName)\(run.format_YYYYMMdd)00000042310001\(wiredNumber)1MA"
            let url = "https://api.eumetsat.int/data/download/1.0.0/collections/EO%3AEUM%3ADAT%3A0863/products/\(id)/entry?name=\(id).nc"
            let memory = try await api.download(url: url)
            let (time, data) = try memory.readNetcdf(name: variable.eumetsatName)
            var dataFastTime = Array2DFastSpace(data: data, nLocations: domain.grid.count, nTime: time.count).transpose().data
            
            // Transform instant solar radiation values to backwards averaged values
            // Instant values have a scan time difference which needs to be corrected for
            if variable == .direct_radiation || variable == .shortwave_radiation {
                let start = DispatchTime.now()
                let timerange = TimerangeDt(start: run, nTime: time.count, dtSeconds: domain.dtSeconds)
                Zensun.instantaneousSolarRadiationToBackwardsAverages(
                    timeOrientedData: &dataFastTime,
                    grid: domain.grid,
                    locationRange: 0..<domain.grid.count,
                    timerange: timerange,
                    scanTimeDifferenceHours: meta.timeDifference,
                    sunDeclinationCutOffDegrees: 1
                )
                logger.info("\(variable) conversion took \(start.timeElapsedPretty())")
            }
            
            let writer = OmFileSplitter.makeSpatialWriter(domain: domain, nTime: time.count)
            let fn = try writer.writeTemporary(compressionType: .pfor_delta2d_int16, scalefactor: variable.scalefactor, all: dataFastTime)
            return GenericVariableHandle(
                variable: variable,
                time: time[0],
                member: 0,
                fn: fn
            )
        })
    }
}

/// Manages EUMETSAT API tokens and downloads
fileprivate final class EumetsatApiDownloader {
    private let auth: String
    
    private var token: String?
    
    let curl: Curl
    
    init(application: Application, key: String, secret: String, deadLineHours: Double) {
        self.auth = "\(key):\(secret)".base64String()
        self.token = nil
        self.curl = Curl(
            logger: application.logger,
            client: application.dedicatedHttpClient,
            deadLineHours: deadLineHours,
            retryError4xx: false
        )
    }
    
    func getToken() async throws -> String {
        if let token {
            return token
        }
        struct AuthResponse: Decodable {
            let access_token: String
        }
        let url = "https://api.eumetsat.int/token"
        var request = HTTPClientRequest(url: url)
        request.method = .POST
        request.headers.add(name: "Authorization", value: "Basic \(auth)")
        request.body = .bytes(.init(string: "grant_type=client_credentials"))
        
        let response = try await curl.client.executeRetry(request, logger: curl.logger, deadline: .hours(1))
        if response.status.code == 400, let error = try await response.readStringImmutable() {
            throw CdsApiError.error(message: error, reason: "")
        }
        guard let token = try await response.readJSONDecodable(AuthResponse.self) else {
            fatalError("Did not get token")
        }
        self.token = token.access_token
        return token.access_token
    }
    
    /// Download data to memory. Retries with a new API token if the old one expired
    func download(url: String) async throws -> ByteBuffer {
        let token = try await getToken()
        do {
            let memory = try await curl.downloadInMemoryAsync(url: url, minSize: 1024, headers: [("Authorization", "Bearer \(token)")])
            return memory
        } catch CurlErrorNonRetry.unauthorized {
            self.token = nil
            let token = try await getToken()
            let memory = try await curl.downloadInMemoryAsync(url: url, minSize: 1024, headers: [("Authorization", "Bearer \(token)")])
            return memory
        }
    }
}


fileprivate extension ByteBuffer {
    func readNetcdf(name: String) throws -> (timestamps: [Timestamp], data: [Float]) {
        return try withUnsafeReadableBytes { memory in
            guard let nc = try NetCDF.open(memory: memory) else {
                fatalError("Could not open netcdf from memory")
            }
            guard let time = try nc.getVariable(name: "time")?.asType(Double.self)?.read().map ({ Timestamp(1983,1,1).add(Int($0*3600)) }) else {
                fatalError("Could not open variable time")
            }
            if let data = try nc.getVariable(name: name)?.asType(Float.self)?.read() {
                return (time, data)
            }
            if let data = try nc.getVariable(name: name)?.asType(Int16.self)?.read().map({
                return $0 <= -999 ? Float.nan : Float($0)
            }) {
                return (time, data)
            }
            fatalError("Could not open variable \(name)")
        }
    }
}
