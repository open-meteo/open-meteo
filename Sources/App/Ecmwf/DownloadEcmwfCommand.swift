import Foundation
import Vapor
import SwiftNetCDF


enum EcmwfVariable: String, CaseIterable, Hashable, Codable, GenericVariable {
    case soil_temperature_0_7cm
    case skin_temperature
    case geopotential_height_1000hPa
    case geopotential_height_925hPa
    case geopotential_height_850hPa
    case geopotential_height_700hPa
    case geopotential_height_500hPa
    case geopotential_height_300hPa
    case geopotential_height_250hPa
    case geopotential_height_200hPa
    case geopotential_height_50hPa
    case northward_wind_1000hPa
    case northward_wind_925hPa
    case northward_wind_850hPa
    case northward_wind_700hPa
    case northward_wind_500hPa
    case northward_wind_300hPa
    case northward_wind_250hPa
    case northward_wind_200hPa
    case northward_wind_50hPa
    case eastward_wind_1000hPa
    case eastward_wind_925hPa
    case eastward_wind_850hPa
    case eastward_wind_700hPa
    case eastward_wind_500hPa
    case eastward_wind_300hPa
    case eastward_wind_250hPa
    case eastward_wind_200hPa
    case eastward_wind_50hPa
    case temperature_1000hPa
    case temperature_925hPa
    case temperature_850hPa
    case temperature_700hPa
    case temperature_500hPa
    case temperature_300hPa
    case temperature_250hPa
    case temperature_200hPa
    case temperature_50hPa
    case relative_humidity_1000hPa
    case relative_humidity_925hPa
    case relative_humidity_850hPa
    case relative_humidity_700hPa
    case relative_humidity_500hPa
    case relative_humidity_300hPa
    case relative_humidity_250hPa
    case relative_humidity_200hPa
    case relative_humidity_50hPa
    case surface_air_pressure
    case pressure_msl
    case total_column_integrated_water_vapour
    case northward_wind_10m
    case eastward_wind_10m
    case specific_humidity_1000hPa
    case specific_humidity_925hPa
    case specific_humidity_850hPa
    case specific_humidity_700hPa
    case specific_humidity_500hPa
    case specific_humidity_300hPa
    case specific_humidity_250hPa
    case specific_humidity_200hPa
    case specific_humidity_50hPa
    case temperature_2m
    case atmosphere_relative_vorticity_1000hPa
    case atmosphere_relative_vorticity_925hPa
    case atmosphere_relative_vorticity_850hPa
    case atmosphere_relative_vorticity_700hPa
    case atmosphere_relative_vorticity_500hPa
    case atmosphere_relative_vorticity_300hPa
    case atmosphere_relative_vorticity_250hPa
    case atmosphere_relative_vorticity_200hPa
    case atmosphere_relative_vorticity_50hPa
    case divergence_of_wind_1000hPa
    case divergence_of_wind_925hPa
    case divergence_of_wind_850hPa
    case divergence_of_wind_700hPa
    case divergence_of_wind_500hPa
    case divergence_of_wind_300hPa
    case divergence_of_wind_250hPa
    case divergence_of_wind_200hPa
    case divergence_of_wind_50hPa
    
    var isElevationCorrectable: Bool {
        return self == .temperature_2m
    }
    
    static let pressure_levels = [1000, 925, 850, 700, 500, 300, 250, 200, 50]
    
    var omFileName: String {
        return nameInFiles
    }
    
    var nameInFiles: String {
        // TODO: data files should be renamed on storage!
        switch self {
        case .temperature_2m:
            return "air_temperature_2m"
        case .pressure_msl:
            return "air_pressure_at_mean_sea_level"
        case .soil_temperature_0_7cm:
            return "soil_temperature_0to7cm"
        case .temperature_1000hPa:
            return "air_temperature_1000hPa"
        case .temperature_925hPa:
            return "air_temperature_925hPa"
        case .temperature_850hPa:
            return "air_temperature_850hPa"
        case .temperature_700hPa:
            return "air_temperature_700hPa"
        case .temperature_500hPa:
            return "air_temperature_500hPa"
        case .temperature_300hPa:
            return "air_temperature_300hPa"
        case .temperature_250hPa:
            return "air_temperature_250hPa"
        case .temperature_200hPa:
            return "air_temperature_200hPa"
        case .temperature_50hPa:
            return "air_temperature_50hPa"
        default: return rawValue
        }
    }
    
