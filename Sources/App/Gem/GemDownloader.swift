import Foundation
import Vapor
import SwiftPFor2D
import SwiftEccodes

/**
Gem regional and global Downloader
 - Regional https://dd.weather.gc.ca/model_gem_regional/10km/grib2/
 - Global https://dd.weather.gc.ca/model_gem_global/15km/grib2/lat_lon/
 
 High perf server
 - Global https://hpfx.collab.science.gc.ca/20221121/WXO-DD/model_gem_global/15km/grib2/lat_lon/00/
 - Regional https://hpfx.collab.science.gc.ca/20221121/WXO-DD/model_gem_regional/10km/grib2/00/

 TODO:
 - elevation and sea mask for hrdps
 */
struct GemDownload: AsyncCommandFix {
    struct Signature: CommandSignature {
        @Argument(name: "domain")
        var domain: String
        
        @Option(name: "run")
        var run: String?
        
        @Option(name: "past-days")
        var pastDays: Int?
        
        @Flag(name: "skip-existing")
        var skipExisting: Bool
        
        @Flag(name: "create-netcdf")
        var createNetcdf: Bool
        
        @Flag(name: "upper-level", help: "Download upper-level variables on pressure levels")
        var upperLevel: Bool
        
        @Option(name: "only-variables")
        var onlyVariables: String?
    }
    
    var help: String {
        "Download Gem models"
    }
    
