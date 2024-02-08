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
struct JmaDownload: AsyncCommand {
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
        
        @Option(name: "timeinterval", short: "t", help: "Timeinterval to download past forecasts. Format 20220101-20220131")
        var timeinterval: String?

        @Option(name: "concurrent", short: "c", help: "Numer of concurrent download/conversion jobs")
        var concurrent: Int?
        
        @Option(name: "upload-s3-bucket", help: "Upload open-meteo database to an S3 bucket after processing")
        var uploadS3Bucket: String?
    }
    
    var help: String {
        "Download JMA models"
    }
    
    func run(using context: CommandContext, signature: Signature) async throws {
        let start = DispatchTime.now()
        let logger = context.application.logger
        let domain = try JmaDomain.load(rawValue: signature.domain)
        let nConcurrent = signature.concurrent ?? 1
        guard let server = signature.server else {
            fatalError("Parameter server required")
        }
        try FileManager.default.createDirectory(atPath: domain.downloadDirectory, withIntermediateDirectories: true)
        
        if let timeinterval = signature.timeinterval {
            for run in try Timestamp.parseRange(yyyymmdd: timeinterval).toRange(dt: 86400).with(dtSeconds: 86400 / 4) {
                let handles = try await download(application: context.application, domain: domain, run: run, server: server, concurrent: nConcurrent)
                try await GenericVariableHandle.convert(logger: logger, domain: domain, createNetcdf: signature.createNetcdf, run: run, nMembers: 1, handles: handles, concurrent: nConcurrent)
            }
            return
        }
        
        let run = try signature.run.flatMap(Timestamp.fromRunHourOrYYYYMMDD) ?? domain.lastRun
        let handles = try await download(application: context.application, domain: domain, run: run, server: server, concurrent: nConcurrent)
        try await GenericVariableHandle.convert(logger: logger, domain: domain, createNetcdf: signature.createNetcdf, run: run, nMembers: 1, handles: handles, concurrent: nConcurrent)
        logger.info("Finished in \(start.timeElapsedPretty())")

        if let uploadS3Bucket = signature.uploadS3Bucket {
            let variables = handles.map { $0.variable }.uniqued(on: { $0.rawValue })
            try domain.domainRegistry.syncToS3(bucket: uploadS3Bucket, variables: variables)
        }
    }
    
    /// MSM or GSM domain
    /// Return open file handles, to ensure overlapping runs are not conflicting
    func download(application: Application, domain: JmaDomain, run: Timestamp, server: String, concurrent: Int) async throws -> [GenericVariableHandle] {
        let logger = application.logger
        logger.info("Downloading domain '\(domain.rawValue)' run '\(run.iso8601_YYYY_MM_dd_HH_mm)'")
        let deadLineHours: Double = domain == .gsm ? 3 : 6
        let curl = Curl(logger: logger, client: application.dedicatedHttpClient, deadLineHours: deadLineHours)
        Process.alarm(seconds: Int(deadLineHours + 1) * 3600)
        let nLocationsPerChunk = OmFileSplitter(domain).nLocationsPerChunk
        let writer = OmFileWriter(dim0: 1, dim1: domain.grid.count, chunk0: 1, chunk1: nLocationsPerChunk)
        
        let runDate = run.toComponents()
        let server = server.replacingOccurrences(of: "YYYY", with: runDate.year.zeroPadded(len: 4))
            .replacingOccurrences(of: "MM", with: runDate.month.zeroPadded(len: 2))
            .replacingOccurrences(of: "DD", with: runDate.day.zeroPadded(len: 2))
            .replacingOccurrences(of: "HH", with: run.hour.zeroPadded(len: 2))
        
        let filesToDownload: [String]
        switch domain {
        case .gsm:
            filesToDownload = domain.forecastHours(run: run).map { hour in
                "Z__C_RJTD_\(run.format_YYYYMMddHH)0000_GSM_GPV_Rgl_FD\((hour/24).zeroPadded(len: 2))\((hour%24).zeroPadded(len: 2))_grib2.bin"
            }
        case .msm:
            // 0 und 12z run have more data
            let runc = run.toComponents()
            let after2022july = (runc.year >= 2022 && runc.month >= 7) || runc.year >= 2023
            let range = (run.hour % 12 == 0 && after2022july) ? ["00-15", "16-33", "34-39", "40-51", "52-78"] : ["00-15", "16-33", "34-39"]
            filesToDownload = range.map { hour in
                "Z__C_RJTD_\(run.format_YYYYMMddHH)0000_MSM_GPV_Rjp_Lsurf_FH\(hour)_grib2.bin"
            }
        }
        
        /// Keep values from previous timestep. Actori isolated, because of concurrent data conversion
        let deaverager = GribDeaverager()
        
        let handles = try await filesToDownload.asyncFlatMap { filename -> [GenericVariableHandle] in
            let url = "\(server)\(filename)"
            return try await curl.withGribStream(url: url, bzip2Decode: false, nConcurrent: concurrent) { stream in
                return try await stream.mapStream(nConcurrent: concurrent) { message -> GenericVariableHandle? in
                    guard let variable = message.toJmaVariable(),
                          let stepRange = message.get(attribute: "stepRange"),
                          let stepType = message.get(attribute: "stepType"),
                          let hour = message.get(attribute: "endStep").flatMap(Int.init) else {
                        return nil
                    }
                    if hour == 0 && variable.skipHour0 {
                        return nil
                    }
                    let timestamp = run.add(hours: hour)
                    var grib2d = GribArray2D(nx: domain.grid.nx, ny: domain.grid.ny)
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
                    
                    // Deaccumulate precipitation. MSM model falsely marks `stepType` as accumulation for precipitation, resulting in negative values
                    if domain != .msm {
                        guard await deaverager.deaccumulateIfRequired(variable: variable, member: 0, stepType: stepType, stepRange: stepRange, grib2d: &grib2d) else {
                            return nil
                        }
                    }
                    
                    //try data.writeNetcdf(filename: "\(domain.downloadDirectory)\(variable.variable.omFileName.file)_\(variable.hour).nc")
                    logger.info("Compressing and writing data to \(variable.omFileName.file)_\(hour).om")
                    let fn = try writer.writeTemporary(compressionType: .p4nzdec256, scalefactor: variable.scalefactor, all: grib2d.array.data)
                    return GenericVariableHandle(variable: variable, time: timestamp, member: 0, fn: fn, skipHour0: variable.skipHour0)
                }.collect().compactMap({$0})
            }
        }
        await curl.printStatistics()
        Process.alarm(seconds: 0)
        return handles
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
        case "2r": return JmaSurfaceVariable.relative_humidity_2m
        case "lcc": return JmaSurfaceVariable.cloud_cover_low
        case "mcc": return JmaSurfaceVariable.cloud_cover_mid
        case "hcc": return JmaSurfaceVariable.cloud_cover_high
        case "dswrf": return JmaSurfaceVariable.shortwave_radiation
        case "unknown":
            if parameterCategory == 6 && parameterNumber == 1 {
                return JmaSurfaceVariable.cloud_cover
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
                return JmaSurfaceVariable.relative_humidity_2m
            }
            return JmaPressureVariable(variable: .relative_humidity, level: level)
        default: return nil
        }
    }
}

