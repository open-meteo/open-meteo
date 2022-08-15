import Foundation
import Vapor
import SwiftPFor2D
import SwiftEccodes


enum NcepDomain: String {
    case gfs025
    
    var omfileDirectory: String {
        return "./data/omfile-\(rawValue)/"
    }
    var downloadDirectory: String {
        return "./data/\(rawValue)/"
    }
    var omfileArchive: String? {
        return nil
    }
    
    var dtSeconds: Int {
        return 3600
    }
    
    var elevationFile: OmFileReader? {
        return nil
    }
    
    var omFileLength: Int {
        switch self {
        case .gfs025:
            return 384 + 1 + 4*24
        }
    }
}


enum GfsVariable: String, CurlIndexedVariable, CaseIterable {
    case temperature_2m
    case cloudcover
    case cloudcover_low
    case cloudcover_mid
    case cloudcover_high
    case pressure_msl
    case relativehumidity_2m
    
    /// accumulated since forecast start
    case precipitation
    
    case v_10m
    case u_10m
    case v_80m
    case u_80m
    
    case soil_temperature_0_to_10cm
    case soil_temperature_10_to_40cm
    case soil_temperature_40_to_100cm
    case soil_temperature_100_to_200cm
    
    case soil_moisture_0_to_10cm
    case soil_moisture_10_to_40cm
    case soil_moisture_40_to_100cm
    case soil_moisture_100_to_200cm
    
    case snow_depth
    
    /// averaged since model start
    case sensible_heatflux
    case latent_heatflux
    
    case showers
    //case rain
    //case snowfall_convective_water_equivalent
    //case snowfall_water_equivalent
    
    case windgusts_10m
    case freezinglevel_height
    case shortwave_radiation
    // diff could be estimated with https://arxiv.org/pdf/2007.01639.pdf 3) method
    //case diffuse_radiation
    //case direct_radiation
    
    var skipHour0: Bool {
        switch self {
        case .precipitation: return true
        case .sensible_heatflux: return true
        case .latent_heatflux: return true
        case .showers: return true
        case .shortwave_radiation: return true
        default: return false
        }
    }
    
    var gribIndexName: String {
        switch self {
        case .temperature_2m:
            return ":TMP:2 m above ground:"
        case .cloudcover:
            return ":TCDC:entire atmosphere:"
        case .cloudcover_low:
            return ":LCDC:low cloud layer:"
        case .cloudcover_mid:
            return ":MCDC:middle cloud layer:"
        case .cloudcover_high:
            return ":HCDC:high cloud layer:"
        case .pressure_msl:
            return ":PRMSL:mean sea level:"
        case .relativehumidity_2m:
            return ":RH:2 m above ground:"
        case .precipitation:
            return ":APCP:surface:"
        case .v_10m:
            return ":VGRD:10 m above ground:"
        case .u_10m:
            return ":UGRD:10 m above ground:"
        case .v_80m:
            return ":VGRD:80 m above ground:"
        case .u_80m:
            return ":UGRD:80 m above ground:"
        case .soil_temperature_0_to_10cm:
            return ":TSOIL:0-0.1 m below ground:"
        case .soil_temperature_10_to_40cm:
            return ":TSOIL:0.1-0.4 m below ground:"
        case .soil_temperature_40_to_100cm:
            return ":TSOIL:0.4-1 m below ground:"
        case .soil_temperature_100_to_200cm:
            return ":TSOIL:1-2 m below ground:"
        case .soil_moisture_0_to_10cm:
            return ":SOILW:0-0.1 m below ground:"
        case .soil_moisture_10_to_40cm:
            return ":SOILW:0.1-0.4 m below ground:"
        case .soil_moisture_40_to_100cm:
            return ":SOILW:0.4-1 m below ground:"
        case .soil_moisture_100_to_200cm:
            return ":SOILW:1-2 m below ground:"
        case .snow_depth:
            return ":SNOD:surface:"
        case .sensible_heatflux:
            return ":SHTFL:surface:"
        case .latent_heatflux:
            return ":LHTFL:surface:"
        case .showers:
            return ":ACPCP:surface:"
        case .windgusts_10m:
            return ":GUST:surface:"
        case .freezinglevel_height:
            return ":HGT:0C isotherm:"
        case .shortwave_radiation:
            return ":DSWRF:surface:"
        }
    }
}


/**
NCEP GFS downloader
 */
struct NcepDownload: Command {
    struct Signature: CommandSignature {
        @Argument(name: "domain")
        var domain: String

        @Option(name: "run")
        var run: String?

        @Flag(name: "skip-existing")
        var skipExisting: Bool
        
        @Option(name: "only-variables")
        var onlyVariables: String?
    }

    var help: String {
        "Download GFS from NOAA NCEP"
    }
    