    func run(using context: CommandContext, signature: Signature) async throws {
        let start = DispatchTime.now()
        let logger = context.application.logger
        guard let domain = GemDomain.init(rawValue: signature.domain) else {
            fatalError("Invalid domain '\(signature.domain)'")
        }
        
        let run = signature.run.flatMap(Int.init).map { Timestamp.now().with(hour: $0) } ?? domain.lastRun
        
        let onlyVariables: [GemVariableDownloadable]? = signature.onlyVariables.map {
            $0.split(separator: ",").map {
                if let variable = GemPressureVariable(rawValue: String($0)) {
                    return variable
                }
                guard let variable = GemSurfaceVariable(rawValue: String($0)) else {
                    fatalError("Invalid variable '\($0)'")
                }
                return variable
            }
        }
        
        let variablesAll: [GemVariableDownloadable] = GemSurfaceVariable.allCases + domain.levels.flatMap {
            level in GemPressureVariableType.allCases.compactMap { variable in
                return GemPressureVariable(variable: variable, level: level)
            }
        }
        
        let variables = onlyVariables ?? variablesAll
        
        logger.info("Downloading domain '\(domain.rawValue)' run '\(run.iso8601_YYYY_MM_dd_HH_mm)'")
        
        try FileManager.default.createDirectory(atPath: domain.downloadDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(atPath: domain.omfileDirectory, withIntermediateDirectories: true)
        
        try await downloadElevation(application: context.application, domain: domain, run: run)
        try await download(application: context.application, domain: domain, variables: variables, run: run, skipFilesIfExisting: signature.skipExisting)
        try convert(logger: logger, domain: domain, variables: variables, run: run, createNetcdf: signature.createNetcdf)
        logger.info("Finished in \(start.timeElapsedPretty())")
    }
    
    // download seamask and height
    func downloadElevation(application: Application, domain: GemDomain, run: Timestamp) async throws {
        if domain == .gem_hrdps_continental {
            // HGT_SFC_0 file is missing... no idea why
            return
        }
        
        let logger = application.logger
        let surfaceElevationFileOm = domain.surfaceElevationFileOm
        if FileManager.default.fileExists(atPath: surfaceElevationFileOm) {
            return
        }
        try FileManager.default.createDirectory(atPath: domain.omfileDirectory, withIntermediateDirectories: true)
        
        logger.info("Downloading height and elevation data")
        
        let server = "https://hpfx.collab.science.gc.ca/\(run.format_YYYYMMdd)/WXO-DD/\(domain.gribFileGridResolution)/\(run.hh)/"
        
        let yyyymmddhh = run.format_YYYYMMddHH
        let hhhmm = domain == .gem_hrdps_continental ? "000-00" : "000"
        
        
        var height: Array2D? = nil
        var landmask: Array2D? = nil
        let curl = Curl(logger: logger, client: application.dedicatedHttpClient, deadLineHours: 4)
        
        var grib2d = GribArray2D(nx: domain.grid.nx, ny: domain.grid.ny)
        
        let terrainUrl = "\(server)000/CMC_\(domain.gribFileDomainName)_HGT_SFC_0_\(domain.gribFileGridName)_\(yyyymmddhh)_P\(hhhmm).grib2"
        for message in try await curl.downloadGrib(url: terrainUrl, bzip2Decode: false) {
            try grib2d.load(message: message)
            height = grib2d.array
            //try grib2d.array.writeNetcdf(filename: "\(domain.downloadDirectory)terrain.nc")
        }
        
        let landmaskUrl = "\(server)000/CMC_\(domain.gribFileDomainName)_LAND_SFC_0_\(domain.gribFileGridName)_\(yyyymmddhh)_P\(hhhmm).grib2"
        for message in try await curl.downloadGrib(url: landmaskUrl, bzip2Decode: false) {
            try grib2d.load(message: message)
            landmask = grib2d.array
            //try grib2d.array.writeNetcdf(filename: "\(domain.downloadDirectory)landmask.nc")
        }
        
        guard var height = height, let landmask = landmask else {
            fatalError("Could not download land and sea mask")
        }
        
        for i in height.data.indices {
            // landmask: 0=sea, 1=land
            height.data[i] = landmask.data[i] >= 0.5 ? height.data[i] : -999
        }
        try OmFileWriter(dim0: domain.grid.ny, dim1: domain.grid.nx, chunk0: 20, chunk1: 20).write(file: surfaceElevationFileOm, compressionType: .p4nzdec256, scalefactor: 1, all: height.data)
    }
    
    /// Download data and store as compressed files for each timestep
    func download(application: Application, domain: GemDomain, variables: [GemVariableDownloadable], run: Timestamp, skipFilesIfExisting: Bool) async throws {
        let logger = application.logger
        let curl = Curl(logger: logger, client: application.dedicatedHttpClient, deadLineHours: 4)
        let downloadDirectory = domain.downloadDirectory
        
        let nLocationsPerChunk = OmFileSplitter(basePath: domain.omfileDirectory, nLocations: domain.grid.count, nTimePerFile: domain.omFileLength, yearlyArchivePath: nil).nLocationsPerChunk
        let writer = OmFileWriter(dim0: 1, dim1: domain.grid.count, chunk0: 1, chunk1: nLocationsPerChunk)
        
        var grib2d = GribArray2D(nx: domain.grid.nx, ny: domain.grid.ny)
        
        let server = "https://hpfx.collab.science.gc.ca/\(run.format_YYYYMMdd)/WXO-DD/\(domain.gribFileGridResolution)/\(run.hh)/"
        
        let forecastHours = domain.forecastHours
        for hour in forecastHours {
            logger.info("Downloading hour \(hour)")
            let h3 = hour.zeroPadded(len: 3)
            let yyyymmddhh = run.format_YYYYMMddHH
            for variable in variables {
                if !variable.availableFor(domain: domain) {
                    continue
                }
                if hour == 0 && variable.skipHour0 {
                    continue
                }
                if !variable.includedFor(hour: hour) {
                    continue
                }
                let filenameDest = "\(downloadDirectory)\(variable.omFileName)_\(h3).om"
                if skipFilesIfExisting && FileManager.default.fileExists(atPath: filenameDest) {
                    continue
                }
                /// 003/CMC_glb_CIN_SFC_0_latlon.15x.15_2022112100_P003.grib2
                let hhhmm = domain == .gem_hrdps_continental ? "\(h3)-00" : "\(h3)"
                let gribName = variable.gribName(domain: domain)
                let url = "\(server)\(h3)/CMC_\(domain.gribFileDomainName)_\(gribName)_\(domain.gribFileGridName)_\(yyyymmddhh)_P\(hhhmm).grib2"
                for message in try await curl.downloadGrib(url: url, bzip2Decode: false) {
                    //try message.debugGrid(grid: domain.grid)
                    //fatalError()
                    try grib2d.load(message: message)
                    
                    try FileManager.default.removeItemIfExists(at: filenameDest)
                    // Scaling before compression with scalefactor
                    if let fma = variable.multiplyAdd(dtSeconds: domain.dtSeconds) {
                        grib2d.array.data.multiplyAdd(multiply: fma.multiply, add: fma.add)
                    }
                    
                    /// Correct wind direction for true north -> GEM winddirection is already true north corrected....
                    /*if let trueNorthDirection, variable.unit == .degreeDirection {
                        for i in trueNorthDirection.indices {
                            grib2d.array.data[i] = (grib2d.array.data[i] - trueNorthDirection[i] + 360).truncatingRemainder(dividingBy: 360)
                        }
                    }*/
                    
                    //try grib2d.array.writeNetcdf(filename: "\(domain.downloadDirectory)\(variable.omFileName)_\(h3).nc")
                    let compression = variable.isAccumulatedSinceModelStart ? CompressionType.fpxdec32 : .p4nzdec256
                    try writer.write(file: filenameDest, compressionType: compression, scalefactor: variable.scalefactor, all: grib2d.array.data)
                }
            }
        }
        curl.printStatistics()
    }
    
    /// Process each variable and update time-series optimised files
    func convert(logger: Logger, domain: GemDomain, variables: [GemVariableDownloadable], run: Timestamp, createNetcdf: Bool) throws {
        let downloadDirectory = domain.downloadDirectory
        let grid = domain.grid
        
        let forecastHours = domain.forecastHours
        let nTime = forecastHours.max()! / domain.dtHours + 1
        let nLocations = grid.nx * grid.ny
        
        try FileManager.default.createDirectory(atPath: domain.omfileDirectory, withIntermediateDirectories: true)
        let om = OmFileSplitter(basePath: domain.omfileDirectory, nLocations: nLocations, nTimePerFile: domain.omFileLength, yearlyArchivePath: nil)
        let nLocationsPerChunk = om.nLocationsPerChunk
        let ringtime = run.timeIntervalSince1970 / domain.dtSeconds ..< run.timeIntervalSince1970 / domain.dtSeconds + nTime
        
        var data2d = Array2DFastTime(nLocations: nLocationsPerChunk, nTime: nTime)
        var readTemp = [Float](repeating: .nan, count: nLocationsPerChunk)

        for variable in variables {
            if !variable.availableFor(domain: domain) {
                continue
            }
            let skip = variable.skipHour0 ? 1 : 0
            let progress = ProgressTracker(logger: logger, total: nLocations, label: "Convert \(variable.rawValue)")

            let readers: [(hour: Int, reader: OmFileReader<MmapFile>)] = try forecastHours.compactMap({ hour in
                if hour == 0 && variable.skipHour0 {
                    return nil
                }
                if !variable.includedFor(hour: hour) {
                    return nil
                }
                let h3 = hour.zeroPadded(len: 3)
                let reader = try OmFileReader(file: "\(downloadDirectory)\(variable.omFileName)_\(h3).om")
                try reader.willNeed()
                return (hour, reader)
            })
            
            try om.updateFromTimeOrientedStreaming(variable: variable.omFileName, ringtime: ringtime, skipFirst: skip, smooth: 0, skipLast: 0, scalefactor: variable.scalefactor) { d0offset in
                
                let locationRange = d0offset ..< min(d0offset+nLocationsPerChunk, nLocations)
                data2d.data.fillWithNaNs()
                for reader in readers {
                    try reader.reader.read(into: &readTemp, arrayRange: 0..<locationRange.count, dim0Slow: 0..<1, dim1: locationRange)
                    data2d[0..<data2d.nLocations, reader.hour / domain.dtHours] = readTemp
                }
                
                // De-accumulate precipitation
                if variable.isAccumulatedSinceModelStart {
                    data2d.deaccumulateOverTime(slidingWidth: data2d.nTime, slidingOffset: 1)
                }
                
                progress.add(locationRange.count)
                return data2d.data[0..<locationRange.count * nTime]
            }
            progress.finish()
        }
    }
}

protocol GemVariableDownloadable: GenericVariable {
    func multiplyAdd(dtSeconds: Int) -> (multiply: Float, add: Float)?
    var skipHour0: Bool { get }
    func includedFor(hour: Int) -> Bool
    func gribName(domain: GemDomain) -> String
    var isAccumulatedSinceModelStart: Bool { get }
    func availableFor(domain: GemDomain) -> Bool
}

enum GemSurfaceVariable: String, CaseIterable, Codable, GemVariableDownloadable, GenericVariableMixable {
    case temperature_2m
    case temperature_40m
    case temperature_80m
    case temperature_120m
    case dewpoint_2m
    case cloudcover
    case pressure_msl
    