    var unit: SiUnit {
        switch self {
        case .soil_temperature_0_7cm: fallthrough
        case .skin_temperature: return .celsius
        case .geopotential_height_1000hPa: fallthrough
        case .geopotential_height_925hPa: fallthrough
        case .geopotential_height_850hPa: fallthrough
        case .geopotential_height_700hPa: fallthrough
        case .geopotential_height_500hPa: fallthrough
        case .geopotential_height_300hPa: fallthrough
        case .geopotential_height_250hPa: fallthrough
        case .geopotential_height_200hPa: fallthrough
        case .geopotential_height_50hPa: return .gpm
        case .northward_wind_1000hPa: fallthrough
        case .northward_wind_925hPa: fallthrough
        case .northward_wind_850hPa: fallthrough
        case .northward_wind_700hPa: fallthrough
        case .northward_wind_500hPa: fallthrough
        case .northward_wind_300hPa: fallthrough
        case .northward_wind_250hPa: fallthrough
        case .northward_wind_200hPa: fallthrough
        case .northward_wind_50hPa: fallthrough
        case .eastward_wind_1000hPa: fallthrough
        case .eastward_wind_925hPa: fallthrough
        case .eastward_wind_850hPa: fallthrough
        case .eastward_wind_700hPa: fallthrough
        case .eastward_wind_500hPa: fallthrough
        case .eastward_wind_300hPa: fallthrough
        case .eastward_wind_250hPa: fallthrough
        case .eastward_wind_200hPa: fallthrough
        case .eastward_wind_50hPa: return .ms
        case .temperature_1000hPa: fallthrough
        case .temperature_925hPa: fallthrough
        case .temperature_850hPa: fallthrough
        case .temperature_700hPa: fallthrough
        case .temperature_500hPa: fallthrough
        case .temperature_300hPa: fallthrough
        case .temperature_250hPa: fallthrough
        case .temperature_200hPa: fallthrough
        case .temperature_50hPa: return .celsius
        case .relative_humidity_1000hPa: fallthrough
        case .relative_humidity_925hPa: fallthrough
        case .relative_humidity_850hPa: fallthrough
        case .relative_humidity_700hPa: fallthrough
        case .relative_humidity_500hPa: fallthrough
        case .relative_humidity_300hPa: fallthrough
        case .relative_humidity_250hPa: fallthrough
        case .relative_humidity_200hPa: fallthrough
        case .relative_humidity_50hPa: return .gramPerKilogram
        case .surface_air_pressure: return .hectoPascal
        case .pressure_msl: return .hectoPascal
        case .total_column_integrated_water_vapour: return .kilogramPerSquareMeter
        case .northward_wind_10m: return .ms
        case .eastward_wind_10m: return .ms
        case .specific_humidity_1000hPa: fallthrough
        case .specific_humidity_925hPa: fallthrough
        case .specific_humidity_850hPa: fallthrough
        case .specific_humidity_700hPa: fallthrough
        case .specific_humidity_500hPa: fallthrough
        case .specific_humidity_300hPa: fallthrough
        case .specific_humidity_250hPa: fallthrough
        case .specific_humidity_200hPa: fallthrough
        case .specific_humidity_50hPa: return .gramPerKilogram
        case .temperature_2m: return .celsius
        case .atmosphere_relative_vorticity_1000hPa: fallthrough
        case .atmosphere_relative_vorticity_925hPa: fallthrough
        case .atmosphere_relative_vorticity_850hPa: fallthrough
        case .atmosphere_relative_vorticity_700hPa: fallthrough
        case .atmosphere_relative_vorticity_500hPa: fallthrough
        case .atmosphere_relative_vorticity_300hPa: fallthrough
        case .atmosphere_relative_vorticity_250hPa: fallthrough
        case .atmosphere_relative_vorticity_200hPa: fallthrough
        case .atmosphere_relative_vorticity_50hPa: return .perSecond
        case .divergence_of_wind_1000hPa: fallthrough
        case .divergence_of_wind_925hPa: fallthrough
        case .divergence_of_wind_850hPa: fallthrough
        case .divergence_of_wind_700hPa: fallthrough
        case .divergence_of_wind_500hPa: fallthrough
        case .divergence_of_wind_300hPa: fallthrough
        case .divergence_of_wind_250hPa: fallthrough
        case .divergence_of_wind_200hPa: fallthrough
        case .divergence_of_wind_50hPa: return .perSecond
        }
    }
    
