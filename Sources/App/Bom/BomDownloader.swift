import Foundation
import OmFileFormat
import Vapor
import SwiftNetCDF

/**
 Downloader for BOM domains
 */
struct DownloadBomCommand: AsyncCommand {
    struct Signature: CommandSignature {
        @Option(name: "run")
        var run: String?

        @Argument(name: "domain")
        var domain: String

        @Option(name: "server", help: "Root server path")
        var server: String?

        @Option(name: "upload-s3-bucket", help: "Upload open-meteo database to an S3 bucket after processing")
        var uploadS3Bucket: String?

        @Flag(name: "create-netcdf")
        var createNetcdf: Bool

        @Flag(name: "upper-level")
        var upperLevel: Bool

        @Option(name: "concurrent", short: "c", help: "Numer of concurrent download/conversion jobs")
        var concurrent: Int?

        @Flag(name: "skip-existing", help: "ONLY FOR TESTING! Do not use in production. May update the database with stale data")
        var skipExisting: Bool

        @Flag(name: "upload-s3-only-probabilities", help: "Only upload probabilities files to S3")
        var uploadS3OnlyProbabilities: Bool
    }

    var help: String {
        "Download a specified Bom model run"
    }

    func run(using context: CommandContext, signature: Signature) async throws {
        disableIdleSleep()

        let domain = try BomDomain.load(rawValue: signature.domain)
        let run = try signature.run.flatMap(Timestamp.fromRunHourOrYYYYMMDD) ?? domain.lastRun
        let logger = context.application.logger

        logger.info("Downloading domain \(domain) run '\(run.iso8601_YYYY_MM_dd_HH_mm)'")

        guard let server = signature.server else {
            fatalError("Parameter 'server' is required")
        }

        let nConcurrent = signature.concurrent ?? 1
        try FileManager.default.createDirectory(atPath: domain.downloadDirectory, withIntermediateDirectories: true)
        try await downloadElevation(application: context.application, domain: domain, server: server, run: run)
        let handles = domain == .access_global_ensemble ?
            try await downloadEnsemble(application: context.application, domain: domain, run: run, server: server, concurrent: nConcurrent, skipFilesIfExisting: signature.skipExisting) : signature.upperLevel ?
            try await downloadModelLevel(application: context.application, domain: domain, run: run, server: server, concurrent: nConcurrent, skipFilesIfExisting: signature.skipExisting) :
            try await download(application: context.application, domain: domain, run: run, server: server, concurrent: nConcurrent, skipFilesIfExisting: signature.skipExisting)
        try await GenericVariableHandle.convert(logger: logger, domain: domain, createNetcdf: signature.createNetcdf, run: run, handles: handles, concurrent: nConcurrent, writeUpdateJson: true, uploadS3Bucket: signature.uploadS3Bucket, uploadS3OnlyProbabilities: signature.uploadS3OnlyProbabilities)
    }

    func downloadElevation(application: Application, domain: BomDomain, server: String, run: Timestamp) async throws {
        let logger = application.logger
        let surfaceElevationFileOm = domain.surfaceElevationFileOm.getFilePath()
        if FileManager.default.fileExists(atPath: surfaceElevationFileOm) {
            return
        }
        try domain.surfaceElevationFileOm.createDirectory()

        logger.info("Downloading height and elevation data")

        let curl = Curl(logger: logger, client: application.dedicatedHttpClient, deadLineHours: 4, waitAfterLastModifiedBeforeDownload: TimeInterval(60 * 500))
        var base = "\(server)\(run.format_YYYYMMdd)/\(run.hh)00/an/"
        if domain == .access_global_ensemble {
            base = "\(server)\(run.format_YYYYMMdd)/\(run.hh)00/cf/"
        }

        let topogFile = "\(domain.downloadDirectory)topog.nc"
        let lndMaskFile = "\(domain.downloadDirectory)lnd_mask.nc"
        if !FileManager.default.fileExists(atPath: topogFile) {
            _ = try await curl.downloadNetCdf(
                url: "\(base)sfc/topog.nc",
                file: topogFile,
                ncVariable: "topog",
                bzip2Decode: false
            )
        }
        if !FileManager.default.fileExists(atPath: lndMaskFile) {
            _ = try await curl.downloadNetCdf(
                url: "\(base)sfc/lnd_mask.nc",
                file: lndMaskFile,
                ncVariable: "lnd_mask",
                bzip2Decode: false
            )
        }

        guard var elevation = try NetCDF.open(path: topogFile, allowUpdate: false)?.getVariable(name: "topog")?.asType(Float.self)?.read() else {
            fatalError("Could not read topog file")
        }
        guard let landMask = try NetCDF.open(path: lndMaskFile, allowUpdate: false)?.getVariable(name: "lnd_mask")?.asType(Float.self)?.read() else {
            fatalError("Could not read topog file")
        }
        for i in elevation.indices {
            if landMask[i] <= 0 {
                // mask sea
                elevation[i] = -999
            }
        }

        elevation.shift180LongitudeAndFlipLatitude(nt: 1, ny: domain.grid.ny, nx: domain.grid.nx)
        try elevation.writeOmFile2D(file: surfaceElevationFileOm, grid: domain.grid)
    }

