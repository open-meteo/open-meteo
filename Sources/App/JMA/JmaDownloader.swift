import Foundation
import Vapor
import SwiftPFor2D
import SwiftEccodes

/**
Jma Downloader
 
 TODO:
 - elevation download
 - 3h MSM pressue level data
 */
struct JmaDownload: AsyncCommandFix {
    struct Signature: CommandSignature {
        @Argument(name: "domain")
        var domain: String
        
        @Option(name: "server", help: "Base URL with username and password for JMA server")
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
        "Download JMA models"
    }
    
    func run(using context: CommandContext, signature: Signature) async throws {
        let start = DispatchTime.now()
        let logger = context.application.logger
        guard let domain = JmaDomain.init(rawValue: signature.domain) else {
            fatalError("Invalid domain '\(signature.domain)'")
        }
        
        let run = signature.run.flatMap(Int.init).map { Timestamp.now().with(hour: $0) } ?? domain.lastRun

        guard let server = signature.server else {
            fatalError("Parameter server required")
        }
        
        let variables: [JmaVariableDownloadable]
        switch domain {
        case .gsm:
            variables = JmaSurfaceVariable.allCases.filter({$0 != .shortwave_radiation}) + domain.levels.flatMap {
                level in JmaPressureVariableType.allCases.compactMap { variable in
                    if variable == .relativehumidity && level <= 250 {
                        return nil
                    }
                    return JmaPressureVariable(variable: variable, level: level)
                }
            }
        case .msm:
            variables = JmaSurfaceVariable.allCases
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
    func download(application: Application, domain: JmaDomain, run: Timestamp, server: String) async throws {
        let logger = application.logger
        let curl = Curl(logger: logger, client: application.dedicatedHttpClient, deadLineHours: 3)
        
        let nLocationsPerChunk = OmFileSplitter(basePath: domain.omfileDirectory, nLocations: domain.grid.count, nTimePerFile: domain.omFileLength, yearlyArchivePath: nil).nLocationsPerChunk
        let writer = OmFileWriter(dim0: 1, dim1: domain.grid.count, chunk0: 1, chunk1: nLocationsPerChunk)
        
        var grib2d = GribArray2D(nx: domain.grid.nx, ny: domain.grid.ny)
        
        let runDate = run.toComponents()
        let server = server.replacingOccurrences(of: "YYYY", with: runDate.year.zeroPadded(len: 4))
            .replacingOccurrences(of: "MM", with: runDate.month.zeroPadded(len: 2))
            .replacingOccurrences(of: "DD", with: runDate.day.zeroPadded(len: 2))
            .replacingOccurrences(of: "HH", with: run.hour.zeroPadded(len: 2))
        
        let filesToDownload: [String]
        switch domain {
        case .gsm:
            filesToDownload = domain.forecastHours(run: run.hour).map { hour in
                "Z__C_RJTD_\(run.format_YYYYMMddHH)0000_GSM_GPV_Rgl_FD\((hour/24).zeroPadded(len: 2))\((hour%24).zeroPadded(len: 2))_grib2.bin"
            }
        case .msm:
            // 0 und 12z run have more data
            let range = run.hour % 12 == 0 ? ["00-15", "16-33", "34-39", "40-51", "52-78"] : ["00-15", "16-33", "34-39"]
            filesToDownload = range.map { hour in
                "Z__C_RJTD_\(run.format_YYYYMMddHH)0000_MSM_GPV_Rjp_Lsurf_FH\(hour)_grib2.bin"
            }
        }
        
        for filename in filesToDownload {
            for message in try await curl.downloadGrib(url: "\(server)\(filename)", bzip2Decode: false) {
                guard let variable = message.toJmaVariable(),
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
        curl.printStatistics()
    }
    
    /// Process each variable and update time-series optimised files
    func convert(logger: Logger, domain: JmaDomain, variables: [JmaVariableDownloadable], run: Timestamp, createNetcdf: Bool) throws {
        let om = OmFileSplitter(basePath: domain.omfileDirectory, nLocations: domain.grid.count, nTimePerFile: domain.omFileLength, yearlyArchivePath: nil)
        let nLocationsPerChunk = om.nLocationsPerChunk
        let forecastHours = domain.forecastHours(run: run.hour)
        let nTime = forecastHours.max()! / domain.dtHours + 1
        let ringtime = run.timeIntervalSince1970 / domain.dtSeconds ..< run.timeIntervalSince1970 / domain.dtSeconds + nTime
        
        let grid = domain.grid
        let nLocations = grid.count
        
        var data2d = Array2DFastTime(nLocations: nLocationsPerChunk, nTime: nTime)
        var readTemp = [Float](repeating: .nan, count: nLocationsPerChunk)
        
        for variable in variables {
            let skip = variable.skipHour0 ? 1 : 0
            let progress = ProgressTracker(logger: logger, total: nLocations, label: "Convert \(variable.rawValue)")
            
            let readers: [(hour: Int, reader: OmFileReader<MmapFile>)] = try forecastHours.compactMap({ hour in
                if hour == 0 && variable.skipHour0 {
                    return nil
                }
                let reader = try OmFileReader(file: "\(domain.downloadDirectory)\(variable.omFileName)_\(hour).om")
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
                
                progress.add(locationRange.count)
                return data2d.data[0..<locationRange.count * nTime]
            }
            progress.finish()
        }
    }
}

protocol JmaVariableDownloadable: GenericVariable {
    var multiplyAdd: (multiply: Float, add: Float)? { get }
    var skipHour0: Bool { get }
}

extension GribMessage {
    /// Return the corresponding JMA variable for this grib message
    func toJmaVariable() -> JmaVariableDownloadable? {
        guard let shortName = get(attribute: "shortName"),
              let parameterCategory = get(attribute: "parameterCategory").flatMap(Int.init),
              let parameterNumber = get(attribute: "parameterNumber").flatMap(Int.init),
              let level = get(attribute: "level").flatMap(Int.init)
        else {
            fatalError("Could not get message parameters. Should not be possible.")
        }
        
        if ["gh", "u", "v", "t", "w", "r"].contains(shortName) && level >= 10 && level <= 70 {
            // upper level use 1° grid resolution
            return nil
        }
        
        switch shortName {
        case "prmsl": return JmaSurfaceVariable.pressure_msl
        case "sp": return nil
        case "10u": return JmaSurfaceVariable.wind_u_component_10m
        case "10v": return JmaSurfaceVariable.wind_v_component_10m
        case "2t": return JmaSurfaceVariable.temperature_2m
        case "2r": return JmaSurfaceVariable.relativehumidity_2m
        case "lcc": return JmaSurfaceVariable.cloudcover_low
        case "mcc": return JmaSurfaceVariable.cloudcover_mid
        case "hcc": return JmaSurfaceVariable.cloudcover_high
        case "dswrf": return JmaSurfaceVariable.shortwave_radiation
        case "unknown":
            if parameterCategory == 6 && parameterNumber == 1 {
                return JmaSurfaceVariable.cloudcover
            }
            if parameterCategory == 1 && parameterNumber == 8 {
                return JmaSurfaceVariable.precipitation
            }
            return nil
        case "gh": return JmaPressureVariable(variable: .geopotential_height, level: level)
        case "u": return JmaPressureVariable(variable: .wind_u_component, level: level)
        case "v": return JmaPressureVariable(variable: .wind_v_component, level: level)
        case "t":
            if level == 2 { // MSM case
                return JmaSurfaceVariable.temperature_2m
            }
            return JmaPressureVariable(variable: .temperature, level: level)
        case "w": return JmaPressureVariable(variable: .vertical_velocity, level: level)
        case "r":
            if level == 2 { // MSM case
                return JmaSurfaceVariable.relativehumidity_2m
            }
            return JmaPressureVariable(variable: .relativehumidity, level: level)
        default: return nil
        }
    }
}

enum JmaSurfaceVariable: String, CaseIterable, Codable, JmaVariableDownloadable, GenericVariableMixable {
    case temperature_2m
    case cloudcover
    case cloudcover_low
    case cloudcover_mid
    case cloudcover_high
    case pressure_msl
    case relativehumidity_2m
    
    /// not in global model
    case shortwave_radiation
    
    case wind_v_component_10m
    case wind_u_component_10m
    
    /// accumulated since forecast start
    case precipitation
    
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
enum JmaPressureVariableType: String, CaseIterable {
    case temperature
    case wind_u_component
    case wind_v_component
    case geopotential_height
    case vertical_velocity
    case relativehumidity
}


/**
 A pressure level variable on a given level in hPa / mb
 */
struct JmaPressureVariable: PressureVariableRespresentable, JmaVariableDownloadable, Hashable, GenericVariableMixable {
    let variable: JmaPressureVariableType
    let level: Int
    
    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
    
    var omFileName: String {
        return rawValue
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
typealias JmaVariable = SurfaceAndPressureVariable<JmaSurfaceVariable, JmaPressureVariable>


enum JmaDomain: String, GenericDomain {
    case gsm
    case msm
    
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
        if self == .gsm {
            return 6*3600
        }
        return 3600
    }
    var isGlobal: Bool {
        return self == .gsm
    }

    private static var gsmElevationFile = try? OmFileReader(file: Self.gsm.surfaceElevationFileOm)
    private static var msmElevationFile = try? OmFileReader(file: Self.msm.surfaceElevationFileOm)
    
    var elevationFile: OmFileReader<MmapFile>? {
        switch self {
        case .gsm:
            return Self.gsmElevationFile
        case .msm:
            return Self.msmElevationFile
        }
    }
    
    /// Based on the current time , guess the current run that should be available soon on the open-data server
    var lastRun: Timestamp {
        let t = Timestamp.now()
        switch self {
        case .gsm:
            // First hours 3.5 h delay, second part 6.5 h delay
            // every 6 hours
            return t.add(-6*3600).floor(toNearest: 6*3600)
        case .msm:
            // Delay of 2-3 hours to init
            // every 3 hours
            return t.add(-2*3600).floor(toNearest: 3*3600)
        }
    }
    
    /// Filename of the surface elevation file
    var surfaceElevationFileOm: String {
        "\(omfileDirectory)HSURF.om"
    }
    
    func forecastHours(run: Int) -> [Int] {
        switch self {
        case .gsm:
            let through = run == 00 || run == 12 ? 264 : 136
            return Array(stride(from: 0, through: through, by: 6))
        case .msm:
            let through = run == 00 || run == 12 ? 78 : 39
            return Array(stride(from: 0, through: through, by: 1))
        }
    }
    
    /// pressure levels
    var levels: [Int] {
        switch self {
        case .gsm:
            return [1000, 925, 850, 700, 500, 400, 300, 250, 200, 150, 100]
        case .msm:
            return []
        }
    }
    
    /// All levels available in the API
    static var apiLevels: [Int] {
        return Self.gsm.levels
    }
    
    var omFileLength: Int {
        switch self {
        case .gsm:
            return 110
        case .msm:
            return 78+36
        }
    }
    
    var grid: Gridable {
        switch self {
        case .gsm:
            return RegularGrid(nx: 720, ny: 361, latMin: -90, lonMin: -180, dx: 0.5, dy: 0.5)
        case .msm:
            return RegularGrid(nx: 481, ny: 505, latMin: 22.4, lonMin: 120, dx: 0.0625, dy: 0.05)
        }
    }
}
