import Foundation
import SwiftPFor2D
import Vapor
import SwiftNetCDF

/**
 Downloader for BOM domains
 */
struct DownloadBomCommand: AsyncCommand {
    struct Signature: CommandSignature {
        @Option(name: "run")
        var run: String?
        
        @Argument(name: "domain")
        var domain: String
        
        @Option(name: "server", help: "Root server path")
        var server: String?
        
        @Option(name: "upload-s3-bucket", help: "Upload open-meteo database to an S3 bucket after processing")
        var uploadS3Bucket: String?
        
        @Flag(name: "create-netcdf")
        var createNetcdf: Bool
        
        @Option(name: "concurrent", short: "c", help: "Numer of concurrent download/conversion jobs")
        var concurrent: Int?
    }

    var help: String {
        "Download a specified Bom model run"
    }
    
    func run(using context: CommandContext, signature: Signature) async throws {
        disableIdleSleep()
        
        let domain = try BomDomain.load(rawValue: signature.domain)
        let run = try signature.run.flatMap(Timestamp.fromRunHourOrYYYYMMDD) ?? domain.lastRun
        let logger = context.application.logger

        logger.info("Downloading domain \(domain) run '\(run.iso8601_YYYY_MM_dd_HH_mm)'")
        
        guard let server = signature.server else {
            fatalError("Parameter 'server' is required")
        }

        let nConcurrent = signature.concurrent ?? 1
        try FileManager.default.createDirectory(atPath: domain.downloadDirectory, withIntermediateDirectories: true)
        let handles = try await download(application: context.application, domain: domain, run: run, server: server, concurrent: nConcurrent)
        try await GenericVariableHandle.convert(logger: logger, domain: domain, createNetcdf: signature.createNetcdf, run: run, nMembers: 1, handles: handles, concurrent: nConcurrent)
        
        if let uploadS3Bucket = signature.uploadS3Bucket {
            let variables = handles.map { $0.variable }.uniqued(on: { $0.rawValue })
            try domain.domainRegistry.syncToS3(bucket: uploadS3Bucket, variables: variables)
        }
    }
    