    /// Download model level wind on 40, 80 and 120 m. Model level have 1h delay
    func downloadModelLevel(application: Application, domain: BomDomain, run: Timestamp, server: String, concurrent: Int, skipFilesIfExisting: Bool) async throws -> [GenericVariableHandle] {
        let logger = application.logger
        let deadLineHours: Double = 6
        let curl = Curl(logger: logger, client: application.dedicatedHttpClient, deadLineHours: deadLineHours, waitAfterLastModifiedBeforeDownload: TimeInterval(60 * 15))
        Process.alarm(seconds: Int(deadLineHours + 1) * 3600)
        let variables = ["wnd_ucmp", "wnd_vcmp"]

        // Download u/v wind
        try await variables.foreachConcurrent(nConcurrent: concurrent) { variable in
            let base = "\(server)\(run.format_YYYYMMdd)/\(run.hh)00/"
            let analysisFile = "\(domain.downloadDirectory)\(variable)_an.nc"
            let forecastFile = "\(domain.downloadDirectory)\(variable)_fc.nc"
            if !skipFilesIfExisting || !FileManager.default.fileExists(atPath: analysisFile) {
                _ = try await curl.downloadNetCdf(
                    url: "\(base)an/ml/\(variable).nc",
                    file: analysisFile,
                    ncVariable: variable,
                    bzip2Decode: false
                )
            }
            if !skipFilesIfExisting || !FileManager.default.fileExists(atPath: forecastFile) {
                _ = try await curl.downloadNetCdf(
                    url: "\(base)fc/ml/\(variable).nc",
                    file: forecastFile,
                    ncVariable: variable,
                    bzip2Decode: false
                )
            }
        }

        // Convert
        let map: [(level: Float, speed: BomVariable, direction: BomVariable)] = [
            (36.664, .wind_speed_40m, .wind_direction_40m),
            (76.664, .wind_speed_80m, .wind_direction_80m),
            (130, .wind_speed_120m, .wind_direction_120m)
        ]
        let handles = try await map.mapConcurrent(nConcurrent: concurrent) { map -> [GenericVariableHandle] in
            logger.info("Calculate wind level \(map.level)")
            let writer = OmFileSplitter.makeSpatialWriter(domain: domain)
            return try zip(
                try combineAnalysisForecast(domain: domain, variable: "wnd_ucmp", run: run, level: map.level),
                try combineAnalysisForecast(domain: domain, variable: "wnd_vcmp", run: run, level: map.level)
            ).flatMap { u, v -> [GenericVariableHandle] in
                let timestamp = u.0
                let speed = zip(u.1, v.1).map(Meteorology.windspeed)
                let direction = Meteorology.windirectionFast(u: u.1, v: v.1)
                let fnSpeed = try writer.write(domain: domain, variable: map.speed, data: speed)
                let fnDirection = try writer.write(domain: domain, variable: map.direction, data: direction)
                return [
                    GenericVariableHandle(variable: map.speed, time: timestamp, member: 0, fn: fnSpeed),
                    GenericVariableHandle(variable: map.direction, time: timestamp, member: 0, fn: fnDirection)
                    ]
            }
        }.flatMap({ $0 })
        await curl.printStatistics()
        Process.alarm(seconds: 0)
        return handles
    }

