import Foundation
import Vapor
import OmFileFormat
import Dispatch

/**
 Download command for the AICON model (DWD's AI-based ICON variant).

 AICON provides 3-hourly forecasts up to 180 h on the same global R3B7 icosahedral grid
 as ICON global, remapped to a regular lat-lon grid on the opendata server.
 Data is served under:
   http://opendata.dwd.de/weather/nwp/v1/m/aicon/p/

 URL patterns
 ────────────
 Surface variables:
   .../p/{VAR}/r/{YYYY-MM-DDTHH:00}/s/PT{HHH}H00M.grib2

 Model-level variables (13 levels, 1-based):
   .../p/{VAR}/lvt1/150/lv1/{LEVEL}/r/{YYYY-MM-DDTHH:00}/s/PT{HHH}H00M.grib2

 Unlike classic ICON open-data, AICON files are plain .grib2 (no bzip2 compression).
 The remapped lat-lon grid matches ICON global exactly, so the same CDO weights are reused
 via CdoHelper (which returns nil for AiconDomain.iconGridName, skipping the icosahedral
 remapping step and reading the array directly at the correct dimensions).
 */
struct DownloadAiconCommand: AsyncCommand {
    struct Signature: CommandSignature {
        @Argument(name: "domain")
        var domain: String

        @Option(name: "run", help: "Model run to download, e.g. '12' for today's 12z run")
        var run: String?

        @Option(name: "concurrent", short: "c", help: "Number of concurrent download/conversion jobs")
        var concurrent: Int?

        @Flag(name: "create-netcdf")
        var createNetcdf: Bool

        @Option(name: "only-variables", help: "Comma-separated list of surface variables to download")
        var onlyVariables: String?

        @Option(name: "upload-s3-bucket", help: "Upload open-meteo database to an S3 bucket after processing")
        var uploadS3Bucket: String?
    }

    let help: String = "Download a specified AICON model run"

    /**
     Download all requested variables for one model run.

     For every 3-hourly forecast step (3, 6, … 180 h) all surface and model-level
     variables are downloaded concurrently, remapped if necessary via CdoHelper,
     and written to the om-file storage.
     */
    func downloadAicon(
        application: Application,
        domain: AiconDomain,
        run: Timestamp,
        surfaceVariables: [AiconSurfaceVariable],
        modelLevelVariables: [AiconModelLevelVariable],
        concurrent: Int,
        uploadS3Bucket: String?
    ) async throws -> [GenericVariableHandle] {
        let logger = application.logger
        
        try FileManager.default.createDirectory(atPath: domain.domainRegistry.directoryStatic, withIntermediateDirectories: true)
        
        let downloadDirectory = domain.downloadDirectory
        try FileManager.default.createDirectory(atPath: downloadDirectory, withIntermediateDirectories: true)
        
        let curl = Curl(
            logger: logger,
            client: application.dedicatedHttpClient,
            deadLineHours: 5,
            waitAfterLastModified: 120
        )
        Process.alarm(seconds: 6 * 3600)
        defer { Process.alarm(seconds: 0) }
        
        let cdo = try await CdoHelper(domain: domain, logger: logger, curl: curl)

        let deaverager = GribDeaverager()
        let timestamps = domain.forecastSteps.map { run.add(hours: $0) }

        let handles = try await timestamps.enumerated().asyncMap { (i, timestamp) -> [GenericVariableHandle] in
            let forecastHours = (timestamp.timeIntervalSince1970 - run.timeIntervalSince1970) / 3600
            logger.info("Downloading AICON hour \(forecastHours)")

            let writer = OmSpatialTimestepWriter(
                domain: domain,
                run: run,
                time: timestamp,
                storeOnDisk: true,
                realm: nil
            )

            // Download surface variables concurrently
            try await surfaceVariables.foreachConcurrent(nConcurrent: concurrent) { variable in
                let url = domain.surfaceVariableUrl(
                    variable: variable.gribVariableName,
                    run: run,
                    forecastHours: forecastHours
                )
                // bzip2Decode: false — AICON files are plain .grib2
                let messages = try await cdo.downloadAndRemap(url, bzip2Decode: false)
                for (message, var array2d) in messages {
                    // guard let stepRange = message.get(attribute: "stepRange"),
                    //       let stepType  = message.get(attribute: "stepType") else {
                    //     fatalError("AICON GRIB2 message is missing stepRange / stepType")
                    // }
                    if let fma = variable.multiplyAdd {
                        array2d.data.multiplyAdd(multiply: fma.multiply, add: fma.add)
                    }
                    try await writer.write(member: 0, variable: variable, data: array2d.data)
                }
            }

            // Download model-level variables concurrently
            try await modelLevelVariables.foreachConcurrent(nConcurrent: concurrent) { variable in
                let url = domain.modelLevelVariableUrl(
                    variable: variable.gribVariableName,
                    level: variable.level,
                    run: run,
                    forecastHours: forecastHours
                )
                // bzip2Decode: false — AICON files are plain .grib2
                let messages = try await cdo.downloadAndRemap(url, bzip2Decode: false)
                for (message, var array2d) in messages {
                    guard let stepRange = message.get(attribute: "stepRange"),
                          let stepType  = message.get(attribute: "stepType") else {
                        fatalError("AICON GRIB2 message is missing stepRange / stepType")
                    }
                    if let fma = variable.multiplyAdd {
                        array2d.data.multiplyAdd(multiply: fma.multiply, add: fma.add)
                    }
                    // guard await deaverager.deaccumulateIfRequired(
                    //     variable: variable,
                    //     member: 0,
                    //     stepType: stepType,
                    //     stepRange: stepRange,
                    //     array2d: &array2d
                    // ) else {
                    //     continue
                    // }
                    try await writer.write(member: 0, variable: variable, data: array2d.data)
                }
            }

            let completed = i == timestamps.count - 1
            return try await writer.finalise(
                completed: completed,
                validTimes: Array(timestamps[0...i]),
                uploadS3Bucket: uploadS3Bucket
            )
        }

        await curl.printStatistics()
        return handles.flatMap { $0 }
    }