enum JmaSurfaceVariable: String, CaseIterable, JmaVariableDownloadable, GenericVariableMixable {
    case temperature_2m
    case cloud_cover
    case cloud_cover_low
    case cloud_cover_mid
    case cloud_cover_high
    case pressure_msl
    case relative_humidity_2m
    
    /// not in global model
    case shortwave_radiation
    
    case wind_v_component_10m
    case wind_u_component_10m
    
    /// accumulated since forecast start
    case precipitation
    
    var storePreviousForecast: Bool {
        switch self {
        case .temperature_2m, .relative_humidity_2m: return true
        case .precipitation: return true
        case .pressure_msl: return true
        case .cloud_cover: return true
        case .shortwave_radiation: return true
        case .wind_v_component_10m, .wind_u_component_10m: return true
        default: return false
        }
    }
    
    var omFileName: (file: String, level: Int) {
        return (rawValue, 0)
    }
    
    var scalefactor: Float {
        switch self {
        case .temperature_2m:
            return 20
        case .cloud_cover:
            return 1
        case .cloud_cover_low:
            return 1
        case .cloud_cover_mid:
            return 1
        case .cloud_cover_high:
            return 1
        case .relative_humidity_2m:
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
        case .cloud_cover:
            return .hermite(bounds: 0...100)
        case .cloud_cover_low:
            return .hermite(bounds: 0...100)
        case .cloud_cover_mid:
            return .hermite(bounds: 0...100)
        case .cloud_cover_high:
            return .hermite(bounds: 0...100)
        case .pressure_msl:
            return .hermite(bounds: nil)
        case .relative_humidity_2m:
            return .hermite(bounds: 0...100)
        case .wind_v_component_10m:
            return .hermite(bounds: nil)
        case .wind_u_component_10m:
            return .hermite(bounds: nil)
        case .precipitation:
            return .backwards_sum
        case .shortwave_radiation:
            return .solar_backwards_averaged
        }
    }
    
