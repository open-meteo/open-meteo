import Vapor
import SwiftNetCDF
import AsyncHTTPClient

/**
 Important: EUMETSAT LSA SAF data originally uses instantaneous solar radiation values every 15 minutes. However, each line has a scan time offset of 0-15 minutes.
 In Europe the offset is around 12 minutes. OpenMeteo corrects this scan time offset and stores backwards averaged 15 minutes values.
 For 15 minutes values, this difference is rather small, but we do the correction anyways.
 
 overview: https://lsa-saf.eumetsat.int/en/data/products/radiation/
 data: https://datalsasaf.lsasvcs.ipma.pt/PRODUCTS/MSG/MDSSFTD/NETCDF/2025/02/03/
 docs: https://nextcloud.lsasvcs.ipma.pt/s/QSABgnG4dZGBo5W?dir=undefined&path=%2FPUM-Product_User_Manual&openfile=27089
 */
struct EumetsatLsaSafDownload: AsyncCommand {
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
        
        @Option(name: "username", help: "Username for data server")
        var username: String?
        
        @Option(name: "password", help: "Password for data server")
        var password: String?
        
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
        let domain = try EumetsatLsaSafDomain.load(rawValue: signature.domain)
        let nConcurrent = signature.concurrent ?? 1
        
        guard let username = signature.username, let password = signature.password else {
            fatalError("Parameter username and password are required")
        }
        
