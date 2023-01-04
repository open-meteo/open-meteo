import Foundation
import Vapor
import SwiftPFor2D
import SwiftNetCDF


/**
 https://esgf-data.dkrz.de/search/cmip6-dkrz/
 https://esgf-node.llnl.gov/search/cmip6/
 
 INTERESSTING:
 
 CMCC-CM2-VHR4 (CMCC Italy) https://www.wdc-climate.de/ui/cmip6?input=CMIP6.HighResMIP.CMCC.CMCC-CM2-VHR4
 0.3125°
 6h: 2m temp, humidity, wind, surface temp,
 daily: 2m temp, humidity. wind, precip, longwave,
 monthly: temp, clouds, precip, runoff, wind, soil moist 1 level, humidity, snow,
 NO daily min/max directly
 
 FGOALS-f3  (CAS China) https://www.wdc-climate.de/ui/cmip6?input=CMIP6.HighResMIP.CAS.FGOALS-f3-H.highresSST-future
 0.25°
 3h: air tmp, clc, wind, hum, sw
 6h: missing temperature for higher altitude,
 day: missing temperature for land,clc, wind, hum, precip, sw,
 monthly: temp, clc, wind, hum, precip,
 NO daily min/max directly
 
 HiRAM-SIT-HR (RCEC taiwan) https://www.wdc-climate.de/ui/cmip6?input=CMIP6.HighResMIP.AS-RCEC.HiRAM-SIT-HR
 0.23°
 daily: 2m temp, surface temp (min max), clc, precip, wind, snow, swrad
 monthly: 2m temp, clc, wind, hum, snow, swrad,
 
 MRI-AGCM3-2-S (MRI Japan, ) https://www.wdc-climate.de/ui/cmip6?input=CMIP6.HighResMIP.MRI.MRI-AGCM3-2-S.highresSST-present
 0.1875°
 3h: 2m temp, wind, soil moisture, hum, surface temperature
 day: temp, clc, soild moist, wind, hum, runoff, precip, snow, swrad,
 month: same
 
 MEDIUM:
 
 NICAM16-9S https://gmd.copernicus.org/articles/14/795/2021/
 0.14°, but only 2040-2050 and 1950–1960, 2000–2010 (high computational cost hindered us from running NICAM16-9S for 100 years)
 1h: precip
 3h: precip, clc, snow, swrad (+cs), temp, wind, pres, hum
 day: temp, clc, wind, precip, snow, hum, swrad,
 month: temp, (clc), precio, runoff,
 
 LESS:
 
 CESM1-CAM5-SE-HR -> old model from 2012
 native ne120 spectral element grid... 25km
 day: only ocean
 monthly: NO 2m temp, surface (min,max), clc, wind, hum, snow, swrad,
 
 HiRAM-SIT-LR: only present
 
 ACCESS-OM2-025 -> only ocean
 AWI-CM-1-1-HR: onlt oean
 
 ECMWF-IFS-HR:
 0.5°
 6h: 2m temp, wind, hum, pres
 day: 2m temp, clouds, precip, wind, hum, snow, swrad, surface temp (min/max),
 month: temp 2m, clc, wind, leaf area index, precip, runoff, soil moist, soil temp, hum,
 
 IPSL-CM6A-ATM-ICO-VHR: ipsl france: only 1950-2014
 
 MRI-AGCM3-2-H
 0.5°
 6h: pres, 2m temp, wind, hum
 day: 2m temp, clc, wind, soil moist, precip, runoff, snow, hum, swrad, (T pressure levels = only 1000hpa.. massive holes!)
 mon: 2m temp, surface temp, clc, wind, hum, swrad,
 
 
 Sizes:
 MRI: Raw 2.15TB, Compressed 413 GB
 HiRAM_SIT_HR_daily: Raw 1.3TB, Compressed 210 GB
 */

enum Cmip6Domain: String, GenericDomain {
    case CMCC_CM2_VHR4_daily
    case FGOALS_f3_H_daily
    case HiRAM_SIT_HR_daily
    case MRI_AGCM3_2_S_daily
    
