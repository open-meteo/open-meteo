import Foundation
import Vapor
import SwiftPFor2D
import SwiftEccodes


/**
 
 NCEP CFSv2 https://nomads.ncep.noaa.gov/pub/data/nccf/com/cfs/prod/cfs.20220808/00/
 https://rda.ucar.edu/datasets/ds094.0/#metadata/grib2.html?_do=y
 
 requires jpeg2000 support for eccodes, brew needs to rebuild
 brew edit eccodes
 set DENABLE_JPG_LIBJASPER to ON
 brew reinstall eccodes --build-from-source
 */
struct SeasonalForecastDownload: AsyncCommand {
    struct Signature: CommandSignature {
        @Argument(name: "domain")
        var domain: String

        @Option(name: "run")
        var run: String?

        @Flag(name: "skip-existing", help: "ONLY FOR TESTING! Do not use in production. May update the database with stale data")
        var skipExisting: Bool
        
        @Option(name: "only-variables")
        var onlyVariables: String?
        
        @Option(name: "upload-s3-bucket", help: "Upload open-meteo database to an S3 bucket after processing")
        var uploadS3Bucket: String?
    }

    var help: String {
        "Download seasonal forecasts from Copernicus"
    }
    
    func run(using context: CommandContext, signature: Signature) async throws {
        let logger = context.application.logger
        let domain = try SeasonalForecastDomain.load(rawValue: signature.domain)
        
        switch domain {
        case .ecmwf:
            fatalError()
        case .ukMetOffice:
            fatalError()
        case .meteoFrance:
            fatalError()
        case .dwd:
            fatalError()
        case .cmcc:
            fatalError()
        case .ncep:
            /// 18z run is available the day after starting 05:26
            let run = try signature.run.flatMap(Timestamp.fromRunHourOrYYYYMMDD) ?? domain.lastRun
            
            try await downloadCfsElevation(application: context.application, domain: domain, run: run)
            
            try await downloadCfs(application: context.application, domain: domain, run: run, skipFilesIfExisting: signature.skipExisting)
            try convertCfs(logger: logger, domain: domain, run: run)
        case .jma:
            fatalError()
        case .eccc:
            fatalError()
        }
        
        if let uploadS3Bucket = signature.uploadS3Bucket {
            try domain.domainRegistry.syncToS3(bucket: uploadS3Bucket, variables: CfsVariable.allCases)
        }
    }
    
    /// download cfs domain
    func downloadCfsElevation(application: Application, domain: SeasonalForecastDomain, run: Timestamp) async throws {
        /// download seamask and height
        let surfaceElevationFileOm = domain.surfaceElevationFileOm.getFilePath()
        if FileManager.default.fileExists(atPath: surfaceElevationFileOm) {
            return
        }
                
        let url = "https://nomads.ncep.noaa.gov/pub/data/nccf/com/cfs/prod/cfs.\(run.format_YYYYMMdd)/\(run.hour.zeroPadded(len: 2))/6hrly_grib_01/flxf\(run.format_YYYYMMddHH).01.\(run.format_YYYYMMddHH).grb2"
        try await GfsDownload().downloadNcepElevation(application: application, url: [url], surfaceElevationFileOm: domain.surfaceElevationFileOm, grid: domain.grid, isGlobal: true)
    }
    
    func downloadCfs(application: Application, domain: SeasonalForecastDomain, run: Timestamp, skipFilesIfExisting: Bool) async throws {
        let logger = application.logger
        try FileManager.default.createDirectory(atPath: domain.downloadDirectory, withIntermediateDirectories: true)
        
        let curl = Curl(logger: logger, client: application.dedicatedHttpClient, deadLineHours: 18, readTimeout: 20*60)
        Process.alarm(seconds: Int(18 + 1) * 3600)
        defer { Process.alarm(seconds: 0) }
        
        let gribVariables = ["tmp2m", "tmin", "soilt1", "dswsfc", "cprat", "q2m", "wnd10m", "tcdcclm", "prate", "soilm3", "pressfc", "soilm2", "soilm1", "soilm4", "tmax"]
        
        for gribVariable in gribVariables {
            logger.info("Downloading variable \(gribVariable)")
            for member in 1..<domain.nMembers+1 {
                // https://nomads.ncep.noaa.gov/pub/data/nccf/com/cfs/prod/cfs.20220808/18/time_grib_01/tmin.01.2022080818.daily.grb2.idx
                let url = "https://nomads.ncep.noaa.gov/pub/data/nccf/com/cfs/prod/cfs.\(run.format_YYYYMMdd)/\(run.hour.zeroPadded(len: 2))/time_grib_\(member.zeroPadded(len: 2))/\(gribVariable).\(member.zeroPadded(len: 2)).\(run.format_YYYYMMddHH).daily.grb2"
                
                let fileDest = "\(domain.downloadDirectory)\(gribVariable)_\(member).grb2"
                if skipFilesIfExisting && FileManager.default.fileExists(atPath: fileDest) {
                    continue
                }
                
                try await curl.download(url: url, toFile: fileDest, bzip2Decode: false)
            }
        }
        await curl.printStatistics()
    }
    
