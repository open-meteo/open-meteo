import Foundation
import Vapor
import OmFileFormat
import Dispatch

/**
 TODO:
 - Elevation files should not mask out sea level locations -> this breaks surface pressure correction as a lake can be above sea level
 */
struct DownloadIconCommand: AsyncCommand {
    enum VariableGroup: String, RawRepresentable, CaseIterable {
        case all
        case surface
        case modelLevel
        case pressureLevel
        case pressureLevelGt500
        case pressureLevelLtE500
    }

    struct Signature: CommandSignature {
        @Argument(name: "domain")
        var domain: String

        @Option(name: "run")
        var run: String?

        @Option(name: "concurrent", short: "c", help: "Number of concurrent download/conversion jobs")
        var concurrent: Int?

        @Flag(name: "create-netcdf")
        var createNetcdf: Bool

        @Option(name: "group")
        var group: String?

        @Option(name: "only-variables")
        var onlyVariables: String?

        @Option(name: "upload-s3-bucket", help: "Upload open-meteo database to an S3 bucket after processing")
        var uploadS3Bucket: String?

        @Flag(name: "upload-s3-only-probabilities", help: "Only upload probabilities files to S3")
        var uploadS3OnlyProbabilities: Bool
    }

    var help: String {
        "Download a specified icon model run"
    }

    /**
     Convert surface elevation. Out of grid positions are NaN. Sea grid points are -999.
     */
    func convertSurfaceElevation(application: Application, domain: IconDomains, run: Timestamp) async throws {
        let logger = application.logger
        let surfaceElevationFileOm = domain.surfaceElevationFileOm.getFilePath()
        if FileManager.default.fileExists(atPath: surfaceElevationFileOm) {
            return
        }
        try domain.surfaceElevationFileOm.createDirectory()

        let downloadDirectory = domain.downloadDirectory
        try FileManager.default.createDirectory(atPath: downloadDirectory, withIntermediateDirectories: true)

        let deadLineHours: Double = (domain == .iconD2 || domain == .iconD2Eps) ? 2 : 5
        let curl = Curl(logger: logger, client: application.dedicatedHttpClient, deadLineHours: deadLineHours)
        let domainPrefix = "\(domain.rawValue)_\(domain.region)"
        let cdo = try await CdoHelper(domain: domain, logger: logger, curl: curl)
        let gridType = cdo.needsRemapping ? "icosahedral" : "regular-lat-lon"

        // https://opendata.dwd.de/weather/nwp/icon/grib/00/t_2m/icon_global_icosahedral_single-level_2022070800_000_T_2M.grib2.bz2
        // https://opendata.dwd.de/weather/nwp/icon-eu/grib/00/t_2m/icon-eu_europe_regular-lat-lon_single-level_2022072000_000_T_2M.grib2.bz2
        let serverPrefix = "http://opendata.dwd.de/weather/nwp/\(domain.rawValue)/grib/\(run.hour.zeroPadded(len: 2))/"
        let dateStr = run.format_YYYYMMddHH

        // surface elevation
        // https://opendata.dwd.de/weather/nwp/icon/grib/00/hsurf/icon_global_icosahedral_time-invariant_2022072400_HSURF.grib2.bz2

        let additionalTimeString = (domain == .iconD2 || domain == .iconD2Eps) ? "_000_0" : ""
        let variableName = (domain == .iconD2 || domain == .iconD2Eps || domain == .iconEuEps || domain == .iconEps) ? "hsurf" : "HSURF"
        let file = "\(serverPrefix)hsurf/\(domainPrefix)_\(gridType)_time-invariant_\(dateStr)\(additionalTimeString)_\(variableName).grib2.bz2"
        var hsurf = try await cdo.downloadAndRemap(file)[0].data.data

        let variableName2 = (domain == .iconD2 || domain == .iconD2Eps || domain == .iconEuEps || domain == .iconEps) ? "fr_land" : "FR_LAND"
        let file2 = "\(serverPrefix)fr_land/\(domainPrefix)_\(gridType)_time-invariant_\(dateStr)\(additionalTimeString)_\(variableName2).grib2.bz2"
        let landFraction = try await cdo.downloadAndRemap(file2)[0].data.data

        // try Array2D(data: hsurf, nx: domain.grid.nx, ny: domain.grid.ny).writeNetcdf(filename: "\(downloadDirectory)hsurf.nc")
        // try Array2D(data: landFraction, nx: domain.grid.nx, ny: domain.grid.ny).writeNetcdf(filename: "\(downloadDirectory)fr_land.nc")

        // Set all sea grid points to -999
        precondition(hsurf.count == landFraction.count)
        for i in hsurf.indices {
            if landFraction[i] < 0.5 {
                hsurf[i] = -999
            }
        }

        try hsurf.writeOmFile2D(file: surfaceElevationFileOm, grid: domain.grid, createNetCdf: false)
    }

