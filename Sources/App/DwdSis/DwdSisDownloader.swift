import Vapor
import SwiftNetCDF
import AsyncHTTPClient

/**
 Satellite solar radiation from DWD open-data server
 https://www.dwd.de/DE/leistungen/fernerkund_globalstrahlung_sis/fernerkund_globalstrahlung_sis.html
 */
struct DwdSisDownloader: AsyncCommand {
    struct Signature: CommandSignature {
        @Argument(name: "domain")
        var domain: String

        @Flag(name: "create-netcdf")
        var createNetcdf: Bool

        @Option(name: "concurrent", short: "c", help: "Number of concurrent download/conversion jobs")
        var concurrent: Int?

        @Option(name: "upload-s3-bucket", help: "Upload open-meteo database to an S3 bucket after processing")
        var uploadS3Bucket: String?
    }

    var help: String {
        "Download DWD satellite radiation data"
    }

    func run(using context: CommandContext, signature: Signature) async throws {
        disableIdleSleep()
        let logger = context.application.logger
        let domain = try DwdSisDomain.load(rawValue: signature.domain)
        let nConcurrent = signature.concurrent ?? 1
        
        /// Cronjob every 10 minutes. Make sure there is no overlap.
        Process.alarm(seconds: 10*60)
        defer { Process.alarm(seconds: 0) }

        let timestampFile = "\(domain.downloadDirectory)last.txt"
        let firstAvailableTimeStep = Timestamp.now().subtract(minutes: 30).floor(toNearest: domain.dtSeconds)
        let endTime = Timestamp.now().subtract(minutes: 10).floor(toNearest: domain.dtSeconds).add(domain.dtSeconds)
        let lastDownloadedTimeStep = ((try? String(contentsOfFile: timestampFile, encoding: .utf8))?.toTimestamp())
        let startTime = max(lastDownloadedTimeStep?.add(domain.dtSeconds) ?? firstAvailableTimeStep, firstAvailableTimeStep)
        guard startTime <= endTime else {
            logger.info("All steps already downloaded")
            return
        }
        let downloadRange = TimerangeDt(range: startTime ..< endTime, dtSeconds: domain.dtSeconds)
        let lastTimestampFile = timestampFile
        logger.info("Downloading range \(downloadRange.prettyString())")
        let handles = try await downloadRange.enumerated().asyncFlatMap { i, run -> [GenericVariableHandle] in
            return try await downloadRun(application: context.application, run: run, domain: domain)
        }
        if let last = handles.max(by: { $0.time.range.lowerBound < $1.time.range.lowerBound })?.time.range.lowerBound {
            try FileManager.default.createDirectory(atPath: domain.downloadDirectory, withIntermediateDirectories: true)
            try "\(last.timeIntervalSince1970)".write(toFile: lastTimestampFile, atomically: true, encoding: .utf8)
        }
        try await GenericVariableHandle.convert(logger: logger, domain: domain, createNetcdf: signature.createNetcdf, run: nil, handles: handles, concurrent: nConcurrent, writeUpdateJson: true, uploadS3Bucket: signature.uploadS3Bucket, uploadS3OnlyProbabilities: false)
    }
    
