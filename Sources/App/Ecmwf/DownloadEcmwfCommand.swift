import Foundation
import OmFileFormat
import Vapor


/**
 Download from
 https://confluence.ecmwf.int/display/UDOC/ECMWF+Open+Data+-+Real+Time
 https://data.ecmwf.int/forecasts/20220831/00z/0p4-beta/oper/
 
 model info (not everything is open data) https://www.ecmwf.int/en/forecasts/datasets/set-i
 */
struct DownloadEcmwfCommand: AsyncCommand {
    struct Signature: CommandSignature {
        @Option(name: "run")
        var run: String?
        
        @Option(name: "domain")
        var domain: String?
        
        @Option(name: "server", help: "Root server path. Default: 'https://data.ecmwf.int/forecasts/'")
        var server: String?

        @Option(name: "concurrent", short: "c", help: "Numer of concurrent download/conversion jobs")
        var concurrent: Int?
        
        @Option(name: "max-forecast-hour", help: "Only download data until this forecast hour")
        var maxForecastHour: Int?
        
        @Option(name: "timeinterval", short: "t", help: "Timeinterval to download past forecasts. Format 20220101-20220131")
        var timeinterval: String?
        
        @Flag(name: "create-netcdf")
        var createNetcdf: Bool
        
        @Option(name: "only-variables")
        var onlyVariables: String?
        
        @Option(name: "upload-s3-bucket", help: "Upload open-meteo database to an S3 bucket after processing")
        var uploadS3Bucket: String?
        
        @Flag(name: "upload-s3-only-probabilities", help: "Only upload probabilities files to S3")
        var uploadS3OnlyProbabilities: Bool
    }

    var help: String {
        "Download a specified ecmwf model run"
    }
    
    func run(using context: CommandContext, signature: Signature) async throws {
        disableIdleSleep()
        
        let domain = signature.domain.map {
            guard let domain = EcmwfDomain(rawValue: $0) else {
                fatalError("Could not initialise domain from \($0)")
            }
            return domain
        } ?? EcmwfDomain.ifs04
        
        let run = try signature.run.flatMap(Timestamp.fromRunHourOrYYYYMMDD) ?? domain.lastRun
        
        let logger = context.application.logger
        let isWave = domain == .wam025 || domain == .wam025_ensemble

        let onlyVariables = try EcmwfVariable.load(commaSeparatedOptional: signature.onlyVariables)
        let ensembleVariables = EcmwfVariable.allCases.filter({$0.includeInEnsemble != nil})
        let defaultVariables = domain.isEnsemble ? ensembleVariables : EcmwfVariable.allCases
        let variables = onlyVariables ?? defaultVariables
        let nConcurrent = signature.concurrent ?? 1
        let base = signature.server ?? "https://data.ecmwf.int/forecasts/"
        
        let waveVariables = [EcmwfWaveVariable.wave_direction, .wave_height, .wave_period, .wave_period_peak]

        if let timeinterval = signature.timeinterval {
            for run in try Timestamp.parseRange(yyyymmdd: timeinterval).toRange(dt: 86400).with(dtSeconds: 86400 / 4) {
                logger.info("Downloading domain ECMWF run '\(run.iso8601_YYYY_MM_dd_HH_mm)'")
                let handles = isWave ? try await downloadEcmwfWave(application: context.application, domain: domain, base: base, run: run, variables: waveVariables, concurrent: nConcurrent, maxForecastHour: signature.maxForecastHour) : try await downloadEcmwf(application: context.application, domain: domain, base: base, run: run, variables: variables, concurrent: nConcurrent, maxForecastHour: signature.maxForecastHour)
                try await GenericVariableHandle.convert(logger: logger, domain: domain, createNetcdf: signature.createNetcdf, run: run, handles: handles, concurrent: nConcurrent, writeUpdateJson: false, uploadS3Bucket: nil, uploadS3OnlyProbabilities: false)
            }
            return
        }
        logger.info("Downloading domain ECMWF run '\(run.iso8601_YYYY_MM_dd_HH_mm)'")

        if !isWave {
            try await downloadEcmwfElevation(application: context.application, domain: domain, base: base, run: run)
        }
        let handles = isWave ? try await downloadEcmwfWave(application: context.application, domain: domain, base: base, run: run, variables: waveVariables, concurrent: nConcurrent, maxForecastHour: signature.maxForecastHour) : try await downloadEcmwf(application: context.application, domain: domain, base: base, run: run, variables: variables, concurrent: nConcurrent, maxForecastHour: signature.maxForecastHour)
        try await GenericVariableHandle.convert(logger: logger, domain: domain, createNetcdf: signature.createNetcdf, run: run, handles: handles, concurrent: nConcurrent, writeUpdateJson: true, uploadS3Bucket: signature.uploadS3Bucket, uploadS3OnlyProbabilities: signature.uploadS3OnlyProbabilities)
    }
    
