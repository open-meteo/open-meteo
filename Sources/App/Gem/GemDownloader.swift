import Foundation
import Vapor
import SwiftPFor2D
import SwiftEccodes

/**
Gem regional and global Downloader
 - Regional https://dd.weather.gc.ca/model_gem_regional/10km/grib2/
 - Global https://dd.weather.gc.ca/model_gem_global/15km/grib2/lat_lon/

 */
struct GemDownload: AsyncCommandFix {
    struct Signature: CommandSignature {
        @Argument(name: "domain")
        var domain: String
        
        @Option(name: "server", help: "Base URL with username and password for Gem server")
        var server: String?
        
        @Option(name: "run")
        var run: String?
        
        @Option(name: "past-days")
        var pastDays: Int?
        
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

        guard let server = signature.server else {
            fatalError("Parameter server required")
        }
        
        let variables: [GemVariableDownloadable]
        switch domain {
        case .global:
            variables = GemSurfaceVariable.allCases.filter({$0 != .shortwave_radiation}) + domain.levels.flatMap {
                level in GemPressureVariableType.allCases.compactMap { variable in
                    if variable == .relativehumidity && level <= 250 {
                        return nil
                    }
                    return GemPressureVariable(variable: variable, level: level)
                }
            }
        case .regional:
            variables = GemSurfaceVariable.allCases
        }
        
        logger.info("Downloading domain '\(domain.rawValue)' run '\(run.iso8601_YYYY_MM_dd_HH_mm)'")
        
        try FileManager.default.createDirectory(atPath: domain.downloadDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(atPath: domain.omfileDirectory, withIntermediateDirectories: true)
        
        //try await downloadElevation(application: context.application, domain: domain)
        try await download(application: context.application, domain: domain, run: run, server: server)
        try convert(logger: logger, domain: domain, variables: variables, run: run, createNetcdf: signature.createNetcdf)
        logger.info("Finished in \(start.timeElapsedPretty())")
    }
    
    /// MSM or GSM domain
    func download(application: Application, domain: GemDomain, run: Timestamp, server: String) async throws {
        let logger = application.logger
        let curl = Curl(logger: logger, deadLineHours: 3)
        
        let writer = OmFileWriter(dim0: 1, dim1: domain.grid.count, chunk0: 1, chunk1: 8*1024)
        
        var grib2d = GribArray2D(nx: domain.grid.nx, ny: domain.grid.ny)
        
        let runDate = run.toComponents()
        let server = server.replacingOccurrences(of: "YYYY", with: runDate.year.zeroPadded(len: 4))
            .replacingOccurrences(of: "MM", with: runDate.month.zeroPadded(len: 2))
            .replacingOccurrences(of: "DD", with: runDate.day.zeroPadded(len: 2))
            .replacingOccurrences(of: "HH", with: run.hour.zeroPadded(len: 2))
        
        let filesToDownload: [String]
        switch domain {
        case .global:
            filesToDownload = domain.forecastHours(run: run.hour).map { hour in
                "Z__C_RJTD_\(run.format_YYYYMMddHH)0000_GSM_GPV_Rgl_FD\((hour/24).zeroPadded(len: 2))\((hour%24).zeroPadded(len: 2))_grib2.bin"
            }
        case .regional:
            // 0 und 12z run have more data
            let range = run.hour % 12 == 0 ? ["00-15", "16-33", "34-39", "40-51", "52-78"] : ["00-15", "16-33", "34-39"]
            filesToDownload = range.map { hour in
                "Z__C_RJTD_\(run.format_YYYYMMddHH)0000_MSM_GPV_Rjp_Lsurf_FH\(hour)_grib2.bin"
            }
        }
        
        for filename in filesToDownload {
            for message in try await curl.downloadGrib(url: "\(server)\(filename)", client: application.dedicatedHttpClient).messages {
                guard let variable = message.toGemVariable(),
                      let hour = message.get(attribute: "endStep").flatMap(Int.init) else {
                    continue
                }
                try grib2d.load(message: message)
                if domain.isGlobal {
                    grib2d.array.shift180LongitudeAndFlipLatitude()
                } else {
                    grib2d.array.flipLatitude()
                }
                
                // Scaling before compression with scalefactor
                if let fma = variable.multiplyAdd {
                    grib2d.array.data.multiplyAdd(multiply: fma.multiply, add: fma.add)
                }
                
                //try data.writeNetcdf(filename: "\(domain.downloadDirectory)\(variable.variable.omFileName)_\(variable.hour).nc")
                let file = "\(domain.downloadDirectory)\(variable.omFileName)_\(hour).om"
                try FileManager.default.removeItemIfExists(at: file)
                
                logger.info("Compressing and writing data to \(variable.omFileName)_\(hour).om")
                //let compression = variable.isAveragedOverForecastTime || variable.isAccumulatedSinceModelStart ? CompressionType.fpxdec32 : .p4nzdec256
                try writer.write(file: file, compressionType: .p4nzdec256, scalefactor: variable.scalefactor, all: grib2d.array.data)
            }
        }
    }
    