    /// Download variables, convert to temporary om files and return all handles
    /// Ensemble do no have `rh_scrn` and `cld_phys_thunder_p`
    func downloadEnsemble(application: Application, domain: BomDomain, run: Timestamp, server: String, concurrent: Int, skipFilesIfExisting: Bool) async throws -> [GenericVariableHandle] {
        let logger = application.logger
        let deadLineHours: Double = 6
        let curl = Curl(logger: logger, client: application.dedicatedHttpClient, deadLineHours: deadLineHours, waitAfterLastModifiedBeforeDownload: TimeInterval(60 * 15))
        Process.alarm(seconds: Int(deadLineHours + 1) * 3600)

        // list of variables to download
        // http://www.bom.gov.au/nwp/doc/access/docs/ACCESS-G.all-flds.slv.surface.shtml
        let variables: [(name: String, om: BomVariable?)] = [
            ("temp_scrn", .temperature_2m),
            ("accum_conv_rain", .showers),
            ("accum_prcp", .precipitation),
            ("mslp", .pressure_msl),
            ("av_sfc_sw_dir", .direct_radiation),
            ("av_swsfcdown", .shortwave_radiation),
            // ("rh_scrn", .relative_humidity_2m),
            ("ttl_cld", .cloud_cover),
            /*("hi_cld", .cloud_cover_high),
            ("mid_cld", .cloud_cover_mid),
            ("low_cld", .cloud_cover_low),*/
            ("sfc_temp", .surface_temperature),
            ("snow_amt_lnd", .snow_depth),
            ("soil_temp", .soil_temperature_0_to_10cm),
            ("soil_temp2", .soil_temperature_10_to_35cm),
            ("soil_temp3", .soil_temperature_35_to_100cm),
            ("soil_temp4", .soil_temperature_100_to_300cm),
            ("soil_mois", .soil_moisture_0_to_10cm),
            ("soil_mois2", .soil_moisture_10_to_35cm),
            ("soil_mois3", .soil_moisture_35_to_100cm),
            ("soil_mois4", .soil_moisture_100_to_300cm),
            ("visibility", .visibility),
            ("wndgust10m", .wind_gusts_10m),
            ("uwnd10m", nil),
            ("vwnd10m", nil),
            ("accum_conv_snow", nil),
            ("accum_ls_snow", nil),
            ("dewpt_scrn", nil)
            // ("cld_phys_thunder_p", nil)
        ]

        let handles: [GenericVariableHandle] = try await variables.mapConcurrent(nConcurrent: concurrent) { variable -> [GenericVariableHandle] in
            var handles = try await (0..<domain.ensembleMembers).asyncFlatMap { member -> [GenericVariableHandle] in
                let base = "\(server)\(run.format_YYYYMMdd)/\(run.hh)00/"
                let forecastFile = "\(domain.downloadDirectory)\(variable.name)_fc_\(member).nc"
                let memberStr = ((run.hour % 12 == 6) ? (member + 17) : member).zeroPadded(len: 3)
                if !skipFilesIfExisting || !FileManager.default.fileExists(atPath: forecastFile) {
                    let url = member == 0 ? "\(base)cf/sfc/\(variable.name).nc" : "\(base)pf/\(memberStr)/sfc/\(variable.name).nc"
                    _ = try await curl.downloadNetCdf(
                        url: url,
                        file: forecastFile,
                        ncVariable: variable.name,
                        bzip2Decode: false
                    )
                }
                guard let omVariable = variable.om else {
                    return []
                }
                let writer = OmFileSplitter.makeSpatialWriter(domain: domain, nMembers: domain.ensembleMembers)
                logger.info("Compressing and writing data to member_\(member) \(omVariable.omFileName.file).om")
                return try self.iterateForecast(domain: domain, member: member, variable: variable.name, run: run).map { timestamp, data in
                    let fn = try writer.write(domain: domain, variable: omVariable, data: data)
                    return GenericVariableHandle(variable: omVariable, time: timestamp, member: member, fn: fn)
                }
            }
            if domain == .access_global_ensemble && variable.om == .precipitation {
                logger.info("Calculating precipitation probability")
                try handles.append(contentsOf: handles.calculatePrecipitationProbabilityMultipleTimestamps(
                    precipitationVariable: BomVariable.precipitation,
                    domain: domain
                ))
            }
            return handles
        }.flatMap({ $0 })

        let handlesSnow = try await (0..<domain.ensembleMembers).asyncFlatMap { member -> [GenericVariableHandle] in
            logger.info("Calculate weather codes and snow sum member_\(member)")
            return try await zip(
                zip(zip(
                    try iterateForecast(domain: domain, member: member, variable: "accum_conv_snow", run: run),
                    try iterateForecast(domain: domain, member: member, variable: "accum_ls_snow", run: run)
                ), zip(
                    try iterateForecast(domain: domain, member: member, variable: "ttl_cld", run: run),
                    try iterateForecast(domain: domain, member: member, variable: "accum_prcp", run: run)
                )), zip(zip(
                    try iterateForecast(domain: domain, member: member, variable: "accum_conv_rain", run: run),
                    try iterateForecast(domain: domain, member: member, variable: "wndgust10m", run: run)
                ),
                    try iterateForecast(domain: domain, member: member, variable: "visibility", run: run)
                )
            ).mapConcurrent(nConcurrent: concurrent) { arg -> [GenericVariableHandle] in
                let (((conv_snow, ls_snow), (ttl_cld, precipitation)), ((conv_rain, wndgust10m), visibility)) = arg
                let timestamp = conv_snow.0
                let writer = OmFileSplitter.makeSpatialWriter(domain: domain, nMembers: domain.ensembleMembers)
                let snow = zip(conv_snow.1, ls_snow.1).map(+)
                let weather_code = WeatherCode.calculate(cloudcover: ttl_cld.1.map { $0 * 100 }, precipitation: precipitation.1, convectivePrecipitation: conv_rain.1, snowfallCentimeters: snow.map { $0 * 0.7 }, gusts: wndgust10m.1, cape: nil, liftedIndex: nil, visibilityMeters: visibility.1, categoricalFreezingRain: nil, modelDtSeconds: domain.dtSeconds)
                let fnSnow = try writer.write(domain: domain, variable: .snowfall_water_equivalent, data: snow)
                let fnWeatherCode = try writer.write(domain: domain, variable: .weather_code, data: weather_code)
                return [
                    GenericVariableHandle(variable: BomVariable.snowfall_water_equivalent, time: timestamp, member: member, fn: fnSnow),
                    GenericVariableHandle(variable: BomVariable.weather_code, time: timestamp, member: member, fn: fnWeatherCode)
                ]
            }.flatMap({ $0 })
        }

        let handlesRh = try await (0..<domain.ensembleMembers).asyncFlatMap { member -> [GenericVariableHandle] in
            logger.info("Calculate relative humidity member_\(member)")
            return try await zip(
                try iterateForecast(domain: domain, member: member, variable: "sfc_temp", run: run),
                try iterateForecast(domain: domain, member: member, variable: "dewpt_scrn", run: run)
            ).mapConcurrent(nConcurrent: concurrent) { arg -> GenericVariableHandle in
                let (sfc_temp, dewpt_scrn) = arg
                let timestamp = sfc_temp.0
                let writer = OmFileSplitter.makeSpatialWriter(domain: domain, nMembers: domain.ensembleMembers)
                let rh = zip(sfc_temp.1, dewpt_scrn.1).map({ Meteorology.relativeHumidity(temperature: $0.0 - 273.15, dewpoint: $0.1 - 273.15) })
                let fnRh = try writer.write(domain: domain, variable: .relative_humidity_2m, data: rh)
                return GenericVariableHandle(variable: BomVariable.relative_humidity_2m, time: timestamp, member: member, fn: fnRh)
            }
        }

        let handlesWind = try await (0..<domain.ensembleMembers).asyncFlatMap { member -> [GenericVariableHandle] in
            logger.info("Calculate wind member_\(member)")
            return try await zip(
                try iterateForecast(domain: domain, member: member, variable: "uwnd10m", run: run),
                try iterateForecast(domain: domain, member: member, variable: "vwnd10m", run: run)
            ).mapConcurrent(nConcurrent: concurrent) { u, v -> [GenericVariableHandle] in
                let timestamp = u.0
                let speed = zip(u.1, v.1).map(Meteorology.windspeed)
                let direction = Meteorology.windirectionFast(u: u.1, v: v.1)
                let writer = OmFileSplitter.makeSpatialWriter(domain: domain, nMembers: domain.ensembleMembers)
                let fnSpeed = try writer.write(domain: domain, variable: .wind_speed_10m, data: speed)
                let fnDirection = try writer.write(domain: domain, variable: .wind_direction_10m, data: direction)
                return [
                    GenericVariableHandle(variable: BomVariable.wind_speed_10m, time: timestamp, member: member, fn: fnSpeed),
                    GenericVariableHandle(variable: BomVariable.wind_direction_10m, time: timestamp, member: member, fn: fnDirection)
                ]
            }.flatMap({ $0 })
        }
        await curl.printStatistics()
        Process.alarm(seconds: 0)
        return handles + handlesSnow + handlesWind + handlesRh
    }