    /// Download ICON global, eu and d2 *.grid2.bz2 files
    func downloadIcon(application: Application, domain: IconDomains, run: Timestamp, variables: [any IconVariableDownloadable], concurrent: Int, uploadS3Bucket: String?) async throws -> (handles: [GenericVariableHandle], handles15minIconD2: [GenericVariableHandle]) {
        let logger = application.logger
        let downloadDirectory = domain.downloadDirectory
        try FileManager.default.createDirectory(atPath: downloadDirectory, withIntermediateDirectories: true)

        let deadLineHours: Double = (domain == .iconD2 || domain == .iconD2Eps) ? 2 : 5
        let curl = Curl(logger: logger, client: application.dedicatedHttpClient, deadLineHours: deadLineHours, waitAfterLastModified: 120)
        Process.alarm(seconds: Int(deadLineHours + 1) * 3600)
        defer { Process.alarm(seconds: 0) }

        let domainPrefix = "\(domain.rawValue)_\(domain.region)"
        let cdo = try await CdoHelper(domain: domain, logger: logger, curl: curl)
        let gridType = cdo.needsRemapping ? "icosahedral" : "regular-lat-lon"
        let storeOnDisk = domain == .icon || domain == .iconD2 || domain == .iconEu
        let writer = OmRunSpatialWriter(domain: domain, run: run, storeOnDisk: storeOnDisk)

        // https://opendata.dwd.de/weather/nwp/icon/grib/00/t_2m/icon_global_icosahedral_single-level_2022070800_000_T_2M.grib2.bz2
        // https://opendata.dwd.de/weather/nwp/icon-eu/grib/00/t_2m/icon-eu_europe_regular-lat-lon_single-level_2022072000_000_T_2M.grib2.bz2
        let serverPrefix = "http://opendata.dwd.de/weather/nwp/\(domain.rawValue)/grib/\(run.hour.zeroPadded(len: 2))/"
        let dateStr = run.format_YYYYMMddHH

        // let nMembers = domain.ensembleMembers

        let handles = GenericVariableHandleStorage()
        let handles15minIconD2 = GenericVariableHandleStorage()

        let deaverager = GribDeaverager()
        let deaverager15min = GribDeaverager()

        /// Domain elevation field. Used to calculate sea level pressure from surface level pressure in ICON EPS and ICON EU EPS
        let domainElevation = {
            guard let elevation = try? domain.getStaticFile(type: .elevation)?.read() else {
                fatalError("cannot read elevation for domain \(domain)")
            }
            return elevation
        }()

        let forecastSteps = domain.getDownloadForecastSteps(run: run.hour)
        var previousHour = 0
        for hour in forecastSteps {
            logger.info("Downloading hour \(hour)")
            let timestamp = run.add(hours: hour)
            let h3 = hour.zeroPadded(len: 3)

            let storage = VariablePerMemberStorage<IconSurfaceVariable>()
            let storage15min = VariablePerMemberStorage<IconSurfaceVariable>()

            try await variables.foreachConcurrent(nConcurrent: concurrent) { variable in
                //var grib2d = GribArray2D(nx: domain.grid.nx, ny: domain.grid.ny)

                if variable.skipHour(hour: hour, domain: domain, forDownload: true, run: run) {
                    return
                }
                guard let v = variable.getVarAndLevel(domain: domain) else {
                    return
                }
                let level = v.level.map({ "_\($0)" }) ?? (domain == .iconD2 || domain == .iconD2Eps ? "_2d" : "")
                let variableName = (domain == .iconD2 || domain == .iconD2Eps || domain == .iconEuEps || domain == .iconEps) ? v.variable : v.variable.uppercased()
                let filenameFrom = "\(domainPrefix)_\(gridType)_\(v.cat)_\(dateStr)_\(h3)\(level)_\(variableName).grib2.bz2"

                let url = "\(serverPrefix)\(v.variable)/\(filenameFrom)"

                var messages = try await cdo.downloadAndRemap(url)
                if domain == .iconD2 && messages.count > 1 {
                    // Write 15min D2 icon data
                    let downloadDirectory = IconDomains.iconD2_15min.downloadDirectory
                    try FileManager.default.createDirectory(atPath: downloadDirectory, withIntermediateDirectories: true)
                    let writer = OmRunSpatialWriter(domain: IconDomains.iconD2_15min, run: run, storeOnDisk: false)
                    for (i, (message, array2d)) in messages.enumerated() {
                        var array2d = array2d
                        guard let stepRange = message.get(attribute: "stepRange"),
                              let stepType = message.get(attribute: "stepType") else {
                            fatalError("could not get step range or type")
                        }
                        let timestamp = run.add(hour * 3600 + i * 900)
                        if let fma = variable.multiplyAdd {
                            array2d.data.multiplyAdd(multiply: fma.multiply, add: fma.add)
                        }
                        // Deaccumulate precipitation
                        guard await deaverager15min.deaccumulateIfRequired(variable: variable, member: 0, stepType: stepType, stepRange: stepRange, array2d: &array2d) else {
                            continue
                        }
                        if let variable = variable as? IconSurfaceVariable {
                            if [IconSurfaceVariable.precipitation, .snowfall_height, .rain, .snowfall_water_equivalent, .snowfall_convective_water_equivalent].contains(variable) {
                                await storage15min.set(variable: variable, timestamp: timestamp, member: 0, data: array2d)
                                continue
                            }
                        }
                        await handles15minIconD2.append(try writer.write(time: timestamp, member: 0, variable: variable, data: array2d.data))
                    }
                    messages = [messages[0]]
                }

                // Make sure to skip wind gusts hour0 which only contains `0` values
                if variable.skipHour(hour: hour, domain: domain, forDownload: false, run: run) {
                    return
                }

                // Contains more than 1 message for ensemble models
                for (member, (message, array2d)) in messages.enumerated() {
                    var array2d = array2d

                    // Scaling before compression with scalefactor
                    if let fma = variable.multiplyAdd {
                        array2d.data.multiplyAdd(multiply: fma.multiply, add: fma.add)
                    }

                    guard let stepRange = message.get(attribute: "stepRange"),
                          let stepType = message.get(attribute: "stepType") else {
                        fatalError("could not get step range or type")
                    }

                    // Deaccumulate precipitation
                    guard await deaverager.deaccumulateIfRequired(variable: variable, member: member, stepType: stepType, stepRange: stepRange, array2d: &array2d) else {
                        continue
                    }

                    if let variable = variable as? IconSurfaceVariable {
                        if [IconSurfaceVariable.precipitation, .temperature_2m, .snowfall_height, .rain, .snowfall_water_equivalent, .snowfall_convective_water_equivalent, .weather_code, .freezing_level_height, .pressure_msl, .relative_humidity_2m].contains(variable) {
                            await storage.set(variable: variable, timestamp: timestamp, member: member, data: array2d)
                            continue
                        }
                    }
                    // logger.info("Compressing and writing data to \(filenameDest)")
                    await handles.append(try writer.write(time: timestamp, member: member, variable: variable, data: array2d.data))
                }
            }

            /// Calculate precipitation >0.1mm/h probability
            if domain.ensembleMembers > 1 {
                try await handles.append(storage.calculatePrecipitationProbability(
                    precipitationVariable: .precipitation,
                    domain: domain,
                    timestamp: timestamp,
                    run: run,
                    dtHoursOfCurrentStep: hour - previousHour
                ))
            }

            /// All variables for this timestep have been downloaded. Selected variables are kept in memory.
            /// Do some post processing
            /// Note: Sometimes some members for temperature are missing for a single timestep!
            try await storage.data.foreachConcurrent(nConcurrent: concurrent) { v, data in
                var data = data
                if [.iconEps, .iconEuEps].contains(domain) && v.variable == .pressure_msl,
                    let t2m = await storage.get(v.with(variable: .temperature_2m)) {
                    // ICON EPC is actually downloading surface level pressure
                    // calculate sea level pressure using temperature and elevation
                    data.data = Meteorology.sealevelPressureSpatial(temperature: t2m.data, pressure: data.data, elevation: domainElevation)
                }
                if domain == .iconEps && v.variable == .relative_humidity_2m,
                   let t2m = await storage.get(v.with(variable: .temperature_2m)) {
                    // ICON EPS is using dewpoint, convert to relative humidity
                    data.data.multiplyAdd(multiply: 1, add: -273.15)
                    data.data = zip(t2m.data, data.data).map(Meteorology.relativeHumidity)
                }

                // DWD ICON weather codes show rain although precipitation is 0
                // Similar for snow at +2°C or more
                if v.variable == .weather_code,
                    let t2m = await storage.get(v.with(variable: .temperature_2m)),
                    let precip = await storage.get(v.with(variable: .precipitation)) {
                    let snowfallHeight = await storage.get(v.with(variable: .snowfall_height))
                    for i in data.data.indices {
                        guard data.data[i].isFinite, let weathercode = WeatherCode(rawValue: Int(data.data[i])) else {
                            continue
                        }
                        data.data[i] = Float(weathercode.correctDwdIconWeatherCode(
                            temperature_2m: t2m.data[i],
                            precipitation: precip.data[i],
                            snowfallHeightAboveGrid: t2m.data[i] > 0 && snowfallHeight?.data[i] ?? .nan > max(0, domainElevation[i]) + 50
                        ).rawValue)
                    }
                }

                /// Lower freezing level height below grid-cell elevation to adjust data to mixed terrain
                /// Use temperature to estimate freezing level height below ground. This is consistent with GFS
                /// https://github.com/open-meteo/open-meteo/issues/518#issuecomment-1827381843
                /// Note: snowfall height is NaN if snowfall height is at ground level
                if v.variable == .freezing_level_height || v.variable == .snowfall_height,
                   let t2m = await storage.get(v.with(variable: .temperature_2m)) {
                    for i in data.data.indices {
                        let freezingLevelHeight = data.data[i].isNaN ? max(0, domainElevation[i]) : data.data[i]
                        let temperature_2m = t2m.data[i]
                        let newHeight = freezingLevelHeight - abs(-1 * temperature_2m) * 0.7 * 100
                        if newHeight <= domainElevation[i] {
                            data.data[i] = newHeight
                        }
                    }
                }

                /// Add snow to liquid rain if temperature is > 1.5°C or snowfall height is higher than 50 metre above groud
                if v.variable == .rain,
                    let snowfallWaterEquivalent = await storage.get(v.with(variable: .snowfall_water_equivalent)),
                    let t2m = await storage.get(v.with(variable: .temperature_2m)) {
                    let snowfallHeight = await storage.get(v.with(variable: .snowfall_height))
                    let snowfallConvectiveWaterEquivalent = await storage.get(v.with(variable: .snowfall_convective_water_equivalent))
                    for i in data.data.indices {
                        if t2m.data[i] > IconDomains.tMelt || (t2m.data[i] > 0 && snowfallHeight?.data[i] ?? .nan > max(0, domainElevation[i]) + 50) {
                            let snowWater = snowfallWaterEquivalent.data[i].isNaN ? 0 : snowfallWaterEquivalent.data[i]
                            let snowConvWater = snowfallConvectiveWaterEquivalent?.data[0].isNaN == true ? 0 : snowfallConvectiveWaterEquivalent?.data[0] ?? 0
                            data.data[i] += snowWater + snowConvWater
                        }
                    }
                }

                /// Set snow to 0 if temperature is > 1.5°C or snowfall height is higher than 50 metre above groud
                if v.variable == .snowfall_water_equivalent,
                    let t2m = await storage.get(v.with(variable: .temperature_2m)) {
                    let snowfallHeight = await storage.get(v.with(variable: .snowfall_height))
                    let snowfallConvectiveWaterEquivalent = await storage.get(v.with(variable: .snowfall_convective_water_equivalent))
                    for i in data.data.indices {
                        // Add convective snow, to regular snow
                        data.data[i] += snowfallConvectiveWaterEquivalent?.data[0].isNaN == true ? 0 : snowfallConvectiveWaterEquivalent?.data[0] ?? 0
                        if t2m.data[i] > IconDomains.tMelt || (t2m.data[i] > 0 && snowfallHeight?.data[i] ?? .nan > max(0, domainElevation[i]) + 50) {
                            /*if (data.data[i] > 0.1 && domainElevation[i] > -100) {
                                print("corrected case value=\(data.data[i]) t=\(t2m.data[i]) sh=\(snowfallHeight?.data[i] ?? .nan) ele=\(domainElevation[i])")
                            }*/
                            data.data[i] = 0
                        }
                    }
                }

                if v.variable == .snowfall_convective_water_equivalent {
                    // Do not write snowfall_convective_water_equivalent to disk anymore
                    return
                }

                if v.variable == .convective_cloud_top || v.variable == .convective_cloud_base {
                    // Icon sets points where no convective clouds are present to -500
                    // We set them to 0 to be consistent with cloud_top and cloud_base in DMI Harmonie model
                    data.data = data.data.map { $0 < -499 ? 0 : $0 }
                }
                await handles.append(try writer.write(time: v.timestamp, member: v.member, variable: v.variable, data: data.data))
            }

            /// Post process 15 minutes data. Note: There is no temperature in 15min data
            try await storage15min.data.foreachConcurrent(nConcurrent: concurrent) { v, data in
                var data = data
                let writer = OmRunSpatialWriter(domain: IconDomains.iconD2_15min, run: run, storeOnDisk: false)
                /// Add snow to liquid rain if temperature is > 1.5°C or snowfall height is higher than 50 metre above groud
                if v.variable == .rain, let snowfallWaterEquivalent = await storage15min.get(v.with(variable: .snowfall_water_equivalent)) {
                    /// Take temperature from 1-hourly data
                    guard let t2m = await storage.get(v.with(variable: .temperature_2m, timestamp: v.timestamp.floor(toNearest: 3600))) else {
                        fatalError("Rain correction requires temperature 2m")
                    }
                    let snowfallHeight = await storage15min.get(v.with(variable: .snowfall_height))
                    let snowfallConvectiveWaterEquivalent = await storage15min.get(v.with(variable: .snowfall_convective_water_equivalent))
                    for i in data.data.indices {
                        if t2m.data[i] > IconDomains.tMelt || (t2m.data[i] > 0 && snowfallHeight?.data[i] ?? .nan > max(0, domainElevation[i]) + 50) {
                            let snowWater = snowfallWaterEquivalent.data[i].isNaN ? 0 : snowfallWaterEquivalent.data[i]
                            let snowConvWater = snowfallConvectiveWaterEquivalent?.data[0].isNaN == true ? 0 : snowfallConvectiveWaterEquivalent?.data[0] ?? 0
                            data.data[i] += snowWater + snowConvWater
                        }
                    }
                }

                /// Set snow to 0 if temperature is > 1.5°C or snowfall height is higher than 50 metre above groud
                if v.variable == .snowfall_water_equivalent {
                    /// Take temperature from 1-hourly data
                    guard let t2m = await storage.get(v.with(variable: .temperature_2m, timestamp: v.timestamp.floor(toNearest: 3600))) else {
                        fatalError("Snow correction requires temperature 2m")
                    }
                    let snowfallHeight = await storage15min.get(v.with(variable: .snowfall_height))
                    let snowfallConvectiveWaterEquivalent = await storage15min.get(v.with(variable: .snowfall_convective_water_equivalent))
                    for i in data.data.indices {
                        // Add convective snow, to regular snow
                        data.data[i] += snowfallConvectiveWaterEquivalent?.data[0].isNaN == true ? 0 : snowfallConvectiveWaterEquivalent?.data[0] ?? 0
                        if t2m.data[i] > IconDomains.tMelt || (t2m.data[i] > 0 && snowfallHeight?.data[i] ?? .nan > max(0, domainElevation[i]) + 50) {
                            /*if (data.data[i] > 0.1 && domainElevation[i] > -100) {
                                print("corrected case value=\(data.data[i]) t=\(t2m?.data[i] ?? .nan) sh=\(snowfallHeight?.data[i] ?? .nan) ele=\(domainElevation[i])")
                            }*/
                            data.data[i] = 0
                        }
                    }
                }

                /// Lower freezing level height below grid-cell elevation to adjust data to mixed terrain
                /// Use temperature to estimate freezing level height below ground. This is consistent with GFS
                /// https://github.com/open-meteo/open-meteo/issues/518#issuecomment-1827381843
                if v.variable == .freezing_level_height || v.variable == .snowfall_height {
                    /// Take temperature from 1-hourly data
                    guard let t2m = await storage.get(v.with(variable: .temperature_2m, timestamp: v.timestamp.floor(toNearest: 3600))) else {
                        fatalError("Freezing level height and snowfall height correction requires temperature_2m")
                    }
                    for i in data.data.indices {
                        let freezingLevelHeight = data.data[i].isNaN ? max(0, domainElevation[i]) : data.data[i]
                        let temperature_2m = t2m.data[i]
                        let newHeight = freezingLevelHeight - abs(-1 * temperature_2m) * 0.7 * 100
                        if newHeight <= domainElevation[i] {
                            data.data[i] = newHeight
                        }
                    }
                }

                if v.variable == .snowfall_convective_water_equivalent {
                    // Do not write snowfall_convective_water_equivalent to disk anymore
                    return
                }
                await handles15minIconD2.append(try writer.write(time: v.timestamp, member: v.member, variable: v.variable, data: data.data))
            }
            if let uploadS3Bucket {
                try domain.domainRegistry.syncToS3Spatial(bucket: uploadS3Bucket, timesteps: [timestamp])
            }
            previousHour = hour
        }
        await curl.printStatistics()
        return await (handles.handles, handles15minIconD2.handles)
    }