    /// Download elevation file
    func downloadEcmwfElevation(application: Application, domain: EcmwfDomain, base: String, run: Timestamp) async throws {
        let logger = application.logger
        let surfaceElevationFileOm = domain.surfaceElevationFileOm
        if FileManager.default.fileExists(atPath: surfaceElevationFileOm.getFilePath()) {
            return
        }
        let curl = Curl(logger: logger, client: application.dedicatedHttpClient)
        
        var generateElevationFileData: (lsm: [Float]?, surfacePressure: [Float]?, sealevelPressure: [Float]?, temperature_2m: [Float]?) = (nil, nil, nil, nil)
        var grib2d = GribArray2D(nx: domain.grid.nx, ny: domain.grid.ny)
        
        logger.info("Downloading height and elevation data")
        let url = domain.getUrl(base: base, run: run, hour: 0)
        for try await message in try await curl.downloadEcmwfIndexed(url: url, concurrent: 1, isIncluded: { entry in
            guard entry.number == nil else {
                // ignore ensemble members, only use control
                return false
            }
            return entry.levtype == .sfc && ["lsm", "2t", "sp", "msl"].contains(entry.param)
        }) {
            let shortName = message.get(attribute: "shortName")!
            try grib2d.load(message: message)
            grib2d.array.flipLatitude()
            
            switch shortName {
            case "lsm":
                generateElevationFileData.lsm = grib2d.array.data
            case "2t":
                grib2d.array.data.multiplyAdd(multiply: 1, add: -273.15)
                generateElevationFileData.temperature_2m = grib2d.array.data
            case "sp":
                grib2d.array.data.multiplyAdd(multiply: 1/100, add: 0)
                generateElevationFileData.surfacePressure = grib2d.array.data
            case "msl":
                grib2d.array.data.multiplyAdd(multiply: 1/100, add: 0)
                generateElevationFileData.sealevelPressure = grib2d.array.data
            default:
                fatalError("Received too many grib messages \(shortName)")
            }
        }
        logger.info("Generating elevation file")
        guard let lsm = generateElevationFileData.lsm else {
            fatalError("Did not get LSM data")
        }
        guard let surfacePressure = generateElevationFileData.surfacePressure,
              let sealevelPressure = generateElevationFileData.sealevelPressure,
              let temperature_2m = generateElevationFileData.temperature_2m else {
            fatalError("Did not get pressure data")
        }
        let elevation: [Float] = zip(zip(surfacePressure, sealevelPressure), zip(temperature_2m, lsm)).map {
            let ((surfacePressure, sealevelPressure), (temperature_2m, landmask)) = $0
            return landmask < 0.5 ? -999 : Meteorology.elevation(sealevelPressure: sealevelPressure, surfacePressure: surfacePressure, temperature_2m: temperature_2m)
        }
        try domain.surfaceElevationFileOm.createDirectory()
        try elevation.writeOmFile2D(file: domain.surfaceElevationFileOm.getFilePath(), grid: domain.grid)
    }
    
