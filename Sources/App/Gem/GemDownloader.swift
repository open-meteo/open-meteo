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
 - Regional

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
        
        let variables: [GemVariableDownloadable] = GemSurfaceVariable.allCases + domain.levels.flatMap {
            level in GemPressureVariableType.allCases.compactMap { variable in
                return GemPressureVariable(variable: variable, level: level)
            }
        }
        
        logger.info("Downloading domain '\(domain.rawValue)' run '\(run.iso8601_YYYY_MM_dd_HH_mm)'")
        
        try FileManager.default.createDirectory(atPath: domain.downloadDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(atPath: domain.omfileDirectory, withIntermediateDirectories: true)
        
        //try await downloadElevation(application: context.application, domain: domain)
        try await download(application: context.application, domain: domain, variables: variables, run: run, skipFilesIfExisting: signature.skipExisting)
        try convert(logger: logger, domain: domain, variables: variables, run: run, createNetcdf: signature.createNetcdf)
        logger.info("Finished in \(start.timeElapsedPretty())")
    }
    
    /// Download data and store as compressed files for each timestep
    func download(application: Application, domain: GemDomain, variables: [GemVariableDownloadable], run: Timestamp, skipFilesIfExisting: Bool) async throws {
        let logger = application.logger
        let curl = Curl(logger: logger, deadLineHours: 3)
        let downloadDirectory = domain.downloadDirectory
        
        let writer = OmFileWriter(dim0: 1, dim1: domain.grid.count, chunk0: 1, chunk1: 8*1024)
        
        var grib2d = GribArray2D(nx: domain.grid.nx, ny: domain.grid.ny)
        
        let server = "https://hpfx.collab.science.gc.ca/\(run.format_YYYYMMdd)/WXO-DD/model_gem_global/15km/grib2/lat_lon/\(run.hh)/"
        
        let forecastHours = domain.forecastHours
        for hour in forecastHours {
            logger.info("Downloading hour \(hour)")
            let h3 = hour.zeroPadded(len: 3)
            let yyyymmddhh = run.format_YYYYMMddHH
            for variable in variables {
                if hour == 0 && variable.skipHour0 {
                    continue
                }
                let filenameDest = "\(downloadDirectory)\(variable.omFileName)_\(h3).om"
                if skipFilesIfExisting && FileManager.default.fileExists(atPath: filenameDest) {
                    continue
                }
                /// 003/CMC_glb_CIN_SFC_0_latlon.15x.15_2022112100_P003.grib2
                let url = "\(server)\(h3)/CMC_glb_\(variable.gribName)_latlon.15x.15_\(yyyymmddhh)_P\(h3).grib2"
                for message in try await curl.downloadGrib(url: url, client: application.dedicatedHttpClient).messages {
                    try grib2d.load(message: message)
                    grib2d.array.flipLatitude()
                    
                    try FileManager.default.removeItemIfExists(at: filenameDest)
                    // Scaling before compression with scalefactor
                    if let fma = variable.multiplyAdd {
                        grib2d.array.data.multiplyAdd(multiply: fma.multiply, add: fma.add)
                    }
                    let compression = variable.isAccumulatedSinceModelStart ? CompressionType.fpxdec32 : .p4nzdec256
                    try writer.write(file: filenameDest, compressionType: compression, scalefactor: variable.scalefactor, all: grib2d.array.data)
                }
            }
        }
    }
    
    /// Process each variable and update time-series optimised files
    func convert(logger: Logger, domain: GemDomain, variables: [GemVariableDownloadable], run: Timestamp, createNetcdf: Bool) throws {
        let om = OmFileSplitter(basePath: domain.omfileDirectory, nLocations: domain.grid.count, nTimePerFile: domain.omFileLength, yearlyArchivePath: nil)
        let forecastHours = domain.forecastHours
        let nForecastHours = forecastHours.max()! / domain.dtHours + 1
        
        let grid = domain.grid
        let nLocation = grid.count
        
        for variable in variables {
            let startConvert = DispatchTime.now()
            
            logger.info("Converting \(variable)")
            
            var data2d = Array2DFastTime(nLocations: nLocation, nTime: nForecastHours)

            for forecastHour in forecastHours {
                if forecastHour == 0 && variable.skipHour0 {
                    continue
                }
                let file = "\(domain.downloadDirectory)\(variable.omFileName)_\(forecastHour).om"
                data2d[0..<nLocation, forecastHour / domain.dtHours] = try OmFileReader(file: file).readAll()
            }
            
            let skip = variable.skipHour0 ? 1 : 0
            
            let time = run.timeIntervalSince1970 / domain.dtSeconds ..< run.timeIntervalSince1970 / domain.dtSeconds + nForecastHours
            
            if createNetcdf {
                try data2d.transpose().writeNetcdf(filename: "\(domain.downloadDirectory)\(variable.omFileName).nc", nx: grid.nx, ny: grid.ny)
            }
            
            logger.info("Reading and interpolation done in \(startConvert.timeElapsedPretty()). Starting om file update")
            let startOm = DispatchTime.now()
            try om.updateFromTimeOriented(variable: variable.omFileName, array2d: data2d, ringtime: time, skipFirst: skip, smooth: 0, skipLast: 0, scalefactor: variable.scalefactor)
            logger.info("Update om finished in \(startOm.timeElapsedPretty())")
        }
    }
}

