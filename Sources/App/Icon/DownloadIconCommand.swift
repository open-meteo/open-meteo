import Foundation
import Vapor
import OmFileFormat
import Dispatch

/**
 TODO:
 - Elevation files should not mask out sea level locations -> this breaks surface pressure correction as a lake can be above sea level
 - Add z0
 */
struct DownloadIconCommand: AsyncCommand {
    enum VariableGroup: String, RawRepresentable, CaseIterable {
        case all
        case surface
        case surfaceAndPressure
        case modelLevel
        case pressureLevel
        case pressureLevelGt500
        case pressureLevelLtE500
        
        var realm: String? {
            switch self {
            case .modelLevel:
                return "model-level"
            case .pressureLevel:
                return "pressure-level"
            default:
                return nil
            }
        }
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
        
        @Flag(name: "skip-timeseries")
        var skipTimeseries: Bool

        @Flag(name: "skip-regridding", help: "For icon or icon-native, write only native global output; skip regridded forecasts and elevation")
        var skipRegridding: Bool
    }

    var help: String {
        "Download a specified DWD ICON or AICON model run"
    }

    static func variables(model: DwdModel, group: VariableGroup, onlyVariables: String?) throws -> [any DwdVariableDownloadable] {
        if let onlyVariables {
            return try onlyVariables.split(separator: ",").map { name in
                if model == .aicon {
                    if let variable = AiconModelLevelVariable(rawValue: String(name)) { return variable }
                    return try AiconSurfaceVariable.load(rawValue: String(name))
                }
                if name == "visibility" {
                    throw Abort(.badRequest, reason: "Visibility is not available in the DWD ICON v1 feed.")
                }
                if let variable = IconPressureVariable(rawValue: String(name)) { return variable }
                return try IconSurfaceVariable.load(rawValue: String(name))
            }
        }
        let surface: [any DwdVariableDownloadable]
        let modelLevel: [any DwdVariableDownloadable]
        let pressure: [any DwdVariableDownloadable]
        switch model {
        case .aicon:
            surface = AiconSurfaceVariable.allCases
            modelLevel = (1...13).flatMap { level in
                AiconModelLevelVariableType.allCases.map { AiconModelLevelVariable(variable: $0, level: level) }
            }
            pressure = []
        case .icon(let domain):
            surface = IconSurfaceVariable.allCases.filter { $0.getVarAndLevel(domain: domain)?.cat != "model-level" }
            modelLevel = IconSurfaceVariable.allCases.filter { $0.getVarAndLevel(domain: domain)?.cat == "model-level" }
            pressure = domain.levels.reversed().flatMap { level in
                IconPressureVariableType.allCases.map { IconPressureVariable(variable: $0, level: level) }
            }
        }
        switch group {
        case .all: return surface + modelLevel + pressure
        case .surface: return surface
        case .surfaceAndPressure: return surface + pressure
        case .modelLevel: return modelLevel
        case .pressureLevel, .pressureLevelGt500, .pressureLevelLtE500:
            guard model != .aicon else {
                throw Abort(.badRequest, reason: "AICON publishes model levels, not pressure levels.")
            }
            return pressure.filter {
                guard let level = $0.getVarAndLevel(model: model)?.level else { return false }
                return group == .pressureLevel || (group == .pressureLevelGt500 ? level > 500 : level <= 500)
            }
        }
    }

