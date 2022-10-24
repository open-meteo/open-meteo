import Foundation
import Vapor
import SwiftPFor2D
import SwiftEccodes

/**
Meteofrance Arome, Arpge downloader
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
        
        @Flag(name: "skip-existing")
        var skipExisting: Bool
        
        @Flag(name: "create-netcdf")
        var createNetcdf: Bool
        
        @Option(name: "only-variables")
        var onlyVariables: String?
        
        @Flag(name: "upper-level", help: "Download upper-level variables on pressure levels")
        var upperLevel: Bool
    }
    
    var help: String {
        "Download MeteoFrance models"
    }
    
    func run(using context: CommandContext, signature: Signature) async throws {
        let start = DispatchTime.now()
        let logger = context.application.logger
        guard let domain = JmaDomain.init(rawValue: signature.domain) else {
            fatalError("Invalid domain '\(signature.domain)'")
        }
        let run = signature.run.map {
            guard let run = Int($0) else {
                fatalError("Invalid run '\($0)'")
            }
            return run
        } ?? domain.lastRun
        
        guard let server = signature.server else {
            fatalError("Parameter server required")
        }
        
        /*let onlyVariables: [MeteoFranceVariableDownloadable]? = signature.onlyVariables.map {
            $0.split(separator: ",").map {
                if let variable = MeteoFrancePressureVariable(rawValue: String($0)) {
                    return variable
                }
                guard let variable = MeteoFranceSurfaceVariable(rawValue: String($0)) else {
                    fatalError("Invalid variable '\($0)'")
                }
                return variable
            }
        }
        
        let pressureVariables = domain.levels.reversed().flatMap { level in
            MeteoFrancePressureVariableType.allCases.compactMap { variable -> MeteoFrancePressureVariable? in
                if variable == .cloudcover && level < 100 {
                    return nil
                }
                return MeteoFrancePressureVariable(variable: variable, level: level)
            }
        }
        let surfaceVariables = MeteoFranceSurfaceVariable.allCases
        
        let variablesAll = onlyVariables ?? (signature.upperLevel ? pressureVariables : surfaceVariables)
        
        let variables = variablesAll.filter({ $0.availableFor(domain: domain) })*/
        
        let date = Timestamp.now().add(-24*3600 * (signature.pastDays ?? 0)).with(hour: run)
        
        logger.info("Downloading domain '\(domain.rawValue)' run '\(date.iso8601_YYYY_MM_dd_HH_mm)'")
        
        try FileManager.default.createDirectory(atPath: domain.downloadDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(atPath: domain.omfileDirectory, withIntermediateDirectories: true)
        
        //try await downloadElevation(application: context.application, domain: domain)
        try await download(application: context.application, domain: domain, run: date, server: server, skipFilesIfExisting: signature.skipExisting)
        //try convert(logger: logger, domain: domain, variables: variables, run: date, createNetcdf: signature.createNetcdf)
        logger.info("Finished in \(start.timeElapsedPretty())")
    }
    
    /// download MeteoFrance
    func download(application: Application, domain: JmaDomain, run: Timestamp, server: String, skipFilesIfExisting: Bool) async throws {
        let logger = application.logger
        let curl = Curl(logger: logger, deadLineHours: 4)
        
        let writer = OmFileWriter(dim0: 1, dim1: domain.grid.count, chunk0: 1, chunk1: 8*1024)
        
        var grib2d = GribArray2D(nx: domain.grid.nx, ny: domain.grid.ny)
        
        let runDate = run.toComponents()
        let server = server.replacingOccurrences(of: "YYYY", with: runDate.year.zeroPadded(len: 4))
            .replacingOccurrences(of: "MM", with: runDate.month.zeroPadded(len: 2))
            .replacingOccurrences(of: "DD", with: runDate.day.zeroPadded(len: 2))
        
        for hour in domain.forecastHours(run: run.hour) {
            let filename = "Z__C_RJTD_\(run.format_YYYYMMddHH)0000_GSM_GPV_Rgl_FD\((hour/24).zeroPadded(len: 2))\((hour%24).zeroPadded(len: 2))_grib2.bin"
            for message in try await curl.downloadGrib(url: "\(server)\(filename)", client: application.http.client.shared).messages {
                guard let variable = message.toJmaVariable() else {
                    continue
                }
                try grib2d.load(message: message)
                if domain.isGlobal {
                    grib2d.array.shift180LongitudeAndFlipLatitude()
                } else {
                    grib2d.array.flipLatitude()
                }
                
                // Scaling before compression with scalefactor
                /*if let fma = variable.multiplyAdd {
                    grib2d.array.data.multiplyAdd(multiply: fma.multiply, add: fma.add)
                }*/
                
                //try data.writeNetcdf(filename: "\(domain.downloadDirectory)\(variable.variable.omFileName)_\(variable.hour).nc")
                let file = "\(domain.downloadDirectory)\(variable.omFileName)_\(hour).om"
                try FileManager.default.removeItemIfExists(at: file)
                
                logger.info("Compressing and writing data to \(variable.omFileName)_\(hour).om")
                //let compression = variable.isAveragedOverForecastTime || variable.isAccumulatedSinceModelStart ? CompressionType.fpxdec32 : .p4nzdec256
                try writer.write(file: file, compressionType: .p4nzdec256, scalefactor: variable.scalefactor, all: grib2d.array.data)
            }
            
        }
    }
}

