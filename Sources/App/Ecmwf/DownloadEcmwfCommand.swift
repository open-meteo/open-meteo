import Foundation
import SwiftPFor2D
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
        
        @Flag(name: "create-netcdf")
        var createNetcdf: Bool
        
        @Option(name: "only-variables")
        var onlyVariables: String?
        
        @Option(name: "upload-s3-bucket", help: "Upload open-meteo database to an S3 bucket after processing")
        var uploadS3Bucket: String?
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

        logger.info("Downloading domain ECMWF run '\(run.iso8601_YYYY_MM_dd_HH_mm)'")
        
        let onlyVariables = try EcmwfVariable.load(commaSeparatedOptional: signature.onlyVariables)
        let ensembleVariables = EcmwfVariable.allCases.filter({$0.includeInEnsemble != nil})
        let defaultVariables = domain.isEnsemble ? ensembleVariables : EcmwfVariable.allCases
        let variables = onlyVariables ?? defaultVariables
        let nConcurrent = signature.concurrent ?? 1
        let base = signature.server ?? "https://data.ecmwf.int/forecasts/"

        try FileManager.default.createDirectory(atPath: domain.downloadDirectory, withIntermediateDirectories: true)
        try await downloadEcmwfElevation(application: context.application, domain: domain, base: base, run: run)
        let handles = try await downloadEcmwf(application: context.application, domain: domain, base: base, run: run, variables: variables, concurrent: nConcurrent)
        try await GenericVariableHandle.convert(logger: logger, domain: domain, createNetcdf: signature.createNetcdf, run: run, nMembers: domain.ensembleMembers, handles: handles, concurrent: nConcurrent)
        
        if let uploadS3Bucket = signature.uploadS3Bucket {
            try domain.domainRegistry.syncToS3(bucket: uploadS3Bucket, variables: variables)
        }
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
        //try Array2DFastSpace(data: elevation, nLocations: domain.grid.count, nTime: 1).writeNetcdf(filename: "\(domain.downloadDirectory)/elevation.nc", nx: domain.grid.nx, ny: domain.grid.ny)
        try domain.surfaceElevationFileOm.createDirectory()
        if domain == .aifs025 {
            try OmFileWriter(dim0: domain.grid.ny, dim1: domain.grid.nx, chunk0: 1, chunk1: 20*20).write(file: domain.surfaceElevationFileOm.getFilePath(), compressionType: .p4nzdec256, scalefactor: 1, all: elevation)
        } else {
            try OmFileWriter(dim0: domain.grid.ny, dim1: domain.grid.nx, chunk0: 20, chunk1: 20).write(file: domain.surfaceElevationFileOm.getFilePath(), compressionType: .p4nzdec256, scalefactor: 1, all: elevation)
        }

    }
    
    /// Download ECMWF ifs open data
    func downloadEcmwf(application: Application, domain: EcmwfDomain, base: String, run: Timestamp, variables: [EcmwfVariable], concurrent: Int) async throws -> [GenericVariableHandle] {
        let logger = application.logger
        let curl = Curl(logger: logger, client: application.dedicatedHttpClient)
        Process.alarm(seconds: 6 * 3600)
        defer { Process.alarm(seconds: 0) }
        
        let forecastSteps = domain.getDownloadForecastSteps(run: run.hour)
        let nMembers = domain.ensembleMembers
        let nLocationsPerChunk = OmFileSplitter(domain, nMembers: nMembers, chunknLocations: nMembers > 1 ? nMembers : nil).nLocationsPerChunk
        let writer = OmFileWriter(dim0: 1, dim1: domain.grid.count, chunk0: 1, chunk1: nLocationsPerChunk)
        
        var handles = [GenericVariableHandle]()
        let deaverager = GribDeaverager()
        
        for hour in forecastSteps {
            logger.info("Downloading hour \(hour)")
            let timestamp = run.add(hours: hour)
            
            if variables.isEmpty {
                continue
            }
            struct EcmwfVariableMember: Hashable {
                let variable: EcmwfVariable
                let member: Int
                
                init(_ variable: EcmwfVariable, _ member: Int) {
                    self.variable = variable
                    self.member = member
                }
            }
            let inMemory = DictionaryActor<EcmwfVariableMember, [Float]>()
            
            /// Relative humidity missing in AIFS
            func calcRh(rh: EcmwfVariable, q:  EcmwfVariable, t: EcmwfVariable, member: Int, hpa: Float) async throws {
                guard await inMemory.get(.init(rh, member)) == nil, let q = await inMemory.get(.init(q, member)), let t = await inMemory.get(.init(t, member)) else {
                    return
                }
                let data = Meteorology.specificToRelativeHumidity(specificHumidity: q, temperature: t, pressure: .init(repeating: hpa, count: t.count))
                await inMemory.set(.init(rh, member), data)
                let fn = try writer.writeTemporary(compressionType: .p4nzdec256, scalefactor: 1, all: data)
                handles.append(GenericVariableHandle(
                    variable: rh,
                    time: timestamp,
                    member: member,
                    fn: fn,
                    skipHour0: false
                ))
            }
            
            /// AIFS missed U/V wind components
            func calcWindComponents(u: EcmwfVariable, v: EcmwfVariable, gph: EcmwfVariable, member: Int, hpa: Float) async throws {
                guard await inMemory.get(.init(u, member)) == nil, let gph = await inMemory.get(.init(gph, member)) else {
                    return
                }
                guard let grid = domain.grid as? RegularGrid else {
                    fatalError("required regular grid")
                }
                let (uData, vData) = Meteorology.geostrophicWind(geopotentialHeightMeters: gph, grid: grid)
                handles.append(GenericVariableHandle(
                    variable: u,
                    time: timestamp,
                    member: member,
                    fn: try writer.writeTemporary(compressionType: .p4nzdec256, scalefactor: u.scalefactor, all: uData),
                    skipHour0: false
                ))
                handles.append(GenericVariableHandle(
                    variable: v,
                    time: timestamp,
                    member: member,
                    fn: try writer.writeTemporary(compressionType: .p4nzdec256, scalefactor: u.scalefactor, all: vData),
                    skipHour0: false
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
                //logger.info("Processing \(variable)")
                var grib2d = GribArray2D(nx: domain.grid.nx, ny: domain.grid.ny)
                try grib2d.load(message: message)
                grib2d.array.flipLatitude()
                
                //try message.debugGrid(grid: domain.grid, flipLatidude: false, shift180Longitude: false)
                //fatalError()
                
                // Scaling before compression with scalefactor
                if let fma = variable.multiplyAdd {
                    grib2d.array.data.multiplyAdd(multiply: fma.multiply, add: fma.add)
                }
                
                if shortName == "z" && domain == .aifs025 {
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
                    await inMemory.set(.init(variable, member), grib2d.array.data)
                }
                
                // For AIFS keep specific humidity and temperature in memory
                // geopotential and vertical velocity for wind calculation
                if domain == .aifs025 && ["t", "q", "w", "z", "gh"].contains(variable.gribName) {
                    await inMemory.set(.init(variable, member), grib2d.array.data)
                }
                if variable == .temperature_2m {
                    await inMemory.set(.init(variable, member), grib2d.array.data)
                }
                
                if variable == .dew_point_2m {
                    await inMemory.set(.init(variable, member), grib2d.array.data)
                    return nil
                }
                
                if domain.isEnsemble && variable.includeInEnsemble != .downloadAndProcess {
                    // do not generate some database files for ensemble
                    return nil
                }
                
                let fn = try writer.writeTemporary(compressionType: .p4nzdec256, scalefactor: variable.scalefactor, all: grib2d.array.data)
                return GenericVariableHandle(
                    variable: variable,
                    time: timestamp,
                    member: member,
                    fn: fn,
                    skipHour0: false
                )
            }.collect().compactMap({$0})
            handles.append(contentsOf: h)
            
            // Calculate mid/low/high/total cloudocover
            logger.info("Calculating cloud cover")
            for member in 0..<domain.ensembleMembers {
                /// calculate RH 2m from dewpoint. Only store RH on disk.
                if let dewpoint = await inMemory.get(.init(.dew_point_2m, member)), let temperature = await inMemory.get(.init(.temperature_2m, member)) {
                    let rh = zip(temperature, dewpoint).map(Meteorology.relativeHumidity)
                    let fn = try writer.writeTemporary(compressionType: .p4nzdec256, scalefactor: 1, all: rh)
                    handles.append(GenericVariableHandle(
                        variable: EcmwfVariable.relative_humidity_2m,
                        time: timestamp,
                        member: member,
                        fn: fn,
                        skipHour0: false
                    ))
                } else if let rh1000 = await inMemory.get(.init(.relative_humidity_1000hPa, member)) {
                    let fn = try writer.writeTemporary(compressionType: .p4nzdec256, scalefactor: 1, all: rh1000)
                    handles.append(GenericVariableHandle(
                        variable: EcmwfVariable.relative_humidity_2m,
                        time: timestamp,
                        member: member,
                        fn: fn,
                        skipHour0: false
                    ))
                }
                
                /// U/V wind components
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
                
                /// Relative humidity missing in AIFS
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
                
                guard let rh1000 = await inMemory.get(.init(.relative_humidity_1000hPa, member)),
                      let rh925 = await inMemory.get(.init(.relative_humidity_925hPa, member)),
                      let rh850 = await inMemory.get(.init(.relative_humidity_850hPa, member)),
                      let rh700 = await inMemory.get(.init(.relative_humidity_700hPa, member)),
                      let rh500 = await inMemory.get(.init(.relative_humidity_500hPa, member)),
                      let rh300 = await inMemory.get(.init(.relative_humidity_300hPa, member)),
                      let rh250 = await inMemory.get(.init(.relative_humidity_250hPa, member)),
                      let rh200 = await inMemory.get(.init(.relative_humidity_200hPa, member)),
                      let rh50 = await inMemory.get(.init(.relative_humidity_50hPa, member)) else {
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
                let fnCloudCoverLow = try writer.writeTemporary(compressionType: .p4nzdec256, scalefactor: 1, all: cloudcoverLow)
                let fnCloudCoverMid = try writer.writeTemporary(compressionType: .p4nzdec256, scalefactor: 1, all: cloudcoverMid)
                let fnCloudCoverHigh = try writer.writeTemporary(compressionType: .p4nzdec256, scalefactor: 1, all: cloudcoverHigh)
                let cloudcover = Meteorology.cloudCoverTotal(low: cloudcoverLow, mid: cloudcoverMid, high: cloudcoverHigh)
                let fnCloudCover = try writer.writeTemporary(compressionType: .p4nzdec256, scalefactor: 1, all: cloudcover)
                
                handles.append(GenericVariableHandle(
                    variable: EcmwfVariable.cloud_cover_low,
                    time: timestamp,
                    member: member,
                    fn: fnCloudCoverLow,
                    skipHour0: false
                ))
                handles.append(GenericVariableHandle(
                    variable: EcmwfVariable.cloud_cover_mid,
                    time: timestamp,
                    member: member,
                    fn: fnCloudCoverMid,
                    skipHour0: false
                ))
                handles.append(GenericVariableHandle(
                    variable: EcmwfVariable.cloud_cover_high,
                    time: timestamp,
                    member: member,
                    fn: fnCloudCoverHigh,
                    skipHour0: false
                ))
                handles.append(GenericVariableHandle(
                    variable: EcmwfVariable.cloud_cover,
                    time: timestamp,
                    member: member,
                    fn: fnCloudCover,
                    skipHour0: false
                ))
            }
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
        case .ifs04_ensemble, .ifs025_ensemble:
            fallthrough
        case .ifs04,. ifs025:
            // ECMWF has a delay of 7-8 hours after initialisation
            return twoHoursAgo.with(hour: ((t.hour - 7 + 24) % 24) / 6 * 6)
        case .aifs025:
            // AIFS025 has a delay of 6-7 hours after initialisation
            return twoHoursAgo.with(hour: ((t.hour - 6 + 24) % 24) / 6 * 6)
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
        case .ifs04_ensemble:
            return "\(base)\(dateStr)/\(runStr)z/ifs/0p4-beta/enfo/\(dateStr)\(runStr)0000-\(hour)h-enfo-ef.grib2"
        case .ifs025:
            let product = run.hour == 0 || run.hour == 12 ? "oper" : "scda"
            return "\(base)\(dateStr)/\(runStr)z/ifs/0p25/\(product)/\(dateStr)\(runStr)0000-\(hour)h-\(product)-fc.grib2"
        case .ifs025_ensemble:
            return "\(base)\(dateStr)/\(runStr)z/ifs/0p25/enfo/\(dateStr)\(runStr)0000-\(hour)h-enfo-ef.grib2"
        case .aifs025:
            let product = "oper"// run.hour == 0 || run.hour == 12 ? "oper" : "scda"
            return "\(base)\(dateStr)/\(runStr)z/aifs/0p25/\(product)/\(dateStr)\(runStr)0000-\(hour)h-\(product)-fc.grib2"
        }
    }
}