    case shortwave_radiation
    
    case windspeed_10m
    case winddirection_10m
    case windspeed_40m
    case winddirection_40m
    case windspeed_80m
    case winddirection_80m
    case windspeed_120m
    case winddirection_120m
    
    /// there is also min/max
    case windgusts_10m
    
    case showers
    
    case snowfall_water_equivalent
    
    case soil_temperature_0_to_10cm
    case soil_moisture_0_to_10cm
    
    
    /// accumulated since forecast start `kg m-2 sec-1`
    case precipitation
    
    case cape
    
    //case cin
    
    //case lifted_index
    
    func gribName(domain: GemDomain) -> String {
        switch self {
        case .temperature_2m:
            return "TMP_TGL_2"
        case .temperature_40m:
            return "TMP_TGL_40"
        case .temperature_80m:
            return "TMP_TGL_80"
        case .temperature_120m:
            return "TMP_TGL_120"
        case .windspeed_10m:
            return "WIND_TGL_10"
        case.winddirection_10m:
            return "WDIR_TGL_10"
        case .windspeed_40m:
            return "WIND_TGL_40"
        case .winddirection_40m:
            return "WDIR_TGL_40"
        case .windspeed_80m:
            return "WIND_TGL_80"
        case.winddirection_80m:
            return "WDIR_TGL_80"
        case .windspeed_120m:
            return "WIND_TGL_120"
        case.winddirection_120m:
            return "WDIR_TGL_120"
        case .dewpoint_2m:
            return "DPT_TGL_2"
        case .showers:
            return "ACPCP_SFC_0"
        case .cloudcover:
            return "TCDC_SFC_0"
        case .pressure_msl:
            return "PRMSL_MSL_0"
        case .shortwave_radiation:
            return "DSWRF_SFC_0"
        case .windgusts_10m:
            return "GUST_TGL_10"
        case .precipitation:
            return "APCP_SFC_0"
        case .snowfall_water_equivalent:
            return "WEASN_SFC_0"
        case .cape:
            return domain == .gem_hrdps_continental ? "CAPE_ETAL_10000" : "CAPE_SFC_0"
        //case .cin:
        //    return "CIN_SFC_0"
        //case .lifted_index:
        //    return "4LFTX_SFC_0"
        case .soil_temperature_0_to_10cm:
            return "TSOIL_SFC_0"
        case .soil_moisture_0_to_10cm:
            return "SOILW_DBLY_10"
        }
    }
    