    /// Process each variable and update time-series optimised files
    func convert(logger: Logger, domain: GemDomain, variables: [GemVariableDownloadable], run: Timestamp, createNetcdf: Bool) throws {
        let om = OmFileSplitter(basePath: domain.omfileDirectory, nLocations: domain.grid.count, nTimePerFile: domain.omFileLength, yearlyArchivePath: nil)
        let forecastHours = domain.forecastHours(run: run.hour)
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
    
    
    /// not in global model
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
            return "ACPCP_SFC"
        case .cloudcover:
            return "TCDC_SFC_0"
        case .pressure_msl:
            return "PRMSL_MSL_0"
        case .shortwave_radiation:
            return "DSWRF_SFC_0"
        case .windgusts:
            return "GUST_TGL_10"
        case .precipitation:
            return "APCP_SFC"
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
    
    
    
    var omFileName: String {
        return rawValue
    }
    
    var scalefactor: Float {
        switch self {
        case .temperature_2m:
            return 20
        case .cloudcover:
            return 1
        case .cloudcover_low:
            return 1
        case .cloudcover_mid:
            return 1
        case .cloudcover_high:
            return 1
        case .relativehumidity_2m:
            return 1
        case .precipitation:
            return 10
        case .pressure_msl:
            return 10
        case .wind_v_component_10m:
            return 10
        case .wind_u_component_10m:
            return 10
        case .shortwave_radiation:
            return 1
        }
    }
    
    
    var multiplyAdd: (multiply: Float, add: Float)? {
        switch self {
        case .temperature_2m:
            return (1, -273.15)
        case .pressure_msl:
            return (1/100, 0)
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
        case .cloudcover_low:
            return .hermite(bounds: 0...100)
        case .cloudcover_mid:
            return .hermite(bounds: 0...100)
        case .cloudcover_high:
            return .hermite(bounds: 0...100)
        case .pressure_msl:
            return .hermite(bounds: nil)
        case .relativehumidity_2m:
            return .hermite(bounds: 0...100)
        case .wind_v_component_10m:
            return .hermite(bounds: nil)
        case .wind_u_component_10m:
            return .hermite(bounds: nil)
        case .precipitation:
            return .linear
        case .shortwave_radiation:
            return .solar_backwards_averaged
        }
    }
    
    var unit: SiUnit {
        switch self {
        case .temperature_2m:
            return .celsius
        case .cloudcover:
            return .percent
        case .cloudcover_low:
            return .percent
        case .cloudcover_mid:
            return .percent
        case .cloudcover_high:
            return .percent
        case .relativehumidity_2m:
            return .percent
        case .precipitation:
            return .millimeter
        case .pressure_msl:
            return .hectoPascal
        case .wind_v_component_10m:
            return .ms
        case .wind_u_component_10m:
            return .ms
        case .shortwave_radiation:
            return .wattPerSquareMeter
        }
    }
    
    var isElevationCorrectable: Bool {
        return self == .temperature_2m
    }
    
    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
    
    var skipHour0: Bool {
        switch self {
        case .precipitation: return true
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
        let isbl = "ISBL_\(level.zeroPadded(len: 4))"
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
        case .wind_u_component:
            fallthrough
        case .wind_v_component:
            // Use scalefactor 3 for levels higher than 500 hPa.
            return (3..<10).interpolated(atFraction: (500..<1000).fraction(of: Float(level)))
        case .geopotential_height:
            return (0.05..<1).interpolated(atFraction: (0..<500).fraction(of: Float(level)))
        case .vertical_velocity:
            return (10..<15).interpolated(atFraction: (0..<800).fraction(of: Float(level)))
        case .relativehumidity:
            return (0.2..<1).interpolated(atFraction: (0..<800).fraction(of: Float(level)))
        }
    }
    
    var interpolation: ReaderInterpolation {
        switch variable {
        case .temperature:
            return .hermite(bounds: nil)
        case .wind_u_component:
            return .hermite(bounds: nil)
        case .wind_v_component:
            return .hermite(bounds: nil)
        case .geopotential_height:
            return .hermite(bounds: nil)
        case .vertical_velocity:
            return .hermite(bounds: nil)
        case .relativehumidity:
            return .hermite(bounds: 0...100)
        }
    }
    
    var multiplyAdd: (multiply: Float, add: Float)? {
        switch variable {
        case .temperature:
            return (1, -273.15)
        case .geopotential_height:
            // convert geopotential to height (WMO defined gravity constant)
            return (1/9.80665, 0)
        default:
            return nil
        }
    }
    
    var unit: SiUnit {
        switch variable {
        case .temperature:
            return .celsius
        case .wind_u_component:
            return .ms
        case .wind_v_component:
            return .ms
        case .geopotential_height:
            return .meter
        case .vertical_velocity:
            return .ms
        case .relativehumidity:
            return .percent
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
    case global
    case regional
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
        if self == .global {
            return 3*3600
        }
        return 3600
    }
    var isGlobal: Bool {
        return self == .global
    }

    private static var gsmElevationFile = try? OmFileReader(file: Self.global.surfaceElevationFileOm)
    private static var msmElevationFile = try? OmFileReader(file: Self.regional.surfaceElevationFileOm)
    
    var elevationFile: OmFileReader? {
        switch self {
        case .global:
            return Self.gsmElevationFile
        case .regional:
            return Self.msmElevationFile
        }
    }
    
    /// Based on the current time , guess the current run that should be available soon on the open-data server
    var lastRun: Timestamp {
        let t = Timestamp.now()
        switch self {
        case .global:
            // First hours 3:40 h delay, second part 6.5 h delay
            // every 12 hours
            return t.add(-3*3600).floor(toNearest: 12*3600)
        case .regional:
            // Delay of 2:47 hours to init
            // every 6 hours
            return t.add(-2*3600).floor(toNearest: 6*3600)
        }
    }
    
    /// Filename of the surface elevation file
    var surfaceElevationFileOm: String {
        "\(omfileDirectory)HSURF.om"
    }
    
    func forecastHours(run: Int) -> [Int] {
        switch self {
        case .global:
            return Array(stride(from: 0, through: 240, by: 3))
        case .regional:
            return Array(stride(from: 0, through: 84, by: 1))
        }
    }
    
    /// pressure levels
    var levels: [Int] {
        switch self {
        case .global:
            return [1000, 925, 850, 700, 500, 400, 300, 250, 200, 150, 100]
        case .regional:
            return [1015, 1000, 985, 970, 950, 925, 900, 875, 850, 800, 750, 700, 650, 600, 550, 500, 450, 400, 350, 300, 275, 250, 225, 200, 175, 150, 100, 50, 30, 20, 10, 5, 1]
        }
    }
    
    /// All levels available in the API
    static var apiLevels: [Int] {
        return Self.global.levels
    }
    
    var omFileLength: Int {
        switch self {
        case .global:
            return 110
        case .regional:
            return 78+36
        }
    }
    
    var grid: Gridable {
        switch self {
        case .global:
            return RegularGrid(nx: 720, ny: 361, latMin: -90, lonMin: -180, dx: 0.5, dy: 0.5)
        case .regional:
            return RegularGrid(nx: 481, ny: 505, latMin: 22.4, lonMin: 120, dx: 0.0625, dy: 0.05)
        }
    }
}