    /// Download ECMWF ifs open data
    func downloadEcmwf(application: Application, domain: EcmwfDomain, base: String, run: Timestamp, variables: [EcmwfVariable], concurrent: Int, maxForecastHour: Int?) async throws -> [GenericVariableHandle] {
        let logger = application.logger
        let curl = Curl(logger: logger, client: application.dedicatedHttpClient)
        Process.alarm(seconds: 6 * 3600)
        defer { Process.alarm(seconds: 0) }
        
        var forecastHours = domain.getDownloadForecastSteps(run: run.hour)
        if let maxForecastHour {
            forecastHours = forecastHours.filter({$0 <= maxForecastHour})
        }
        let writer = OmFileSplitter.makeSpatialWriter(domain: domain, nMembers: domain.ensembleMembers)
        
        var handles = [GenericVariableHandle]()
        let deaverager = GribDeaverager()
        
        var previousHour = 0
        for hour in forecastHours {
            logger.info("Downloading hour \(hour)")
            let timestamp = run.add(hours: hour)
            /// Delta time seconds considering irregular timesteps
            let dtSeconds = previousHour == 0 ? domain.dtSeconds : ((hour - previousHour) * 3600)
            
            if variables.isEmpty {
                continue
            }
            let inMemory = VariablePerMemberStorage<EcmwfVariable>()
            
            /// Relative humidity missing in AIFS
            func calcRh(rh: EcmwfVariable, q:  EcmwfVariable, t: EcmwfVariable, member: Int, hpa: Float) async throws {
                guard await inMemory.get(variable: rh, timestamp: timestamp, member: member) == nil,
                    let q = await inMemory.get(variable: q, timestamp: timestamp, member: member),
                    let t = await inMemory.get(variable: t, timestamp: timestamp, member: member) else {
                    return
                }
                let data = Meteorology.specificToRelativeHumidity(specificHumidity: q.data, temperature: t.data, pressure: .init(repeating: hpa, count: t.count))
                await inMemory.set(variable: rh, timestamp: timestamp, member: member, data: Array2D(data: data, nx: t.nx, ny: t.ny))
                let fn = try writer.writeTemporary(compressionType: .pfor_delta2d_int16, scalefactor: 1, all: data)
                handles.append(GenericVariableHandle(
                    variable: rh,
                    time: timestamp,
                    member: member,
                    fn: fn
                ))
            }
            
            /// AIFS missed U/V wind components
            func calcWindComponents(u: EcmwfVariable, v: EcmwfVariable, gph: EcmwfVariable, member: Int, hpa: Float) async throws {
                guard await inMemory.get(variable: u, timestamp: timestamp, member: member) == nil,
                        let gph = await inMemory.get(variable: gph, timestamp: timestamp, member: member) else {
                    return
                }
                guard let grid = domain.grid as? RegularGrid else {
                    fatalError("required regular grid")
                }
                let (uData, vData) = Meteorology.geostrophicWind(geopotentialHeightMeters: gph.data, grid: grid)
                handles.append(GenericVariableHandle(
                    variable: u,
                    time: timestamp,
                    member: member,
                    fn: try writer.writeTemporary(compressionType: .pfor_delta2d_int16, scalefactor: u.scalefactor, all: uData)
                ))
                handles.append(GenericVariableHandle(
                    variable: v,
                    time: timestamp,
                    member: member,
                    fn: try writer.writeTemporary(compressionType: .pfor_delta2d_int16, scalefactor: u.scalefactor, all: vData)
                ))
            }
            
            let url = domain.getUrl(base: base, run: run, hour: hour)
            let h = try await curl.downloadEcmwfIndexed(url: url, concurrent: concurrent, isIncluded: { entry in
                return variables.contains(where: { variable in
                    if let level = entry.level {
                        // entry is a pressure level variable
                        if variable.gribName == "gh" && variable.level == level && entry.param == "z" {
                            return true
                        }
                        return variable.level == level && entry.param == variable.gribName
                    }
                    return entry.param == variable.gribName
                })
            }).mapStream(nConcurrent: concurrent) { message -> GenericVariableHandle? in
                guard let shortName = message.get(attribute: "shortName"),
                      var stepRange = message.get(attribute: "stepRange"),
                      let stepType = message.get(attribute: "stepType") else {
                    fatalError("could not get step range or type")
                }
                if shortName == "lsm" {
                    return nil
                }
                let levelhPa = message.get(attribute: "level").flatMap(Int.init)!
                let member = message.get(attribute: "perturbationNumber").flatMap(Int.init) ?? 0
                
                guard let variable = variables.first(where: { variable in
                    if variable == .total_column_integrated_water_vapour && shortName == "tcwv" {
                        return true
                    }
                    if let level = variable.level {
                        if shortName == "z" && variable.gribName == "gh" && levelhPa == level {
                            return true
                        }
                        return shortName == variable.gribName && levelhPa == level
                    }
                    return shortName == variable.gribName
                }) else {
                    print(
                        message.get(attribute: "name")!,
                        message.get(attribute: "shortName")!,
                        message.get(attribute: "level")!,
                        message.get(attribute: "paramId")!
                    )
                    if message.get(attribute: "name") == "unknown" {
                        message.iterate(namespace: .ls).forEach({print($0)})
                        message.iterate(namespace: .parameter).forEach({print($0)})
                        message.iterate(namespace: .mars).forEach({print($0)})
                        message.iterate(namespace: .all).forEach({print($0)})
                    }
                    fatalError("Got unknown variable \(shortName) \(levelhPa)")
                }
                
                /// Gusts in hour 0 only contain `0` values. The attributes for stepType and stepRange are not correctly set.
                if [EcmwfVariable.wind_gusts_10m, .temperature_2m_max, .temperature_2m_min, .shortwave_radiation, .precipitation, .runoff].contains(variable) && hour == 0 {
                    return nil
                }
                
                //logger.info("Processing \(variable)")
                var grib2d = GribArray2D(nx: domain.grid.nx, ny: domain.grid.ny)
                try grib2d.load(message: message)
                grib2d.array.flipLatitude()
                
                //try message.debugGrid(grid: domain.grid, flipLatidude: false, shift180Longitude: false)
                //fatalError()
                
                // Scaling before compression with scalefactor
                if let fma = variable.multiplyAdd(domain: domain, dtSeconds: dtSeconds) {
                    grib2d.array.data.multiplyAdd(multiply: fma.multiply, add: fma.add)
                }
                
                if shortName == "z" && [EcmwfDomain.aifs025, .aifs025_single].contains(domain) {
                    grib2d.array.data.multiplyAdd(multiply: 1/9.80665, add: 0)
                }
                
                // solar shortwave radition show accum with step range "90"
                if stepType == "accum" && !stepRange.contains("-") {
                    stepRange = "0-\(stepRange)"
                }
                
                // Deaccumulate precipitation
                guard await deaverager.deaccumulateIfRequired(variable: variable, member: member, stepType: stepType, stepRange: stepRange, grib2d: &grib2d) else {
                    return nil
                }
                
                // Keep relative humidity in memory to generate total cloud cover files
                if variable.gribName == "r" {
                    await inMemory.set(variable: variable, timestamp: timestamp, member: member, data: grib2d.array)
                }
                
                // For AIFS keep specific humidity and temperature in memory
                // geopotential and vertical velocity for wind calculation
                if [EcmwfDomain.aifs025, .aifs025_single].contains(domain) && ["t", "q", "w", "z", "gh"].contains(variable.gribName) {
                    await inMemory.set(variable: variable, timestamp: timestamp, member: member, data: grib2d.array)
                }
                if ["w", "q"].contains(variable.gribName) {
                    // do not store specific humidity on disk
                    return nil
                }
                if variable == .temperature_2m {
                    await inMemory.set(variable: variable, timestamp: timestamp, member: member, data: grib2d.array)
                }
                
                if variable == .dew_point_2m {
                    await inMemory.set(variable: variable, timestamp: timestamp, member: member, data: grib2d.array)
                    return nil
                }
                // Keep precip in memory for probability
                if domain == .ifs025_ensemble && variable == .precipitation {
                    await inMemory.set(variable: variable, timestamp: timestamp, member: member, data: grib2d.array)
                }
                
                if domain.isEnsemble && variable.includeInEnsemble != .downloadAndProcess {
                    // do not generate some database files for ensemble
                    return nil
                }
                let skipHour0 = [.shortwave_radiation, .precipitation, .runoff].contains(variable)
                // Shortwave radiation and precipitation contain always 0 values for hour 0.
                if hour == 0 && skipHour0 {
                    return nil
                }
                
                let fn = try writer.writeTemporary(compressionType: .pfor_delta2d_int16, scalefactor: variable.scalefactor, all: grib2d.array.data)
                // Note: skipHour0 needs still to be set for solar interpolation
                logger.info("Processing \(variable) member \(member) timestep \(timestamp)")
                return GenericVariableHandle(
                    variable: variable,
                    time: timestamp,
                    member: member,
                    fn: fn
                )
            }.collect().compactMap({$0})
            handles.append(contentsOf: h)
            
            // Calculate mid/low/high/total cloudocover
            logger.info("Calculating derived variables")
            for member in 0..<domain.ensembleMembers {
                /// calculate RH 2m from dewpoint. Only store RH on disk.
                if let dewpoint = await inMemory.get(variable: .dew_point_2m, timestamp: timestamp, member: member)?.data,
                   let temperature = await inMemory.get(variable: .temperature_2m, timestamp: timestamp, member: member)?.data {
                    let rh = zip(temperature, dewpoint).map(Meteorology.relativeHumidity)
                    let fn = try writer.writeTemporary(compressionType: .pfor_delta2d_int16, scalefactor: 1, all: rh)
                    handles.append(GenericVariableHandle(
                        variable: EcmwfVariable.relative_humidity_2m,
                        time: timestamp,
                        member: member,
                        fn: fn
                    ))
                } else if let rh1000 = await inMemory.get(variable: .relative_humidity_1000hPa, timestamp: timestamp, member: member)?.data {
                    let fn = try writer.writeTemporary(compressionType: .pfor_delta2d_int16, scalefactor: 1, all: rh1000)
                    handles.append(GenericVariableHandle(
                        variable: EcmwfVariable.relative_humidity_2m,
                        time: timestamp,
                        member: member,
                        fn: fn
                    ))
                }
                
                // U/V wind components
                if !handles.contains(where: { $0.variable as? EcmwfVariable == EcmwfVariable.wind_u_component_1000hPa && $0.time == timestamp && $0.member == member}) {
                    logger.info("Calculating U/V components from geostrophic wind")
                    try await calcWindComponents(u: .wind_u_component_1000hPa, v: .wind_v_component_1000hPa, gph: .geopotential_height_1000hPa, member: member, hpa: 1000)
                    try await calcWindComponents(u: .wind_u_component_925hPa, v: .wind_v_component_925hPa, gph: .geopotential_height_925hPa, member: member, hpa: 925)
                    try await calcWindComponents(u: .wind_u_component_850hPa, v: .wind_v_component_850hPa, gph: .geopotential_height_850hPa, member: member, hpa: 850)
                    try await calcWindComponents(u: .wind_u_component_700hPa, v: .wind_v_component_700hPa, gph: .geopotential_height_700hPa, member: member, hpa: 700)
                    try await calcWindComponents(u: .wind_u_component_600hPa, v: .wind_v_component_600hPa, gph: .geopotential_height_600hPa, member: member, hpa: 600)
                    try await calcWindComponents(u: .wind_u_component_500hPa, v: .wind_v_component_500hPa, gph: .geopotential_height_500hPa, member: member, hpa: 500)
                    try await calcWindComponents(u: .wind_u_component_400hPa, v: .wind_v_component_400hPa, gph: .geopotential_height_400hPa, member: member, hpa: 400)
                    try await calcWindComponents(u: .wind_u_component_300hPa, v: .wind_v_component_300hPa, gph: .geopotential_height_300hPa, member: member, hpa: 300)
                    try await calcWindComponents(u: .wind_u_component_250hPa, v: .wind_v_component_250hPa, gph: .geopotential_height_250hPa, member: member, hpa: 250)
                    try await calcWindComponents(u: .wind_u_component_200hPa, v: .wind_v_component_200hPa, gph: .geopotential_height_200hPa, member: member, hpa: 200)
                    try await calcWindComponents(u: .wind_u_component_100hPa, v: .wind_v_component_100hPa, gph: .geopotential_height_100hPa, member: member, hpa: 100)
                    try await calcWindComponents(u: .wind_u_component_50hPa, v: .wind_v_component_50hPa, gph: .geopotential_height_50hPa, member: member, hpa: 50)
                }
                
                // Relative humidity missing in AIFS
                if !handles.contains(where: { $0.variable as? EcmwfVariable == EcmwfVariable.relative_humidity_1000hPa && $0.time == timestamp && $0.member == member}) {
                    logger.info("Calculating relative humidity")
                    try await calcRh(rh: .relative_humidity_1000hPa, q: .specific_humidity_1000hPa, t: .temperature_1000hPa, member: member, hpa: 1000)
                    try await calcRh(rh: .relative_humidity_925hPa, q: .specific_humidity_925hPa, t: .temperature_925hPa, member: member, hpa: 925)
                    try await calcRh(rh: .relative_humidity_850hPa, q: .specific_humidity_850hPa, t: .temperature_850hPa, member: member, hpa: 850)
                    try await calcRh(rh: .relative_humidity_700hPa, q: .specific_humidity_700hPa, t: .temperature_700hPa, member: member, hpa: 700)
                    try await calcRh(rh: .relative_humidity_600hPa, q: .specific_humidity_600hPa, t: .temperature_600hPa, member: member, hpa: 600)
                    try await calcRh(rh: .relative_humidity_500hPa, q: .specific_humidity_500hPa, t: .temperature_500hPa, member: member, hpa: 500)
                    try await calcRh(rh: .relative_humidity_400hPa, q: .specific_humidity_400hPa, t: .temperature_400hPa, member: member, hpa: 400)
                    try await calcRh(rh: .relative_humidity_300hPa, q: .specific_humidity_300hPa, t: .temperature_300hPa, member: member, hpa: 300)
                    try await calcRh(rh: .relative_humidity_250hPa, q: .specific_humidity_250hPa, t: .temperature_250hPa, member: member, hpa: 250)
                    try await calcRh(rh: .relative_humidity_200hPa, q: .specific_humidity_200hPa, t: .temperature_200hPa, member: member, hpa: 200)
                    try await calcRh(rh: .relative_humidity_100hPa, q: .specific_humidity_100hPa, t: .temperature_100hPa, member: member, hpa: 100)
                    try await calcRh(rh: .relative_humidity_50hPa, q: .specific_humidity_50hPa, t: .temperature_50hPa, member: member, hpa: 50)
                }
                
                if !handles.contains(where: { $0.variable as? EcmwfVariable == EcmwfVariable.cloud_cover && $0.time == timestamp && $0.member == member}) {
                    logger.info("Calculating cloud cover")
                    guard let rh1000 = await inMemory.get(variable: .relative_humidity_1000hPa, timestamp: timestamp, member: member)?.data,
                          let rh925 = await inMemory.get(variable: .relative_humidity_925hPa, timestamp: timestamp, member: member)?.data,
                          let rh850 = await inMemory.get(variable: .relative_humidity_850hPa, timestamp: timestamp, member: member)?.data,
                          let rh700 = await inMemory.get(variable: .relative_humidity_700hPa, timestamp: timestamp, member: member)?.data,
                          let rh500 = await inMemory.get(variable: .relative_humidity_500hPa, timestamp: timestamp, member: member)?.data,
                          let rh300 = await inMemory.get(variable: .relative_humidity_300hPa, timestamp: timestamp, member: member)?.data,
                          let rh250 = await inMemory.get(variable: .relative_humidity_250hPa, timestamp: timestamp, member: member)?.data,
                          let rh200 = await inMemory.get(variable: .relative_humidity_200hPa, timestamp: timestamp, member: member)?.data,
                          let rh50 = await inMemory.get(variable: .relative_humidity_50hPa, timestamp: timestamp, member: member)?.data else {
                        logger.warning("Pressure level relative humidity unavailable")
                        continue
                    }
                    
                    let cloudcoverLow = zip(rh1000, zip(rh925, rh850)).map {
                        return max(Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0.0, pressureHPa: 1000),
                                   max(Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0.1.0, pressureHPa: 925),
                                       Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0.1.1, pressureHPa: 850)))
                    }
                    let cloudcoverMid = zip(rh700, zip(rh500, rh300)).map {
                        return max(Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0.0, pressureHPa: 700),
                                   max(Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0.1.0, pressureHPa: 500),
                                       Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0.1.1, pressureHPa: 300)))
                    }
                    let cloudcoverHigh = zip(rh250, zip(rh200, rh50)).map {
                        return max(Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0.0, pressureHPa: 250),
                                   max(Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0.1.0, pressureHPa: 200),
                                       Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0.1.1, pressureHPa: 50)))
                    }
                    let fnCloudCoverLow = try writer.writeTemporary(compressionType: .pfor_delta2d_int16, scalefactor: 1, all: cloudcoverLow)
                    let fnCloudCoverMid = try writer.writeTemporary(compressionType: .pfor_delta2d_int16, scalefactor: 1, all: cloudcoverMid)
                    let fnCloudCoverHigh = try writer.writeTemporary(compressionType: .pfor_delta2d_int16, scalefactor: 1, all: cloudcoverHigh)
                    let cloudcover = Meteorology.cloudCoverTotal(low: cloudcoverLow, mid: cloudcoverMid, high: cloudcoverHigh)
                    let fnCloudCover = try writer.writeTemporary(compressionType: .pfor_delta2d_int16, scalefactor: 1, all: cloudcover)
                    
                    handles.append(GenericVariableHandle(
                        variable: EcmwfVariable.cloud_cover_low,
                        time: timestamp,
                        member: member,
                        fn: fnCloudCoverLow
                    ))
                    handles.append(GenericVariableHandle(
                        variable: EcmwfVariable.cloud_cover_mid,
                        time: timestamp,
                        member: member,
                        fn: fnCloudCoverMid
                    ))
                    handles.append(GenericVariableHandle(
                        variable: EcmwfVariable.cloud_cover_high,
                        time: timestamp,
                        member: member,
                        fn: fnCloudCoverHigh
                    ))
                    handles.append(GenericVariableHandle(
                        variable: EcmwfVariable.cloud_cover,
                        time: timestamp,
                        member: member,
                        fn: fnCloudCover
                    ))
                }
            }
            
            if domain == .ifs025_ensemble {
                logger.info("Calculating precipitation probability")
                if let handle = try await inMemory.calculatePrecipitationProbability(
                    precipitationVariable: .precipitation,
                    domain: domain,
                    timestamp: timestamp,
                    dtHoursOfCurrentStep: hour - previousHour
                ) {
                    handles.append(handle)
                }
            }
            previousHour = hour
        }
        await curl.printStatistics()
        return handles
    }
    
    
    /// Download ECMWF ifs open data
    func downloadEcmwfWave(application: Application, domain: EcmwfDomain, base: String, run: Timestamp, variables: [EcmwfWaveVariable], concurrent: Int, maxForecastHour: Int?) async throws -> [GenericVariableHandle] {
        let logger = application.logger
        let curl = Curl(logger: logger, client: application.dedicatedHttpClient)
        Process.alarm(seconds: 6 * 3600)
        defer { Process.alarm(seconds: 0) }
        
        var forecastHours = domain.getDownloadForecastSteps(run: run.hour)
        if let maxForecastHour {
            forecastHours = forecastHours.filter({$0 <= maxForecastHour})
        }
        let writer = OmFileSplitter.makeSpatialWriter(domain: domain, nMembers: domain.ensembleMembers)
        
        var handles = [GenericVariableHandle]()
        
        for hour in forecastHours {
            logger.info("Downloading hour \(hour)")
            let timestamp = run.add(hours: hour)
            
            if variables.isEmpty {
                continue
            }
            
            let url = domain.getUrl(base: base, run: run, hour: hour)
            let h = try await curl.downloadEcmwfIndexed(url: url, concurrent: concurrent, isIncluded: { entry in
                return variables.contains(where: { variable in
                    return entry.param == variable.gribName
                })
            }).mapStream(nConcurrent: concurrent) { message -> GenericVariableHandle? in
                guard let shortName = message.get(attribute: "shortName") else {
                    fatalError("could not get step range or type")
                }
                if shortName == "lsm" {
                    return nil
                }
                let levelhPa = message.get(attribute: "level").flatMap(Int.init)!
                let member = message.get(attribute: "perturbationNumber").flatMap(Int.init) ?? 0
                
                guard let variable = variables.first(where: { variable in
                    return shortName == variable.gribName
                }) else {
                    print(
                        message.get(attribute: "name")!,
                        message.get(attribute: "shortName")!,
                        message.get(attribute: "level")!,
                        message.get(attribute: "paramId")!
                    )
                    if message.get(attribute: "name") == "unknown" {
                        message.iterate(namespace: .ls).forEach({print($0)})
                        message.iterate(namespace: .parameter).forEach({print($0)})
                        message.iterate(namespace: .mars).forEach({print($0)})
                        message.iterate(namespace: .all).forEach({print($0)})
                    }
                    fatalError("Got unknown variable \(shortName) \(levelhPa)")
                }
                //logger.info("Processing \(variable)")
                var grib2d = GribArray2D(nx: domain.grid.nx, ny: domain.grid.ny)
                try grib2d.load(message: message)
                grib2d.array.flipLatitude()
                
                //try message.debugGrid(grid: domain.grid, flipLatidude: true, shift180Longitude: false)
                //fatalError()
                
                // Scaling before compression with scalefactor
                //if let fma = variable.multiplyAdd {
                //    grib2d.array.data.multiplyAdd(multiply: fma.multiply, add: fma.add)
                //}
                
                let fn = try writer.writeTemporary(compressionType: .pfor_delta2d_int16, scalefactor: variable.scalefactor, all: grib2d.array.data)
                // Note: skipHour0 needs still to be set for solar interpolation
                return GenericVariableHandle(
                    variable: variable,
                    time: timestamp,
                    member: member,
                    fn: fn
                )
            }.collect().compactMap({$0})
            handles.append(contentsOf: h)
        }
        await curl.printStatistics()
        return handles
    }
}

