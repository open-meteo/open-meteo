import Foundation
import Vapor
import SwiftEccodes
import OmFileFormat

struct KmaDownload: AsyncCommand {
    struct Signature: CommandSignature {
        @Argument(name: "domain")
        var domain: String

        @Option(name: "run")
        var run: String?
        
        @Flag(name: "create-netcdf")
        var createNetcdf: Bool

        @Option(name: "upload-s3-bucket", help: "Upload open-meteo database to an S3 bucket after processing")
        var uploadS3Bucket: String?
        
        @Option(name: "max-forecast-hour", help: "Only download data until this forecast hour")
        var maxForecastHour: Int?
        
        @Option(name: "concurrent", short: "c", help: "Number of concurrent download/conversion jobs")
        var concurrent: Int?
        
        @Option(name: "server", short: "c", help: "Server prefix")
        var server: String?
    }

    var help: String {
        "Download Kma models"
    }
    
    func run(using context: CommandContext, signature: Signature) async throws {
        disableIdleSleep()
        let start = DispatchTime.now()
        let logger = context.application.logger
        let domain = try KmaDomain.load(rawValue: signature.domain)
        
        let run = try signature.run.flatMap(Timestamp.fromRunHourOrYYYYMMDD) ?? domain.lastRun
        
        let nConcurrent = signature.concurrent ?? 4
        
        logger.info("Downloading domain '\(domain.rawValue)' run '\(run.iso8601_YYYY_MM_dd_HH_mm)'")
        
        guard let server = signature.server else {
            fatalError("Option server is required")
        }
        try await downloadElevation(application: context.application, domain: domain, run: run, server: server)
        let handles = try await download(application: context.application, domain: domain, run: run, concurrent: nConcurrent, maxForecastHour: signature.maxForecastHour, server: server)
        
        try await GenericVariableHandle.convert(logger: logger, domain: domain, createNetcdf: signature.createNetcdf, run: run, handles: handles, concurrent: nConcurrent, writeUpdateJson: true, uploadS3Bucket: signature.uploadS3Bucket, uploadS3OnlyProbabilities: false)
        logger.info("Finished in \(start.timeElapsedPretty())")
    }
    
    func downloadElevation(application: Application, domain: KmaDomain, run: Timestamp, server: String) async throws {
        let surfaceElevationFileOm = domain.surfaceElevationFileOm
        if FileManager.default.fileExists(atPath: surfaceElevationFileOm.getFilePath()) {
            return
        }
        let logger = application.logger
        let ftp = FtpDownloader()
        ftp.connectTimeout = 5
        
        let grid = domain.grid
        let urlLand = "\(server)\(domain.filePrefix)_v070_land_unis_h000.\(run.format_YYYYMMddHH).gb2"
        /// fraction 0=sea, 1=land
        let landmask = try await ftp.get404Retry(logger: logger, url: urlLand).withUnsafeBytes({
            let message = try SwiftEccodes.getMessages(memory: $0, multiSupport: true)[0]
            return try message.to2D(nx: grid.nx, ny: grid.ny, shift180LongitudeAndFlipLatitudeIfRequired: true)
        })
        
        let urlElevation = "\(server)\(domain.filePrefix)_v070_dist_unis_h000.\(run.format_YYYYMMddHH).gb2"
        var elevation = try await ftp.get404Retry(logger: logger, url: urlElevation).withUnsafeBytes({
            let message = try SwiftEccodes.getMessages(memory: $0, multiSupport: true)[0]
            return try message.to2D(nx: grid.nx, ny: grid.ny, shift180LongitudeAndFlipLatitudeIfRequired: true)
        })
        
        for i in elevation.array.data.indices {
            if landmask.array.data[i] < 0.5 {
                elevation.array.data[i] = -999
            }
        }
        
        try elevation.array.data.writeOmFile2D(file: surfaceElevationFileOm.getFilePath(), grid: domain.grid, createNetCdf: false)
    }
    