        if let timeinterval = signature.timeinterval {
            let chunkDt = domain.omFileLength * domain.dtSeconds
            let timerange = try Timestamp.parseRange(yyyymmdd: timeinterval).toRange(dt: 86400).with(dtSeconds: domain.dtSeconds)
            for (_, runs) in timerange.groupedPreservedOrder(by: {$0.timeIntervalSince1970 / chunkDt}) {
                logger.info("Downloading runs \(runs.iso8601_YYYYMMdd)")
                let handles = try await runs.asyncFlatMap { run in
                    return try await downloadRun(application: context.application, run: run, domain: domain, username: username, password: password)
                }
                try await GenericVariableHandle.convert(logger: logger, domain: domain, createNetcdf: signature.createNetcdf, run: runs[0], handles: handles, concurrent: nConcurrent, writeUpdateJson: false, uploadS3Bucket: nil, uploadS3OnlyProbabilities: false)
            }
            return
        }
        // every hour at 19 minutes past, all timesteps for the entire hour are published
        // cronjobs run every hour at 25 min past
        let run = try signature.run.flatMap(Timestamp.fromRunHourOrYYYYMMDD) ?? Timestamp.now().subtract(minutes: 20).floor(toNearestHour: 1).subtract(minutes: 45)
        let handles = try await TimerangeDt(start: run, nTime: 4, dtSeconds: domain.dtSeconds).asyncFlatMap { run in
            try await downloadRun(application: context.application, run: run, domain: domain, username: username, password: password)
        }
        try await GenericVariableHandle.convert(logger: logger, domain: domain, createNetcdf: signature.createNetcdf, run: run, handles: handles, concurrent: nConcurrent, writeUpdateJson: true, uploadS3Bucket: signature.uploadS3Bucket, uploadS3OnlyProbabilities: false)
    }
    
    fileprivate func downloadRun(application: Application, run: Timestamp, domain: EumetsatLsaSafDomain, username: String, password: String) async throws -> [GenericVariableHandle] {
        let logger = application.logger
        let curl = Curl(logger: logger, client: application.dedicatedHttpClient, retryError4xx: false)
        let nx = domain.grid.nx
        let ny = domain.grid.ny
        
        let server = "https://\(username):\(password)@datalsasaf.lsasvcs.ipma.pt"
        let url: String
        switch domain {
        case .msg:
            url = "\(server)/PRODUCTS/MSG/MDSSFTD/NETCDF/\(run.format_directoriesYYYYMMdd)/NETCDF4_LSASAF_MSG_MDSSFTD_MSG-Disk_\(run.format_YYYYMMddHHmm).nc"
        case .iodc:
            url = "\(server)/PRODUCTS/MSG-IODC/MDSSFTD/NETCDF/\(run.format_directoriesYYYYMMdd)/NETCDF4_LSASAF_MSG-IODC_MDSSFTD_IODC-Disk_\(run.format_YYYYMMddHHmm).nc"
        }
        
        // https://datalsasaf.lsasvcs.ipma.pt/PRODUCTS/MSG/MDSSFTD/NETCDF/2025/02/03/NETCDF4_LSASAF_MSG_MDSSFTD_MSG-Disk_202502031430.nc
        // https://datalsasaf.lsasvcs.ipma.pt/PRODUCTS/MSG-IODC/MDSSFTD/NETCDF/2025/01/01/NETCDF4_LSASAF_MSG-IODC_MDSSFTD_IODC-Disk_202501012315.nc
        let data: ByteBuffer
        do {
            data = try await curl.downloadInMemoryAsync(url: url, minSize: 0)
        } catch CurlError.fileNotFound {
            logger.warning("File not found, skipping")
            return []
        }
        guard data.readableBytes > 0 else {
            logger.warning("Empty file, skipping")
            return []
        }
        
        /// SEVIRI image scans are performed from South to North. Hence in Northern Europe the line acquisition time deviates from the slot time by approximately 12 minutes.
        /// OpenMeteo grids are ordered South to North, therefore the scan time should increase with the line number
        /// Europe is at scan line 2570 => (760-(3201-2570)/5) = 633 seconds
        let scanTimeDifferenceHours = (0..<3201*3201).map {
            let line = $0 / 3201
            return (760 - Double(3201 - line) / 5) / 3600
        }
        
        return try data.withUnsafeReadableBytes { memory in
            guard let nc = try NetCDF.open(memory: memory) else {
                fatalError("Could not open netcdf from memory")
            }
            guard var shortwave_radiation = try nc.getVariable(name: "DSSF_TOT")?.readAndScale() else {
                fatalError("Could not open variable DSSF_TOT")
            }
            shortwave_radiation.flipLatitude(nt: 1, ny: ny, nx: nx)
            guard var diffuse_fraction = try nc.getVariable(name: "FRACTION_DIFFUSE")?.readAndScale() else {
                fatalError("Could not open variable FRACTION_DIFFUSE")
            }
            diffuse_fraction.flipLatitude(nt: 1, ny: ny, nx: nx)
            
            let start = DispatchTime.now()
            let timerange = TimerangeDt(start: run, nTime: 1, dtSeconds: domain.dtSeconds)
            Zensun.instantaneousSolarRadiationToBackwardsAverages(
                timeOrientedData: &shortwave_radiation,
                grid: domain.grid,
                locationRange: 0..<domain.grid.count,
                timerange: timerange,
                scanTimeDifferenceHours: scanTimeDifferenceHours,
                sunDeclinationCutOffDegrees: 1
            )
            logger.info("conversion took \(start.timeElapsedPretty())")
            
            let direct_radiation = zip(shortwave_radiation, diffuse_fraction).map { (sw, df) -> Float in
                return sw * (1-df)
            }
            
            let writer = OmFileSplitter.makeSpatialWriter(domain: domain, nTime: 1)
            let sw = GenericVariableHandle(
                variable: EumetsatLsaSafVariable.shortwave_radiation,
                time: run,
                member: 0,
                fn: try writer.writeTemporary(compressionType: .pfor_delta2d_int16, scalefactor: EumetsatLsaSafVariable.shortwave_radiation.scalefactor, all: shortwave_radiation)
            )
            let direct = GenericVariableHandle(
                variable: EumetsatLsaSafVariable.direct_radiation,
                time: run,
                member: 0,
                fn: try writer.writeTemporary(compressionType: .pfor_delta2d_int16, scalefactor: EumetsatLsaSafVariable.direct_radiation.scalefactor, all: direct_radiation)
            )
            return [sw, direct]
        }
    }
}

extension Variable {
    /// Following the climate convention use scale-factor and add-offset
    func readAndScale() throws -> [Float]? {
        let scaleFactor: Float = try getAttribute("scale_factor")?.readFloat() ?? 1
        let addOffset: Float = try getAttribute("add_offset")?.readFloat() ?? 0
        if let short = try self.asType(Int16.self)?.read() {
            if let fillValue: Int16? = try getAttribute("_FillValue")?.read() {
                return short.map {
                    return $0 == fillValue ? Float.nan : Float($0) * scaleFactor + addOffset
                }
            }
            return short.map {
                return Float($0) * scaleFactor + addOffset
            }
        }
        fatalError("Could not scale variable")
    }
}

extension Attribute {
    func readFloat() throws -> Float? {
        if let value: Float = try read() {
            return value
        }
        if let value: Double = try read() {
            return Float(value)
        }
        return nil
    }
}