    func includedFor(hour: Int) -> Bool {
        if self == .cape && hour >= 171 {
            return false
        }
        return true
    }
    
    var isAccumulatedSinceModelStart: Bool {
        switch self {
        case .shortwave_radiation:
            fallthrough
        case .precipitation:
            fallthrough
        case .showers:
            fallthrough
        case .snowfall_water_equivalent:
            return true
        default:
            return false
        }
    }
    
    func availableFor(domain: GemDomain) -> Bool {
        if domain == .gem_hrdps_continental {
            if self == .showers {
                return false
            }
        }
        return true
    }
    
    var omFileName: String {
        return rawValue
    }
    
    var scalefactor: Float {
        switch self {
        case .temperature_2m:
            return 20
        case .cloudcover:
            return 1
        case .precipitation:
            return 10
        case .pressure_msl:
            return 10
        case .windspeed_10m:
            return 10
        case .winddirection_10m:
            return 1
        case .windspeed_40m:
            return 8
        case .winddirection_40m:
            return 0.5
        case .windspeed_80m:
            return 8
        case .winddirection_80m:
            return 0.5
        case .windspeed_120m:
            return 8
        case .winddirection_120m:
            return 0.5
        case .soil_temperature_0_to_10cm:
            return 20
        case .soil_moisture_0_to_10cm:
            return 1000
        case .shortwave_radiation:
            return 1
        case .temperature_40m:
            return 20
        case .temperature_80m:
            return 20
        case .temperature_120m:
            return 20
        case .dewpoint_2m:
            return 20
        case .windgusts_10m:
            return 10
        case .showers:
            return 10
        case .snowfall_water_equivalent:
            return 10
        case .cape:
            return 0.1
        }
    }
    
    
    func multiplyAdd(dtSeconds: Int) -> (multiply: Float, add: Float)? {
        switch self {
        case .temperature_2m:
            fallthrough
        case .temperature_40m:
            fallthrough
        case .temperature_80m:
            fallthrough
        case .temperature_120m:
            fallthrough
        case .dewpoint_2m:
            fallthrough
        case .soil_temperature_0_to_10cm:
            return (1, -273.15)
        case .pressure_msl:
            return (1/100, 0)
        case .shortwave_radiation:
            return (1/Float(dtSeconds), 0) // joules to watt
        default:
            return nil
        }
    }
    
