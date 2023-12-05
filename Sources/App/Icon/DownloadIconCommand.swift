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

        @Flag(name: "skip-existing", help: "ONLY FOR TESTING! Do not use in production. May update the database with stale data")
        var skipExisting: Bool
        
        @Option(name: "group")
        var group: String?
        
        @Option(name: "only-variables")
        var onlyVariables: String?
    }

    var help: String {
        "Download a specified icon model run"
    }
    
    /**
     Convert surface elevation. Out of grid positions are NaN. Sea grid points are -999.
     */
    func convertSurfaceElevation(application: Application, domain: IconDomains, run: Timestamp) async throws {
        let logger = application.logger
        if FileManager.default.fileExists(atPath: domain.surfaceElevationFileOm) {
            return
        }
        
        let downloadDirectory = domain.downloadDirectory
        try FileManager.default.createDirectory(atPath: downloadDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(atPath: domain.omfileDirectory, withIntermediateDirectories: true)
        
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
        
        try OmFileWriter(dim0: domain.grid.ny, dim1: domain.grid.nx, chunk0: 20, chunk1: 20).write(file: domain.surfaceElevationFileOm, compressionType: .p4nzdec256, scalefactor: 1, all: hsurf)
    }
    
    
    /// Download ICON global, eu and d2 *.grid2.bz2 files
    func downloadIcon(application: Application, domain: IconDomains, run: Timestamp, skipFilesIfExisting: Bool, variables: [IconVariableDownloadable]) async throws {
        let logger = application.logger
        let downloadDirectory = domain.downloadDirectory
        try FileManager.default.createDirectory(atPath: downloadDirectory, withIntermediateDirectories: true)
        
        let deadLineHours: Double = (domain == .iconD2 || domain == .iconD2Eps) ? 2 : 5
        let curl = Curl(logger: logger, client: application.dedicatedHttpClient, deadLineHours: deadLineHours, waitAfterLastModified: 120)
        
        let domainPrefix = "\(domain.rawValue)_\(domain.region)"
        let cdo = try await CdoHelper(domain: domain, logger: logger, curl: curl)
        let gridType = cdo.needsRemapping ? "icosahedral" : "regular-lat-lon"
        
        // https://opendata.dwd.de/weather/nwp/icon/grib/00/t_2m/icon_global_icosahedral_single-level_2022070800_000_T_2M.grib2.bz2
        // https://opendata.dwd.de/weather/nwp/icon-eu/grib/00/t_2m/icon-eu_europe_regular-lat-lon_single-level_2022072000_000_T_2M.grib2.bz2
        let serverPrefix = "http://opendata.dwd.de/weather/nwp/\(domain.rawValue)/grib/\(run.hour.zeroPadded(len: 2))/"
        let dateStr = run.format_YYYYMMddHH

        let nMembers = domain.ensembleMembers
        let nLocationsPerChunk = OmFileSplitter(basePath: domain.omfileDirectory, nLocations: domain.grid.count, nTimePerFile: domain.omFileLength, yearlyArchivePath: nil, chunknLocations: nMembers > 1 ? nMembers : nil).nLocationsPerChunk
        
        let writer = OmFileWriter(dim0: 1, dim1: domain.grid.count, chunk0: 1, chunk1: nLocationsPerChunk)
        
        var grib2d = GribArray2D(nx: domain.grid.nx, ny: domain.grid.ny)
        
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
                
                let filenameDest = "single-level_\(h3)_\(variable.omFileName.file.uppercased()).fpg"
                if skipFilesIfExisting && FileManager.default.fileExists(atPath: "\(downloadDirectory)\(filenameDest)") {
                    continue
                }
                
                var messages = try await cdo.downloadAndRemap(url)
                if domain == .iconD2 && messages.count > 1 {
                    // Write 15min D2 icon data
                    let downloadDirectory = IconDomains.iconD2_15min.downloadDirectory
                    try FileManager.default.createDirectory(atPath: downloadDirectory, withIntermediateDirectories: true)
                    for (i, message) in messages.enumerated() {
                        let h3 = (hour*4+i).zeroPadded(len: 3)
                        let filenameDest = "single-level_\(h3)_\(variable.omFileName.file.uppercased()).fpg"
                        try grib2d.load(message: message)
                        var data = grib2d.array.data
                        try FileManager.default.removeItemIfExists(at: "\(downloadDirectory)\(filenameDest)")
                        if let fma = variable.multiplyAdd {
                            data.multiplyAdd(multiply: fma.multiply, add: fma.add)
                        }
                        let compression = variable.isAveragedOverForecastTime || variable.isAccumulatedSinceModelStart ? CompressionType.fpxdec32 : .p4nzdec256
                        try writer.write(file: "\(downloadDirectory)\(filenameDest)", compressionType: compression, scalefactor: variable.scalefactor, all: data)
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
                        if domain == .iconEps && variable == .relativehumidity_2m {
                            // ICON EPS is using dewpoint, convert to relative humidity
                            guard let t2m = temperature2m[member] else {
                                fatalError("Relative humidity calculation requires temperature_2m")
                            }
                            grib2d.array.data.multiplyAdd(multiply: 1, add: -273.15)
                            grib2d.array.data = zip(t2m.data, grib2d.array.data).map(Meteorology.relativeHumidity)
                        }
                        // DWD ICON weather codes show rain although precipitation is 0
                        // Similar for snow at +2°C or more
                        if variable == .weathercode {
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
                        if variable == .freezinglevel_height {
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
                    try writer.write(file: "\(downloadDirectory)\(filenameDest)", compressionType: compression, scalefactor: variable.scalefactor, all: grib2d.array.data)
                }
                // icon global downloads tend to use a lot of memory due to numerous allocations
                chelper_malloc_trim()
            }
        }
        curl.printStatistics()
    }

    /// unompress and remap
    /// Process variable after variable
    func convertIcon(logger: Logger, domain: IconDomains, run: Timestamp, variables: [IconVariableDownloadable]) throws {
        let downloadDirectory = domain.downloadDirectory
        let grid = domain.grid
        let nMembers = domain.ensembleMembers
        
        let forecastSteps = domain.getDownloadForecastSteps(run: run.hour)
        let nTime = forecastSteps.max()! * 3600 / domain.dtSeconds + 1
        let time = TimerangeDt(start: run, nTime: nTime, dtSeconds: domain.dtSeconds)
        let nLocations = grid.count
        
        try FileManager.default.createDirectory(atPath: domain.omfileDirectory, withIntermediateDirectories: true)
        let om = OmFileSplitter(basePath: domain.omfileDirectory, nLocations: nLocations * nMembers, nTimePerFile: domain.omFileLength, yearlyArchivePath: nil, chunknLocations: nMembers > 1 ? nMembers : nil)
        let nLocationsPerChunk = om.nLocationsPerChunk
        //print("nLocationsPerChunk \(nLocationsPerChunk)... \(nLocations/nLocationsPerChunk) iterations")

        // ICON global + eu only have 3h data after 78 hours
        // ICON global 6z and 18z have 120 instead of 180 forecast hours
        // Stategy: Read each variable in a spatial array and interpolate missing values
        // Afterwards merge into temporal data files
        
        var data3d = Array3DFastTime(nLocations: nLocationsPerChunk, nLevel: nMembers, nTime: nTime)
        var readTemp = [Float](repeating: .nan, count: nLocationsPerChunk)

        for variable in variables {
            guard variable.getVarAndLevel(domain: domain) != nil else {
                continue
            }
            let v = variable.omFileName.file.uppercased()
            let skip = variable.skipHour(hour: 0, domain: domain, forDownload: false, run: run) ? 1 : 0
            
            // For ICON-EPS, `direct radiation` only contains 3-hourly data. Remove them from `forecastSteps` for interpolation
            let forecastSteps = forecastSteps.filter({
                $0 == 0 || !variable.skipHour(hour: $0, domain: domain, forDownload: false, run: run)
            })
            
            let progress = ProgressTracker(logger: logger, total: nLocations * nMembers, label: "Convert \(variable.rawValue)")
            
            let readers: [(hour: Int, reader: [OmFileReader<MmapFile>])] = try forecastSteps.compactMap({ hour in
                if hour < skip {
                    return nil
                }
                let readers = try (0..<nMembers).map { member in
                    let memberStr = member > 0 ? "_\(member)" : ""
                    return try OmFileReader(file: "\(downloadDirectory)single-level_\(hour.zeroPadded(len: 3))_\(v)\(memberStr).fpg")
                }
                return (hour, readers)
            })
            
            try om.updateFromTimeOrientedStreaming(variable: variable.omFileName.file, indexTime: time.toIndexTime(), skipFirst: skip, smooth: 0, skipLast: 0, scalefactor: variable.scalefactor) { offset in
                let d0offset = offset / nMembers
                
                let locationRange = d0offset ..< min(d0offset+nLocationsPerChunk, nLocations)
                data3d.data.fillWithNaNs()
                for reader in readers {
                    for (i, memberReader) in reader.reader.enumerated() {
                        try memberReader.read(into: &readTemp, arrayDim1Range: 0..<locationRange.count, arrayDim1Length: locationRange.count, dim0Slow: 0..<1, dim1: locationRange)
                        data3d[0..<data3d.nLocations, i, reader.hour /*/ domain.dtHours*/] = readTemp
                    }
                }
                
                // Deaverage radiation. Not really correct for 3h data after 81 hours, but interpolation will correct in the next step.
                if variable.isAveragedOverForecastTime {
                    data3d.deavergeOverTime()
                }

                
                // De-accumulate precipitation
                if variable.isAccumulatedSinceModelStart {
                    data3d.deaccumulateOverTime()
                }
                
                // Interpolate all missing values
                // ICON-EPS ensemble model has 12-hourly values after 120 hours of forecast
                // EPS ensemble models have 6-hourly data after 2 or 3 days of forecast
                // Fill in missing hourly values after switching to 3h
                data3d.interpolateInplace(type: variable.interpolation, skipFirst: skip, time: time, grid: domain.grid, locationRange: locationRange)
                
                progress.add(locationRange.count * nMembers)
                return data3d.data[0..<locationRange.count * nTime * nMembers]
            }
            progress.finish()
        }
        //try "\(run.timeIntervalSince1970)".write(toFile: domain.initFileNameOm, atomically: true, encoding: .utf8)
    }

    func run(using context: CommandContext, signature: Signature) async throws {
        let start = DispatchTime.now()
        let domain = try IconDomains.load(rawValue: signature.domain)
        
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
        
        try await downloadIcon(application: context.application, domain: domain, run: run, skipFilesIfExisting: signature.skipExisting, variables: variables)
        try convertIcon(logger: logger, domain: domain, run: run, variables: variables)
        if domain == .iconD2 {
            // ICON-D2 download 15min data as well
            try convertIcon(logger: logger, domain: .iconD2_15min, run: run, variables: variables)
        }
        
        logger.info("Finished in \(start.timeElapsedPretty())")
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