    /**
     Convert surface elevation. Out of grid positions are NaN. Sea grid points are -999.
     */
    func convertSurfaceElevation(application: Application, outputs: DwdDownloadDomains, remapper: IconRemapper?, run: Timestamp, uploadS3Bucket: String?) async throws {
        let logger = application.logger
        let model = outputs.source.staticSource
        let domain = model.iconDomain
        let needsPrimary = !FileManager.default.fileExists(atPath: outputs.primary.surfaceElevationFileOm.getFilePath())
        let missingRemapped = outputs.remapped.flatMap { domain in
            FileManager.default.fileExists(atPath: domain.surfaceElevationFileOm.getFilePath()) ? nil : domain
        }
        guard needsPrimary || missingRemapped != nil else {
            return
        }
        if needsPrimary {
            try outputs.primary.surfaceElevationFileOm.createDirectory()
        }
        try missingRemapped?.surfaceElevationFileOm.createDirectory()

        let downloadDirectory = outputs.primary.downloadDirectory
        try FileManager.default.createDirectory(atPath: downloadDirectory, withIntermediateDirectories: true)

        let deadLineHours: Double = (domain == .iconD2 || domain == .iconD2Eps) ? 2 : 5
        let curl = Curl(logger: logger, client: application.dedicatedHttpClient, deadLineHours: deadLineHours)
        let downloader = DwdGribDownloader(domain: model, curl: curl, remapper: outputs.nativeDomain == nil ? remapper : nil)
        // AICON's side runs can bootstrap static fields from the preceding main ICON run.
        let staticRun = outputs.source == .aicon ? run.floor(toNearestHour: 6) : run
        let surface = try await downloader.downloadAndRemap(field: ("HSURF", "single-level", nil), run: staticRun, leadSeconds: 0)
        var hsurf = surface.data.data
        let land = try await downloader.downloadAndRemap(field: ("FR_LAND", "single-level", nil), run: staticRun, leadSeconds: 0)
        let landFraction = land.data.data

        // Set all sea grid points to -999
        precondition(hsurf.count == landFraction.count)
        for i in hsurf.indices {
            if landFraction[i] < 0.5 {
                hsurf[i] = -999
            }
        }

        if needsPrimary {
            try await hsurf.writeStaticOmFile(file: outputs.primary.surfaceElevationFileOm, grid: outputs.primary.grid, application: application, uploadS3Bucket: uploadS3Bucket)
        }
        if let remappedDomain = missingRemapped {
            guard let remapper else {
                preconditionFailure("Remapped ICON elevation requires a grid mapping")
            }
            try await remapper.remap(hsurf).writeStaticOmFile(
                file: remappedDomain.surfaceElevationFileOm,
                grid: remappedDomain.grid,
                application: application,
                uploadS3Bucket: uploadS3Bucket
            )
        }
    }