    var soureName: String {
        switch self {
        case .CMCC_CM2_VHR4_daily:
            return "CMCC-CM2-VHR4"
        case .FGOALS_f3_H_daily:
            return "FGOALS-f3-H"
        case .HiRAM_SIT_HR_daily:
            return "HiRAM-SIT-HR"
        case .MRI_AGCM3_2_S_daily:
            return "MRI-AGCM3-2-S"
        }
    }
    
    var gridName: String {
        switch self {
        case .CMCC_CM2_VHR4_daily:
            return "gr"
        case .FGOALS_f3_H_daily:
            return "gr"
        case .HiRAM_SIT_HR_daily:
            return "gn"
        case .MRI_AGCM3_2_S_daily:
            return "gn"
        }
    }
    
    var institute: String {
        switch self {
        case .CMCC_CM2_VHR4_daily:
            return "CMC"
        case .FGOALS_f3_H_daily:
            return "CAS"
        case .HiRAM_SIT_HR_daily:
            return "AS-RCEC"
        case .MRI_AGCM3_2_S_daily:
            return "MRI"
        }
    }
    
    var server: String {
        switch self {
        case .CMCC_CM2_VHR4_daily:
            return "https://esgf.ceda.ac.uk/thredds/fileServer/esg_cmip6/"
        case .FGOALS_f3_H_daily:
            // only some files are on the US server
            //return "https://esgf-data1.llnl.gov/thredds/fileServer/css03_data/CMIP6/"
            return "http://esg.lasg.ac.cn/thredds/fileServer/esg_dataroot/CMIP6/"
        case .HiRAM_SIT_HR_daily:
            // or http://esgf-data04.diasjp.net/thredds/fileServer/esg_dataroot/
            return "https://esgf-data1.llnl.gov/thredds/fileServer/css03_data/CMIP6/"
        case .MRI_AGCM3_2_S_daily:
            return "https://esgf3.dkrz.de/thredds/fileServer/cmip6/"
        }
    }
    
    var omfileDirectory: String {
        return "\(OpenMeteo.dataDictionary)omfile-\(rawValue)/"
    }
    var downloadDirectory: String {
        return "\(OpenMeteo.dataDictionary)download-\(rawValue)/"
    }
    var omfileArchive: String? {
        return "\(OpenMeteo.dataDictionary)archive-\(rawValue)/"
    }
    
    var dtSeconds: Int {
        return 3600
    }
    
    var elevationFile: OmFileReader<MmapFile>? {
        return nil
    }
    
    var omFileLength: Int {
        // has no realtime updates
        return 0
    }
    
    var grid: Gridable {
        switch self {
        case .CMCC_CM2_VHR4_daily:
            return RegularGrid(nx: 900, ny: 451, latMin: -90, lonMin: -180, dx: 0.4, dy: 0.4)
        case .FGOALS_f3_H_daily:
            return RegularGrid(nx: 900, ny: 451, latMin: -90, lonMin: -180, dx: 0.4, dy: 0.4)
        case .HiRAM_SIT_HR_daily:
            return RegularGrid(nx: 900, ny: 451, latMin: -90, lonMin: -180, dx: 0.4, dy: 0.4)
        case .MRI_AGCM3_2_S_daily:
            return RegularGrid(nx: 900, ny: 451, latMin: -90, lonMin: -180, dx: 0.4, dy: 0.4)
        }
    }
}

enum Cmip6Variable: String, CaseIterable {
    case pressure_msl
    case temperature_2m_min
    case temperature_2m_max
    case temperature_2m
    case cloudcover
    case precipitation
    case runoff
    case snowfall_water_equivalent
    case relative_humidity_min
    case relative_humidity_max
    case relative_humidity
    case windspeed_10m
    
    case surface_temperature
    
    /// Moisture in Upper Portion of Soil Column.
    case soil_moisture_0_to_10cm
    case shortwave_radiation
    
    case specific_humidity
    
    
    enum TimeType {
        case monthly
        case yearly
        case tenYearly
    }
    
    func version(for domain: Cmip6Domain) -> String {
        switch domain {
        case .CMCC_CM2_VHR4_daily:
            if self == .precipitation {
                return "20210308"
            }
            return "20190725"
        case .FGOALS_f3_H_daily:
            return "20190817"
        case .HiRAM_SIT_HR_daily:
            return "20210713" // "20210707"
        case .MRI_AGCM3_2_S_daily:
            return "20190711"
        }
    }
    