    func run(using context: CommandContext, signature: Signature) throws {
        let logger = context.application.logger
        guard let domain = NcepDomain.init(rawValue: signature.domain) else {
            fatalError("Invalid domain '\(signature.domain)'")
        }
        switch domain {
        case .gfs025:
            let run = signature.run.map {
                guard let run = Int($0) else {
                    fatalError("Invalid run '\($0)'")
                }
                return run
            } ?? ((Timestamp.now().hour - 2 + 24) % 24 ).floor(to: 6)
            
            let variables: [GfsVariable] = signature.onlyVariables.map {
                $0.split(separator: ",").map {
                    guard let variable = GfsVariable(rawValue: String($0)) else {
                        fatalError("Invalid variable '\($0)'")
                    }
                    return variable
                }
            } ?? GfsVariable.allCases
            
            /// 18z run is available the day after starting 05:26
            let date = Timestamp.now().with(hour: run)
            
            try downloadGfs(logger: logger, domain: domain, run: date, variables: variables, skipFilesIfExisting: signature.skipExisting)
            //try convertGfs(logger: logger, domain: domain, run: date)
        }
    }
    
    /// download cfs domain
    /*func downloadCfsElevation(logger: Logger, domain: SeasonalForecastDomain, run: Timestamp) throws {
        /// download seamask and height
        if FileManager.default.fileExists(atPath: domain.surfaceElevationFileOm) {
            return
        }
        
        try FileManager.default.createDirectory(atPath: domain.omfileDirectory, withIntermediateDirectories: true)
        
        logger.info("Downloading height and elevation data")
        let url = "https://nomads.ncep.noaa.gov/pub/data/nccf/com/cfs/prod/cfs.\(run.format_YYYYMMdd)/\(run.hour.zeroPadded(len: 2))/6hrly_grib_01/flxf\(run.format_YYYYMMddHH).01.\(run.format_YYYYMMddHH).grb2"
        
        enum ElevationVariable: String, CurlIndexedVariable, CaseIterable {
            case height
            case landmask
            
            var gribIndexName: String {
                switch self {
                case .height:
                    return ":HGT:surface:"
                case .landmask:
                    return ":LAND:surface:"
                }
            }
        }
        
        var height: Array2D? = nil
        var landmask: Array2D? = nil
        let curl = Curl(logger: logger)
        for (variable, data2) in try curl.downloadIndexedGrib(url: url, variables: ElevationVariable.allCases) {
            var data = data2
            data.shift180LongitudeAndFlipLatitude()
            switch variable {
            case .height:
                height = data
            case .landmask:
                landmask = data
            }
            //try data.writeNetcdf(filename: "\(domain.downloadDirectory)\(variable.rawValue).nc")
        }
        guard var height = height, let landmask = landmask else {
            fatalError("Could not download land and sea mask")
        }
        for i in height.data.indices {
            // landmask: 0=sea, 1=land
            height.data[i] = landmask.data[i] == 1 ? height.data[i] : -999
        }
        try OmFileWriter.write(file: domain.surfaceElevationFileOm, compressionType: .p4nzdec256, scalefactor: 1, dim0: domain.grid.ny, dim1: domain.grid.nx, chunk0: 20, chunk1: 20, all: height.data)
    }*/
    
    func downloadGfs(logger: Logger, domain: NcepDomain, run: Timestamp, variables: [GfsVariable], skipFilesIfExisting: Bool) throws {
        try FileManager.default.createDirectory(atPath: domain.downloadDirectory, withIntermediateDirectories: true)
        
        let curl = Curl(logger: logger)
        let forecastHours = Array(stride(from: 0, to: 120, by: 1)) + Array(stride(from: 120, through: 384, by: 3))
        let variablesHour0 = variables.filter({!$0.skipHour0})
        
        for forecastHour in forecastHours {
            logger.info("Downloading forecastHour \(forecastHour)")
            let variables = (forecastHour == 0 ? variablesHour0 : variables).filter { variable in
                let fileDest = "\(domain.downloadDirectory)\(variable.rawValue)_\(forecastHour).fpg"
                return !skipFilesIfExisting || !FileManager.default.fileExists(atPath: fileDest)
            }
            if variables.isEmpty {
                continue
            }
            
            //https://nomads.ncep.noaa.gov/pub/data/nccf/com/gfs/prod/gfs.20220813/00/atmos/gfs.t00z.pgrb2.0p25.f084.idx
            let url = "https://nomads.ncep.noaa.gov/pub/data/nccf/com/gfs/prod/gfs.\(run.format_YYYYMMdd)/\(run.hh)/atmos/gfs.t\(run.hh)z.pgrb2.0p25.f\(forecastHour.zeroPadded(len: 3))"
            
            for (variable, data) in try curl.downloadIndexedGrib(url: url, variables: variables) {
                var data = data
                data.shift180LongitudeAndFlipLatitude()
                //try data.writeNetcdf(filename: "\(domain.downloadDirectory)\(variable.rawValue)_\(forecastHour).nc")
                try FloatArrayCompressor.write(file: "\(domain.downloadDirectory)\(variable.rawValue)_\(forecastHour).fpg", data: data.data)
            }
        }
    }
    
