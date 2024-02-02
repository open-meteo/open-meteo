import Foundation
import Vapor
import SwiftPFor2D
import Dispatch
import CHelper

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

        @Option(name: "concurrent", short: "c", help: "Numer of concurrent download/conversion jobs")
        var concurrent: Int?
        
        @Flag(name: "create-netcdf")
        var createNetcdf: Bool
        
        @Option(name: "group")
        var group: String?
        
        @Option(name: "only-variables")
        var onlyVariables: String?
        
        @Option(name: "upload-s3-bucket", help: "Upload open-meteo database to an S3 bucket after processing")
        var uploadS3Bucket: String?
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
        var hsurf = try await cdo.downloadAndRemap(file)[0].getDouble().map(Float.init)
        
        
        let variableName2 = (domain == .iconD2 || domain == .iconD2Eps || domain == .iconEuEps || domain == .iconEps) ? "fr_land" : "FR_LAND"
        let file2 = "\(serverPrefix)fr_land/\(domainPrefix)_\(gridType)_time-invariant_\(dateStr)\(additionalTimeString)_\(variableName2).grib2.bz2"
        let landFraction = try await cdo.downloadAndRemap(file2)[0].getDouble().map(Float.init)
        
        //try Array2D(data: hsurf, nx: domain.grid.nx, ny: domain.grid.ny).writeNetcdf(filename: "\(downloadDirectory)hsurf.nc")
        //try Array2D(data: landFraction, nx: domain.grid.nx, ny: domain.grid.ny).writeNetcdf(filename: "\(downloadDirectory)fr_land.nc")

        // Set all sea grid points to -999
        precondition(hsurf.count == landFraction.count)
        for i in hsurf.indices {
            if landFraction[i] < 0.5 {
                hsurf[i] = -999
            }
        }
        
        try OmFileWriter(dim0: domain.grid.ny, dim1: domain.grid.nx, chunk0: 20, chunk1: 20).write(file: surfaceElevationFileOm, compressionType: .p4nzdec256, scalefactor: 1, all: hsurf)
    }
    
    
    /// Download ICON global, eu and d2 *.grid2.bz2 files
    func downloadIcon(application: Application, domain: IconDomains, run: Timestamp, variables: [IconVariableDownloadable]) async throws -> (handles: [GenericVariableHandle], handles15minIconD2: [GenericVariableHandle]) {
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
        
        // https://opendata.dwd.de/weather/nwp/icon/grib/00/t_2m/icon_global_icosahedral_single-level_2022070800_000_T_2M.grib2.bz2
        // https://opendata.dwd.de/weather/nwp/icon-eu/grib/00/t_2m/icon-eu_europe_regular-lat-lon_single-level_2022072000_000_T_2M.grib2.bz2
        let serverPrefix = "http://opendata.dwd.de/weather/nwp/\(domain.rawValue)/grib/\(run.hour.zeroPadded(len: 2))/"
        let dateStr = run.format_YYYYMMddHH

        let nMembers = domain.ensembleMembers
        let nLocationsPerChunk = OmFileSplitter(domain, nMembers: nMembers, chunknLocations: nMembers > 1 ? nMembers : nil).nLocationsPerChunk
        
        let writer = OmFileWriter(dim0: 1, dim1: domain.grid.count, chunk0: 1, chunk1: nLocationsPerChunk)
        
        var grib2d = GribArray2D(nx: domain.grid.nx, ny: domain.grid.ny)
        var handles = [GenericVariableHandle]()
        var handles15minIconD2 = [GenericVariableHandle]()
        
        /// Domain elevation field. Used to calculate sea level pressure from surface level pressure in ICON EPS and ICON EU EPS
        lazy var domainElevation = {
            guard let elevation = try? domain.getStaticFile(type: .elevation)?.readAll() else {
                fatalError("cannot read elevation for domain \(domain)")
            }
            return elevation
        }()

        let forecastSteps = domain.getDownloadForecastSteps(run: run.hour)
        for hour in forecastSteps {
            logger.info("Downloading hour \(hour)")
            let timestamp = run.add(hours: hour)
            let h3 = hour.zeroPadded(len: 3)
            
            /// Keep temperature 2m in memory if required for sea level pressure conversion
            var temperature2m = [Int: Array2D]()
            
            /// Keep precipitation in memory to correct weather codes
            var precipitation = [Int: Array2D]()
            
            for variable in variables {
                if variable.skipHour(hour: hour, domain: domain, forDownload: true, run: run) {
                    continue
                }
                guard let v = variable.getVarAndLevel(domain: domain) else {
                    continue
                }
                let level = v.level.map({"_\($0)"}) ?? (domain == .iconD2 || domain == .iconD2Eps ? "_2d" : "")
                let variableName = (domain == .iconD2 || domain == .iconD2Eps || domain == .iconEuEps || domain == .iconEps) ? v.variable : v.variable.uppercased()
                let filenameFrom = "\(domainPrefix)_\(gridType)_\(v.cat)_\(dateStr)_\(h3)\(level)_\(variableName).grib2.bz2"
                
                let url = "\(serverPrefix)\(v.variable)/\(filenameFrom)"
                
                var messages = try await cdo.downloadAndRemap(url)
                if domain == .iconD2 && messages.count > 1 {
                    // Write 15min D2 icon data
                    let downloadDirectory = IconDomains.iconD2_15min.downloadDirectory
                    try FileManager.default.createDirectory(atPath: downloadDirectory, withIntermediateDirectories: true)
                    for (i, message) in messages.enumerated() {
                        let h3 = (hour*4+i).zeroPadded(len: 3)
                        let timestamp = run.add(hour*3600 + i*900)
                        let filenameDest = "single-level_\(h3)_\(variable.omFileName.file.uppercased()).fpg"
                        try grib2d.load(message: message)
                        var data = grib2d.array.data
                        try FileManager.default.removeItemIfExists(at: "\(downloadDirectory)\(filenameDest)")
                        if let fma = variable.multiplyAdd {
                            data.multiplyAdd(multiply: fma.multiply, add: fma.add)
                        }
                        let compression = variable.isAveragedOverForecastTime || variable.isAccumulatedSinceModelStart ? CompressionType.fpxdec32 : .p4nzdec256
                        let fn = try writer.write(file: "\(downloadDirectory)\(filenameDest)", compressionType: compression, scalefactor: variable.scalefactor, all: data)
                        handles15minIconD2.append(GenericVariableHandle(
                            variable: variable,
                            time: timestamp,
                            member: 0,
                            fn: fn,
                            skipHour0: variable.skipHour(hour: 0, domain: domain, forDownload: false, run: run),
                            isAveragedOverTime: variable.isAveragedOverForecastTime,
                            isAccumulatedSinceModelStart: variable.isAccumulatedSinceModelStart
                        ))
                        try FileManager.default.removeItemIfExists(at: "\(downloadDirectory)\(filenameDest)")
                    }
                    messages = [messages[0]]
                }
                
                // Contains more than 1 message for ensemble models
                for (member, message) in messages.enumerated() {
                    try grib2d.load(message: message)
                    let memberStr = member > 0 ? "_\(member)" : ""
                    let filenameDest = "single-level_\(h3)_\(variable.omFileName.file.uppercased())\(memberStr).fpg"
                    
                    // Write data as encoded floats to disk
                    try FileManager.default.removeItemIfExists(at: "\(downloadDirectory)\(filenameDest)")
                    
                    // Scaling before compression with scalefactor
                    if let fma = variable.multiplyAdd {
                        grib2d.array.data.multiplyAdd(multiply: fma.multiply, add: fma.add)
                    }
                    
                    if let variable = variable as? IconSurfaceVariable {
                        if variable == .precipitation {
                            precipitation[member] = grib2d.array
                        }
                        if variable == .temperature_2m {
                            // store in memory for this member
                            temperature2m[member] = grib2d.array
                        }
                        if [.iconEps, .iconEuEps].contains(domain) {
                            if variable == .pressure_msl {
                                // ICON EPC is actually downloading surface level pressure
                                // calculate sea level presure using temperature and elevation
                                guard let t2m = temperature2m[member] else {
                                    fatalError("Sea level pressure calculation required temperature 2m")
                                }
                                grib2d.array.data = Meteorology.sealevelPressureSpatial(temperature: t2m.data, pressure: grib2d.array.data, elevation: domainElevation)
                            }
                        }
                        if domain == .iconEps && variable == .relative_humidity_2m {
                            // ICON EPS is using dewpoint, convert to relative humidity
                            guard let t2m = temperature2m[member] else {
                                fatalError("Relative humidity calculation requires temperature_2m")
                            }
                            grib2d.array.data.multiplyAdd(multiply: 1, add: -273.15)
                            grib2d.array.data = zip(t2m.data, grib2d.array.data).map(Meteorology.relativeHumidity)
                        }
                        // DWD ICON weather codes show rain although precipitation is 0
                        // Similar for snow at +2°C or more
                        if variable == .weather_code {
                            guard let t2m = temperature2m[member] else {
                                fatalError("Weather code correction requires temperature_2m")
                            }
                            guard let precip = precipitation[member] else {
                                fatalError("Weather code correction requires precipitation")
                            }
                            for i in grib2d.array.data.indices {
                                guard let weathercode = WeatherCode(rawValue: Int(grib2d.array.data[i])) else {
                                    continue
                                }
                                grib2d.array.data[i] = Float(weathercode.correctDwdIconWeatherCode(
                                    temperature_2m: t2m.data[i],
                                    precipitation: precip.data[i]
                                ).rawValue)
                            }
                        }
                        
                        /// Lower freezing level height below grid-cell elevation to adjust data to mixed terrain
                        /// Use temperature to esimate freezing level height below ground. This is consistent with GFS
                        /// https://github.com/open-meteo/open-meteo/issues/518#issuecomment-1827381843
                        if variable == .freezing_level_height {
                            guard let t2m = temperature2m[member] else {
                                fatalError("Freezing level height correction requires temperature_2m")
                            }
                            for i in grib2d.array.data.indices {
                                let freezingLevelHeight = grib2d.array.data[i]
                                let temperature_2m = t2m.data[i]
                                let newHeight = freezingLevelHeight - abs(-1 * temperature_2m) * 0.7 * 100
                                if newHeight <= domainElevation[i] {
                                    grib2d.array.data[i] = newHeight
                                }
                            }
                        }
                    }
                    
                    //try grib2d.array.writeNetcdf(filename: "\(downloadDirectory)\(variable.omFileName.file)\(memberStr)_\(h3).nc")
                    
                    //logger.info("Compressing and writing data to \(filenameDest)")
                    let compression = variable.isAveragedOverForecastTime || variable.isAccumulatedSinceModelStart ? CompressionType.fpxdec32 : .p4nzdec256
                    let fn = try writer.write(file: "\(downloadDirectory)\(filenameDest)", compressionType: compression, scalefactor: variable.scalefactor, all: grib2d.array.data)
                    handles.append(GenericVariableHandle(
                        variable: variable,
                        time: timestamp,
                        member: member,
                        fn: fn,
                        skipHour0: variable.skipHour(hour: 0, domain: domain, forDownload: false, run: run),
                        isAveragedOverTime: variable.isAveragedOverForecastTime,
                        isAccumulatedSinceModelStart: variable.isAccumulatedSinceModelStart
                    ))
                    try FileManager.default.removeItemIfExists(at: "\(downloadDirectory)\(filenameDest)")
                }
                // icon global downloads tend to use a lot of memory due to numerous allocations
                chelper_malloc_trim()
            }
        }
        await curl.printStatistics()
        return (handles, handles15minIconD2)
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
        
        let onlyVariables: [IconVariableDownloadable]? = try signature.onlyVariables.map {
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
        var groupVariables: [IconVariableDownloadable]
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
        
        let (handles, handles15minIconD2) = try await downloadIcon(application: context.application, domain: domain, run: run, variables: variables)
        try await GenericVariableHandle.convert(logger: logger, domain: domain, createNetcdf: signature.createNetcdf, run: run, nMembers: domain.ensembleMembers, handles: handles, concurrent: nConcurrent)
        if domain == .iconD2 {
            // ICON-D2 downloads 15min data as well
            try await GenericVariableHandle.convert(logger: logger, domain: IconDomains.iconD2_15min, createNetcdf: signature.createNetcdf, run: run, nMembers: IconDomains.iconD2_15min.ensembleMembers, handles: handles15minIconD2, concurrent: nConcurrent)
        }
        
        logger.info("Finished in \(start.timeElapsedPretty())")
        
        if let uploadS3Bucket = signature.uploadS3Bucket {
            try domain.domainRegistry.syncToS3(bucket: uploadS3Bucket, variables: variables)
            if domain == .iconD2 {
                try DomainRegistry.dwd_icon_d2_15min.syncToS3(bucket: uploadS3Bucket, variables: variables)
            }
        }
    }
}

extension IconDomains {
    /// Based on the current time , guess the current run that should be available soon on the open-data server
    fileprivate var lastRun: Timestamp {
        let t = Timestamp.now()
        switch self {
        case .iconEps:
            fallthrough
        case .icon:
            // Icon has a delay of 2-3 hours after initialisation  with 4 runs a day
            return t.with(hour: ((t.hour - 2 + 24) % 24) / 6 * 6)
        case .iconEuEps:
            fallthrough
        case .iconEu:
            // Icon-eu has a delay of 2:40 hours after initialisation with 8 runs a day
            return t.with(hour: ((t.hour - 2 + 24) % 24) / 3 * 3)
        case .iconD2Eps:
            fallthrough
        case .iconD2:
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