    var scalefactor: Float {
        switch self {
        case .pressure_msl:
            return 10
        case .temperature_2m_min:
            return 20
        case .temperature_2m_max:
            return 20
        case .temperature_2m:
            return 20
        case .cloudcover:
            return 1
        case .precipitation:
            return 10
        case .runoff:
            return 10
        case .snowfall_water_equivalent:
            return 10
        case .relative_humidity_min:
            return 1
        case .relative_humidity_max:
            return 1
        case .relative_humidity:
            return 1
        case .windspeed_10m:
            return 10
        case .surface_temperature:
            return 20
        case .soil_moisture_0_to_10cm:
            return 1000
        case .shortwave_radiation:
            return 1
        case .specific_humidity:
            return 100
        }
    }
    
    func domainTimeRange(for domain: Cmip6Domain) -> TimeType? {
        switch domain {
        case .MRI_AGCM3_2_S_daily:
            switch self {
            case .pressure_msl:
                return .yearly
            case .temperature_2m_min:
                return .yearly
            case .temperature_2m_max:
                return .yearly
            case .temperature_2m:
                return .yearly
            case .cloudcover:
                return .yearly
            case .precipitation:
                return .yearly
            case .runoff:
                return .yearly
            case .snowfall_water_equivalent:
                return .yearly
            case .relative_humidity_min:
                return .yearly
            case .relative_humidity_max:
                return .yearly
            case .relative_humidity:
                return .yearly
            case .surface_temperature:
                return .yearly
            case .soil_moisture_0_to_10cm:
                return .yearly
            case .shortwave_radiation:
                return .yearly
            case .specific_humidity:
                return nil
            case .windspeed_10m:
                return .yearly
            }
        case .CMCC_CM2_VHR4_daily:
            switch self {
            case .relative_humidity:
                return .monthly
            case .precipitation:
                // only precip is in yearly files...
                return .yearly
            case .temperature_2m:
                return .monthly
            case .windspeed_10m:
                return .monthly
            default:
                return nil
            }
        case .FGOALS_f3_H_daily:
            // no near surface RH, only specific humidity
            switch self {
            case .specific_humidity:
                return .yearly
            case .cloudcover:
                return .yearly
            case .temperature_2m:
                return .yearly
            case .pressure_msl:
                return .yearly
            case .snowfall_water_equivalent:
                return .yearly
            case .shortwave_radiation:
                return .yearly
            case .windspeed_10m:
                return .yearly
            case .precipitation:
                return .yearly
            default:
                return nil
            }
        case .HiRAM_SIT_HR_daily:
            // no u/v wind components near surface
            switch self {
            case .temperature_2m:
                return .yearly
            case .temperature_2m_max:
                return .yearly
            case .temperature_2m_min:
                return .yearly
            case .cloudcover:
                return .yearly
            case .precipitation:
                return .yearly
            case .snowfall_water_equivalent:
                return .yearly
            case .relative_humidity:
                return .yearly
            case .shortwave_radiation:
                return .yearly
            case .windspeed_10m:
                return .yearly
            default:
                return nil
            }
        }
    }
    
    /// hourly the same but no min/max. Hourly one file per month. Daily = yearly file
    var shortname: String {
        switch self {
        case .pressure_msl:
            return "psl"
        case .temperature_2m_min:
            return "tasmin"
        case .temperature_2m_max:
            return "tasmax"
        case .temperature_2m:
            return "tas"
        case .cloudcover:
            return "clt"
        case .precipitation:
            return "pr"
        case .relative_humidity_min:
            return "hursmax"
        case .relative_humidity_max:
            return "hursmin"
        case .relative_humidity:
            return "hurs"
        case .runoff:
            return "mrro"
        case .snowfall_water_equivalent:
            return "prsn" //kg m-2 s-1
        case .soil_moisture_0_to_10cm: // Moisture in Upper Portion of Soil Column
            return "mrsos"
        case .shortwave_radiation:
            return "rsds"
        case .surface_temperature:
            return "tslsi"
        case .specific_humidity:
            return "huss"
        case .windspeed_10m:
            return "sfcWind"
        }
    }
    
