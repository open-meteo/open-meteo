import Vapor
import SwiftHDF5
import AsyncHTTPClient

/// Download data from openradar-24h/ bucket at https://s3.waw3-1.cloudferro.com/
/// The data is organized in by days in directories such as
/// s3://openradar-24h/2026/02/13/OPERA/COMP/
/// An example file we want to download and convert to om-files is
/// OPERA@20260224T1445@0@RATE.h5 which contains precipitation rates over the
/// last 15 minutes. We need to aggregate this to a 15min precipitation sum.
struct EumetnetDownloader: AsyncCommand {
    struct Signature: CommandSignature {
        @Argument(name: "domain")
        var domain: String

        @Flag(name: "create-netcdf")
        var createNetcdf: Bool

        @Option(name: "concurrent", short: "c", help: "Number of concurrent download/conversion jobs")
        var concurrent: Int?

        @Option(name: "upload-s3-bucket", help: "Upload open-meteo database to an S3 bucket after processing")
        var uploadS3Bucket: String?

        @Option(name: "timeinterval", short: "t", help: "Timeinterval to download past data. Format 20220101-20220131")
        var timeinterval: String?

        @Option(name: "run", help: "A specific run timestamp to download. Format YYYYMMDDTHHMM")
        var run: String?
    }

    var help: String {
        "Download Eumetnet radar data"
    }

    func run(using context: CommandContext, signature: Signature) async throws {
        disableIdleSleep()
        let logger = context.application.logger
        let domain = try EumetnetDomain.load(rawValue: signature.domain)
        let nConcurrent = signature.concurrent ?? 1

        if let timeinterval = signature.timeinterval {
            let chunkDt = domain.omFileLength * domain.dtSeconds
            let timerange = try Timestamp.parseRange(yyyymmdd: timeinterval)
                .toRange(dt: 86400)
                .with(dtSeconds: domain.dtSeconds)
            for (_, runs) in timerange.groupedPreservedOrder(by: { $0.timeIntervalSince1970 / chunkDt }) {
                logger.info("Downloading runs \(runs.iso8601_YYYYMMddHHmm)")
                let handles = try await runs.asyncFlatMap { run in
                    return try await downloadRun(application: context.application, run: run, domain: domain)
                }
                try await GenericVariableHandle.convert(
                    logger: logger,
                    domain: domain,
                    createNetcdf: signature.createNetcdf,
                    run: runs[0],
                    handles: handles,
                    concurrent: nConcurrent,
                    writeUpdateJson: false,
                    uploadS3Bucket: nil,
                    uploadS3OnlyProbabilities: false
                )
            }
            return
        }

        if let runStr = signature.run {
            let run = try Timestamp.fromRunHourOrYYYYMMDD(runStr)
            let handles = try await downloadRun(application: context.application, run: run, domain: domain)
            try await GenericVariableHandle.convert(
                logger: logger,
                domain: domain,
                createNetcdf: signature.createNetcdf,
                run: run,
                handles: handles,
                concurrent: nConcurrent,
                writeUpdateJson: true,
                uploadS3Bucket: signature.uploadS3Bucket,
                uploadS3OnlyProbabilities: false
            )
            return
        }

        // Near-realtime mode: track last downloaded timestamp and download up to now
        Process.alarm(seconds: 15 * 60 - 5)
        defer { Process.alarm(seconds: 0) }

        let lastTimestampFile = "\(domain.downloadDirectory)last.txt"
        let firstAvailableTimeStep = Timestamp.now().subtract(minutes: 30).floor(toNearest: domain.dtSeconds)
        let endTime = Timestamp.now().floor(toNearest: domain.dtSeconds)
        let lastDownloadedTimeStep = ((try? String(contentsOfFile: lastTimestampFile, encoding: .utf8))?.toTimestamp())
        let startTime = max(lastDownloadedTimeStep?.add(domain.dtSeconds) ?? firstAvailableTimeStep, firstAvailableTimeStep)

        guard startTime <= endTime else {
            logger.info("All steps already downloaded")
            return
        }

        let downloadRange = TimerangeDt(range: startTime ..< endTime, dtSeconds: domain.dtSeconds)
        logger.info("Downloading range \(downloadRange.prettyString())")

        let handles = try await downloadRange.asyncFlatMap { run in
            return try await downloadRun(application: context.application, run: run, domain: domain)
        }

        try FileManager.default.createDirectory(atPath: domain.downloadDirectory, withIntermediateDirectories: true)
        if let last = handles.max(by: { $0.time.range.lowerBound < $1.time.range.lowerBound })?.time.range.lowerBound {
            try "\(last.timeIntervalSince1970)".write(toFile: lastTimestampFile, atomically: true, encoding: .utf8)
        }

        try await GenericVariableHandle.convert(
            logger: logger,
            domain: domain,
            createNetcdf: signature.createNetcdf,
            run: nil,
            handles: handles,
            concurrent: nConcurrent,
            writeUpdateJson: true,
            uploadS3Bucket: signature.uploadS3Bucket,
            uploadS3OnlyProbabilities: false
        )
    }

