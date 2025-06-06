import Foundation
import Vapor
import SwiftNetCDF
import OmFileFormat

/**
 Download wave model form the german weather service
 https://www.dwd.de/DE/leistungen/opendata/help/modelle/legend_ICON_wave_EN_pdf.pdf?__blob=publicationFile&v=3
 
 All equations: https://library.wmo.int/doc_num.php?explnum_id=10979
 */
struct DownloadIconWaveCommand: AsyncCommand {
    struct Signature: CommandSignature {
        @Argument(name: "domain")
        var domain: String

        @Option(name: "run")
        var run: String?

        @Option(name: "only-variables")
        var onlyVariables: String?

        @Option(name: "upload-s3-bucket", help: "Upload open-meteo database to an S3 bucket after processing")
        var uploadS3Bucket: String?

        @Flag(name: "create-netcdf")
        var createNetcdf: Bool

        @Option(name: "concurrent", short: "c", help: "Number of concurrent download/conversion jobs")
        var concurrent: Int?

        @Option(name: "max-forecast-hour", help: "Only download data until this forecast hour")
        var maxForecastHour: Int?
    }

    var help: String {
        "Download a specified wave model run"
    }

    func run(using context: CommandContext, signature: Signature) async throws {
        let domain = try IconWaveDomain.load(rawValue: signature.domain)

        let runHH = signature.run.map {
            guard let run = Int($0) else {
                fatalError("Invalid run '\($0)'")
            }
            return run
        } ?? domain.lastRun

        let onlyVariables = try IconWaveVariable.load(commaSeparatedOptional: signature.onlyVariables)

        let logger = context.application.logger
        let run = Timestamp.now().with(hour: runHH)
        logger.info("Downloading domain '\(domain.rawValue)' run '\(run.iso8601_YYYY_MM_dd_HH_mm)'")

        let variables = onlyVariables ?? IconWaveVariable.allCases
        let handles = try await download(application: context.application, domain: domain, run: run, variables: variables, maxForecastHour: signature.maxForecastHour, uploadS3Bucket: signature.uploadS3Bucket)
        let nConcurrent = signature.concurrent ?? 1
        try await GenericVariableHandle.convert(logger: logger, domain: domain, createNetcdf: signature.createNetcdf, run: run, handles: handles, concurrent: nConcurrent, writeUpdateJson: true, uploadS3Bucket: signature.uploadS3Bucket, uploadS3OnlyProbabilities: false)
    }

    /// Download all timesteps and preliminarily covnert it to compressed files
    func download(application: Application, domain: IconWaveDomain, run: Timestamp, variables: [IconWaveVariable], maxForecastHour: Int?, uploadS3Bucket: String?) async throws -> [GenericVariableHandle] {
        // https://opendata.dwd.de/weather/maritime/wave_models/gwam/grib/00/mdww/GWAM_MDWW_2022072800_000.grib2.bz2
        // https://opendata.dwd.de/weather/maritime/wave_models/ewam/grib/00/mdww/EWAM_MDWW_2022072800_000.grib2.bz2
        let baseUrl = "http://opendata.dwd.de/weather/maritime/wave_models/\(domain.rawValue)/grib/\(run.hour.zeroPadded(len: 2))/"
        let logger = application.logger
        try FileManager.default.createDirectory(atPath: domain.downloadDirectory, withIntermediateDirectories: true)

        let curl = Curl(logger: logger, client: application.dedicatedHttpClient)
        let nx = domain.grid.nx
        let ny = domain.grid.ny

        let writer = OmRunSpatialWriter(domain: domain, run: run, storeOnDisk: true)

        var grib2d = GribArray2D(nx: nx, ny: ny)

        let handles = try await (0..<(maxForecastHour ?? domain.countForecastHours)).asyncFlatMap { forecastStep in
            /// E.g. 0,3,6...174 for gwam
            let forecastHour = forecastStep * domain.dtHours
            let timestamp = run.add(hours: forecastHour)
            logger.info("Downloading hour \(forecastHour)")
            
            let handles: [GenericVariableHandle] = try await variables.asyncCompactMap { variable in
                guard variable.availableFor(domain: domain) else {
                    return nil
                }
                let url = "\(baseUrl)\(variable.dwdName)/\(domain.rawValue.uppercased())_\(variable.dwdName.uppercased())_\(run.format_YYYYMMddHH)_\(forecastHour.zeroPadded(len: 3)).grib2.bz2"

                let message = try await curl.downloadGrib(url: url, bzip2Decode: true)[0]
                try grib2d.load(message: message)
                if domain == .gwam {
                    grib2d.array.shift180LongitudeAndFlipLatitude()
                } else {
                    grib2d.array.flipLatitude()
                }

                /// Create elevation file for sea mask
                if !FileManager.default.fileExists(atPath: domain.surfaceElevationFileOm.getFilePath()) {
                    var elevation = grib2d.array.data
                    for i in elevation.indices {
                        /// `NaN` out of domain, `-999` sea grid point
                        elevation[i] = elevation[i].isNaN ? .nan : -999
                    }
                    try domain.surfaceElevationFileOm.createDirectory()
                    try elevation.writeOmFile2D(file: domain.surfaceElevationFileOm.getFilePath(), grid: domain.grid, createNetCdf: false)
                }
                
                return try writer.write(time: timestamp, member: 0, variable: variable, data: grib2d.array.data)
            }
            if let uploadS3Bucket {
                try domain.domainRegistry.syncToS3Spatial(bucket: uploadS3Bucket, timesteps: [timestamp])
            }
            return handles
        }
        await curl.printStatistics()
        return handles
    }
}

extension IconWaveDomain {
    /// Based on the current time , guess the current run that should be available soon on the open-data server
    fileprivate var lastRun: Int {
        let t = Timestamp.now()
        switch self {
        case .ewam, .gwam:
            // Wave models have a delay of 3-4 hours after initialisation
            return ((t.hour - 3 + 24) % 24) / 12 * 12
        }
    }
}