    /// Download native DWD v1 fields and adapt them to the selected storage outputs.
    func downloadDwd(application: Application, outputs: DwdDownloadDomains, remapper: IconRemapper?, run: Timestamp, variables: [any DwdVariableDownloadable], concurrent: Int, uploadS3Bucket: String?, realm: String?) async throws -> (handles: [GenericVariableHandle], handles15minIconD2: [GenericVariableHandle]) {
        let logger = application.logger
        let client = application.http.client.shared
        let model = outputs.source
        let domain = model.iconDomain
        let remappedDomain = outputs.remapped
        let downloadDirectory = outputs.primary.downloadDirectory
        try FileManager.default.createDirectory(atPath: downloadDirectory, withIntermediateDirectories: true)

        let deadLineHours: Double = (domain == .iconD2 || domain == .iconD2Eps) ? 2 : 5
        let curl = Curl(logger: logger, client: application.dedicatedHttpClient, deadLineHours: deadLineHours, waitAfterLastModified: 120)
        Process.alarm(seconds: Int(deadLineHours + 1) * 3600)
        defer { Process.alarm(seconds: 0) }

        let downloader = DwdGribDownloader(domain: model, curl: curl, remapper: outputs.nativeDomain == nil ? remapper : nil)
        let isEnsemble = model.countEnsembleMember > 1

        let deaverager = GribDeaverager()
        let deaverager15min = GribDeaverager()

        /// Domain elevation field. Used to calculate sea level pressure from surface level pressure in ICON EPS and ICON EU EPS
        let domainElevation = await {
            guard let elevation = try? await outputs.primary.getStaticFile(type: .elevation, httpClient: client, logger: logger)?.read() else {
                fatalError("cannot read elevation for model \(model.modelName)")
            }
            return elevation
        }()
        
        let jobs = variables.flatMap { variable in
            (0..<model.countEnsembleMember).map { (variable: variable, member: $0) }
        }
        let timestamps = try model.getDownloadForecastSteps(run: run.hour).map { run.add(hours: $0) }
        let handles = try await timestamps.enumerated().asyncMap { (i,timestamp) in
            let hour = (timestamp.timeIntervalSince1970 - run.timeIntervalSince1970) / 3600
            logger.info("Downloading hour \(hour)")

            let storage = VariablePerMemberStorage<IconSurfaceVariable>()
            let storage15min = VariablePerMemberStorage<IconSurfaceVariable>()
            
            let writer = OmSpatialTimestepWriter(domain: outputs.primary, run: run, time: timestamp, storeOnDisk: !isEnsemble, realm: realm, logger: logger, ensembleMeanDomain: outputs.ensembleMean)
            let modelLevelWriter = outputs.modelLevel.map {
                OmSpatialTimestepWriter(domain: $0, run: run, time: timestamp, storeOnDisk: true, realm: nil, logger: logger)
            }
            let remappedWriter = remappedDomain.map {
                OmSpatialTimestepWriter(domain: $0, run: run, time: timestamp, storeOnDisk: true, realm: realm, logger: logger)
            }
            let writerProbabilities = isEnsemble ? OmSpatialTimestepWriter(domain: outputs.primary, run: run, time: timestamp, storeOnDisk: true, realm: nil, logger: logger) : nil
            let writer15Min = outputs.fifteenMinute.map {
                OmSpatialMultistepWriter(domain: $0, run: run, storeOnDisk: true, realm: nil, logger: logger)
            }

            @Sendable func write(member: Int, variable: any GenericVariable, data: [Float]) async throws {
                if let modelLevelWriter,
                   outputs.isModelLevel(variable) {
                    try await modelLevelWriter.write(member: member, variable: variable, data: data)
                } else {
                    try await writer.write(member: member, variable: variable, data: data)
                }
                if let remappedWriter {
                    guard let remapper else {
                        preconditionFailure("Remapped ICON writer requires a grid mapping")
                    }
                    try await remappedWriter.write(member: member, variable: variable, data: remapper.remap(data))
                }
            }

            try await jobs.foreachConcurrent(nConcurrent: concurrent) { job in
                let variable = job.variable
                if variable.skipHour(hour: hour, model: model, forDownload: true, run: run) { return }
                guard let field = variable.getVarAndLevel(model: model) else { return }
                let subhourly = writer15Min != nil && (variable as? IconSurfaceVariable)?.hasQuarterHourlyData == true && hour < 48
                let steps = (subhourly ? [0, 900, 1800, 2700] : [0]).map { hour * 3600 + $0 }
                let messages = try await steps.asyncMap { step in
                    try await downloader.downloadAndRemap(field: field, run: run, leadSeconds: step, member: job.member)
                }
                if let writer15Min, subhourly {
                    for (message, raw) in messages {
                        var array2d = raw
                        let step = try IconStepInterval(message)
                        let stepType = try message.getOrThrow(attribute: "stepType")
                        let timestamp = try message.getValidTimestamp()
                        if let fma = variable.multiplyAdd { array2d.data.multiplyAdd(multiply: fma.multiply, add: fma.add) }
                        guard await deaverager15min.deaccumulateIfRequired(variable: variable, member: job.member, stepType: stepType, startStep: step.start, currentStep: step.end, array2d: &array2d) else { continue }
                        if let variable = variable as? IconSurfaceVariable {
                            variable.correctDownloadedValues(data: &array2d.data)
                            if [IconSurfaceVariable.precipitation, .snowfall_height, .rain, .snowfall_water_equivalent, .snowfall_convective_water_equivalent].contains(variable) {
                                await storage15min.set(variable: variable, timestamp: timestamp, member: job.member, data: array2d)
                                continue
                            }
                        }
                        try await writer15Min.write(time: timestamp, member: job.member, variable: variable, data: array2d.data)
                    }
                }

                // Make sure to skip wind gusts hour0 which only contains `0` values
                if variable.skipHour(hour: hour, model: model, forDownload: false, run: run) {
                    return
                }
                
                // The whole-hour field is shared with the independently deaccumulated 15-minute stream.
                let (message, raw) = messages[0]
                var array2d = raw
                    
                let member = job.member

                // Scaling before compression with scalefactor
                if let fma = variable.multiplyAdd {
                    array2d.data.multiplyAdd(multiply: fma.multiply, add: fma.add)
                }

                let step = try IconStepInterval(message)
                let stepType = try message.getOrThrow(attribute: "stepType")
                guard await deaverager.deaccumulateIfRequired(variable: variable, member: member, stepType: stepType, startStep: step.start, currentStep: step.end, array2d: &array2d) else { return }

                if let variable = variable as? IconSurfaceVariable {
                    variable.correctDownloadedValues(data: &array2d.data)

                    if [IconSurfaceVariable.precipitation, .temperature_2m, .snowfall_height, .rain, .snowfall_water_equivalent, .snowfall_convective_water_equivalent, .weather_code, .freezing_level_height, .pressure_msl, .relative_humidity_2m].contains(variable) {
                        await storage.set(variable: variable, timestamp: timestamp, member: member, data: array2d)
                        return
                    }

                    // ICON EPS downloads shortwave radiation under the name of diffuse radiation
                    if variable == .diffuse_radiation, domain == .iconEps {
                        try await write(member: member, variable: DwdIconEpsGlobalVariable.shortwave_radiation, data: array2d.data)
                        return
                    }
                }

                // logger.info("Compressing and writing data to \(filenameDest)")
                try await write(member: member, variable: variable, data: array2d.data)
            }

            /// Calculate precipitation >0.1mm/h probability
            if let writerProbabilities {
                let previousHour = (timestamps[max(0, i-1)].timeIntervalSince1970 - run.timeIntervalSince1970) / 3600
                try await storage.calculatePrecipitationProbability(
                    precipitationVariable: .precipitation,
                    dtHoursOfCurrentStep: hour - previousHour,
                    writer: writerProbabilities
                )
            }

            /// All variables for this timestep have been downloaded. Selected variables are kept in memory.
            /// Do some post processing
            /// Note: Sometimes some members for temperature are missing for a single timestep!
            try await storage.data.foreachConcurrent(nConcurrent: concurrent) { v, data in
                var data = data
                if (domain == .iconEps || domain == .iconEuEps) && v.variable == .pressure_msl,
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
                try await write(member: v.member, variable: v.variable, data: data.data)
            }

            /// Post process 15 minutes data. Note: There is no temperature in 15min data
            try await storage15min.data.foreachConcurrent(nConcurrent: concurrent) { v, data in
                guard let writer15Min else { return }
                var data = data
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
                try await writer15Min.write(time: v.timestamp, member: v.member, variable: v.variable, data: data.data)
            }

            let completed = i == timestamps.count - 1
            let validTimes = Array(timestamps[0...i])
            let handles = try await writer.finalise(application: application, completed: completed, validTimes: validTimes, uploadS3Bucket: uploadS3Bucket)
                + (modelLevelWriter?.finalise(application: application, completed: completed, validTimes: validTimes, uploadS3Bucket: uploadS3Bucket) ?? [])
                + (remappedWriter?.finalise(application: application, completed: completed, validTimes: validTimes, uploadS3Bucket: uploadS3Bucket) ?? [])
                + (writerProbabilities?.finalise(application: application, completed: completed, validTimes: validTimes, uploadS3Bucket: uploadS3Bucket) ?? [])
            
            // TODO valid times and S3 upload for 15min data
            let handles15min = try await writer15Min?.finalise(application: application, completed: false, validTimes: [], uploadS3Bucket: nil) ?? []
            return (handles, handles15min)
        }
        
        await curl.printStatistics()
        return (handles.flatMap({$0.0}), handles.flatMap({$0.1}))
    }