    var interpolation: ReaderInterpolation {
        switch self {
        case .temperature_2m:
            return .hermite(bounds: nil)
        case .cloudcover:
            return .hermite(bounds: 0...100)
        case .pressure_msl:
            return .hermite(bounds: nil)
        case .precipitation:
            return .linear
        case .shortwave_radiation:
            return .solar_backwards_averaged
        case .temperature_40m:
            return .hermite(bounds: nil)
        case .temperature_80m:
            return .hermite(bounds: nil)
        case .temperature_120m:
            return .hermite(bounds: nil)
        case .dewpoint_2m:
            return .hermite(bounds: nil)
        case .windspeed_10m:
            return .hermite(bounds: nil)
        case .winddirection_10m:
            return .hermite(bounds: 0...360)
        case .windspeed_40m:
            return .hermite(bounds: nil)
        case .winddirection_40m:
            return .hermite(bounds: 0...360)
        case .windspeed_80m:
            return .hermite(bounds: nil)
        case .winddirection_80m:
            return .hermite(bounds: 0...360)
        case .windspeed_120m:
            return .hermite(bounds: nil)
        case .winddirection_120m:
            return .hermite(bounds: 0...360)
        case .windgusts_10m:
            return .hermite(bounds: nil)
        case .showers:
            return .backwards_sum
        case .snowfall_water_equivalent:
            return .backwards_sum
        case .soil_temperature_0_to_10cm:
            return .hermite(bounds: nil)
        case .soil_moisture_0_to_10cm:
            return .hermite(bounds: nil)
        case .cape:
            return .hermite(bounds: 0...10e9)
        }
    }
    
    var unit: SiUnit {
        switch self {
        case .temperature_2m:
            return .celsius
        case .cloudcover:
            return .percent
        case .precipitation:
            return .millimeter
        case .pressure_msl:
            return .hectoPascal
        case .shortwave_radiation:
            return .wattPerSquareMeter
        case .temperature_40m:
            return .celsius
        case .temperature_80m:
            return .celsius
        case .temperature_120m:
            return .celsius
        case .dewpoint_2m:
            return .celsius
        case .windspeed_10m:
            return .ms
        case .winddirection_10m:
            return .degreeDirection
        case .windspeed_40m:
            return .ms
        case .winddirection_40m:
            return .degreeDirection
        case .windspeed_80m:
            return .ms
        case .winddirection_80m:
            return .degreeDirection
        case .windspeed_120m:
            return .ms
        case .winddirection_120m:
            return .degreeDirection
        case .windgusts_10m:
            return .ms
        case .showers:
            return .millimeter
        case .snowfall_water_equivalent:
            return .millimeter
        case .soil_temperature_0_to_10cm:
            return .celsius
        case .soil_moisture_0_to_10cm:
            return .qubicMeterPerQubicMeter
        case .cape:
            return .joulesPerKilogram
        }
    }
    
    var isElevationCorrectable: Bool {
        return self == .temperature_2m
    }
    
    var requiresOffsetCorrectionForMixing: Bool {
        return self == .soil_moisture_0_to_10cm
    }
    