    /// Process each variable and update time-series optimised files
    func convertCfs(logger: Logger, domain: SeasonalForecastDomain, run: Timestamp) throws {
        let om = OmFileSplitter(domain)
        
        for member in 1..<domain.nMembers+1 {
            try GribFile.readAndConvert(logger: logger, gribName: "tmin", member: member, domain: domain, add: -273.15).first!.value
                    .writeCfs(om: om, logger: logger, variable: .temperature_2m_min, member: member, run: run, dtSeconds: domain.dtSeconds)
            try GribFile.readAndConvert(logger: logger, gribName: "tmax", member: member, domain: domain, add: -273.15).first!.value
                    .writeCfs(om: om, logger: logger, variable: .temperature_2m_max, member: member, run: run, dtSeconds: domain.dtSeconds)
            try GribFile.readAndConvert(logger: logger, gribName: "soilt1", member: member, domain: domain, add: -273.15).first!.value
                    .writeCfs(om: om, logger: logger, variable: .soil_temperature_0_to_10cm, member: member, run: run, dtSeconds: domain.dtSeconds)
            
            try GribFile.readAndConvert(logger: logger, gribName: "dswsfc", member: member, domain: domain).first!.value
                    .writeCfs(om: om, logger: logger, variable: .shortwave_radiation, member: member, run: run, dtSeconds: domain.dtSeconds)
            
            try GribFile.readAndConvert(logger: logger, gribName: "cprat", member: member, domain: domain, multiply: Float(domain.dtSeconds)).first!.value
                    .writeCfs(om: om, logger: logger, variable: .showers, member: member, run: run, dtSeconds: domain.dtSeconds)
            
            try GribFile.readAndConvert(logger: logger, gribName: "prate", member: member, domain: domain, multiply: Float(domain.dtSeconds)).first!.value
                    .writeCfs(om: om, logger: logger, variable: .precipitation, member: member, run: run, dtSeconds: domain.dtSeconds)
            
            try GribFile.readAndConvert(logger: logger, gribName: "tcdcclm", member: member, domain: domain).first!.value
                    .writeCfs(om: om, logger: logger, variable: .cloud_cover, member: member, run: run, dtSeconds: domain.dtSeconds)

            try GribFile.readAndConvert(logger: logger, gribName: "soilm1", member: member, domain: domain).first!.value
                    .writeCfs(om: om, logger: logger, variable: .soil_moisture_0_to_10cm, member: member, run: run, dtSeconds: domain.dtSeconds)
            try GribFile.readAndConvert(logger: logger, gribName: "soilm2", member: member, domain: domain).first!.value
                    .writeCfs(om: om, logger: logger, variable: .soil_moisture_10_to_40cm, member: member, run: run, dtSeconds: domain.dtSeconds)
            try GribFile.readAndConvert(logger: logger, gribName: "soilm3", member: member, domain: domain).first!.value
                    .writeCfs(om: om, logger: logger, variable: .soil_moisture_40_to_100cm, member: member, run: run, dtSeconds: domain.dtSeconds)
            try GribFile.readAndConvert(logger: logger, gribName: "soilm4", member: member, domain: domain).first!.value
                    .writeCfs(om: om, logger: logger, variable: .soil_moisture_100_to_200cm, member: member, run: run, dtSeconds: domain.dtSeconds)

            // in a closure to release memory
            try {
                let wind = try GribFile.readAndConvert(logger: logger, gribName: "wnd10m", member: member, domain: domain)
                guard let uwind = wind["10u"] else {
                    fatalError()
                }
                guard let vwind = wind["10v"] else {
                    fatalError()
                }
                try uwind.writeCfs(om: om, logger: logger, variable: .wind_u_component_10m, member: member, run: run, dtSeconds: domain.dtSeconds)
                try vwind.writeCfs(om: om, logger: logger, variable: .wind_v_component_10m, member: member, run: run, dtSeconds: domain.dtSeconds)
            }()
            
            let tmp2m = try GribFile.readAndConvert(logger: logger, gribName: "tmp2m", member: member, domain: domain, add: -273.15).first!.value
            try tmp2m.writeCfs(om: om, logger: logger, variable: .temperature_2m, member: member, run: run, dtSeconds: domain.dtSeconds)
            
            /// hPa
            var surfacePressure = try GribFile.readAndConvert(logger: logger, gribName: "pressfc", member: member, domain: domain, multiply: 1/100).first!.value
            
            try {
                /// g/kg water/air mixing ratio
                let specificHumidity = try GribFile.readAndConvert(logger: logger, gribName: "q2m", member: member, domain: domain, multiply: 1000).first!.value
                
                let relativeHumidity = Array2DFastTime(data: Meteorology.specificToRelativeHumidity(specificHumidity: specificHumidity.data, temperature: tmp2m.data, pressure: surfacePressure.data), nLocations: tmp2m.nLocations, nTime: tmp2m.nTime)
                try relativeHumidity.writeCfs(om: om, logger: logger, variable: .relative_humidity_2m, member: member, run: run, dtSeconds: domain.dtSeconds)
            }()
            
            
            /// -999 for sea
            let elevations = try domain.getStaticFile(type: .elevation)!.readAll()
            
            /// convert surface pressure to mean sea level pressure
            for l in 0..<tmp2m.nLocations {
                let elevation = elevations[l]
                if elevation.isNaN || elevation <= -999 {
                    continue
                }
                for t in 0..<tmp2m.nTime {
                    surfacePressure[l,t] *= Meteorology.sealevelPressureFactor(temperature: tmp2m[l,t], elevation: elevation)
                }
            }
            try surfacePressure.writeCfs(om: om, logger: logger, variable: .pressure_msl, member: member, run: run, dtSeconds: domain.dtSeconds)
        }
    }
}