    fileprivate func downloadRun(application: Application, run: Timestamp, domain: EumetnetDomain) async throws -> [GenericVariableHandle] {
        let logger = application.logger
        let curl = Curl(logger: logger, client: application.dedicatedHttpClient, retryError4xx: false, stripPasswords: false)

        let server = "https://s3.waw3-1.cloudferro.com/openradar-24h"
        let dateDir = run.format_directoriesYYYYMMdd
        // e.g. OPERA@20260224T1445@0@RATE.h5
        let filename = "OPERA@\(run.format_YYYYMMdd)T\(run.hh)\(run.mm)@0@RATE.h5"
        // let url = "\(server)/\(dateDir)/OPERA/COMP/\(filename)"

        // FIXME: hardcoded file for local testing
        let url = "file:///home/fred/Downloads/opera/opera-files/OPERA@20260220T1645@0@RATE.h5"

        let tempFile = "\(domain.downloadDirectory)\(filename)"
        try FileManager.default.createDirectory(atPath: domain.downloadDirectory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(atPath: tempFile)
        }

        do {
            try await curl.download(url: url, toFile: tempFile, bzip2Decode: false)
        } catch CurlError.fileNotFound {
            logger.warning("File not found, skipping: \(url)")
            return []
        }

        guard FileManager.default.fileExists(atPath: tempFile) else {
            logger.warning("Downloaded file not found at \(tempFile), skipping")
            return []
        }

        logger.info("Processing \(filename)")

        // Open HDF5 file and read ODIM precipitation rate data
        let h5 = try SwiftHDF.open(file: tempFile, mode: .readOnly)

        // Read scale parameters from /dataset1/data1/what attributes
        let whatGroup = try h5.openGroup("dataset1").openGroup("data1").openGroup("what")
        let gain: Double = try whatGroup.readAttribute("gain")
        let offset: Double = try whatGroup.readAttribute("offset")
        let nodata: Double = try whatGroup.readAttribute("nodata")
        let undetect: Double = try whatGroup.readAttribute("undetect")

        // Read raw data array
        let dataset = try h5.openGroup("dataset1").openGroup("data1").openDataset("data")
        let dims = try dataset.getSpace().getDimensions()

        guard dims.count == 2, dims[0] == domain.grid.ny, dims[1] == domain.grid.nx else {
            fatalError("Data Layout not as expected: dims \(dims)")
        }

        let rawData: [Double] = try dataset.read()

        guard rawData.count == domain.grid.nx * domain.grid.ny else {
            logger.warning("Unexpected data size \(rawData.count), expected \(domain.grid.nx * domain.grid.ny). Skipping.")
            return []
        }

        // Convert from precipitation rate (mm/h) to 15-minute precipitation sum (mm).
        // nodata → NaN, undetect → 0 (no echo detected / below threshold), otherwise apply gain+offset.
        let dtHours = Double(domain.dtSeconds) / 3600.0
        var precipData: [Float] = rawData.map { v in
            let d = Double(v)
            if d == nodata {
                return Float.nan
            }
            if d == undetect {
                return 0.0
            }
            let rate = d * gain + offset
            return Float(max(0.0, rate) * dtHours)
        }

        // OPERA ODIM composites are stored top-to-bottom (north-to-south, row 0 = top/north).
        // Our ProjectionGrid stores data bottom-to-top (south-to-north, index 0 = bottom/south),
        // so we need to flip the latitude axis.
        precipData.flipLatitude(nt: 1, ny: domain.grid.ny, nx: domain.grid.nx)

        let writer = OmFileSplitter.makeSpatialWriter(domain: domain, nTime: 1)
        let fn = try writer.writeTemporary(
            compressionType: .pfor_delta2d_int16,
            scalefactor: EumetnetVariable.precipitation.scalefactor,
            all: precipData
        )
        return [
            try await GenericVariableHandle(
                variable: EumetnetVariable.precipitation,
                time: run,
                member: 0,
                fn: fn,
                domain: domain
            )
        ]
    }
}


enum EumetnetDomain: String, GenericDomain, CaseIterable {
    case opera_composite

    var grid: any Gridable {
        switch self {
        case .opera_composite:
            let projection = LambertAzimuthalEqualAreaProjection(λ0: 10, ϕ1: 55.0, radius: 6371229)
            return ProjectionGrid(
                nx: 1900,
                ny: 2200,
                latitudeProjectionOrigin: -2100000,
                longitudeProjectionOrigin: 1950000,
                dx: 2000,
                dy: 2000,
                projection: projection
            )
        }
    }

    var domainRegistry: DomainRegistry {
        switch self {
        case .opera_composite: return .eumetnet_opera
        }
    }

    var domainRegistryStatic: DomainRegistry? {
        return nil
    }

    var dtSeconds: Int {
        return 900
    }

    var updateIntervalSeconds: Int {
        return 900
    }

    var hasYearlyFiles: Bool {
        return false
    }

    var masterTimeRange: Range<Timestamp>? {
        return nil
    }

    var omFileLength: Int {
        return 24 * 4
    }

    var countEnsembleMember: Int {
        return 1
    }
}


enum EumetnetVariable: String, GenericVariable {
    case precipitation

    var omFileName: (file: String, level: Int) {
        return (rawValue, 0)
    }

    var scalefactor: Float {
        switch self {
        case .precipitation:
            return 10
        }
    }

    var interpolation: ReaderInterpolation {
        switch self {
        case .precipitation:
            return .backwards_sum
        }
    }

    var unit: SiUnit {
        switch self {
        case .precipitation:
            return .millimetre
        }
    }

    var isElevationCorrectable: Bool {
        return false
    }

    var storePreviousForecast: Bool {
        return false
    }
}
