import Vapor
import SwiftNetCDF
import AsyncHTTPClient
import curl_swift

/**
 L2 10 min data is instantaneous with scan time offset, but has missing steps
 L3 1h hourly seem to be averaged 10 minutes values, completely ignoring zenith angle -> which makes no sense whatsoever.
 Himawari notes state: "This product is a beta version and is intended to show the preliminary result from Himawari-8. Users should keep in mind that the data is NOT quality assured."
 
 https://www.eorc.jaxa.jp/ptree/userguide.html
 https://www.eorc.jaxa.jp/ptree/documents/README_HimawariGeo_en.txt
 */
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
        
        @Option(name: "skip-time-step", help: "Skip a list of timesteps")
        var skipTimeSteps: String?
    }

    var help: String {
        "Download Jaxa Himawari satellite data download"
    }

    func run(using context: CommandContext, signature: Signature) async throws {
        disableIdleSleep()
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
            for (_, runs) in timerange.groupedPreservedOrder(by: { $0.timeIntervalSince1970 / chunkDt }) {
                logger.info("Downloading runs \(runs.iso8601_YYYYMMddHHmm)")
                let handles = try await runs.asyncFlatMap { run -> [GenericVariableHandle] in
                    if let skipTimeSteps = signature.skipTimeSteps, skipTimeSteps.contains(run.format_YYYYMMddHHmm) {
                        logger.info("Skipping \(run.format_YYYYMMddHHmm)")
                        return []
                    }
                    return try await downloadRun(application: context.application, run: run, domain: domain, variables: variables, downloader: downloader)
                }
                try await GenericVariableHandle.convert(logger: logger, domain: domain, createNetcdf: signature.createNetcdf, run: runs[0], handles: handles, concurrent: nConcurrent, writeUpdateJson: false, uploadS3Bucket: nil, uploadS3OnlyProbabilities: false)
            }
            return
        }

        let downloadRange: TimerangeDt
        let lastTimestampFile: String?
        if let run = try signature.run.flatMap(Timestamp.fromRunHourOrYYYYMMDD) {
            downloadRange = TimerangeDt(start: run, nTime: 1, dtSeconds: domain.dtSeconds)
            lastTimestampFile = nil
        } else {
            let timestampFile = "\(domain.downloadDirectory)last.txt"
            let firstAvailableTimeStep = Timestamp.now().subtract(hours: 6).floor(toNearestHour: 1)
            let endTime = Timestamp.now().subtract(minutes: 30).floor(toNearest: domain.dtSeconds).add(domain.dtSeconds)
            let lastDownloadedTimeStep = ((try? String(contentsOfFile: timestampFile, encoding: .utf8))?.toTimestamp())
            let startTime = lastDownloadedTimeStep?.add(domain.dtSeconds) ?? firstAvailableTimeStep
            guard startTime <= endTime else {
                logger.info("All steps already downloaded")
                return
            }
            downloadRange = TimerangeDt(range: startTime ..< endTime, dtSeconds: domain.dtSeconds)
            lastTimestampFile = timestampFile
        }
        if signature.run == nil && signature.timeinterval == nil {
            /// Cronjob every 10 minutes. Make sure there is no overlap. Minus 5 seconds to prevent race conditions
            Process.alarm(seconds: 10*60 - 5)
        }
        logger.info("Downloading range \(downloadRange.prettyString())")
        let handles = try await downloadRange.enumerated().asyncFlatMap { i, run in
            // If the first step is missing, download the previous one to allow interpolation
            let h = try await downloadRun(application: context.application, run: run, domain: domain, variables: variables, downloader: downloader)
            if i == 0 && h.isEmpty && downloadRange.count > 1 {
                logger.info("Fist step missing, download previous step for interpolation")
                return try await downloadRun(application: context.application, run: run.add(-1 * domain.dtSeconds), domain: domain, variables: variables, downloader: downloader)
            }
            return h
        }
        if let lastTimestampFile, let last = handles.max(by: { $0.time.range.lowerBound < $1.time.range.lowerBound })?.time.range.lowerBound {
            try FileManager.default.createDirectory(atPath: domain.downloadDirectory, withIntermediateDirectories: true)
            try "\(last.timeIntervalSince1970)".write(toFile: lastTimestampFile, atomically: true, encoding: .utf8)
        }
        Process.alarm(seconds: 0)
        try await GenericVariableHandle.convert(logger: logger, domain: domain, createNetcdf: signature.createNetcdf, run: nil, handles: handles, concurrent: nConcurrent, writeUpdateJson: true, uploadS3Bucket: signature.uploadS3Bucket, uploadS3OnlyProbabilities: false)
    }

    fileprivate func downloadRun(application: Application, run: Timestamp, domain: JaxaHimawariDomain, variables: [JaxaHimawariVariable], downloader: JaxaFtpDownloader) async throws -> [GenericVariableHandle] {
        let logger = application.logger

        let timeDifference: [Double]
        switch domain {
        case .himawari_10min, .himawari_70e_10min:
            if run.minute == 40 && [2, 14].contains(run.hour) {
                // Please note that no observations are planned at 0240-0250UTC and 1440-1450UTC everyday for house-keeping of the Himawai-8 and -9 satellites
                logger.info("Skipping run \(run) because it is during a house-keeping window")
                return []
            }
            // Download meta data for scan time offsets
            let metaDataFile = "\(domain.downloadDirectory)/AuxilaryData.nc"
            if !FileManager.default.fileExists(atPath: metaDataFile) {
                try FileManager.default.createDirectory(atPath: domain.downloadDirectory, withIntermediateDirectories: true)
                let path = "/jma/netcdf/202501/01/NC_H09_20250101_0000_R21_FLDK.0\(domain.grid.nx)_02401.nc"
                let data = try await downloader.get(logger: logger, path: path)
                try data?.write(to: URL(fileURLWithPath: metaDataFile), options: .atomic)
            }
            timeDifference = try Data(contentsOf: URL(fileURLWithPath: metaDataFile)).readNetcdf(name: "Hour")!.data.map(Double.init)
        case .mtg_fci_10min:
            /// MTG FCI image scans are performed from South to North. Scan time is around 9 minutes 30 seconds
            /// Hence in Northern Europe the line acquisition time deviates from the slot time by approximately 8 minutes.
            /// OpenMeteo grids are ordered South to North, therefore the scan time should increase with the line number
            /// We use a linear interpolation assuming 15 seconds offset from start and 9:30 sweep time
            /// This is not 100% correct, but a reasonable approximation
            timeDifference = (0..<2801 * 2401).map {
                let line = $0 / 2801
                let lineFraction = Double(line) / (2401-1)
                return (15 + lineFraction * (9.5*60) ) / 3600
            }
        }

        return try await variables.asyncCompactMap({ variable -> GenericVariableHandle? in
            logger.info("Downloading \(variable) \(run.iso8601_YYYY_MM_dd_HH_mm)")
            let c = run.toComponents()
            let path: String
            /// For whatever reason, H08 is used again after 2025-10-11 at 15:20 until 2025-11-26 4:40
            let satellite: String = (run >= Timestamp(2022, 12, 13) && run <= Timestamp(2025,10,11,15,20)) || run >= Timestamp(2025,11,26,4,50) ? "H09" : "H08"
            switch domain {
            case .himawari_10min, .himawari_70e_10min:
                path = "/pub/himawari/L2/PAR/021/\(c.year)\(c.mm)/\(c.dd)/\(run.hh)/\(satellite)_\(run.format_YYYYMMdd)_\(run.hh)\(run.mm)_RFL021_FLDK.0\(domain.grid.nx)_02401.nc"
            // case .himawari_hourly:
            //    path = "/pub/himawari/L3/PAR/021/\(c.year)\(c.mm)/\(c.dd)/H09_\(run.format_YYYYMMdd)_\(run.hh)00_1H_RFL021_FLDK.02401_02401.nc"
            case .mtg_fci_10min:
                // pub/mtg/L2/PAR/001/202510/16/06/M3_FCI_20251016_0630_RFL001_FLDK.02801_02401.nc
                path = "/pub/mtg/L2/PAR/001/\(c.year)\(c.mm)/\(c.dd)/\(run.hh)/M3_FCI_\(run.format_YYYYMMdd)_\(run.hh)\(run.mm)_RFL001_FLDK.02801_02401.nc"
            }

            guard let data = try await downloader.get(logger: logger, path: path) else {
                logger.warning("File missing")
                return nil
            }
            do {
                guard var sw = try data.readNetcdf(name: "SWR") else {
                    logger.warning("warning: Could not open variable SWR. Skipping")
                    return nil
                }

                // Transform instant solar radiation values to backwards averaged values
                // Instant values have a scan time difference which needs to be corrected for
                if variable == .shortwave_radiation {
                    let start = DispatchTime.now()
                    let timerange = TimerangeDt(start: run, nTime: 1, dtSeconds: domain.dtSeconds)
                    Zensun.instantaneousSolarRadiationToBackwardsAverages(
                        timeOrientedData: &sw.data,
                        grid: domain.grid,
                        locationRange: 0..<domain.grid.count,
                        timerange: timerange,
                        scanTimeDifferenceHours: timeDifference,
                        sunDeclinationCutOffDegrees: 1
                    )
                    logger.info("\(variable) conversion took \(start.timeElapsedPretty())")
                }

                let writer = OmFileSplitter.makeSpatialWriter(domain: domain, nTime: 1)
                let fn = try writer.writeTemporary(compressionType: .pfor_delta2d_int16, scalefactor: variable.scalefactor, all: sw.data)
                return try await GenericVariableHandle(
                    variable: variable,
                    time: run,
                    member: 0,
                    fn: fn,
                    domain: domain
                )
            } catch NetCDFError.ncerror(let code, let error) {
                logger.info("Skipping NetCDF error \(code): \(error)")
                return nil
            } catch NetCDFError.hdf5Error {
               logger.info("Skipping HDF5 error")
               return nil
           }
        })
    }
}

fileprivate struct JaxaFtpDownloader {
    let ftp: FtpDownloader
    let auth: String

    public init(username: String, password: String) {
        self.auth = "\(username):\(password)"
        self.ftp = .init()
    }

    public func get(logger: Logger, path: String) async throws -> Data? {
        let url = "ftp://\(auth)@ftp.ptree.jaxa.jp\(path)"
        return try await ftp.get(logger: logger, url: url)
    }
}

fileprivate extension Data {
    func readNetcdf(name: String) throws -> Array2D? {
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
            return nil
        }
    }
}