    func download(application: Application, domain: KmaDomain, run: Timestamp, concurrent: Int, maxForecastHour: Int?, server: String) async throws -> [GenericVariableHandle] {
        let logger = application.logger
        let deadLineHours = Double(6)
        Process.alarm(seconds: Int(deadLineHours+0.5) * 3600)
        defer { Process.alarm(seconds: 0) }
        
        let grid = domain.grid
        let writer = OmFileSplitter.makeSpatialWriter(domain: domain, nMembers: domain.ensembleMembers)
        
        let ftp = FtpDownloader()
        ftp.connectTimeout = 5
        let variables = KmaSurfaceVariable.allCases
        // 0z/12z 288, 6z/18z 87
        let forecastHours: StrideThrough<Int>
        switch domain {
        case .gdps:
            let forecastHoursMax = run.hour % 12 == 6 ? 87 : 288
            forecastHours = stride(from: 0, through: min(forecastHoursMax, maxForecastHour ?? forecastHoursMax), by: 3)
        case .ldps:
            forecastHours = stride(from: 0, through: min(48, maxForecastHour ?? 48), by: 1)
        }
        
        return try await forecastHours.asyncFlatMap { forecastHour -> [GenericVariableHandle] in
            let inMemory = VariablePerMemberStorage<KmaSurfaceVariable>()
            let handles = try await variables.mapConcurrent(nConcurrent: concurrent) { variable -> GenericVariableHandle? in
                guard let kmaName = variable.getKmaName(domain: domain) else {
                    return nil
                }
                
                let fHHH = forecastHour.zeroPadded(len: 3)
                let timestamp = run.add(hours: forecastHour)
                let url = "\(server)\(domain.filePrefix)_v070_\(kmaName)_unis_h\(fHHH).\(run.format_YYYYMMddHH).gb2"
                let data = try await ftp.get404Retry(logger: logger, url: url)
                let array2d = try data.withUnsafeBytes({
                    let message = try SwiftEccodes.getMessages(memory: $0, multiSupport: true)[0]
                    //try message.debugGrid(grid: grid, flipLatidude: true, shift180Longitude: true)
                    //fatalError()
                    var array2d = try message.to2D(nx: grid.nx, ny: grid.ny, shift180LongitudeAndFlipLatitudeIfRequired: true)
                    switch variable {
                    case /*.cloud_cover,*/ .cloud_cover_2m, .cloud_cover_low, .cloud_cover_mid, .cloud_cover_high:
                        array2d.array.data.multiplyAdd(multiply: 100, add: 0)
                    case .pressure_msl:
                        array2d.array.data.multiplyAdd(multiply: 1/100, add: 0)
                    case .temperature_2m, .surface_temperature:
                        array2d.array.data.multiplyAdd(multiply: 1, add: -273.15)
                    default:
                        break
                    }
                    return array2d
                })
                
                if [KmaSurfaceVariable.wind_speed_10m, .wind_direction_10m, .wind_speed_50m, .wind_direction_50m].contains(variable) {
                    logger.info("Keep in memory \(variable) timestep \(timestamp.format_YYYYMMddHH)")
                    await inMemory.set(variable: variable, timestamp: timestamp, member: 0, data: array2d.array)
                    return nil
                }
                switch domain {
                case .gdps:
                    if [KmaSurfaceVariable.snowfall_water_equivalent_convective, .snowfall_water_equivalent].contains(variable) {
                        // sum up snowfall large scale and convective for GDPS
                        await inMemory.set(variable: variable, timestamp: timestamp, member: 0, data: array2d.array)
                        return nil
                    }
                case .ldps:
                    if [KmaSurfaceVariable.precipitation, .snowfall_water_equivalent].contains(variable) {
                        // Sum up snow and rain to total precipitation
                        await inMemory.set(variable: variable, timestamp: timestamp, member: 0, data: array2d.array)
                        if variable == .precipitation {
                            return nil
                        }
                    }
                }
                
                let fn = try writer.writeTemporary(compressionType: .pfor_delta2d_int16, scalefactor: variable.scalefactor, all: array2d.array.data)
                logger.info("Processing \(variable) timestep \(timestamp.format_YYYYMMddHH)")
                return GenericVariableHandle(
                    variable: variable,
                    time: timestamp,
                    member: 0,
                    fn: fn
                )
            }.compactMap({$0})
            logger.info("Calculating wind speed, direction and snow")
            // Convert U/V wind components to speed and direction
            let wind10 = try await inMemory.calculateWindSpeed(u: .wind_speed_10m, v: .wind_direction_10m, outSpeedVariable: KmaSurfaceVariable.wind_speed_10m, outDirectionVariable: KmaSurfaceVariable.wind_direction_10m, writer: writer)
            let wind50 = try await inMemory.calculateWindSpeed(u: .wind_speed_50m, v: .wind_direction_50m, outSpeedVariable: KmaSurfaceVariable.wind_speed_50m, outDirectionVariable: KmaSurfaceVariable.wind_direction_50m, writer: writer)
            let precipCorrections: [GenericVariableHandle]
            switch domain {
            case .gdps:
                // Snow is downloaded as large scale and convective. Sum up both
                precipCorrections = try await inMemory.sumUp(var1: .snowfall_water_equivalent, var2: .snowfall_water_equivalent_convective, outVariable: KmaSurfaceVariable.snowfall_water_equivalent, writer: writer)
            case .ldps:
                // Precipitation variable contains rain. Sum up snow and rain to total precipitation
                precipCorrections = try await inMemory.sumUp(var1: .precipitation, var2: .snowfall_water_equivalent, outVariable: KmaSurfaceVariable.precipitation, writer: writer)
            }

            return handles + wind10 + wind50 + precipCorrections
        }
    }
}