    /// Download variables, convert to temporary om files and return all handles
    func download(application: Application, domain: BomDomain, run: Timestamp, server: String, concurrent: Int, skipFilesIfExisting: Bool) async throws -> [GenericVariableHandle] {
        let logger = application.logger
        let deadLineHours: Double = 6
        let curl = Curl(logger: logger, client: application.dedicatedHttpClient, deadLineHours: deadLineHours, waitAfterLastModifiedBeforeDownload: TimeInterval(60 * 15))
        Process.alarm(seconds: Int(deadLineHours + 1) * 3600)

        // list of variables to download
        // http://www.bom.gov.au/nwp/doc/access/docs/ACCESS-G.all-flds.slv.surface.shtml
        let variables: [(name: String, om: BomVariable?)] = [
            ("temp_scrn", .temperature_2m),
            ("accum_conv_rain", .showers),
            ("accum_prcp", .precipitation),
            ("mslp", .pressure_msl),
            ("av_sfc_sw_dir", .direct_radiation),
            ("av_swsfcdown", .shortwave_radiation),
            ("rh_scrn", .relative_humidity_2m),
            ("ttl_cld", .cloud_cover),
            ("hi_cld", .cloud_cover_high),
            ("mid_cld", .cloud_cover_mid),
            ("low_cld", .cloud_cover_low),
            ("sfc_temp", .surface_temperature),
            ("snow_amt_lnd", .snow_depth),
            ("soil_temp", .soil_temperature_0_to_10cm),
            ("soil_temp2", .soil_temperature_10_to_35cm),
            ("soil_temp3", .soil_temperature_35_to_100cm),
            ("soil_temp4", .soil_temperature_100_to_300cm),
            ("soil_mois", .soil_moisture_0_to_10cm),
            ("soil_mois2", .soil_moisture_10_to_35cm),
            ("soil_mois3", .soil_moisture_35_to_100cm),
            ("soil_mois4", .soil_moisture_100_to_300cm),
            ("visibility", .visibility),
            ("wndgust10m", .wind_gusts_10m),
            ("uwnd10m", nil),
            ("vwnd10m", nil),
            ("accum_conv_snow", nil),
            ("accum_ls_snow", nil),
            ("cld_phys_thunder_p", nil)
        ]

        let handles = try await variables.mapConcurrent(nConcurrent: concurrent) { variable -> [GenericVariableHandle] in
            let base = "\(server)\(run.format_YYYYMMdd)/\(run.hh)00/"
            let analysisFile = "\(domain.downloadDirectory)\(variable.name)_an.nc"
            let forecastFile = "\(domain.downloadDirectory)\(variable.name)_fc.nc"
            if !skipFilesIfExisting || !FileManager.default.fileExists(atPath: analysisFile) {
                _ = try await curl.downloadNetCdf(
                    url: "\(base)an/sfc/\(variable.name).nc",
                    file: analysisFile,
                    ncVariable: variable.name,
                    bzip2Decode: false
                )
            }
            if !skipFilesIfExisting || !FileManager.default.fileExists(atPath: forecastFile) {
                _ = try await curl.downloadNetCdf(
                    url: "\(base)fc/sfc/\(variable.name).nc",
                    file: forecastFile,
                    ncVariable: variable.name,
                    bzip2Decode: false
                )
            }
            guard let omVariable = variable.om else {
                return []
            }
            let writer = OmFileSplitter.makeSpatialWriter(domain: domain, nMembers: domain.ensembleMembers)
            logger.info("Compressing and writing data to \(omVariable.omFileName.file).om")
            return try self.combineAnalysisForecast(domain: domain, variable: variable.name, run: run).map { timestamp, data in
                let fn = try writer.write(domain: domain, variable: omVariable, data: data)
                return GenericVariableHandle(variable: omVariable, time: timestamp, member: 0, fn: fn)
            }
        }

        logger.info("Calculate weather codes and snow sum")
        let handlesSnow = try await zip(
            zip(zip(
                try combineAnalysisForecast(domain: domain, variable: "accum_conv_snow", run: run),
                try combineAnalysisForecast(domain: domain, variable: "accum_ls_snow", run: run)
            ), zip(
                try combineAnalysisForecast(domain: domain, variable: "ttl_cld", run: run),
                try combineAnalysisForecast(domain: domain, variable: "accum_prcp", run: run)
            )), zip(zip(
                try combineAnalysisForecast(domain: domain, variable: "accum_conv_rain", run: run),
                try combineAnalysisForecast(domain: domain, variable: "wndgust10m", run: run)
            ), zip(
                try combineAnalysisForecast(domain: domain, variable: "cld_phys_thunder_p", run: run),
                try combineAnalysisForecast(domain: domain, variable: "visibility", run: run)
            ))
        ).mapConcurrent(nConcurrent: concurrent) { arg -> [GenericVariableHandle] in
            let (((conv_snow, ls_snow), (ttl_cld, precipitation)), ((conv_rain, wndgust10m), (cld_phys_thunder_p, visibility))) = arg
            let timestamp = conv_snow.0
            let writer = OmFileSplitter.makeSpatialWriter(domain: domain, nMembers: domain.ensembleMembers)
            let snow = zip(conv_snow.1, ls_snow.1).map(+)
            let weather_code = WeatherCode.calculate(cloudcover: ttl_cld.1.map { $0 * 100 }, precipitation: precipitation.1, convectivePrecipitation: conv_rain.1, snowfallCentimeters: snow.map { $0 * 0.7 }, gusts: wndgust10m.1, cape: cld_phys_thunder_p.1.map({ $0 * 3 }), liftedIndex: nil, visibilityMeters: visibility.1, categoricalFreezingRain: nil, modelDtSeconds: domain.dtSeconds)
            let fnSnow = try writer.write(domain: domain, variable: .snowfall_water_equivalent, data: snow)
            let fnWeatherCode = try writer.write(domain: domain, variable: .weather_code, data: weather_code)
            return [
                GenericVariableHandle(variable: BomVariable.snowfall_water_equivalent, time: timestamp, member: 0, fn: fnSnow),
                GenericVariableHandle(variable: BomVariable.weather_code, time: timestamp, member: 0, fn: fnWeatherCode)
            ]
        }

        logger.info("Calculate wind")
        let handlesWind = try await zip(
            try combineAnalysisForecast(domain: domain, variable: "uwnd10m", run: run),
            try combineAnalysisForecast(domain: domain, variable: "vwnd10m", run: run)
        ).mapConcurrent(nConcurrent: concurrent) { u, v -> [GenericVariableHandle] in
            let timestamp = u.0
            let speed = zip(u.1, v.1).map(Meteorology.windspeed)
            let direction = Meteorology.windirectionFast(u: u.1, v: v.1)
            let writer = OmFileSplitter.makeSpatialWriter(domain: domain, nMembers: domain.ensembleMembers)
            let fnSpeed = try writer.write(domain: domain, variable: .wind_speed_10m, data: speed)
            let fnDirection = try writer.write(domain: domain, variable: .wind_direction_10m, data: direction)
            return [
                GenericVariableHandle(variable: BomVariable.wind_speed_10m, time: timestamp, member: 0, fn: fnSpeed),
                GenericVariableHandle(variable: BomVariable.wind_direction_10m, time: timestamp, member: 0, fn: fnDirection)
                ]
        }
        await curl.printStatistics()
        Process.alarm(seconds: 0)
        return handles.flatMap({ $0 }) + handlesSnow.flatMap({ $0 }) + handlesWind.flatMap({ $0 })
    }