    fileprivate func downloadRun(application: Application, run: Timestamp, domain: DwdSisDomain) async throws -> [GenericVariableHandle] {
        let logger = application.logger
        let curl = Curl(logger: application.logger, client: application.dedicatedHttpClient)
        let writer = OmFileSplitter.makeSpatialWriter(domain: domain, nTime: 1)
        
        /// MTG FCI image scans are performed from South to North. Scan time is around 9 minutes 30 seconds
        /// Hence in Northern Europe the line acquisition time deviates from the slot time by approximately 8 minutes.
        /// OpenMeteo grids are ordered South to North, therefore the scan time should increase with the line number
        /// We use a linear interpolation assuming 15 seconds offset from start and 9:30 sweep time
        /// The latitude range is limited to -38 to 65... 4121 lines
        /// Total latitude range (-90 ... 90) would be 7201 pixels, but we only have 4121 pixels, so we need to adjust the time difference accordingly
        /// The southernmost line is acquired 15 seconds plus (90-38)*1/0.025 = 2080 lines by 9.5 minutes => total 3 minutes after sweep start
        /// The scan-time for the limited latitude range is ~5:26 minutes
        /// This is not 100% correct, but a reasonable approximation
        let sweepTimeOfLimitedLatitudeRangeSeconds = (4121/7201*9.5*60)
        let timeDifference: [Double] = (0..<3201 * 4121).map {
            let line = $0 / 3201
            let lineFraction = Double(line) / (4121-1)
            return (3*60 + lineFraction * sweepTimeOfLimitedLatitudeRangeSeconds) / 3600
        }
        
        let sisFile = "https://opendata.dwd.de/weather/satellite/radiation/sis/SISin\(run.format_YYYYMMddHHmm)EAv4.nc"
        let sidFile = "https://opendata.dwd.de/weather/satellite/radiation/sid/SIDin\(run.format_YYYYMMddHHmm)EAv4.nc"

        var (sis, sisc) = try await curl.downloadInMemoryAsync(url: sisFile, minSize: nil).withUnsafeBytes({
            guard let nc = try NetCDF.open(memory: $0) else {
                fatalError("Failed to open \(sisFile)")
            }
            guard let sis = try nc.getVariable(name: "SIS")?.readAndScale(),
                  let sisc = try nc.getVariable(name: "SISc")?.readAndScale() else {
                fatalError("Failed to read variables from \(sisFile)")
            }
            return (sis, sisc)
        })
        var sid = try await curl.downloadInMemoryAsync(url: sidFile, minSize: nil).withUnsafeBytes({
            guard let nc = try NetCDF.open(memory: $0) else {
                fatalError("Failed to open \(sidFile)")
            }
            guard let sid = try nc.getVariable(name: "SID")?.readAndScale() else {
                fatalError("Failed to read variables from \(sidFile)")
            }
            return sid
        })
        // Transform instant solar radiation values to backwards averaged values
        // Instant values have a scan time difference which needs to be corrected for
        let start = DispatchTime.now()
        let timerange = TimerangeDt(start: run, nTime: 1, dtSeconds: domain.dtSeconds)
        Zensun.instantaneousSolarRadiationToBackwardsAverages(
            timeOrientedData: &sis,
            grid: domain.grid,
            locationRange: 0..<domain.grid.count,
            timerange: timerange,
            scanTimeDifferenceHours: timeDifference,
            sunDeclinationCutOffDegrees: 1
        )
        Zensun.instantaneousSolarRadiationToBackwardsAverages(
            timeOrientedData: &sisc,
            grid: domain.grid,
            locationRange: 0..<domain.grid.count,
            timerange: timerange,
            scanTimeDifferenceHours: timeDifference,
            sunDeclinationCutOffDegrees: 1
        )
        Zensun.instantaneousSolarRadiationToBackwardsAverages(
            timeOrientedData: &sid,
            grid: domain.grid,
            locationRange: 0..<domain.grid.count,
            timerange: timerange,
            scanTimeDifferenceHours: timeDifference,
            sunDeclinationCutOffDegrees: 1
        )
        logger.info("instantaneousSolarRadiationToBackwardsAverages took \(start.timeElapsedPretty())")
        
        return [
            try await GenericVariableHandle(
                variable: DwdSisVariable.shortwave_radiation,
                time: run,
                member: 0,
                fn: writer.writeTemporary(compressionType: .pfor_delta2d_int16, scalefactor: 1, all: sis),
                domain: domain
            ),
            try await GenericVariableHandle(
                variable: DwdSisVariable.shortwave_radiation_clear_sky,
                time: run,
                member: 0,
                fn: writer.writeTemporary(compressionType: .pfor_delta2d_int16, scalefactor: 1, all: sisc),
                domain: domain
            ),
            try await GenericVariableHandle(
                variable: DwdSisVariable.direct_radiation,
                time: run,
                member: 0,
                fn: writer.writeTemporary(compressionType: .pfor_delta2d_int16, scalefactor: 1, all: sid),
                domain: domain
            )
        ]
    }
}

enum DwdSisDomain: String, CaseIterable, GenericDomain {
    case europe_africa_v4
    
    var grid: any Gridable {
        // latitude = -38 ... 65
        // longitude = -20 ... 60
        return RegularGrid(nx: 3201, ny: 4121, latMin: -38, lonMin: -20, dx: 0.025, dy: 0.025)
    }
    
    var domainRegistry: DomainRegistry {
        return .dwd_sis_europe_africa_v4
    }
    
    var domainRegistryStatic: DomainRegistry? {
        return domainRegistry
    }
    
    var dtSeconds: Int {
        return 10*60
    }
    
    var updateIntervalSeconds: Int  {
        return 10*60
    }
    
    var hasYearlyFiles: Bool {
        return false
    }
    
    var masterTimeRange: Range<Timestamp>? {
        return nil
    }
    
    var omFileLength: Int {
        // two days of 10 minutely data per file
        return 2*6*24
    }
    
    var countEnsembleMember: Int {
        return 1
    }
}


enum DwdSisVariable: String, GenericVariable {
    case shortwave_radiation
    case direct_radiation
    case shortwave_radiation_clear_sky
    
    var omFileName: (file: String, level: Int) {
        return (rawValue, 0)
    }
    
    var scalefactor: Float {
        switch self {
        case .shortwave_radiation, .direct_radiation, .shortwave_radiation_clear_sky:
            return 1
        }
    }
    
    var interpolation: ReaderInterpolation {
        switch self {
        case .shortwave_radiation, .direct_radiation, .shortwave_radiation_clear_sky:
            return .solar_backwards_missing_not_averaged
        }
    }
    
    var unit: SiUnit {
        switch self {
        case .shortwave_radiation, .direct_radiation, .shortwave_radiation_clear_sky:
            return .wattPerSquareMetre
        }
    }

    var isElevationCorrectable: Bool {
        return false
    }

    var storePreviousForecast: Bool {
        return false
    }
}