    var unit: SiUnit {
        switch self {
        case .temperature_2m:
            return .celsius
        case .cloud_cover:
            return .percentage
        case .cloud_cover_low:
            return .percentage
        case .cloud_cover_mid:
            return .percentage
        case .cloud_cover_high:
            return .percentage
        case .relative_humidity_2m:
            return .percentage
        case .precipitation:
            return .millimetre
        case .pressure_msl:
            return .hectopascal
        case .wind_v_component_10m:
            return .metrePerSecond
        case .wind_u_component_10m:
            return .metrePerSecond
        case .shortwave_radiation:
            return .wattPerSquareMetre
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
    case relative_humidity
}


/**
 A pressure level variable on a given level in hPa / mb
 */
struct JmaPressureVariable: PressureVariableRespresentable, JmaVariableDownloadable, Hashable, GenericVariableMixable {
    let variable: JmaPressureVariableType
    let level: Int
    
    var storePreviousForecast: Bool {
        return false
    }
    
    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
    
    var omFileName: (file: String, level: Int) {
        return (rawValue, 0)
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
        case .relative_humidity:
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
        case .relative_humidity:
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
            return .metrePerSecond
        case .wind_v_component:
            return .metrePerSecond
        case .geopotential_height:
            return .metre
        case .vertical_velocity:
            return .metrePerSecond
        case .relative_humidity:
            return .percentage
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


enum JmaDomain: String, GenericDomain, CaseIterable {
    case gsm
    case msm
    
    var domainRegistry: DomainRegistry {
        switch self {
        case .gsm:
            return .jma_gsm
        case .msm:
            return .jma_msm
        }
    }
    
    var domainRegistryStatic: DomainRegistry? {
        return domainRegistry
    }
    
    var hasYearlyFiles: Bool {
        return false
    }

    var masterTimeRange: Range<Timestamp>? {
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
    
    func forecastHours(run: Timestamp) -> [Int] {
        let hour = run.hour
        switch self {
        case .gsm:
            if run.toComponents().year <= 2018 {
                return Array(stride(from: 0, through: 84, by: 6))
            }
            if run.toComponents().year <= 2020 {
                return Array(stride(from: 0, through: 134, by: 6))
            }
            let through = hour == 00 || hour == 12 ? 264 : 136
            return Array(stride(from: 0, through: through, by: 6))
        case .msm:
            let through = hour == 00 || hour == 12 ? 78 : 39
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


extension Timestamp {
    /// Interprete the run parameter as either a simple hour or a fully specified date
    static func fromRunHourOrYYYYMMDD(_ str: String) throws -> Timestamp {
        if str.count > 2 {
            return try Timestamp.from(yyyymmdd: str)
        }
        guard let run = Int(str) else {
            throw TimeError.InvalidDateFromat
        }
        return Timestamp.now().with(hour: run)
    }
}