    func run(using context: CommandContext, signature: Signature) async throws {
        let start = DispatchTime.now()
        let domain = try IconDomains.load(rawValue: signature.domain)
        let nConcurrent = signature.concurrent ?? 1
        let run = try signature.run.flatMap(Timestamp.fromRunHourOrYYYYMMDD) ?? domain.lastRun

        if signature.onlyVariables != nil && signature.group != nil {
            fatalError("Parameter 'onlyVariables' and 'groups' must not be used simultaneously")
        }

        let group = try VariableGroup.load(rawValueOptional: signature.group) ?? .all

        let onlyVariables: [any IconVariableDownloadable]? = try signature.onlyVariables.map {
            try $0.split(separator: ",").map {
                if let variable = IconPressureVariable(rawValue: String($0)) {
                    return variable
                }
                return try IconSurfaceVariable.load(rawValue: String($0))
            }
        }

        /// 3 different variables sets to optimise download time:
        /// - surface variables with soil
        /// - model-level e.g. for 180m wind, they have a much larger dalay and sometimes are aborted
        /// - pressure level which take forever to download because it is too much data
        var groupVariables: [any IconVariableDownloadable]
        switch group {
        case .all:
            groupVariables = IconSurfaceVariable.allCases + domain.levels.reversed().flatMap { level in
                IconPressureVariableType.allCases.map { variable in
                    IconPressureVariable(variable: variable, level: level)
                }
            }
        case .surface:
            groupVariables = IconSurfaceVariable.allCases.filter {
                !($0.getVarAndLevel(domain: domain)?.cat == "model-level")
            }
        case .modelLevel:
            groupVariables = IconSurfaceVariable.allCases.filter {
                $0.getVarAndLevel(domain: domain)?.cat == "model-level"
            }
        case .pressureLevel:
            groupVariables = domain.levels.reversed().flatMap { level in
                IconPressureVariableType.allCases.map { variable in
                    IconPressureVariable(variable: variable, level: level)
                }
            }
        case .pressureLevelGt500:
            groupVariables = domain.levels.reversed().flatMap { level in
                return level > 500 ? IconPressureVariableType.allCases.map { variable in
                    IconPressureVariable(variable: variable, level: level)
                } : []
            }
        case .pressureLevelLtE500:
            groupVariables = domain.levels.reversed().flatMap { level in
                return level <= 500 ? IconPressureVariableType.allCases.map { variable in
                    IconPressureVariable(variable: variable, level: level)
                } : []
            }
        }

        let variables = onlyVariables ?? groupVariables

        let logger = context.application.logger
        logger.info("Downloading domain '\(domain.rawValue)' run '\(run.iso8601_YYYY_MM_dd_HH_mm)'")
        try await convertSurfaceElevation(application: context.application, domain: domain, run: run)

        let (handles, handles15minIconD2) = try await downloadIcon(application: context.application, domain: domain, run: run, variables: variables, concurrent: nConcurrent, uploadS3Bucket: signature.uploadS3Bucket)

        if domain == .iconD2 {
            // ICON-D2 downloads 15min data as well
            try await GenericVariableHandle.convert(logger: logger, domain: IconDomains.iconD2_15min, createNetcdf: signature.createNetcdf, run: run, handles: handles15minIconD2, concurrent: nConcurrent, writeUpdateJson: true, uploadS3Bucket: signature.uploadS3Bucket, uploadS3OnlyProbabilities: signature.uploadS3OnlyProbabilities)
        }
        try await GenericVariableHandle.convert(logger: logger, domain: domain, createNetcdf: signature.createNetcdf, run: run, handles: handles, concurrent: nConcurrent, writeUpdateJson: true, uploadS3Bucket: signature.uploadS3Bucket, uploadS3OnlyProbabilities: signature.uploadS3OnlyProbabilities)

        logger.info("Finished in \(start.timeElapsedPretty())")
    }
}

extension IconDomains {
    /// Based on the current time , guess the current run that should be available soon on the open-data server
    fileprivate var lastRun: Timestamp {
        let t = Timestamp.now()
        switch self {
        case .iconEps, .icon:
            // Icon has a delay of 2-3 hours after initialisation  with 4 runs a day
            return t.with(hour: ((t.hour - 2 + 24) % 24) / 6 * 6)
        case .iconEuEps, .iconEu:
            // Icon-eu has a delay of 2:40 hours after initialisation with 8 runs a day
            return t.with(hour: ((t.hour - 2 + 24) % 24) / 3 * 3)
        case .iconD2Eps, .iconD2:
            // Icon d2 has a delay of 44 minutes and runs every 3 hours
            return t.with(hour: t.hour / 3 * 3)
        case .iconD2_15min:
            fatalError("ICON-D2 15minute data can not be downloaded individually")
        }
    }

    var ensembleMembers: Int {
        switch self {
        case .iconEps:
            return 40
        case .iconEuEps:
            return 40
        case .iconD2Eps:
            return 20
        default:
            return 1
        }
    }
}