    var level: Int? {
        switch self {
        case .soil_temperature_0_7cm: return 0
        case .skin_temperature: return nil
        case .geopotential_height_1000hPa: return 0
        case .geopotential_height_925hPa: return 1
        case .geopotential_height_850hPa: return 2
        case .geopotential_height_700hPa: return 3
        case .geopotential_height_500hPa: return 4
        case .geopotential_height_300hPa: return 5
        case .geopotential_height_250hPa: return 6
        case .geopotential_height_200hPa: return 7
        case .geopotential_height_50hPa: return 0
        case .northward_wind_1000hPa: return 0
        case .northward_wind_925hPa: return 1
        case .northward_wind_850hPa: return 2
        case .northward_wind_700hPa: return 3
        case .northward_wind_500hPa: return 4
        case .northward_wind_300hPa: return 5
        case .northward_wind_250hPa: return 6
        case .northward_wind_200hPa: return 7
        case .northward_wind_50hPa: return 0
        case .eastward_wind_1000hPa: return 0
        case .eastward_wind_925hPa: return 1
        case .eastward_wind_850hPa: return 2
        case .eastward_wind_700hPa: return 3
        case .eastward_wind_500hPa: return 4
        case .eastward_wind_300hPa: return 5
        case .eastward_wind_250hPa: return 6
        case .eastward_wind_200hPa: return 7
        case .eastward_wind_50hPa: return 0
        case .temperature_1000hPa: return 0
        case .temperature_925hPa: return 1
        case .temperature_850hPa: return 2
        case .temperature_700hPa: return 3
        case .temperature_500hPa: return 4
        case .temperature_300hPa: return 5
        case .temperature_250hPa: return 6
        case .temperature_200hPa: return 7
        case .temperature_50hPa: return 0
        case .relative_humidity_1000hPa: return 0
        case .relative_humidity_925hPa: return 1
        case .relative_humidity_850hPa: return 2
        case .relative_humidity_700hPa: return 3
        case .relative_humidity_500hPa: return 4
        case .relative_humidity_300hPa: return 5
        case .relative_humidity_250hPa: return 6
        case .relative_humidity_200hPa: return 7
        case .relative_humidity_50hPa: return 0
        case .surface_air_pressure: return nil
        case .pressure_msl: return nil
        case .total_column_integrated_water_vapour: return nil
        case .northward_wind_10m: return nil
        case .eastward_wind_10m: return nil
        case .specific_humidity_1000hPa: return 0
        case .specific_humidity_925hPa: return 1
        case .specific_humidity_850hPa: return 2
        case .specific_humidity_700hPa: return 3
        case .specific_humidity_500hPa: return 4
        case .specific_humidity_300hPa: return 5
        case .specific_humidity_250hPa: return 6
        case .specific_humidity_200hPa: return 7
        case .specific_humidity_50hPa: return 0
        case .temperature_2m: return nil
        case .atmosphere_relative_vorticity_1000hPa: return 0
        case .atmosphere_relative_vorticity_925hPa: return 1
        case .atmosphere_relative_vorticity_850hPa: return 2
        case .atmosphere_relative_vorticity_700hPa: return 3
        case .atmosphere_relative_vorticity_500hPa: return 4
        case .atmosphere_relative_vorticity_300hPa: return 5
        case .atmosphere_relative_vorticity_250hPa: return 6
        case .atmosphere_relative_vorticity_200hPa: return 7
        case .atmosphere_relative_vorticity_50hPa: return 0
        case .divergence_of_wind_1000hPa: return 0
        case .divergence_of_wind_925hPa: return 1
        case .divergence_of_wind_850hPa: return 2
        case .divergence_of_wind_700hPa: return 3
        case .divergence_of_wind_500hPa: return 4
        case .divergence_of_wind_300hPa: return 5
        case .divergence_of_wind_250hPa: return 6
        case .divergence_of_wind_200hPa: return 7
        case .divergence_of_wind_50hPa: return 0
        }
    }
    
