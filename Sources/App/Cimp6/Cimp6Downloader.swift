import Foundation
import Vapor


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
 

 */

enum Cmip6Domain: String {
    case CMCC_CM2_VHR4_daily
    case FGOALS_f3_H_daily
    case HiRAM_SIT_HR_daily
    case MRI_AGCM3_2_S_daily
}

enum Cmip6Variable: String {
    case pressure_msl
    case temperature_2m_min
    case temperature_2m_max
    case temperature_2m
    case cloudcover
    case precipitation
    case runoff
    case snowfall
    case relative_humidity_min
    case relative_humidity_max
    case relative_humidity
    case windspeed_10m
    /// Total Soil Moisture Content
    case soil_moisture_total
    
    case surface_temperature
    
    /// Moisture in Upper Portion of Soil Column
    case soil_moisture_upper
    case shortwave
    case shortwave_clearsky
    
    case specific_humidity
    
    
    enum TimeType {
        case monthly
        case yearly
        case tenYearly
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
            case .snowfall:
                return .yearly
            case .relative_humidity_min:
                return .yearly
            case .relative_humidity_max:
                return .yearly
            case .relative_humidity:
                return .yearly
            case .soil_moisture_total:
                return .yearly
            case .surface_temperature:
                return .yearly
            case .soil_moisture_upper:
                return .yearly
            case .shortwave:
                return .yearly
            case .shortwave_clearsky:
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
            case .snowfall:
                return .yearly
            case .shortwave:
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
            case .snowfall:
                return .yearly
            case .relative_humidity:
                return .yearly
            case .shortwave:
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
        case .shortwave_clearsky:
            return "rsdscs"
        case .runoff:
            return "mrro"
        case .snowfall:
            return "prsn" //kg m-2 s-1
        case .soil_moisture_total:
            return "mrso" // kg m-2
        case .soil_moisture_upper: // Moisture in Upper Portion of Soil Column
            return "mrsos"
        case .shortwave:
            return "rsds"
        case .surface_temperature:
            return "tslsi"
        case .specific_humidity:
            return "huss"
        case .windspeed_10m:
            return "sfcWind"
        }
    }
}

struct DownloadCimpCommand: AsyncCommandFix {
    /// 6k locations require around 200 MB memory for a yearly time-series
    static var nLocationsPerChunk = 6_000
    
    struct Signature: CommandSignature {
        @Argument(name: "domain")
        var domain: String
        
        @Option(name: "year", short: "y", help: "Download one year")
        var year: String?
    }
    
    var help: String {
        "Download CMIP6 data and convert"
    }
    
    func run(using context: CommandContext, signature: Signature) async throws {
        let logger = context.application.logger
        
        guard let domain = Cmip6Domain.init(rawValue: signature.domain) else {
            fatalError("Invalid domain '\(signature.domain)'")
        }
        
        //let variables: [GenericVariable] = domain == .cerra ? CerraVariable.allCases : Era5Variable.allCases.filter({ $0.availableForDomain(domain: domain) })
        
        /// Make sure elevation information is present. Otherwise download it
        //try await downloadElevation(application: context.application, cdskey: cdskey, domain: domain)
        
        /// Only download one specified year
        if let yearStr = signature.year {
            if yearStr.contains("-") {
                let split = yearStr.split(separator: "-")
                guard split.count == 2 else {
                    fatalError("year invalid")
                }
                for year in Int(split[0])! ... Int(split[1])! {
                    try await runYear(application: context.application, year: year, domain: domain)
                }
            } else {
                guard let year = Int(yearStr) else {
                    fatalError("Could not convert year to integer")
                }
                try await runYear(application: context.application, year: year, domain: domain)
            }
            return
        }
        fatalError("OK")
    }
    
    func runYear(application: Application, year: Int, domain: Cmip6Domain) async throws {
        
    }
}