    var multiplyAdd: (multiply: Float, add: Float)? {
        switch self {
        case .temperature_2m_min:
            fallthrough
        case .temperature_2m_max:
            fallthrough
        case .temperature_2m:
            return (1, -273.15)
        case .pressure_msl:
            return (1/100, 0)
        case .precipitation:
            fallthrough
        case .snowfall_water_equivalent:
            fallthrough
        case .runoff:
            return (3600*24, 0)
        default:
            return nil
        }
    }
}

struct DownloadCmipCommand: AsyncCommandFix {
    /// 6k locations require around 200 MB memory for a yearly time-series
    static var nLocationsPerChunk = 6_000
    
    struct Signature: CommandSignature {
        @Argument(name: "domain")
        var domain: String
    }
    
    var help: String {
        "Download CMIP6 data and convert"
    }
    
    func run(using context: CommandContext, signature: Signature) async throws {
        let logger = context.application.logger
        
        guard let domain = Cmip6Domain.init(rawValue: signature.domain) else {
            fatalError("Invalid domain '\(signature.domain)'")
        }

        /// Make sure elevation information is present. Otherwise download it
        //try await downloadElevation(application: context.application, cdskey: cdskey, domain: domain)
        
        guard let yearlyPath = domain.omfileArchive else {
            fatalError("yearly archive path not defined")
        }
        try FileManager.default.createDirectory(atPath: domain.downloadDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(atPath: yearlyPath, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(atPath: domain.omfileDirectory, withIntermediateDirectories: true)
        
        let curl = Curl(logger: logger, client: context.application.dedicatedHttpClient, readTimeout: 3600*3, waitAfterLastModified: nil)
        
        for variable in Cmip6Variable.allCases {
            guard let timeType = variable.domainTimeRange(for: domain) else {
                continue
            }
            
            for year in 1950...1950 { // 2014
                logger.info("Downloading \(variable) for year \(year)")
                let source = domain.soureName
                let version = variable.version(for: domain)
                let short = variable.shortname
                let server = domain.server
                let grid = domain.gridName
                
                switch timeType {
                case .monthly:
                    fatalError("monthly")
                case .yearly:
                    let url = "\(server)HighResMIP/\(domain.institute)/\(source)/highresSST-present/r1i1p1f1/day/\(short)/\(grid)/v\(version)/\(short)_day_\(source)_highresSST-present_r1i1p1f1_\(grid)_\(year)0101-\(year)1231.nc"
                    
                    let ncFile = "\(domain.downloadDirectory)\(variable.rawValue)_\(year).nc"
                    let omFile = "\(yearlyPath)\(variable.rawValue)_\(year).nc"
                    if FileManager.default.fileExists(atPath: omFile){
                        continue
                    }
                    if !FileManager.default.fileExists(atPath: ncFile) {
                        try await curl.download(url: url, toFile: "\(ncFile)~", bzip2Decode: false)
                        try FileManager.default.moveFileOverwrite(from: "\(ncFile)~", to: ncFile)
                    }
                    
                    guard let ncFile = try NetCDF.open(path: ncFile, allowUpdate: false) else {
                        fatalError("Could not open nc file for \(variable)")
                    }
                    guard let ncVar = ncFile.getVariable(name: short) else {
                        fatalError("Could not open nc variable for \(short)")
                    }
                    guard let ncFloat = ncVar.asType(Float.self) else {
                        fatalError("Not a float nc variable")
                    }
                    /// 3d spatial oriented file
                    let dim = ncVar.dimensionsFlat
                    /// transpose to fast time
                    var array = Array2DFastSpace(data: try ncFloat.read(), nLocations: dim[1]*dim[2], nTime: dim[0]).transpose()
                    if let fma = variable.multiplyAdd {
                        array.data.multiplyAdd(multiply: fma.multiply, add: fma.add)
                    }
                    
                    try OmFileWriter(dim0: array.nLocations, dim1: array.nTime, chunk0: 6, chunk1: 183).write(file: omFile, compressionType: .p4nzdec256, scalefactor: variable.scalefactor, all: array.data)
                case .tenYearly:
                    fatalError("ten yearly")
                }
                

            }
            
        }
    }
}