    /// Dwonload
    func download(application: Application, domain: BomDomain, run: Timestamp, server: String, concurrent: Int) async throws -> [GenericVariableHandle] {
        
        let logger = application.logger
        let deadLineHours: Double = 5
        let curl = Curl(logger: logger, client: application.dedicatedHttpClient, deadLineHours: deadLineHours)
        Process.alarm(seconds: Int(deadLineHours + 1) * 3600)
        defer {
            curl.printStatistics()
            Process.alarm(seconds: 0)
        }
        let nLocationsPerChunk = OmFileSplitter(domain).nLocationsPerChunk
        
        // list of variables to download
        // http://www.bom.gov.au/nwp/doc/access/docs/ACCESS-G.all-flds.slv.surface.shtml
        let variables: [(name: String, om: BomVariable?)] = [
           ("temp_scrn", .temperature_2m),
            ("accum_conv_rain", .showers),
            ("accum_prcp", .precipitation),
            ("mslp", .pressure_msl),
            ("av_sfc_sw_dir", .direct_radiation),
            ("av_swsfcdown", .shortwave_radiation),
            ("rh_scrn", .relative_humidity_2m),
            ("ttl_cld", .cloud_cover),
            ("hi_cld", .cloud_cover_high),
            ("mid_cld", .cloud_cover_mid),
            ("low_cld", .cloud_cover_low),
            ("sfc_temp", .surface_temperature),
            ("snow_amt_lnd", .snow_depth),
            ("soil_temp", .soil_temperature_10cm),
            ("soil_temp2", .soil_temperature_35cm),
            ("soil_temp3", .soil_temperature_100cm),
            ("soil_temp4", .soil_temperature_300cm),
            ("soil_mois", .soil_moisture_10cm),
            ("soil_mois2", .soil_moisture_35cm),
            ("soil_mois3", .soil_moisture_100cm),
            ("soil_mois4", .soil_moisture_300cm),
            ("visibility", .visibility),
            ("wndgust10m", .wind_gusts_10m),
            ("uwnd10m", nil),
            ("vwnd10m", nil),
            ("accum_conv_snow", nil),
            ("accum_ls_snow", nil),
            ("cld_phys_thunder_p", nil)
        ]
        
        let handles = try await variables.mapConcurrent(nConcurrent: concurrent) { variable -> [GenericVariableHandle] in
            let base = "\(server)\(run.format_YYYYMMdd)/\(run.hh)00/"
            let analysisFile = "\(domain.downloadDirectory)\(variable.name)_an.nc"
            let forecastFile = "\(domain.downloadDirectory)\(variable.name)_fc.nc"
            if !FileManager.default.fileExists(atPath: analysisFile) {
                try await curl.download(
                    url: "\(base)an/sfc/\(variable.name).nc",
                    toFile: analysisFile,
                    bzip2Decode: false
                )
            }
            if !FileManager.default.fileExists(atPath: forecastFile) {
                try await curl.download(
                    url: "\(base)fc/sfc/\(variable.name).nc",
                    toFile: forecastFile,
                    bzip2Decode: false
                )
            }
            
            guard let omVariable = variable.om else {
                return []
            }
            let writer = OmFileWriter(dim0: 1, dim1: domain.grid.count, chunk0: 1, chunk1: nLocationsPerChunk)
            return try self.combineAnalysisForecast(domain: domain, variable: variable.name, run: run).map { (timestamp, data) in
                logger.info("Compressing and writing data to \(omVariable.omFileName.file).om \(timestamp.format_YYYYMMddHH)")
                let fn = try writer.write(domain: domain, variable: omVariable, data: data)
                return GenericVariableHandle(variable: omVariable, time: timestamp, member: 0, fn: fn, skipHour0: false)
            }
        }
        
        let writer = OmFileWriter(dim0: 1, dim1: domain.grid.count, chunk0: 1, chunk1: nLocationsPerChunk)
        
        //return handles.flatMap({$0})
        
        // combine snow and weather codes
        let handlesSnow = try zip(
            zip(zip(
                try combineAnalysisForecast(domain: domain, variable: "accum_conv_snow", run: run),
                try combineAnalysisForecast(domain: domain, variable: "accum_ls_snow", run: run)
            ),
            zip(
                try combineAnalysisForecast(domain: domain, variable: "ttl_cld", run: run),
                try combineAnalysisForecast(domain: domain, variable: "precipitation", run: run)
            )),
            zip(zip(
                try combineAnalysisForecast(domain: domain, variable: "accum_conv_rain", run: run),
                try combineAnalysisForecast(domain: domain, variable: "wndgust10m", run: run)
            ),
            zip(
                try combineAnalysisForecast(domain: domain, variable: "cld_phys_thunder_p", run: run),
                try combineAnalysisForecast(domain: domain, variable: "visibility", run: run)
            ))
        ).map { arg -> [GenericVariableHandle] in
            let (((conv_snow, ls_snow),(ttl_cld,precipitation)),((conv_rain,wndgust10m),(cld_phys_thunder_p,visibility))) = arg
            let timestamp = conv_snow.0
            logger.info("Calculate weather codes and snow sum \(timestamp.format_YYYYMMddHH)")
            let snow = zip(conv_snow.1, ls_snow.1).map(+)
            
            let weather_code = WeatherCode.calculate(cloudcover: ttl_cld.1.map{$0*100}, precipitation: precipitation.1, convectivePrecipitation: conv_rain.1, snowfallCentimeters: snow.map{$0*0.7}, gusts: wndgust10m.1, cape: cld_phys_thunder_p.1.map({$0*3}), liftedIndex: nil, visibilityMeters: visibility.1, categoricalFreezingRain: nil, modelDtSeconds: domain.dtSeconds)
            
            let fnSnow = try writer.write(domain: domain, variable: .snowfall_water_equivalent, data: snow)
            let fnWeatherCode = try writer.write(domain: domain, variable: .weather_code, data: weather_code)
            return [
                GenericVariableHandle(variable: BomVariable.snowfall_water_equivalent, time: timestamp, member: 0, fn: fnSnow, skipHour0: false),
                GenericVariableHandle(variable: BomVariable.weather_code, time: timestamp, member: 0, fn: fnWeatherCode, skipHour0: false)
            ]
        }
        
        // Calculate windspeed from u/v
        let handlesWind = try zip(
            try combineAnalysisForecast(domain: domain, variable: "uwnd10m", run: run),
            try combineAnalysisForecast(domain: domain, variable: "vwnd10m", run: run)
        ).map { (u, v) -> [GenericVariableHandle] in
            let timestamp = u.0
            logger.info("Calculate wind \(timestamp.format_YYYYMMddHH)")
            let speed = zip(u.1, v.1).map(Meteorology.windspeed)
            let direction = Meteorology.windirectionFast(u: u.1, v: v.1)
            let fnSpeed = try writer.write(domain: domain, variable: .wind_speed_10m, data: speed)
            let fnDirection = try writer.write(domain: domain, variable: .wind_speed_10m, data: direction)
            return [
                GenericVariableHandle(variable: BomVariable.wind_speed_10m, time: timestamp, member: 0, fn: fnSpeed, skipHour0: false),
                GenericVariableHandle(variable: BomVariable.wind_direction_10m, time: timestamp, member: 0, fn: fnDirection, skipHour0: false)
                ]
        }
        
        return handles.flatMap({$0}) + handlesSnow.flatMap({$0}) + handlesWind.flatMap({$0})
    }
    