    var skipHour0: Bool {
        switch self {
        case .precipitation: return true
        case .showers: return true
        case .snowfall_water_equivalent: return true
        case .shortwave_radiation: return true
        default: return false
        }
    }
}

/**
 Types of pressure level variables
 */
enum GemPressureVariableType: String, CaseIterable {
    case temperature
    case windspeed
    case winddirection
    case geopotential_height
    case dewpoint_depression
}


/**
 A pressure level variable on a given level in hPa / mb
 */
struct GemPressureVariable: PressureVariableRespresentable, GemVariableDownloadable, Hashable, GenericVariableMixable {
    let variable: GemPressureVariableType
    let level: Int
    
    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
    
    var omFileName: String {
        return rawValue
    }
    func gribName(domain: GemDomain) -> String {
        let isbl = domain == .gem_hrdps_continental ? "ISBL_\(level.zeroPadded(len: 4))" : "ISBL_\(level)"
        switch variable {
        case .temperature:
            return "TMP_\(isbl)"
        case .windspeed:
            return "WIND_\(isbl)"
        case .winddirection:
            return "WDIR_\(isbl)"
        case .geopotential_height:
            return "HGT_\(isbl)"
        case .dewpoint_depression:
            return "DEPR_\(isbl)"
        }
    }
    
    func includedFor(hour: Int) -> Bool {
        if hour >= 171 && ![1000, 925, 850, 700, 500, 5, 1].contains(level) {
            return false
        }
        return true
    }
    
    func availableFor(domain: GemDomain) -> Bool {
        return true
    }
    
    var scalefactor: Float {
        // Upper level data are more dynamic and that is bad for compression. Use lower scalefactors
        switch variable {
        case .temperature:
            fallthrough
        case .dewpoint_depression:
            // Use scalefactor of 2 for everything higher than 300 hPa
            return (2..<10).interpolated(atFraction: (300..<1000).fraction(of: Float(level)))
        case.winddirection:
            return (0.2..<0.5).interpolated(atFraction: (500..<1000).fraction(of: Float(level)))
        case .windspeed:
            // Use scalefactor 3 for levels higher than 500 hPa.
            return (3..<8).interpolated(atFraction: (500..<1000).fraction(of: Float(level)))
        case .geopotential_height:
            return (0.05..<1).interpolated(atFraction: (0..<500).fraction(of: Float(level)))
        }
    }
    
    var isAccumulatedSinceModelStart: Bool {
        return false
    }
    
    var interpolation: ReaderInterpolation {
        switch variable {
        case .temperature:
            return .hermite(bounds: nil)
        case .windspeed:
            return .hermite(bounds: nil)
        case .winddirection:
            return .hermite(bounds: 0...360)
        case .geopotential_height:
            return .hermite(bounds: nil)
        case .dewpoint_depression:
            return .hermite(bounds: nil)
        }
    }
    
    func multiplyAdd(dtSeconds: Int) -> (multiply: Float, add: Float)? {
        switch variable {
        case .temperature:
            return (1, -273.15)
        //case .geopotential_height:
            // convert geopotential to height (WMO defined gravity constant)
            //return (1/9.80665, 0)
        default:
            return nil
        }
    }
    
    var unit: SiUnit {
        switch variable {
        case .temperature:
            return .celsius
        case .windspeed:
            return .ms
        case .winddirection:
            return .degreeDirection
        case .geopotential_height:
            return .meter
        case .dewpoint_depression:
            return .kelvin
        }
    }
    
    var isElevationCorrectable: Bool {
        return false
    }
    
    var skipHour0: Bool {
        return false
    }
}
/**
 Combined surface and pressure level variables with all definitions for downloading and API
 */
typealias GemVariable = SurfaceAndPressureVariable<GemSurfaceVariable, GemPressureVariable>


enum GemDomain: String, GenericDomain {
    case gem_global
    case gem_regional
    case gem_hrdps_continental
    
    var omfileDirectory: String {
        return "\(OpenMeteo.dataDictionary)omfile-\(rawValue)/"
    }
    var downloadDirectory: String {
        return "\(OpenMeteo.dataDictionary)download-\(rawValue)/"
    }
    var omfileArchive: String? {
        return nil
    }
    