    func run(using context: CommandContext, signature: Signature) async throws {
        let start = DispatchTime.now()
        let requestedNativeDomain = IconNativeDomains(rawValue: signature.domain)
            ?? (signature.domain == IconDomains.icon.rawValue ? .iconNative : nil)
        let nativeDomain = requestedNativeDomain?.modelLevelParent ?? requestedNativeDomain
        let model = try nativeDomain?.sourceModel ?? .icon(IconDomains.load(rawValue: signature.domain))
        let domain = model.iconDomain
        guard !signature.skipRegridding || nativeDomain == .iconNative else {
            throw Abort(.badRequest, reason: "--skip-regridding is only supported for icon or icon-native.")
        }
        if let domain, nativeDomain == nil && [.iconEu, .iconD2, .iconD2_15min, .iconEps, .iconEuEps, .iconD2Eps].contains(domain) {
            throw Abort(.badRequest, reason: "Regular-grid downloads for \(domain.rawValue) are no longer supported. Use \(domain.nativeDomain.rawValue) instead.")
        }
        if let domain, [.iconEpsEnsembleMean, .iconEuEpsEnsembleMean, .iconD2EpsEnsembleMean].contains(domain) {
            throw Abort(.badRequest, reason: "Ensemble means are generated by downloading \(domain.nativeDomain.rawValue).")
        }
        let nConcurrent = signature.concurrent ?? 1
        let run = try signature.run.flatMap(Timestamp.fromRunHourOrYYYYMMDD) ?? model.lastRun()
        _ = try model.getDownloadForecastSteps(run: run.hour) // Reject unsupported runs before preparing static files.

        if signature.onlyVariables != nil && signature.group != nil {
            throw Abort(.badRequest, reason: "--only-variables and --group must not be used simultaneously.")
        }

        let group = try VariableGroup.load(rawValueOptional: signature.group)
            ?? (requestedNativeDomain?.modelLevelParent != nil ? .modelLevel : .all)
        if requestedNativeDomain?.modelLevelParent != nil && (group != .modelLevel || signature.onlyVariables != nil) {
            throw Abort(.badRequest, reason: "Model-level domains only support --group modelLevel. Use the parent domain for --only-variables.")
        }

        let variables = try Self.variables(model: model, group: group, onlyVariables: signature.onlyVariables)

        let logger = context.application.logger
        let generateFullRun = model.countEnsembleMember == 1
        if let nativeDomain {
            try await nativeDomain.prepareNativeGrid(
                application: context.application,
                uploadS3Bucket: signature.uploadS3Bucket
            )
        }
        let outputs: DwdDownloadDomains
        if let nativeDomain {
            outputs = try await DwdDownloadDomains(nativeDomain, skipRegridding: signature.skipRegridding)
        } else if let domain {
            outputs = try await DwdDownloadDomains(domain)
        } else {
            throw Abort(.badRequest, reason: "AICON requires native storage.")
        }
        let outputNames = [outputs.primary, outputs.remapped].compactMap { $0 }.map { String(describing: $0) }.joined(separator: "' and '")
        logger.info("Downloading domain '\(outputNames)' run '\(run.iso8601_YYYY_MM_dd_HH_mm)'")
        let needsRemapping = outputs.nativeDomain == nil || outputs.remapped != nil
        let remapper: IconRemapper?
        if needsRemapping, let domain = outputs.source.iconDomain {
            remapper = try await IconRemapper(curl: Curl(logger: logger, client: context.application.dedicatedHttpClient), domain: domain)
        } else {
            remapper = nil
        }
        try await convertSurfaceElevation(application: context.application, outputs: outputs, remapper: remapper, run: run, uploadS3Bucket: signature.uploadS3Bucket)

        let (handles, handles15minIconD2) = try await downloadDwd(application: context.application, outputs: outputs, remapper: remapper, run: run, variables: variables, concurrent: nConcurrent, uploadS3Bucket: signature.uploadS3Bucket, realm: group.realm)

        if let fifteenMinuteDomain = outputs.fifteenMinute {
            // ICON-D2 downloads 15min data as well
            try await GenericVariableHandle.convert(application: context.application, domain: fifteenMinuteDomain, createNetcdf: signature.createNetcdf, run: run, handles: handles15minIconD2, concurrent: nConcurrent, writeUpdateJson: true, uploadS3Bucket: signature.uploadS3Bucket, uploadS3OnlyProbabilities: signature.uploadS3OnlyProbabilities, generateFullRun: generateFullRun, generateTimeSeries: !signature.skipTimeseries)
        }
        try await GenericVariableHandle.convert(application: context.application, domain: outputs.primary, createNetcdf: signature.createNetcdf, run: run, handles: handles, concurrent: nConcurrent, writeUpdateJson: true, uploadS3Bucket: signature.uploadS3Bucket, uploadS3OnlyProbabilities: signature.uploadS3OnlyProbabilities, generateFullRun: generateFullRun, generateTimeSeries: !signature.skipTimeseries)

        logger.info("Finished in \(start.timeElapsedPretty())")
    }
}


extension IconDomains {
    /// Based on the current time , guess the current run that should be available soon on the open-data server
    func lastRun(now t: Timestamp = .now()) -> Timestamp {
        switch self {
        case .iconEps:
            return t.subtract(hours: 2).floor(toNearestHour: 12)
        case .icon:
            // Icon has a delay of 2-3 hours after initialisation  with 4 runs a day
            return t.subtract(hours: 2).floor(toNearestHour: 6)
        case .iconEuEps:
            return t.subtract(hours: 2).floor(toNearestHour: 6)
        case .iconEu:
            // Icon-eu has a delay of 2:40 hours after initialisation with 8 runs a day
            return t.subtract(hours: 2).floor(toNearestHour: 3)
        case .iconD2Eps, .iconD2:
            // Icon d2 has a delay of 44 minutes and runs every 3 hours
            return t.floor(toNearestHour: 3)
        case .iconD2_15min:
            fatalError("ICON-D2 15minute data can not be downloaded individually")
        case .iconEpsEnsembleMean, .iconD2EpsEnsembleMean, .iconEuEpsEnsembleMean:
            fatalError()
        }
    }

    var countEnsembleMember: Int {
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