    var gribName: String {
        switch self {
        case .soil_temperature_0_7cm: return "st"
        case .skin_temperature: return "skt"
        case .geopotential_height_1000hPa: return "gh"
        case .geopotential_height_925hPa: return "gh"
        case .geopotential_height_850hPa: return "gh"
        case .geopotential_height_700hPa: return "gh"
        case .geopotential_height_500hPa: return "gh"
        case .geopotential_height_300hPa: return "gh"
        case .geopotential_height_250hPa: return "gh"
        case .geopotential_height_200hPa: return "gh"
        case .geopotential_height_50hPa: return "gh"
        case .northward_wind_1000hPa: return "v"
        case .northward_wind_925hPa: return "v"
        case .northward_wind_850hPa: return "v"
        case .northward_wind_700hPa: return "v"
        case .northward_wind_500hPa: return "v"
        case .northward_wind_300hPa: return "v"
        case .northward_wind_250hPa: return "v"
        case .northward_wind_200hPa: return "v"
        case .northward_wind_50hPa: return "v"
        case .eastward_wind_1000hPa: return "u"
        case .eastward_wind_925hPa: return "u"
        case .eastward_wind_850hPa: return "u"
        case .eastward_wind_700hPa: return "u"
        case .eastward_wind_500hPa: return "u"
        case .eastward_wind_300hPa: return "u"
        case .eastward_wind_250hPa: return "u"
        case .eastward_wind_200hPa: return "u"
        case .eastward_wind_50hPa: return "u"
        case .temperature_1000hPa: return "t"
        case .temperature_925hPa: return "t"
        case .temperature_850hPa: return "t"
        case .temperature_700hPa: return "t"
        case .temperature_500hPa: return "t"
        case .temperature_300hPa: return "t"
        case .temperature_250hPa: return "t"
        case .temperature_200hPa: return "t"
        case .temperature_50hPa: return "t"
        case .relative_humidity_1000hPa: return "r"
        case .relative_humidity_925hPa: return "r"
        case .relative_humidity_850hPa: return "r"
        case .relative_humidity_700hPa: return "r"
        case .relative_humidity_500hPa: return "r"
        case .relative_humidity_300hPa: return "r"
        case .relative_humidity_250hPa: return "r"
        case .relative_humidity_200hPa: return "r"
        case .relative_humidity_50hPa: return "r"
        case .surface_air_pressure: return "sp"
        case .pressure_msl: return "msl"
        case .total_column_integrated_water_vapour: return "tciwv"
        case .northward_wind_10m: return "10v"
        case .eastward_wind_10m: return "10u"
        case .specific_humidity_1000hPa: return "q"
        case .specific_humidity_925hPa: return "q"
        case .specific_humidity_850hPa: return "q"
        case .specific_humidity_700hPa: return "q"
        case .specific_humidity_500hPa: return "q"
        case .specific_humidity_300hPa: return "q"
        case .specific_humidity_250hPa: return "q"
        case .specific_humidity_200hPa: return "q"
        case .specific_humidity_50hPa: return "q"
        case .temperature_2m: return "2t"
        case .atmosphere_relative_vorticity_1000hPa: return "vo"
        case .atmosphere_relative_vorticity_925hPa: return "vo"
        case .atmosphere_relative_vorticity_850hPa: return "vo"
        case .atmosphere_relative_vorticity_700hPa: return "vo"
        case .atmosphere_relative_vorticity_500hPa: return "vo"
        case .atmosphere_relative_vorticity_300hPa: return "vo"
        case .atmosphere_relative_vorticity_250hPa: return "vo"
        case .atmosphere_relative_vorticity_200hPa: return "vo"
        case .atmosphere_relative_vorticity_50hPa: return "vo"
        case .divergence_of_wind_1000hPa: return "d"
        case .divergence_of_wind_925hPa: return "d"
        case .divergence_of_wind_850hPa: return "d"
        case .divergence_of_wind_700hPa: return "d"
        case .divergence_of_wind_500hPa: return "d"
        case .divergence_of_wind_300hPa: return "d"
        case .divergence_of_wind_250hPa: return "d"
        case .divergence_of_wind_200hPa: return "d"
        case .divergence_of_wind_50hPa: return "d"
        }
    }
    