extension GribMessage {
    func toJmaVariable() -> GenericVariable? {
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
        case "t": return JmaPressureVariable(variable: .temperature, level: level)
        case "w": return JmaPressureVariable(variable: .vertical_velocity, level: level)
        case "r": return JmaPressureVariable(variable: .relativehumidity, level: level)
        default: return nil
        }
    }
}

enum JmaSurfaceVariable: String, CaseIterable, Codable, GenericVariableMixing {
    case temperature_2m
    case cloudcover
    case cloudcover_low
    case cloudcover_mid
    case cloudcover_high
    case pressure_msl
    case relativehumidity_2m
    
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
        }
    }
    
    var interpolation: ReaderInterpolation {
        switch self {
        case .temperature_2m:
            return .hermite(bounds: nil)
        case .cloudcover:
            return .hermite(bounds: 0...10)
        case .cloudcover_low:
            return .hermite(bounds: 0...10)
        case .cloudcover_mid:
            return .hermite(bounds: 0...10)
        case .cloudcover_high:
            return .hermite(bounds: 0...10)
        case .pressure_msl:
            return .hermite(bounds: nil)
        case .relativehumidity_2m:
            return .hermite(bounds: 0...10)
        case .wind_v_component_10m:
            return .hermite(bounds: nil)
        case .wind_u_component_10m:
            return .hermite(bounds: nil)
        case .precipitation:
            return .linear
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
        }
    }
    
    var isElevationCorrectable: Bool {
        return self == .temperature_2m
    }
    
    var requiresOffsetCorrectionForMixing: Bool {
        return false
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
struct JmaPressureVariable: PressureVariableRespresentable, GenericVariableMixing, Hashable {
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
        return "\(OpenMeteo.dataDictionary)\(rawValue)/"
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
    
    var elevationFile: OmFileReader? {
        switch self {
        case .gsm:
            return Self.gsmElevationFile
        case .msm:
            return Self.msmElevationFile
        }
    }
    
    /// Based on the current time , guess the current run that should be available soon on the open-data server
    var lastRun: Int {
        let t = Timestamp.now()
        // Delay of 3:40 hours after initialisation. Cronjobs starts at 3:00 (arpege) or 2:00 (arome)
        return ((t.hour - 2 + 24) % 24) / 6 * 6
    }
    
    /// Filename of the surface elevation file
    var surfaceElevationFileOm: String {
        "\(omfileDirectory)HSURF.om"
    }
    
    func forecastHours(run: Int) -> [Int] {
        switch self {
        case .gsm:
            return Array(stride(from: 0, through: 264, by: 6))
        case .msm:
            //let through = run == 00 || run == 12 ? 42 : 36
            return Array(stride(from: 0, through: 39, by: 1))
        }
    }
    
    /// pressure levels
    /*var levels: [Int] {
        switch self {
        case .arpege_europe:
            return [                    100,      150, 175, 200, 225, 250, 275, 300, 350, 400, 450, 500, 550, 600, 650, 700, 750, 800, 850, 900, 925, 950, 1000]
        case .arpege_world:
            return [10, 20, 30, 50, 70, 100,      150, 175, 200, 225, 250, 275, 300, 350, 400, 450, 500, 550, 600, 650, 700, 750, 800, 850, 900, 925, 950, 1000]
        case .arome_france:
            return [                    100, 125, 150, 175, 200, 225, 250, 275, 300, 350, 400, 450, 500, 550, 600, 650, 700, 750, 800, 850, 900, 925, 950, 1000]
        case .arome_france_hd:
            return []
        }
    }
    
    /// All levels available in the API
    static var apiLevels: [Int] {
        return [10, 20, 30, 50, 70, 100, 125, 150, 175, 200, 225, 250, 275, 300, 350, 400, 450, 500, 550, 600, 650, 700, 750, 800, 850, 900, 925, 950, 1000]
    }*/
    
    var omFileLength: Int {
        switch self {
        case .gsm:
            return 110
        case .msm:
            return 48+18
        }
    }
    
    var grid: Gridable {
        switch self {
        case .gsm:
            return RegularGrid(nx: 720, ny: 361, latMin: -90, lonMin: -180, dx: 0.5, dy: 0.5)
        case .msm:
            return RegularGrid(nx: 801, ny: 601, latMin: 22.4, lonMin: 120, dx: 0.025, dy: 0.05)
        }
    }
}