    /// Process each variable and update time-series optimised files
    /*func convertGfs(logger: Logger, domain: SeasonalForecastDomain, run: Timestamp) throws {
        try FileManager.default.createDirectory(atPath: domain.omfileDirectory, withIntermediateDirectories: true)
        let om = OmFileSplitter(basePath: domain.omfileDirectory, nLocations: domain.grid.count, nTimePerFile: domain.omFileLength, yearlyArchivePath: nil)
        
        for member in 1..<domain.nMembers+1 {
            try GribFile.readAndConvert(logger: logger, gribName: "tmin", member: member, domain: domain, add: -273.15).first!.value
                    .writeCfs(om: om, logger: logger, variable: .temperature_2m_min, member: member, run: run, dtSeconds: domain.dtSeconds)
            try GribFile.readAndConvert(logger: logger, gribName: "tmax", member: member, domain: domain, add: -273.15).first!.value
                    .writeCfs(om: om, logger: logger, variable: .temperature_2m_max, member: member, run: run, dtSeconds: domain.dtSeconds)
            try GribFile.readAndConvert(logger: logger, gribName: "soilt1", member: member, domain: domain, add: -273.15).first!.value
                    .writeCfs(om: om, logger: logger, variable: .soil_temperature_0_to_10_cm, member: member, run: run, dtSeconds: domain.dtSeconds)
            
            try GribFile.readAndConvert(logger: logger, gribName: "dswsfc", member: member, domain: domain).first!.value
                    .writeCfs(om: om, logger: logger, variable: .shortwave_radiation, member: member, run: run, dtSeconds: domain.dtSeconds)
            
            try GribFile.readAndConvert(logger: logger, gribName: "cprat", member: member, domain: domain, multiply: Float(domain.dtSeconds)).first!.value
                    .writeCfs(om: om, logger: logger, variable: .showers, member: member, run: run, dtSeconds: domain.dtSeconds)
            
            try GribFile.readAndConvert(logger: logger, gribName: "prate", member: member, domain: domain, multiply: Float(domain.dtSeconds)).first!.value
                    .writeCfs(om: om, logger: logger, variable: .total_precipitation, member: member, run: run, dtSeconds: domain.dtSeconds)
            
            try GribFile.readAndConvert(logger: logger, gribName: "tcdcclm", member: member, domain: domain).first!.value
                    .writeCfs(om: om, logger: logger, variable: .total_cloud_cover, member: member, run: run, dtSeconds: domain.dtSeconds)

            try GribFile.readAndConvert(logger: logger, gribName: "soilm1", member: member, domain: domain).first!.value
                    .writeCfs(om: om, logger: logger, variable: .soil_moisture_0_to_10_cm, member: member, run: run, dtSeconds: domain.dtSeconds)
            try GribFile.readAndConvert(logger: logger, gribName: "soilm2", member: member, domain: domain).first!.value
                    .writeCfs(om: om, logger: logger, variable: .soil_moisture_10_to_40_cm, member: member, run: run, dtSeconds: domain.dtSeconds)
            try GribFile.readAndConvert(logger: logger, gribName: "soilm3", member: member, domain: domain).first!.value
                    .writeCfs(om: om, logger: logger, variable: .soil_moisture_40_to_100_cm, member: member, run: run, dtSeconds: domain.dtSeconds)
            try GribFile.readAndConvert(logger: logger, gribName: "soilm4", member: member, domain: domain).first!.value
                    .writeCfs(om: om, logger: logger, variable: .soil_moisture_100_to_200_cm, member: member, run: run, dtSeconds: domain.dtSeconds)

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
                try relativeHumidity.writeCfs(om: om, logger: logger, variable: .relativehumidity_2m, member: member, run: run, dtSeconds: domain.dtSeconds)
            }()
            
            
            /// -999 for sea
            let elevations = try domain.elevationFile!.readAll()
            
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
    }*/
}

fileprivate extension Array2DFastTime {
    func writeCfs(om: OmFileSplitter, logger: Logger, variable: CfsVariable, member: Int, run: Timestamp, dtSeconds: Int) throws {
        let startOm = DispatchTime.now()
        let timeIndexStart = run.timeIntervalSince1970 / dtSeconds
        let timeIndices = timeIndexStart ..< timeIndexStart + nTime
        
        try om.updateFromTimeOriented(variable: "\(variable.rawValue)_\(member)", array2d: self, ringtime: timeIndices, skipFirst: 1, smooth: 0, skipLast: 0, scalefactor: variable.scalefactor)
        logger.info("Update om \(variable) finished in \(startOm.timeElapsedPretty())")
    }
}


fileprivate extension GribFile {
    static func readAndConvert(logger: Logger, gribName: String, member: Int, domain: SeasonalForecastDomain, multiply: Float = 1, add: Float = 0) throws -> [String: Array2DFastTime] {
        logger.info("Reading grib '\(gribName)' for member \(member)")
        let startReadGrib = DispatchTime.now()
        var vars = [String: Array2DFastTime]()
        
        let grib = try GribFile(file: "\(domain.downloadDirectory)\(gribName)_\(member).grb2")
        
        /// Note, first forecast hour is always missing
        let nForecastHours = Int(grib.messages.last!.get(attribute: "step")!)! / domain.dtHours + 1
        guard nForecastHours > 10 else {
            fatalError("nForecastHours is \(nForecastHours)")
        }
        
        for message in grib.messages {
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