    var scalefactor: Float {
        switch self {
            
        case .soil_temperature_0_7cm: return 20
        case .skin_temperature: return 20
        case .geopotential_height_1000hPa: fallthrough
        case .geopotential_height_925hPa: fallthrough
        case .geopotential_height_850hPa: fallthrough
        case .geopotential_height_700hPa: fallthrough
        case .geopotential_height_500hPa: fallthrough
        case .geopotential_height_300hPa: fallthrough
        case .geopotential_height_250hPa: fallthrough
        case .geopotential_height_200hPa: fallthrough
        case .geopotential_height_50hPa: return 1
        case .northward_wind_1000hPa: fallthrough
        case .northward_wind_925hPa: fallthrough
        case .northward_wind_850hPa: fallthrough
        case .northward_wind_700hPa: fallthrough
        case .northward_wind_500hPa: fallthrough
        case .northward_wind_300hPa: fallthrough
        case .northward_wind_250hPa: fallthrough
        case .northward_wind_200hPa: fallthrough
        case .northward_wind_50hPa: return 10
        case .eastward_wind_1000hPa: fallthrough
        case .eastward_wind_925hPa: fallthrough
        case .eastward_wind_850hPa: fallthrough
        case .eastward_wind_700hPa: fallthrough
        case .eastward_wind_500hPa: fallthrough
        case .eastward_wind_300hPa: fallthrough
        case .eastward_wind_250hPa: fallthrough
        case .eastward_wind_200hPa: fallthrough
        case .eastward_wind_50hPa: return 10
        case .temperature_1000hPa: fallthrough
        case .temperature_925hPa: fallthrough
        case .temperature_850hPa: fallthrough
        case .temperature_700hPa: fallthrough
        case .temperature_500hPa: fallthrough
        case .temperature_300hPa: fallthrough
        case .temperature_250hPa: fallthrough
        case .temperature_200hPa: fallthrough
        case .temperature_50hPa: return 20
        case .relative_humidity_1000hPa: fallthrough
        case .relative_humidity_925hPa: fallthrough
        case .relative_humidity_850hPa: fallthrough
        case .relative_humidity_700hPa: fallthrough
        case .relative_humidity_500hPa: fallthrough
        case .relative_humidity_300hPa: fallthrough
        case .relative_humidity_250hPa: fallthrough
        case .relative_humidity_200hPa: fallthrough
        case .relative_humidity_50hPa: return 1
        case .surface_air_pressure: return 1
        case .pressure_msl: return 1
        case .total_column_integrated_water_vapour: return 10
        case .northward_wind_10m: return 10
        case .eastward_wind_10m: return 10
        case .specific_humidity_1000hPa: fallthrough
        case .specific_humidity_925hPa: fallthrough
        case .specific_humidity_850hPa: fallthrough
        case .specific_humidity_700hPa: fallthrough
        case .specific_humidity_500hPa: fallthrough
        case .specific_humidity_300hPa: fallthrough
        case .specific_humidity_250hPa: fallthrough
        case .specific_humidity_200hPa: fallthrough
        case .specific_humidity_50hPa: return 100
        case .temperature_2m: return 20
        case .atmosphere_relative_vorticity_1000hPa: fallthrough
        case .atmosphere_relative_vorticity_925hPa: fallthrough
        case .atmosphere_relative_vorticity_850hPa: fallthrough
        case .atmosphere_relative_vorticity_700hPa: fallthrough
        case .atmosphere_relative_vorticity_500hPa: fallthrough
        case .atmosphere_relative_vorticity_300hPa: fallthrough
        case .atmosphere_relative_vorticity_250hPa: fallthrough
        case .atmosphere_relative_vorticity_200hPa: fallthrough
        case .atmosphere_relative_vorticity_50hPa: return 100
        case .divergence_of_wind_1000hPa: fallthrough
        case .divergence_of_wind_925hPa: fallthrough
        case .divergence_of_wind_850hPa: fallthrough
        case .divergence_of_wind_700hPa: fallthrough
        case .divergence_of_wind_500hPa: fallthrough
        case .divergence_of_wind_300hPa: fallthrough
        case .divergence_of_wind_250hPa: fallthrough
        case .divergence_of_wind_200hPa: fallthrough
        case .divergence_of_wind_50hPa: return 100
        }
    }
    
    var interpolation: ReaderInterpolation {
        return .hermite
    }
}


/**
 Download from
 https://confluence.ecmwf.int/display/UDOC/ECMWF+Open+Data+-+Real+Time
 https://data.ecmwf.int/forecasts/20220131/00z/0p4-beta/oper/
 
 model info (not everything is open data) https://www.ecmwf.int/en/forecasts/datasets/set-i
 */