    func run(using context: CommandContext, signature: Signature) async throws {
        let start = DispatchTime.now()
        let logger = context.application.logger

        let domain = try AiconDomain.load(rawValue: signature.domain)
        let nConcurrent = signature.concurrent ?? 1
        let run = try signature.run.flatMap(Timestamp.fromRunHourOrYYYYMMDD) ?? domain.lastRun

        logger.info("Downloading AICON domain '\(domain.rawValue)' run '\(run.iso8601_YYYY_MM_dd_HH_mm)'")

        // Build default variable lists: all surface variables + all 13 model levels × 5 types
        let defaultSurface = AiconSurfaceVariable.allCases
        let defaultModelLevel: [AiconModelLevelVariable] = domain.modelLevels.flatMap { level in
            AiconModelLevelVariableType.allCases.map { AiconModelLevelVariable(variable: $0, level: level) }
        }

        // Optionally restrict to a user-supplied comma-separated list of surface variable names
        let surfaceVariables: [AiconSurfaceVariable]
        let modelLevelVariables: [AiconModelLevelVariable]
        if let onlyVariablesStr = signature.onlyVariables {
            surfaceVariables = try onlyVariablesStr.split(separator: ",").map {
                try AiconSurfaceVariable.load(rawValue: String($0))
            }
            modelLevelVariables = []
        } else {
            surfaceVariables = defaultSurface
            modelLevelVariables = defaultModelLevel
        }

        let handles = try await downloadAicon(
            application: context.application,
            domain: domain,
            run: run,
            surfaceVariables: surfaceVariables,
            modelLevelVariables: modelLevelVariables,
            concurrent: nConcurrent,
            uploadS3Bucket: signature.uploadS3Bucket
        )

        try await GenericVariableHandle.convert(
            logger: logger,
            domain: domain,
            createNetcdf: signature.createNetcdf,
            run: run,
            handles: handles,
            concurrent: nConcurrent,
            writeUpdateJson: true,
            uploadS3Bucket: signature.uploadS3Bucket,
            uploadS3OnlyProbabilities: false,
            generateFullRun: true
        )

        logger.info("AICON download finished in \(start.timeElapsedPretty())")
    }
}