protocol GemVariableDownloadable: GenericVariable {
    var multiplyAdd: (multiply: Float, add: Float)? { get }
    var skipHour0: Bool { get }
    var gribName: String { get }
    var isAccumulatedSinceModelStart: Bool { get }
}

/**
 ABSV
 CWAT
 
 */
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
    case windgusts
    
    case convective_precipitation
    
    case snowfall_water_equivalent
    
    case soil_temperature_0_to_10cm
    case soil_moisture_0_to_10cm
    
    
    /// accumulated since forecast start `kg m-2 sec-1`
    case precipitation
    
    case cape
    
    //case cin
    
    //case lifted_index
    
    var gribName: String {
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
        case .convective_precipitation:
            return "ACPCP_SFC_0"
        case .cloudcover:
            return "TCDC_SFC_0"
        case .pressure_msl:
            return "PRMSL_MSL_0"
        case .shortwave_radiation:
            return "DSWRF_SFC_0"
        case .windgusts:
            return "GUST_TGL_10"
        case .precipitation:
            return "APCP_SFC_0"
        case .snowfall_water_equivalent:
            return "WEASN_SFC_0"
        case .cape:
            return "CAPE_SFC_0"
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
    
    var isAccumulatedSinceModelStart: Bool {
        switch self {
        case .shortwave_radiation:
            fallthrough
        case .precipitation:
            fallthrough
        case .convective_precipitation:
            fallthrough
        case .snowfall_water_equivalent:
            return true
        default:
            return false
        }
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
            return 10
        case .winddirection_40m:
            return 1
        case .windspeed_80m:
            return 10
        case .winddirection_80m:
            return 1
        case .windspeed_120m:
            return 10
        case .winddirection_120m:
            return 1
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
        case .windgusts:
            return 10
        case .convective_precipitation:
            return 10
        case .snowfall_water_equivalent:
            return 10
        case .cape:
            return 0.1
        }
    }
    
    
    var multiplyAdd: (multiply: Float, add: Float)? {
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
            return (0, 1/3600) // joules to watt
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
        case .windgusts:
            return .hermite(bounds: nil)
        case .convective_precipitation:
            return .linear
        case .snowfall_water_equivalent:
            return .linear
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
        case .windgusts:
            return .ms
        case .convective_precipitation:
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
        case .convective_precipitation: return true
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
    var gribName: String {
        let isbl = "ISBL_\(level)"
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
    
    var scalefactor: Float {
        // Upper level data are more dynamic and that is bad for compression. Use lower scalefactors
        switch variable {
        case .temperature:
            // Use scalefactor of 2 for everything higher than 300 hPa
            return (2..<10).interpolated(atFraction: (300..<1000).fraction(of: Float(level)))
        case .dewpoint_depression:
            return (2..<10).interpolated(atFraction: (300..<1000).fraction(of: Float(level)))
        case.winddirection:
            return (0.2..<1).interpolated(atFraction: (500..<1000).fraction(of: Float(level)))
        case .windspeed:
            // Use scalefactor 3 for levels higher than 500 hPa.
            return (3..<10).interpolated(atFraction: (500..<1000).fraction(of: Float(level)))
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
    
    var multiplyAdd: (multiply: Float, add: Float)? {
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
    //case highres
    
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

    private static var gsmElevationFile = try? OmFileReader(file: Self.gem_global.surfaceElevationFileOm)
    private static var msmElevationFile = try? OmFileReader(file: Self.gem_regional.surfaceElevationFileOm)
    
    var elevationFile: OmFileReader? {
        switch self {
        case .gem_global:
            return Self.gsmElevationFile
        case .gem_regional:
            return Self.msmElevationFile
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
        }
    }
    
    /// pressure levels
    var levels: [Int] {
        return [1015, 1000, 985, 970, 950, 925, 900, 875, 850, 800, 750, 700, 650, 600, 550, 500, 450, 400, 350, 300, 275, 250, 225, 200, 175, 150, 100, 50, 30, 20, 10/*, 5, 1*/] // 5 and 1 not available for dewpoint
    }
    
    /// All levels available in the API
    static var apiLevels: [Int] {
        return Self.gem_global.levels
    }
    
    var omFileLength: Int {
        switch self {
        case .gem_global:
            return 110
        case .gem_regional:
            return 78+36
        }
    }
    
    var grid: Gridable {
        switch self {
        case .gem_global:
            return RegularGrid(nx: 2400, ny: 1201, latMin: -90, lonMin: -180, dx: 0.15, dy: 0.15)
        case .gem_regional:
            return RegularGrid(nx: 481, ny: 505, latMin: 22.4, lonMin: 120, dx: 0.0625, dy: 0.05)
        }
    }
}