struct DownloadEcmwfCommand: Command {
    struct Signature: CommandSignature {
        @Option(name: "run")
        var run: String?

        @Flag(name: "skip-existing")
        var skipExisting: Bool
    }

    var help: String {
        "Download a specified ecmwf model run"
    }
    
    func run(using context: CommandContext, signature: Signature) throws {
        let run = signature.run.map {
            guard let run = Int($0) else {
                fatalError("Invalid run '\($0)'")
            }
            return run
        } ?? EcmwfDomain.ifs04.lastRun
        let logger = context.application.logger

        // 18z run starts downloading on the next day
        let twoHoursAgo = Timestamp.now().add(-7200)
        let date = twoHoursAgo.with(hour: run)
        logger.info("Downloading domain ECMWF run '\(date.iso8601_YYYY_MM_dd_HH_mm)'")

        try downloadEcmwf(logger: logger, run: date, skipFilesIfExisting: signature.skipExisting)
        try convertEcmwf(logger: logger, run: date)
    }
    
    func downloadEcmwf(logger: Logger, run: Timestamp, skipFilesIfExisting: Bool) throws {
        let domain = EcmwfDomain.ifs04
        let base = "https://data.ecmwf.int/forecasts/"
        
        let dateStr = run.format_YYYYMMdd
        let curl = Curl(logger: logger)
        let downloadDirectory = "./data/ecmwf-forecast/"
        try FileManager.default.createDirectory(atPath: downloadDirectory, withIntermediateDirectories: true)
        let filenameTemp = "\(downloadDirectory)temp.grib2"
        
        let forecastSteps = domain.getDownloadForecastSteps(run: run.hour)
        
        let product = run.hour == 0 || run.hour == 12 ? "oper" : "scda"
        let runStr = run.hour.zeroPadded(len: 2)
        
        for hour in forecastSteps {
            logger.info("Downloading hour \(hour)")
            
            //https://data.ecmwf.int/forecasts/20220131/00z/0p4-beta/oper/20220131000000-0h-oper-fc.grib2
            //https://data.ecmwf.int/forecasts/20220131/00z/0p4-beta/oper/20220131000000-12h-oper-fc.grib2
            let filenameFrom = "\(base)\(dateStr)/\(runStr)z/0p4-beta/\(product)/\(dateStr)\(runStr)0000-\(hour)h-\(product)-fc.grib2"
            let filenameConverted = "\(downloadDirectory)/\(hour)h.nc"
            
            if skipFilesIfExisting && FileManager.default.fileExists(atPath: filenameConverted) {
                continue
            }
            try curl.download(
                url: filenameFrom,
                to: filenameTemp
            )
            try Process.grib2ToNetCDFInvertLatitude(in: filenameTemp, out: filenameConverted)
        }
    }
    