    var dtSeconds: Int {
        if self == .gem_global {
            return 3*3600
        }
        return 3600
    }
    var isGlobal: Bool {
        return self == .gem_global
    }

    private static var gemGlobalElevationFile = try? OmFileReader(file: Self.gem_global.surfaceElevationFileOm)
    private static var gemRegionalElevationFile = try? OmFileReader(file: Self.gem_regional.surfaceElevationFileOm)
    private static var gemHrdpsContinentalElevationFile = try? OmFileReader(file: Self.gem_hrdps_continental.surfaceElevationFileOm)
    
    var elevationFile: OmFileReader<MmapFile>? {
        switch self {
        case .gem_global:
            return Self.gemGlobalElevationFile
        case .gem_regional:
            return Self.gemRegionalElevationFile
        case .gem_hrdps_continental:
            return Self.gemHrdpsContinentalElevationFile
        }
    }
    
    /// Based on the current time , guess the current run that should be available soon on the open-data server
    var lastRun: Timestamp {
        let t = Timestamp.now()
        switch self {
        case .gem_global:
            // First hours 3:40 h delay, second part 6.5 h delay
            // every 12 hours
            return t.add(-3*3600).floor(toNearest: 12*3600)
        case .gem_regional:
            // Delay of 2:47 hours to init
            // every 6 hours
            return t.add(-2*3600).floor(toNearest: 6*3600)
        case .gem_hrdps_continental:
            // Delay of 3:08 hours to init
            // every 6 hours
            return t.add(-2*3600).floor(toNearest: 6*3600)
        }
    }
    
    /// Filename of the surface elevation file
    var surfaceElevationFileOm: String {
        "\(omfileDirectory)HSURF.om"
    }
    
    var forecastHours: [Int] {
        switch self {
        case .gem_global:
            return Array(stride(from: 0, through: 240, by: 3))
        case .gem_regional:
            return Array(stride(from: 0, through: 84, by: 1))
        case .gem_hrdps_continental:
            return Array(stride(from: 0, through: 48, by: 1))
        }
    }
    
    /// pressure levels
    var levels: [Int] {
        return [1015, 1000, 985, 970, 950, 925, 900, 875, 850, 800, 750, 700, 650, 600, 550, 500, 450, 400, 350, 300, 275, 250, 225, 200, 175, 150, 100, 50, 30, 20, 10/*, 5, 1*/].reversed() // 5 and 1 not available for dewpoint
    }
    
    /// All levels available in the API
    static var apiLevels: [Int] {
        return Self.gem_global.levels
    }
    
    var gribFileDomainName: String {
        switch self {
        case .gem_global:
            return "glb"
        case .gem_regional:
            return "reg"
        case .gem_hrdps_continental:
            return "hrdps_continental"
        }
    }
    
    var gribFileGridName: String {
        switch self {
        case .gem_global:
            return "latlon.15x.15"
        case .gem_regional:
            return "ps10km"
        case .gem_hrdps_continental:
            return "ps2.5km"
        }
    }
    
    var gribFileGridResolution: String {
        switch self {
        case .gem_global:
            return "model_\(rawValue)/15km/grib2/lat_lon"
        case .gem_regional:
            return "model_\(rawValue)/10km/grib2"
        case .gem_hrdps_continental:
            return "model_hrdps/continental/grib2"
        }
    }
    
    var omFileLength: Int {
        switch self {
        case .gem_global:
            return 110
        case .gem_regional:
            return 78+36
        case .gem_hrdps_continental:
            return 48+36
        }
    }
    
    var grid: Gridable {
        switch self {
        case .gem_global:
            return RegularGrid(nx: 2400, ny: 1201, latMin: -90, lonMin: -180, dx: 0.15, dy: 0.15)
        case .gem_regional:
            return ProjectionGrid(nx: 935, ny: 824, latitude: 18.14503...45.405453, longitude: 217.10745...349.8256, projection: StereograpicProjection(latitude: 90, longitude: 249, radius: 6371229))
        case .gem_hrdps_continental:
            return ProjectionGrid(nx: 2576, ny: 1456, latitude: 35.603374...45.85184, longitude: -128.08255...(-43.829773), projection: StereograpicProjection(latitude: 90, longitude: 252, radius: 6371229))
        }
    }
}