    //func downloadForecastAndAnalysis(domain: BomDomain, )
    
    /// Process timsteps from 2 netcdf files: analysis and forecast
    /// Performs deaccumulation if required
    func combineAnalysisForecast(domain: BomDomain, variable: String, run: Timestamp) throws -> AnySequence<(Timestamp, [Float])> {
        let analysisFile = "\(domain.downloadDirectory)\(variable)_an.nc"
        let forecastFile = "\(domain.downloadDirectory)\(variable)_fc.nc"
        
        guard let ncForecast = try NetCDF.open(path: forecastFile, allowUpdate: false) else {
            fatalError("Could not open \(forecastFile)")
        }
        guard let timeForecast = try ncForecast.getVariable(name: "time")?.asType(Int32.self)?.read() else {
            fatalError("Could not read time")
        }
        guard let ncAnalysis = try NetCDF.open(path: analysisFile, allowUpdate: false) else {
            fatalError("Could not open \(forecastFile)")
        }
        guard let varForecast = ncForecast.getVariable(name: variable) else {
            fatalError("Could not open nc variable \(variable)")
        }
        guard let varAnalysis = ncAnalysis.getVariable(name: variable) else {
            fatalError("Could not open nc variable \(variable)")
        }
        let nDims = varAnalysis.dimensionsFlat.count
        let dimensions = ncForecast.getDimensions()
        guard let nx = dimensions.first(where: {$0.name == "lon"})?.length else {
            fatalError("Could not get nx")
        }
        guard let ny = dimensions.first(where: {$0.name == "lat"})?.length else {
         
            fatalError("Could not get ny")
        }
        let isAccumulated = variable.starts(with: "accum_")
        // process indiviual timesteps
        return AnySequence<(Timestamp, [Float])> { () -> AnyIterator<(Timestamp, [Float])> in
            var pos = 0
            var previousStepData: [Float]? = nil
            return AnyIterator<(Timestamp, [Float])> { () -> (Timestamp, [Float])? in
                if pos > timeForecast.count {
                    return nil
                }
                defer {pos += 1}
                if pos == 0 {
                    guard let data = try? varAnalysis.asType(Float.self)?.read(
                        offset: nDims == 3 ? [0, 0, 0] : [0, 0, 0, 0],
                        count: nDims == 3 ? [1, ny, nx]: [1, 1, ny, nx]
                    ) else {
                        fatalError("Could not read analysis timestep for \(variable)")
                    }
                    return (run, data)
                } else {
                    guard var data = try? varForecast.asType(Float.self)?.read(
                        offset: nDims == 3 ? [pos-1, 0, 0] : [pos-1, 0, 0, 0],
                        count: nDims == 3 ? [1, ny, nx] : [1, 1, ny, nx]
                    ) else {
                        fatalError("Could not read timestep")
                    }
                    if isAccumulated {
                        if let previous = previousStepData {
                            previousStepData = data
                            for i in data.indices {
                                data[i] -= previous[i]
                            }
                        } else {
                            previousStepData = data
                        }
                    }
                    return (run.add(Int(timeForecast[pos-1])), data)
                }
            }
        }
    }
}

extension OmFileWriter {
    fileprivate func write(domain: BomDomain, variable: BomVariable, data: [Float]) throws -> FileHandle {
        var data = data
        data.shift180LongitudeAndFlipLatitude(nt: 1, ny: domain.grid.ny, nx: domain.grid.nx)
        // Scaling before compression with scalefactor
        if let fma = variable.multiplyAdd {
            data.multiplyAdd(multiply: fma.multiply, add: fma.add)
        }
        
        let file = "\(domain.downloadDirectory)\(variable.omFileName.file).om"
        try FileManager.default.removeItemIfExists(at: file)
        
        let fn = try write(file: file, compressionType: .p4nzdec256, scalefactor: variable.scalefactor, all: data)
        try FileManager.default.removeItem(atPath: file)
        return fn
    }
}