    func convertEcmwf(logger: Logger, run: Timestamp) throws {
        let domain = EcmwfDomain.ifs04
        let downloadDirectory = "./data/ecmwf-forecast/"
        
        let forecastSteps = domain.getDownloadForecastSteps(run: run.hour)
        let nForecastHours = forecastSteps.max()! / domain.dtHours + 1
        
        let nLocation = domain.grid.nx * domain.grid.ny
        
        /// The time data is placed in the ring
        let ringtime = run.timeIntervalSince1970 / domain.dtSeconds ..< run.timeIntervalSince1970 / domain.dtSeconds + nForecastHours
        
        try FileManager.default.createDirectory(atPath: domain.omfileDirectory, withIntermediateDirectories: true)
        let om = OmFileSplitter(basePath: domain.omfileDirectory, nLocations: nLocation, nTimePerFile: domain.omFileLength, yearlyArchivePath: nil)
        
        for variable in EcmwfVariable.allCases {
            logger.debug("Converting \(variable)")
            var data2d = Array2DFastSpace(
                data: [Float](repeating: .nan, count: nLocation * nForecastHours),
                nLocations: nLocation,
                nTime: nForecastHours
            )
            for hour in forecastSteps {
                /*if hour == 0 && variable.skipHour0 {
                    continue
                }*/
                let d = try Self.readNetcdf(file: "\(downloadDirectory)\(hour)h.nc", variable: variable.gribName, levelOffset: variable.level, nx: domain.grid.nx, ny: domain.grid.ny)
                data2d.data[(hour/domain.dtHours) * nLocation ..< (hour/domain.dtHours + 1) * nLocation] = ArraySlice(d)
            }
            
            for hour in 0..<nForecastHours {
                if forecastSteps.contains(hour * domain.dtHours) {
                    continue
                }
                switch variable.interpolation {
                case .linear:
                    for l in 0..<nLocation {
                        let prev = data2d.data[(hour-1) * nLocation + l]
                        let next = data2d.data[(hour+1) * nLocation + l]
                        data2d.data[hour * nLocation + l] = prev * 1/2 + next * 1/2
                    }
                case .hermite:
                    for l in 0..<nLocation {
                        let A = data2d.data[(hour-3 < 0 ? hour-1 : hour-3) * nLocation + l]
                        let B = data2d.data[(hour-1) * nLocation + l]
                        let C = data2d.data[(hour+1) * nLocation + l]
                        let D = data2d.data[(hour+2 >= nForecastHours ? hour+1 : hour+3) * nLocation + l]
                        let a = -A/2.0 + (3.0*B)/2.0 - (3.0*C)/2.0 + D/2.0
                        let b = A - (5.0*B)/2.0 + 2.0*C - D / 2.0
                        let c = -A/2.0 + C/2.0
                        let d = B
                        data2d.data[hour * nLocation + l] = a*0.5*0.5*0.5 + b*0.5*0.5 + c*0.5 + d
                    }
                }
                
            }
            
            /// Temperature is stored in kelvin. Convert to celsius
            if variable.rawValue.contains("temperature") {
                for i in data2d.data.indices {
                    data2d.data[i] -= 273.15
                }
            }
            
            /*#if Xcode
            try! data2d.writeNetcdf(filename: "\(EcmwfDomain.omfileDirectory)\(variable).nc", nx: domain.grid.nx, ny: domain.grid.ny)
            return
            #endif*/
            
            logger.info("Create om file")
            let startOm = DispatchTime.now()
            try om.updateFromSpaceOriented(variable: variable.nameInFiles, array2d: data2d, ringtime: ringtime, skipFirst: 0, smooth: 0, skipLast: 0, scalefactor: variable.scalefactor)
            logger.info("Update om finished in \(startOm.timeElapsedPretty())")
        }
        
        var indexTimeEnd = run.timeIntervalSince1970 + 241 * 3600
        if run.hour == 6 || run.hour == 18 {
            // run 6 and 18 only have 90 instead 240
            indexTimeEnd += (240 - 90) * 3600
        }
        let indexTimeStart = indexTimeEnd - domain.omFileLength * domain.dtSeconds + 12 * 3600
        try "\(run.timeIntervalSince1970),\(domain.omFileLength),\(indexTimeStart),\(indexTimeEnd)".write(toFile: "\(domain.omfileDirectory)init.txt", atomically: true, encoding: .utf8)
    }
    
    static func readNetcdf(file: String, variable: String, levelOffset: Int?, nx: Int, ny: Int) throws -> [Float] {
        guard let nc = try NetCDF.open(path: file, allowUpdate: false) else {
            fatalError("File \(file) does not exist")
        }
        guard let v = nc.getVariable(name: variable) else {
            fatalError("Could not find data variable with 3d/4d data")
        }
        precondition(v.dimensions[v.dimensions.count-1].length == nx)
        precondition(v.dimensions[v.dimensions.count-2].length == ny)
        guard let varFloat = v.asType(Float.self) else {
            fatalError("Netcdf variable is not float type")
        }
        /// icon-d2 total precip, aswdir and aswdifd has 15 minutes precip inside
        let offset = v.dimensions.count == 3 ? [0,0,0] : [0,levelOffset!,0,0]
        let count = v.dimensions.count == 3 ? [1,ny,nx] : [1,1,ny,nx]
        var d = try varFloat.read(offset: offset, count: count)
        for x in d.indices {
            if d[x] < -100000000 {
                d[x] = .nan
            }
        }
        return d
    }
}

extension EcmwfDomain {
    /// Based on the current time , guess the current run that should be available soon on the open-data server
    fileprivate var lastRun: Int {
        let t = Timestamp.now()
        switch self {
        case .ifs04:
            // ECMWF has a delay of 7-8 hours after initialisation
            return ((t.hour - 7 + 24) % 24) / 6 * 6
        }
    }
}