    /// Process timsteps only on forecast
    /// Performs deaccumulation if required
    func iterateForecast(domain: BomDomain, member: Int, variable: String, run: Timestamp, level: Float? = nil) throws -> AnySequence<(Timestamp, [Float])> {
        let forecastFile = "\(domain.downloadDirectory)\(variable)_fc_\(member).nc"

        guard let ncForecast = try NetCDF.open(path: forecastFile, allowUpdate: false) else {
            fatalError("Could not open \(forecastFile)")
        }
        guard let timeForecast = try ncForecast.getVariable(name: "time")?.asType(Int32.self)?.read() else {
            fatalError("Could not read time")
        }
        guard let varForecast = ncForecast.getVariable(name: variable) else {
            fatalError("Could not open nc variable \(variable)")
        }
        let nDims = varForecast.dimensionsFlat.count
        let dimensions = ncForecast.getDimensions()
        guard let nx = dimensions.first(where: { $0.name == "lon" })?.length else {
            fatalError("Could not get nx")
        }
        guard let ny = dimensions.first(where: { $0.name == "lat" })?.length else {
            fatalError("Could not get ny")
        }
        let isAccumulated = variable.starts(with: "accum_")
        // process indiviual timesteps
        return AnySequence<(Timestamp, [Float])> { () -> AnyIterator<(Timestamp, [Float])> in
            var pos = 0
            var previousStepData: [Float]?
            return AnyIterator<(Timestamp, [Float])> { () -> (Timestamp, [Float])? in
                if pos >= timeForecast.count {
                    return nil
                }
                defer {
                    pos += 1
                    /// Precipitation in ensemble is 1-hourly, but the rest is 3-hourly. Skip 1-hourly data and only use 3-hourly
                    if domain.dtHours == 3 {
                        while pos < timeForecast.count && timeForecast[pos] % (3 * 3600) != 0 {
                            pos += 1
                        }
                    }
                }
                // search level if requried
                let levelIndex = level.map { level in
                    guard let index = try? ncForecast
                        .getVariable(name: "rho_lvl")?
                        .asType(Float.self)?
                        .read()
                        .firstIndex(where: { abs($0 - level) < 0.1 }) else {
                        fatalError("Could not get level index")
                    }
                    return index
                } ?? 0
                guard var data = try? varForecast.asType(Float.self)?.read(
                    offset: nDims == 3 ? [pos, 0, 0] : [pos, levelIndex, 0, 0],
                    count: nDims == 3 ? [1, ny, nx] : [1, 1, ny, nx]
                ) else {
                    fatalError("Could not read timestep")
                }
                if isAccumulated {
                    if let previous = previousStepData {
                        previousStepData = data
                        for i in data.indices {
                            data[i] -= previous[i]
                        }
                    } else {
                        previousStepData = data
                    }
                }
                return (run.add(Int(timeForecast[pos])), data)
            }
        }
    }

