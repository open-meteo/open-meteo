import Foundation
import FlatBuffers
import OpenMeteoSdk


extension CamsVariable: FlatBuffersVariable {
    func getFlatBuffersMeta() -> FlatBufferVariableMeta {
        switch self {
        case .pm10:
            return .init(variable: .pm10)
        case .pm2_5:
            return .init(variable: .pm2p5)
        case .dust:
            return .init(variable: .dust)
        case .aerosol_optical_depth:
            return .init(variable: .aerosolOpticalDepth)
        case .carbon_monoxide:
            return .init(variable: .carbonMonoxide)
        case .nitrogen_dioxide:
            return .init(variable: .nitrogenDioxide)
        case .ammonia:
            return .init(variable: .ammonia)
        case .ozone:
            return .init(variable: .ozone)
        case .sulphur_dioxide:
            return .init(variable: .sulphurDioxide)
        case .uv_index:
            return .init(variable: .uvIndex)
        case .uv_index_clear_sky:
            return .init(variable: .uvIndexClearSky)
        case .alder_pollen:
            return .init(variable: .alderPollen)
        case .birch_pollen:
            return .init(variable: .birchPollen)
        case .grass_pollen:
            return .init(variable: .grassPollen)
        case .mugwort_pollen:
            return .init(variable: .mugwortPollen)
        case .olive_pollen:
            return .init(variable: .olivePollen)
        case .ragweed_pollen:
            return .init(variable: .ragweedPollen)
        case .formaldehyde:
            return .init(variable: .formaldehyde)
        case .glyoxal:
            return .init(variable: .glyoxal)
        case .non_methane_volatile_organic_compounds:
            return .init(variable: .nonMethaneVolatileOrganicCompounds)
        case .pm10_wildfires:
            return .init(variable: .pm10Wildfires)
        case .peroxyacyl_nitrates:
            return .init(variable: .peroxyacylNitrates)
        case .secondary_inorganic_aerosol:
            return .init(variable: .secondaryInorganicAerosol)
        case .residential_elementary_carbon:
            return .init(variable: .residentialElementaryCarbon)
        case .total_elementary_carbon:
            return .init(variable: .totalElementaryCarbon)
        case .pm2_5_total_organic_matter:
            return .init(variable: .pm25TotalOrganicMatter)
        case .sea_salt_aerosol:
            return .init(variable: .seaSaltAerosol)
        case .nitrogen_monoxide:
            return .init(variable: .nitrogenMonoxide)
        case .carbon_dioxide:
            return .init(variable: .carbonDioxide)
        case .methane:
            return .init(variable: .methane)
        }
    }
}

extension CamsVariableDerived: FlatBuffersVariable {
    func getFlatBuffersMeta() -> FlatBufferVariableMeta {
        switch self {
        case .european_aqi:
            return .init(variable: .europeanAqi)
        case .european_aqi_pm2_5:
            return .init(variable: .europeanAqiPm2p5)
        case .european_aqi_pm10:
            return .init(variable: .europeanAqiPm10)
        case .european_aqi_nitrogen_dioxide:
            fallthrough
        case .european_aqi_no2:
            return .init(variable: .europeanAqiNitrogenDioxide)
        case .european_aqi_ozone:
            fallthrough
        case .european_aqi_o3:
            return .init(variable: .europeanAqiOzone)
        case .european_aqi_sulphur_dioxide:
            fallthrough
        case .european_aqi_so2:
            return .init(variable: .europeanAqiSulphurDioxide)
        case .us_aqi:
            return .init(variable: .usAqi)
        case .us_aqi_pm2_5:
            return .init(variable: .usAqiPm2p5)
        case .us_aqi_pm10:
            return .init(variable: .usAqiPm10)
        case .us_aqi_nitrogen_dioxide:
            fallthrough
        case .us_aqi_no2:
            return .init(variable: .usAqiNitrogenDioxide)
        case .us_aqi_ozone:
            fallthrough
        case .us_aqi_o3:
            return .init(variable: .usAqiOzone)
        case .us_aqi_sulphur_dioxide:
            fallthrough
        case .us_aqi_so2:
            return .init(variable: .usAqiSulphurDioxide)
        case .us_aqi_carbon_monoxide:
            fallthrough
        case .us_aqi_co:
            return .init(variable: .usAqiCarbonMonoxide)
        case .is_day:
            return .init(variable: .isDay)
        }
    }
}

extension CamsQuery.Domain: ModelFlatbufferSerialisable {
    typealias HourlyVariable = CamsReader.MixingVar
    
    typealias HourlyPressureType = ForecastPressureVariableType
    
    typealias HourlyHeightType = ForecastHeightVariableType
    
    typealias DailyVariable = ForecastVariableDaily
    
    var flatBufferModel: openmeteo_sdk_Model {
        switch self {
        case .auto:
            return .bestMatch
        case .cams_global:
            return .camsEurope
        case .cams_europe:
            return .camsGlobal
        }
    }
}