fileprivate extension Array2DFastTime {
    func writeCfs(om: OmFileSplitter, logger: Logger, variable: CfsVariable, member: Int, run: Timestamp, dtSeconds: Int) throws {
        let startOm = DispatchTime.now()
        let time = TimerangeDt(start: run, nTime: nTime, dtSeconds: dtSeconds)
        
        try om.updateFromTimeOriented(variable: "\(variable.rawValue)_member\(member)", array2d: self, time: time, skipFirst: 1, scalefactor: variable.scalefactor, storePreviousForecast: variable.storePreviousForecast)
        logger.info("Update om \(variable) finished in \(startOm.timeElapsedPretty())")
    }
}


fileprivate struct GribFile {
    static func readAndConvert(logger: Logger, gribName: String, member: Int, domain: SeasonalForecastDomain, multiply: Float = 1, add: Float = 0) throws -> [String: Array2DFastTime] {
        logger.info("Reading grib '\(gribName)' for member \(member)")
        let startReadGrib = DispatchTime.now()
        var vars = [String: Array2DFastTime]()
        
        let messages = try SwiftEccodes.getMessages(fileName: "\(domain.downloadDirectory)\(gribName)_\(member).grb2", multiSupport: true)
        
        /// Note, first forecast hour is always missing
        let nForecastHours = Int(messages.last!.get(attribute: "step")!)! / domain.dtHours + 1
        guard nForecastHours > 10 else {
            fatalError("nForecastHours is \(nForecastHours)")
        }
        
        for message in messages {
            let shortName = message.get(attribute: "shortName")!
            let forecastStep = Int(message.get(attribute: "step")!)! / domain.dtHours
            var data = try message.read2D()
            data.shift180LongitudeAndFlipLatitude()
            data.data.multiplyAdd(multiply: multiply, add: add)
            
            guard data.nx == domain.grid.nx, data.ny == domain.grid.ny else {
                fatalError("Wrong dimensions. Got \(data.nx)x\(data.ny). Expected \(domain.grid.nx)x\(domain.grid.ny)")
            }
            if vars[shortName] == nil {
                vars[shortName] = Array2DFastTime(nLocations: data.nx*data.ny, nTime: nForecastHours)
            }
            vars[shortName]![0..<data.ny*data.nx, forecastStep] = data.data
        }
        logger.info("Grib read finished in \(startReadGrib.timeElapsedPretty())")
        
        return vars
    }
}

fileprivate extension GribMessage {
    func read2D() throws -> Array2D {
        let data = try getDouble().map(Float.init)
        guard let nx = get(attribute: "Nx").map(Int.init) ?? nil else {
            fatalError("Could not get Nx")
        }
        guard let ny = get(attribute: "Ny").map(Int.init) ?? nil else {
            fatalError("Could not get Ny")
        }
        return Array2D(data: data, nx: nx, ny: ny)
    }
}