extension EcmwfDomain {
    /// Based on the current time , guess the current run that should be available soon on the open-data server
    fileprivate var lastRun: Timestamp {
        // 18z run starts downloading on the next day
        let twoHoursAgo = Timestamp.now().add(-7200)
        let t = Timestamp.now()
        switch self {
        case .ifs04_ensemble, .ifs025_ensemble ,.wam025_ensemble:
            fallthrough
        case .ifs04,. ifs025, .wam025:
            // ECMWF has a delay of 7-8 hours after initialisation
            return twoHoursAgo.with(hour: ((t.hour - 7 + 24) % 24) / 6 * 6)
        case .aifs025, .aifs025_single:
            // AIFS025 has a delay of 5-7 hours after initialisation
            return twoHoursAgo.with(hour: ((t.hour - 5 + 24) % 24) / 6 * 6)
        }
    }
    /// Get download url for a given domain and timestep
    fileprivate func getUrl(base: String, run: Timestamp, hour: Int) -> String {
        let runStr = run.hour.zeroPadded(len: 2)
        let dateStr = run.format_YYYYMMdd
        switch self {
        case .ifs04:
            let product = run.hour == 0 || run.hour == 12 ? "oper" : "scda"
            return "\(base)\(dateStr)/\(runStr)z/ifs/0p4-beta/\(product)/\(dateStr)\(runStr)0000-\(hour)h-\(product)-fc.grib2"
        case .wam025:
            let product = run.hour == 0 || run.hour == 12 ? "wave" : "scwv"
            return "\(base)\(dateStr)/\(runStr)z/ifs/0p25/\(product)/\(dateStr)\(runStr)0000-\(hour)h-\(product)-fc.grib2"
        case .wam025_ensemble:
            let product = run.hour == 0 || run.hour == 12 ? "waef" : "scda"
            return "\(base)\(dateStr)/\(runStr)z/ifs/0p25/\(product)/\(dateStr)\(runStr)0000-\(hour)h-\(product)-ef.grib2"
        case .ifs04_ensemble:
            return "\(base)\(dateStr)/\(runStr)z/ifs/0p4-beta/enfo/\(dateStr)\(runStr)0000-\(hour)h-enfo-ef.grib2"
        case .ifs025:
            let product = run.hour == 0 || run.hour == 12 ? "oper" : "scda"
            return "\(base)\(dateStr)/\(runStr)z/ifs/0p25/\(product)/\(dateStr)\(runStr)0000-\(hour)h-\(product)-fc.grib2"
        case .ifs025_ensemble:
            return "\(base)\(dateStr)/\(runStr)z/ifs/0p25/enfo/\(dateStr)\(runStr)0000-\(hour)h-enfo-ef.grib2"
        case .aifs025:
            return "\(base)\(dateStr)/\(runStr)z/aifs/0p25/oper/\(dateStr)\(runStr)0000-\(hour)h-oper-fc.grib2"
        case .aifs025_single:
            // https://data.ecmwf.int/forecasts/20250220/00z/aifs-single/0p25/experimental/oper/
            return "\(base)\(dateStr)/\(runStr)z/aifs-single/0p25/oper/\(dateStr)\(runStr)0000-\(hour)h-oper-fc.grib2"
        }
    }
}
