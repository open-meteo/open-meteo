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
        
        /// Cronjob every 10 minutes. Make sure there is no overlap. Minus 5 seconds to prevent race conditions
        Process.alarm(seconds: 10*60 - 5)
        let timestampFile = "\(domain.downloadDirectory)last.txt"
        let lastDownloadedTimeStep = ((try? String(contentsOfFile: timestampFile, encoding: .utf8))?.toTimestamp())
        let curl = Curl(logger: logger, client: context.application.dedicatedHttpClient)
        async let sisListing = curl.downloadInMemoryAsync(url: Self.sisDirectory, minSize: nil)
        async let sidListing = curl.downloadInMemoryAsync(url: Self.sidDirectory, minSize: nil)
        guard let sisHtml = try await sisListing.readStringImmutable(),
              let sidHtml = try await sidListing.readStringImmutable() else {
            throw Abort(.badGateway, reason: "Could not decode DWD SIS directory listing")
        }

        let sisRuns = Self.availableRuns(in: sisHtml, filePrefix: "SISin")
        let sidRuns = Self.availableRuns(in: sidHtml, filePrefix: "SIDin")
        let availableRuns = sisRuns.intersection(sidRuns).filter {
            $0 > (lastDownloadedTimeStep ?? Timestamp(0))
        }.sorted()
        guard !availableRuns.isEmpty else {
            logger.info("All steps already downloaded")
            return
        }
        let lastTimestampFile = timestampFile
        logger.info("Downloading \(availableRuns.count) available steps from \(availableRuns.first!.iso8601_YYYY_MM_dd_HH_mm) to \(availableRuns.last!.iso8601_YYYY_MM_dd_HH_mm)")
        let handles = try await availableRuns.asyncFlatMap { run -> [GenericVariableHandle] in
            return try await downloadRun(application: context.application, run: run, domain: domain)
        }
        try FileManager.default.createDirectory(atPath: domain.downloadDirectory, withIntermediateDirectories: true)
        let last = availableRuns.last!
        try "\(last.timeIntervalSince1970)".write(toFile: lastTimestampFile, atomically: true, encoding: .utf8)
        Process.alarm(seconds: 0)
        try await GenericVariableHandle.convert(application: context.application, domain: domain, createNetcdf: signature.createNetcdf, run: nil, handles: handles, concurrent: nConcurrent, writeUpdateJson: true, uploadS3Bucket: signature.uploadS3Bucket, uploadS3OnlyProbabilities: false)
    }

    static let sisDirectory = "https://opendata.dwd.de/weather/satellite/radiation/sis/"
    static let sidDirectory = "https://opendata.dwd.de/weather/satellite/radiation/sid/"

    /// Extract compressed EA v4 products from the Apache directory listing. A set is
    /// used because every filename occurs both in the link target and as link text.
    static func availableRuns(in html: String, filePrefix: String) -> Set<Timestamp> {
        let marker = "\(filePrefix)"
        let suffix = "EAv4.nc.bz2"
        var runs = Set<Timestamp>()
        var searchStart = html.startIndex

        while let markerRange = html.range(of: marker, range: searchStart..<html.endIndex) {
            let timestampStart = markerRange.upperBound
            guard let timestampEnd = html.index(timestampStart, offsetBy: 12, limitedBy: html.endIndex) else {
                break
            }
            let timestampString = html[timestampStart..<timestampEnd]
            let suffixEnd = html.index(timestampEnd, offsetBy: suffix.count, limitedBy: html.endIndex)
            if timestampString.allSatisfy(\.isNumber),
               let suffixEnd,
               html[timestampEnd..<suffixEnd] == suffix,
               let year = Int(timestampString[0..<4]),
               let month = Int(timestampString[4..<6]),
               let day = Int(timestampString[6..<8]),
               let hour = Int(timestampString[8..<10]),
               let minute = Int(timestampString[10..<12]) {
                runs.insert(Timestamp(year, month, day, hour, minute))
            }
            searchStart = timestampEnd
        }
        return runs
    }
    
    fileprivate func downloadRun(application: Application, run: Timestamp, domain: DwdSisDomain) async throws -> [GenericVariableHandle] {
        let logger = application.logger
        let curl = Curl(logger: application.logger, client: application.dedicatedHttpClient)
        let writer = OmFileSplitter.makeSpatialWriter(domain: domain, nTime: 1)
        /// We add 10 minutes to the downloaded timestamp. We use backwards averaged values while `run` refers to scan start time
        /// E.g. The 10:00 run contains values for Europe at around 10:08. We project data for an average value between 10:00 and 10:10.
        /// The final values is then stored in the 10:10 step.
        let time = run.add(domain.dtSeconds)
        let timerange = TimerangeDt(start: time, nTime: 1, dtSeconds: domain.dtSeconds)
        
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
            /// subtract from 10 minutes, because we project data forwards
            return (-10*60 + 3*60 + lineFraction * sweepTimeOfLimitedLatitudeRangeSeconds) / 3600
        }
        
        let sisFile = "\(Self.sisDirectory)SISin\(run.format_YYYYMMddHHmm)EAv4.nc.bz2"
        let sidFile = "\(Self.sidDirectory)SIDin\(run.format_YYYYMMddHHmm)EAv4.nc.bz2"

        var (sis, sisc) = try await curl.downloadInMemoryAsync(url: sisFile, minSize: nil, bzip2Decode: true).withUnsafeBytes({
            guard let nc = try NetCDF.open(memory: $0) else {
                fatalError("Failed to open \(sisFile)")
            }
            guard let sis = try nc.getVariable(name: "SIS")?.readAndScale(),
                  let sisc = try nc.getVariable(name: "SISc")?.readAndScale() else {
                fatalError("Failed to read variables from \(sisFile)")
            }
            return (sis, sisc)
        })
        var sid = try await curl.downloadInMemoryAsync(url: sidFile, minSize: nil, bzip2Decode: true).withUnsafeBytes({
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
        Zensun.instantaneousSolarRadiationToBackwardsAverages(
            timeOrientedData: &sis,
            grid: domain.grid,
            locationRange: 0..<domain.grid.count,
            timerange: timerange,
            sunDeclinationCutOffDegrees: 1,
            scanTimeDifferenceHours: timeDifference
        )
        Zensun.instantaneousSolarRadiationToBackwardsAverages(
            timeOrientedData: &sisc,
            grid: domain.grid,
            locationRange: 0..<domain.grid.count,
            timerange: timerange,
            sunDeclinationCutOffDegrees: 1,
            scanTimeDifferenceHours: timeDifference
        )
        Zensun.instantaneousSolarRadiationToBackwardsAverages(
            timeOrientedData: &sid,
            grid: domain.grid,
            locationRange: 0..<domain.grid.count,
            timerange: timerange,
            sunDeclinationCutOffDegrees: 1,
            scanTimeDifferenceHours: timeDifference
        )
        logger.info("instantaneousSolarRadiationToBackwardsAverages took \(start.timeElapsedPretty())")
        
        return [
            try await GenericVariableHandle(
                variable: DwdSisVariable.shortwave_radiation,
                time: time,
                member: 0,
                fn: writer.writeTemporary(compressionType: .pfor_delta2d_int16, scalefactor: 1, all: sis),
                domain: domain
            ),
            try await GenericVariableHandle(
                variable: DwdSisVariable.shortwave_radiation_clear_sky,
                time: time,
                member: 0,
                fn: writer.writeTemporary(compressionType: .pfor_delta2d_int16, scalefactor: 1, all: sisc),
                domain: domain
            ),
            try await GenericVariableHandle(
                variable: DwdSisVariable.direct_radiation,
                time: time,
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
    
    var generateFullRun: Bool {
         return false
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