    /// Process timsteps from 2 netcdf files: analysis and forecast
    /// Performs deaccumulation if required
    func combineAnalysisForecast(domain: BomDomain, variable: String, run: Timestamp, level: Float? = nil) throws -> AnySequence<(Timestamp, [Float])> {
        let analysisFile = "\(domain.downloadDirectory)\(variable)_an.nc"
        let forecastFile = "\(domain.downloadDirectory)\(variable)_fc.nc"

        guard let ncForecast = try NetCDF.open(path: forecastFile, allowUpdate: false) else {
            fatalError("Could not open \(forecastFile)")
        }
        guard let timeForecast = try ncForecast.getVariable(name: "time")?.asType(Int32.self)?.read() else {
            fatalError("Could not read time")
        }
        guard let ncAnalysis = try NetCDF.open(path: analysisFile, allowUpdate: false) else {
            fatalError("Could not open \(forecastFile)")
        }
        guard let varForecast = ncForecast.getVariable(name: variable) else {
            fatalError("Could not open nc variable \(variable)")
        }
        guard let varAnalysis = ncAnalysis.getVariable(name: variable) else {
            fatalError("Could not open nc variable \(variable)")
        }
        let nDims = varAnalysis.dimensionsFlat.count
        /*let dimensions = ncForecast.getDimensions()
        guard let nx = dimensions.first(where: {$0.name == "lon"})?.length else {
            fatalError("Could not get nx")
        }
        guard let ny = dimensions.first(where: {$0.name == "lat"})?.length else {
            fatalError("Could not get ny")
        }*/
        let nx = 2048
        // somehow vwind on model level has 1537 elements
        let ny = 1536

        let isAccumulated = variable.starts(with: "accum_")
        // process indiviual timesteps
        return AnySequence<(Timestamp, [Float])> { () -> AnyIterator<(Timestamp, [Float])> in
            var pos = 0
            var previousStepData: [Float]?
            return AnyIterator<(Timestamp, [Float])> { () -> (Timestamp, [Float])? in
                if pos > timeForecast.count {
                    return nil
                }
                defer {pos += 1}
                if pos == 0 {
                    // search level if requried
                    let levelIndex = level.map { level in
                        do {
                            guard let index = try ncAnalysis
                                .getVariable(name: "rho_lvl")?
                                .asType(Float.self)?
                                .read()
                                .firstIndex(where: { abs($0 - level) < 0.1 }) else {
                                fatalError("Could not get level index for \(variable) dimensions=\(varAnalysis.dimensionsFlat)")
                            }
                            return index
                        } catch {
                            fatalError("Error during get level index \(error)")
                        }
                    } ?? 0
                    do {
                        guard let data = try varAnalysis.asType(Float.self)?.read(
                            offset: nDims == 3 ? [0, 0, 0] : [0, levelIndex, 0, 0],
                            count: nDims == 3 ? [1, ny, nx] : [1, 1, ny, nx]
                        ) else {
                            fatalError("Could not read analysis timestep for \(variable) levelIndex=\(levelIndex) dimensions=\(varAnalysis.dimensionsFlat)")
                        }
                        return (run, data)
                    } catch {
                        fatalError("Error during read analysis for \(variable) levelIndex=\(levelIndex) dimensions=\(varAnalysis.dimensionsFlat) error=\(error)")
                    }
                } else {
                    // search level if requried
                    let levelIndex = level.map { level in
                        do {
                            guard let index = try ncForecast
                                .getVariable(name: "rho_lvl")?
                                .asType(Float.self)?
                                .read()
                                .firstIndex(where: { abs($0 - level) < 0.1 }) else {
                                fatalError("Could not get level index")
                            }
                            return index
                        } catch {
                            fatalError("Could not read data timestep for \(variable) dimensions=\(varForecast.dimensionsFlat) error=\(error)")
                        }
                    } ?? 0
                    do {
                        guard var data = try varForecast.asType(Float.self)?.read(
                            offset: nDims == 3 ? [pos - 1, 0, 0] : [pos - 1, levelIndex, 0, 0],
                            count: nDims == 3 ? [1, ny, nx] : [1, 1, ny, nx]
                        ) else {
                            fatalError("Could not read timestep")
                        }
                        if isAccumulated {
                            if let previous = previousStepData {
                                previousStepData = data
                                for i in data.indices {
                                    data[i] -= previous[i]
                                }
                            } else {
                                previousStepData = data
                            }
                        }
                        return (run.add(Int(timeForecast[pos - 1])), data)
                    } catch {
                        fatalError("Error during read data for \(variable) levelIndex=\(levelIndex) dimensions=\(varForecast.dimensionsFlat) error=\(error)")
                    }
                }
            }
        }
    }
}

extension OmFileWriterHelper {
    fileprivate func write(domain: BomDomain, variable: BomVariable, data: [Float]) throws -> FileHandle {
        guard data.count == domain.grid.count else {
            fatalError("invalid data array size")
        }
        var data = data
        data.shift180LongitudeAndFlipLatitude(nt: 1, ny: domain.grid.ny, nx: domain.grid.nx)
        if let fma = variable.multiplyAdd {
            data.multiplyAdd(multiply: fma.multiply, add: fma.add)
        }
        let fn = try writeTemporary(compressionType: .pfor_delta2d_int16, scalefactor: variable.scalefactor, all: data)
        return fn
    }
}
