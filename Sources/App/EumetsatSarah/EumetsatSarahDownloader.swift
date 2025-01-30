import Vapor
import SwiftNetCDF

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
        
        @Option(name: "access-token", help: "Access token for EUMETSAT API")
        var accessToken: String?
        
        @Option(name: "concurrent", short: "c", help: "Number of concurrent download/conversion jobs")
        var concurrent: Int?
        
        @Option(name: "upload-s3-bucket", help: "Upload open-meteo database to an S3 bucket after processing")
        var uploadS3Bucket: String?
    }
    
    var help: String {
        "Download Eumetsat Sarah data"
    }
    
    func run(using context: CommandContext, signature: Signature) async throws {
        //let start = DispatchTime.now()
        let logger = context.application.logger
        let domain = try EumetsatSarahDomain.load(rawValue: signature.domain)
        let nConcurrent = signature.concurrent ?? 1
        
        guard let accessToken = signature.accessToken else {
            fatalError("Parameter access token required")
        }
        
        if let timeinterval = signature.timeinterval {
            let chunkDt = domain.omFileLength * domain.dtSeconds
            let timerange = try Timestamp.parseRange(yyyymmdd: timeinterval).toRange(dt: 86400)
            for (_, runs) in timerange.groupedPreservedOrder(by: {$0.timeIntervalSince1970 / chunkDt}) {
                logger.info("Downloading runs \(runs.iso8601_YYYYMMdd)")
                let handles = try await runs.asyncFlatMap { run in
                    return try await downloadRun(application: context.application, run: run, domain: domain, accessToken: accessToken, variables: [.shortwave_radiation])
                }
                try await GenericVariableHandle.convert(logger: logger, domain: domain, createNetcdf: signature.createNetcdf, run: runs[0], handles: handles, concurrent: nConcurrent, writeUpdateJson: true, uploadS3Bucket: signature.uploadS3Bucket, uploadS3OnlyProbabilities: false)
            }
            return
        }
        
        let run = try signature.run.flatMap(Timestamp.fromRunHourOrYYYYMMDD) ?? Timestamp.now().with(hour: 0).subtract(days: 1)
        let handles = try await downloadRun(application: context.application, run: run, domain: domain, accessToken: accessToken, variables: [.shortwave_radiation])
        try await GenericVariableHandle.convert(logger: logger, domain: domain, createNetcdf: signature.createNetcdf, run: run, handles: handles, concurrent: nConcurrent, writeUpdateJson: true, uploadS3Bucket: signature.uploadS3Bucket, uploadS3OnlyProbabilities: false)
    }
    
    func downloadRun(application: Application, run: Timestamp, domain: EumetsatSarahDomain, accessToken: String, variables: [EumetsatSarahVariable]) async throws -> [GenericVariableHandle] {
        let logger = application.logger
        let curl = Curl(logger: logger, client: application.dedicatedHttpClient)
        
        // Download meta data for elevation and scan time offsets
        let metaDataFile = "\(domain.downloadDirectory)/AuxilaryData_SARAH-3.nc"
        if !FileManager.default.fileExists(atPath: metaDataFile) {
            try FileManager.default.createDirectory(atPath: domain.downloadDirectory, withIntermediateDirectories: true)
            let url = "https://public.cmsaf.dwd.de/data/perm/auxilliary_data/AuxilaryData_SARAH-3.nc"
            try await curl.download(url: url, toFile: metaDataFile, bzip2Decode: false)
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
            let url = "https://api.eumetsat.int/data/download/1.0.0/collections/EO%3AEUM%3ADAT%3A0863/products/\(variable.eumetsatApiName)\(run.format_YYYYMMdd)00000042310001I1MA/entry?name=\(variable.eumetsatApiName)\(run.format_YYYYMMdd)00000042310001I1MA.nc&access_token=\(accessToken)"
            let memory = try await curl.downloadInMemoryAsync(url: url, minSize: 1024)
            let (time, data) = try memory.readNetcdf(name: variable.eumetsatName)
            var dataFastTime = Array2DFastSpace(data: data, nLocations: domain.grid.count, nTime: time.count).transpose().data
            
            // Transform instant solar radiation values to backwards averaged values
            // Instant values have a scan time difference which needs to be corrected for
            if /*variable == .direct_radiation ||*/ variable == .shortwave_radiation {
                let timerange = TimerangeDt(start: run, nTime: time.count, dtSeconds: domain.dtSeconds)
                Zensun.instantaneousSolarRadiationToBackwardsAverages(
                    timeOrientedData: &dataFastTime,
                    grid: domain.grid,
                    locationRange: 0..<domain.grid.count,
                    timerange: timerange,
                    scanTimeDifferenceHours: meta.timeDifference,
                    sunDeclinationCutOffDegrees: 1
                )
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

enum EumetsatSarahVariable: String, CaseIterable, GenericVariable, GenericVariableMixable {
    case shortwave_radiation
    case direct_radiation
    
    var omFileName: (file: String, level: Int) {
        return (rawValue, 0)
    }
    
    var scalefactor: Float {
        switch self {
        case .shortwave_radiation, .direct_radiation:
            return 1
        }
    }
    
    var eumetsatName: String {
        switch self {
        case .shortwave_radiation, .direct_radiation:
            return "SIS"
        }
    }
    
    var eumetsatApiName: String {
        switch self {
        case .shortwave_radiation, .direct_radiation:
            return "SISin"
        }
    }
    
    var interpolation: ReaderInterpolation {
        switch self {
        case .shortwave_radiation, .direct_radiation:
            return .solar_backwards_averaged
        }
    }
    
    var unit: SiUnit {
        switch self {
        case .shortwave_radiation, .direct_radiation:
            return .wattPerSquareMetre
        }
    }
    
    var isElevationCorrectable: Bool {
        return false
    }
    
    var storePreviousForecast: Bool {
        return false
    }
    
    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
}