extension KmaDomain {
    var filePrefix: String {
        switch self {
        case .gdps:
            return "GDPS/UNIS/g128"
        case .ldps:
            return "LDPS/UNIS/l015"
        }
    }
}

extension VariablePerMemberStorage {
    /// Sum up 2 variables
    func sumUp(var1: V, var2: V, outVariable: GenericVariable, writer: OmFileWriterHelper) throws -> [GenericVariableHandle] {
        return try self.data
            .groupedPreservedOrder(by: {$0.key.timestampAndMember})
            .compactMap({ (t, handles) -> GenericVariableHandle? in
                guard
                    let var1 = handles.first(where: {$0.key.variable == var1}),
                    let var2 = handles.first(where: {$0.key.variable == var2}) else {
                    return nil
                }
                let snowfall = zip(var1.value.data, var2.value.data).map(+)
                return GenericVariableHandle(
                    variable: outVariable,
                    time: t.timestamp,
                    member: t.member,
                    fn: try writer.writeTemporary(compressionType: .pfor_delta2d_int16, scalefactor: outVariable.scalefactor, all: snowfall)
                )
            }
        )
    }
}


protocol KmaVariableDownloadable {
    func getKmaName(domain: KmaDomain) -> String?
}

extension KmaSurfaceVariable: KmaVariableDownloadable {
    func getKmaName(domain: KmaDomain) -> String? {
        if domain == .ldps && [Self.wind_speed_50m, .wind_direction_50m, .snowfall_water_equivalent_convective, .showers, .cape].contains(self) {
            return nil
        }
        switch self {
        case .temperature_2m:
            return "tmpr"
        //case .cloud_cover:
        //    return "tcar"
        case .cloud_cover_low:
            return "lcdc"
        case .cloud_cover_mid:
            return "mcdc"
        case .cloud_cover_high:
            return "hcdc"
        case .cloud_cover_2m:
            return "fogf"
        case .pressure_msl:
            return "prms"
        case .relative_humidity_2m:
            return "rhwt"
        case .wind_speed_10m:
            return "ugrd"
        case .wind_direction_10m:
            return "vgrd"
        case .wind_speed_50m:
            return "50mu"
        case .wind_direction_50m:
            return "50mv"
        case .snowfall_water_equivalent:
            return "snol"
        case .snowfall_water_equivalent_convective:
            return "snoc"
        case .showers:
            return "acpc"
        case .precipitation:
            /// download large scale rain for ldps instead of total precip. Calculate total precip in post processing
            return domain == .ldps ? "ncpc" : "apcp"
        case .wind_gusts_10m:
            return "maxg"
        case .shortwave_radiation:
            return "tdsw"
        case .direct_radiation:
            return "swdr"
        case .surface_temperature:
            return "tmps"
        case .cape:
            return "cape"
        case .visibility:
            return "visi"
        }
    }
}
