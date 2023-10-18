import Foundation
import FlatBuffers
import OpenMeteoSdk


extension MultiDomains: ModelFlatbufferSerialisable {
    typealias HourlyVariable = ForecastSurfaceVariable
    
    typealias HourlyPressureType = ForecastPressureVariableType
    
    typealias DailyVariable = ForecastVariableDaily
    
    static func encodeHourly(section: ApiSection<ForecastapiResult<Self>.SurfaceAndPressureVariable>, _ fbb: inout FlatBufferBuilder) -> Offset {
        let offsets = ForecastapiResult.encode(section: section, &fbb)
        let start = openmeteo_sdk_WeatherHourly.startWeatherHourly(&fbb)
        openmeteo_sdk_WeatherHourly.add(time: section.timeFlatBuffers(), &fbb)
        for (surface, offset) in offsets.surface {
            switch surface {
            case .temperature_2m:
                openmeteo_sdk_WeatherHourly.add(temperature2m: offset, &fbb)
            case .cloudcover:
                openmeteo_sdk_WeatherHourly.add(cloudcover: offset, &fbb)
            case .cloudcover_low:
                openmeteo_sdk_WeatherHourly.add(cloudcoverLow: offset, &fbb)
            case .cloudcover_mid:
                openmeteo_sdk_WeatherHourly.add(cloudcoverMid: offset, &fbb)
            case .cloudcover_high:
                openmeteo_sdk_WeatherHourly.add(cloudcoverHigh: offset, &fbb)
            case .pressure_msl:
                openmeteo_sdk_WeatherHourly.add(pressureMsl: offset, &fbb)
            case .relativehumidity_2m:
                openmeteo_sdk_WeatherHourly.add(relativehumidity2m: offset, &fbb)
            case .precipitation:
                openmeteo_sdk_WeatherHourly.add(precipitation: offset, &fbb)
            case .precipitation_probability:
                openmeteo_sdk_WeatherHourly.add(precipitationProbability: offset, &fbb)
            case .weathercode:
                openmeteo_sdk_WeatherHourly.add(weathercode: offset, &fbb)
            case .temperature_80m:
                openmeteo_sdk_WeatherHourly.add(temperature80m: offset, &fbb)
            case .temperature_120m:
                openmeteo_sdk_WeatherHourly.add(temperature120m: offset, &fbb)
            case .temperature_180m:
                openmeteo_sdk_WeatherHourly.add(temperature180m: offset, &fbb)
            case .soil_temperature_0cm:
                openmeteo_sdk_WeatherHourly.add(soilTemperature0cm: offset, &fbb)
            case .soil_temperature_6cm:
                openmeteo_sdk_WeatherHourly.add(soilTemperature6cm: offset, &fbb)
            case .soil_temperature_18cm:
                openmeteo_sdk_WeatherHourly.add(soilTemperature18cm: offset, &fbb)
            case .soil_temperature_54cm:
                openmeteo_sdk_WeatherHourly.add(soilTemperature54cm: offset, &fbb)
            case .soil_moisture_0_1cm:
                fallthrough
            case .soil_moisture_0_to_1cm:
                openmeteo_sdk_WeatherHourly.add(soilMoisture0To1cm: offset, &fbb)
            case .soil_moisture_1_3cm:
                fallthrough
            case .soil_moisture_1_to_3cm:
                openmeteo_sdk_WeatherHourly.add(soilMoisture1To3cm: offset, &fbb)
            case .soil_moisture_3_9cm:
                fallthrough
            case .soil_moisture_3_to_9cm:
                openmeteo_sdk_WeatherHourly.add(soilMoisture3To9cm: offset, &fbb)
            case .soil_moisture_9_27cm:
                fallthrough
            case .soil_moisture_9_to_27cm:
                openmeteo_sdk_WeatherHourly.add(soilMoisture9To27cm: offset, &fbb)
            case .soil_moisture_27_81cm:
                fallthrough
            case .soil_moisture_27_to_81cm:
                openmeteo_sdk_WeatherHourly.add(soilMoisture27To81cm: offset, &fbb)
            case .snow_depth:
                openmeteo_sdk_WeatherHourly.add(snowDepth: offset, &fbb)
            case .snow_height:
                openmeteo_sdk_WeatherHourly.add(snowHeight: offset, &fbb)
            case .sensible_heatflux:
                openmeteo_sdk_WeatherHourly.add(sensibleHeatflux: offset, &fbb)
            case .latent_heatflux:
                openmeteo_sdk_WeatherHourly.add(latentHeatflux: offset, &fbb)
            case .showers:
                openmeteo_sdk_WeatherHourly.add(showers: offset, &fbb)
            case .rain:
                openmeteo_sdk_WeatherHourly.add(rain: offset, &fbb)
            case .windgusts_10m:
                openmeteo_sdk_WeatherHourly.add(windgusts10m: offset, &fbb)
            case .freezinglevel_height:
                openmeteo_sdk_WeatherHourly.add(freezinglevelHeight: offset, &fbb)
            case .dewpoint_2m:
                openmeteo_sdk_WeatherHourly.add(dewpoint2m: offset, &fbb)
            case .diffuse_radiation:
                openmeteo_sdk_WeatherHourly.add(diffuseRadiation: offset, &fbb)
            case .direct_radiation:
                openmeteo_sdk_WeatherHourly.add(directRadiation: offset, &fbb)
            case .apparent_temperature:
                openmeteo_sdk_WeatherHourly.add(apparentTemperature: offset, &fbb)
            case .windspeed_10m:
                openmeteo_sdk_WeatherHourly.add(windspeed10m: offset, &fbb)
            case .winddirection_10m:
                openmeteo_sdk_WeatherHourly.add(winddirection10m: offset, &fbb)
            case .windspeed_80m:
                openmeteo_sdk_WeatherHourly.add(windspeed80m: offset, &fbb)
            case .winddirection_80m:
                openmeteo_sdk_WeatherHourly.add(winddirection80m: offset, &fbb)
            case .windspeed_120m:
                openmeteo_sdk_WeatherHourly.add(windspeed120m: offset, &fbb)
            case .winddirection_120m:
                openmeteo_sdk_WeatherHourly.add(winddirection120m: offset, &fbb)
            case .windspeed_180m:
                openmeteo_sdk_WeatherHourly.add(windspeed180m: offset, &fbb)
            case .winddirection_180m:
                openmeteo_sdk_WeatherHourly.add(winddirection180m: offset, &fbb)
            case .direct_normal_irradiance:
                openmeteo_sdk_WeatherHourly.add(directNormalIrradiance: offset, &fbb)
            case .evapotranspiration:
                openmeteo_sdk_WeatherHourly.add(evapotranspiration: offset, &fbb)
            case .et0_fao_evapotranspiration:
                openmeteo_sdk_WeatherHourly.add(et0FaoEvapotranspiration: offset, &fbb)
            case .vapor_pressure_deficit:
                openmeteo_sdk_WeatherHourly.add(vaporPressureDeficit: offset, &fbb)
            case .shortwave_radiation:
                openmeteo_sdk_WeatherHourly.add(shortwaveRadiation: offset, &fbb)
            case .snowfall:
                openmeteo_sdk_WeatherHourly.add(snowfall: offset, &fbb)
            case .snowfall_height:
                openmeteo_sdk_WeatherHourly.add(snowfallHeight: offset, &fbb)
            case .surface_pressure:
                openmeteo_sdk_WeatherHourly.add(surfacePressure: offset, &fbb)
            case .terrestrial_radiation:
                openmeteo_sdk_WeatherHourly.add(terrestrialRadiation: offset, &fbb)
            case .terrestrial_radiation_instant:
                openmeteo_sdk_WeatherHourly.add(terrestrialRadiationInstant: offset, &fbb)
            case .shortwave_radiation_instant:
                openmeteo_sdk_WeatherHourly.add(shortwaveRadiationInstant: offset, &fbb)
            case .diffuse_radiation_instant:
                openmeteo_sdk_WeatherHourly.add(diffuseRadiationInstant: offset, &fbb)
            case .direct_radiation_instant:
                openmeteo_sdk_WeatherHourly.add(directRadiationInstant: offset, &fbb)
            case .direct_normal_irradiance_instant:
                openmeteo_sdk_WeatherHourly.add(directNormalIrradianceInstant: offset, &fbb)
            case .visibility:
                openmeteo_sdk_WeatherHourly.add(visibility: offset, &fbb)
            case .cape:
                openmeteo_sdk_WeatherHourly.add(cape: offset, &fbb)
            case .uv_index:
                openmeteo_sdk_WeatherHourly.add(uvIndex: offset, &fbb)
            case .uv_index_clear_sky:
                openmeteo_sdk_WeatherHourly.add(uvIndexClearSky: offset, &fbb)
            case .is_day:
                openmeteo_sdk_WeatherHourly.add(isDay: offset, &fbb)
            case .lightning_potential:
                openmeteo_sdk_WeatherHourly.add(lightningPotential: offset, &fbb)
            case .growing_degree_days_base_0_limit_50:
                openmeteo_sdk_WeatherHourly.add(growingDegreeDaysBase0Limit50: offset, &fbb)
            case .leaf_wetness_probability:
                openmeteo_sdk_WeatherHourly.add(leafWetnessProbability: offset, &fbb)
            case .runoff:
                openmeteo_sdk_WeatherHourly.add(runoff: offset, &fbb)
            case .skin_temperature:
                openmeteo_sdk_WeatherHourly.add(surfaceTemperature: offset, &fbb)
            case .snowfall_water_equivalent:
                openmeteo_sdk_WeatherHourly.add(snowfallWaterEquivalent: offset, &fbb)
            case .soil_moisture_0_to_100cm:
                openmeteo_sdk_WeatherHourly.add(soilMoisture0To100cm: offset, &fbb)
            case .soil_moisture_0_to_10cm:
                openmeteo_sdk_WeatherHourly.add(soilMoisture0To10cm: offset, &fbb)
            case .soil_moisture_0_to_7cm:
                openmeteo_sdk_WeatherHourly.add(soilMoisture0To7cm: offset, &fbb)
            case .soil_moisture_100_to_200cm:
                openmeteo_sdk_WeatherHourly.add(soilMoisture100To200cm: offset, &fbb)
            case .soil_moisture_100_to_255cm:
                openmeteo_sdk_WeatherHourly.add(soilMoisture100To255cm: offset, &fbb)
            case .soil_moisture_10_to_40cm:
                openmeteo_sdk_WeatherHourly.add(soilMoisture10To40cm: offset, &fbb)
            case .soil_moisture_28_to_100cm:
                openmeteo_sdk_WeatherHourly.add(soilMoisture28To100cm: offset, &fbb)
            case .soil_moisture_40_to_100cm:
                openmeteo_sdk_WeatherHourly.add(soilMoisture40To100cm: offset, &fbb)
            case .soil_moisture_7_to_28cm:
                openmeteo_sdk_WeatherHourly.add(soilMoisture7To28cm: offset, &fbb)
            case .soil_moisture_index_0_to_100cm:
                openmeteo_sdk_WeatherHourly.add(soilMoistureIndex0To100cm: offset, &fbb)
            case .soil_moisture_index_0_to_7cm:
                openmeteo_sdk_WeatherHourly.add(soilMoistureIndex0To7cm: offset, &fbb)
            case .soil_moisture_index_100_to_255cm:
                openmeteo_sdk_WeatherHourly.add(soilMoistureIndex100To255cm: offset, &fbb)
            case .soil_moisture_index_28_to_100cm:
                openmeteo_sdk_WeatherHourly.add(soilMoistureIndex28To100cm: offset, &fbb)
            case .soil_moisture_index_7_to_28cm:
                openmeteo_sdk_WeatherHourly.add(soilMoistureIndex7To28cm: offset, &fbb)
            case .soil_temperature_0_to_100cm:
                openmeteo_sdk_WeatherHourly.add(soilTemperature0To100cm: offset, &fbb)
            case .soil_temperature_0_to_10cm:
                openmeteo_sdk_WeatherHourly.add(soilTemperature0To10cm: offset, &fbb)
            case .soil_temperature_0_to_7cm:
                openmeteo_sdk_WeatherHourly.add(soilTemperature0To7cm: offset, &fbb)
            case .soil_temperature_100_to_200cm:
                openmeteo_sdk_WeatherHourly.add(soilTemperature100To200cm: offset, &fbb)
            case .soil_temperature_100_to_255cm:
                openmeteo_sdk_WeatherHourly.add(soilTemperature100To255cm: offset, &fbb)
            case .soil_temperature_10_to_40cm:
                openmeteo_sdk_WeatherHourly.add(soilTemperature10To40cm: offset, &fbb)
            case .soil_temperature_28_to_100cm:
                openmeteo_sdk_WeatherHourly.add(soilTemperature28To100cm: offset, &fbb)
            case .soil_temperature_40_to_100cm:
                openmeteo_sdk_WeatherHourly.add(soilTemperature40To100cm: offset, &fbb)
            case .soil_temperature_7_to_28cm:
                openmeteo_sdk_WeatherHourly.add(soilTemperature7To28cm: offset, &fbb)
            case .surface_air_pressure:
                openmeteo_sdk_WeatherHourly.add(surfacePressure: offset, &fbb)
            case .surface_temperature:
                openmeteo_sdk_WeatherHourly.add(surfaceTemperature: offset, &fbb)
            case .temperature_40m:
                openmeteo_sdk_WeatherHourly.add(temperature40m: offset, &fbb)
            case .total_column_integrated_water_vapour:
                openmeteo_sdk_WeatherHourly.add(totalColumnIntegratedWaterVapour: offset, &fbb)
            case .updraft:
                openmeteo_sdk_WeatherHourly.add(updraft: offset, &fbb)
            case .winddirection_100m:
                openmeteo_sdk_WeatherHourly.add(winddirection100m: offset, &fbb)
            case .winddirection_150m:
                openmeteo_sdk_WeatherHourly.add(winddirection150m: offset, &fbb)
            case .winddirection_200m:
                openmeteo_sdk_WeatherHourly.add(winddirection200m: offset, &fbb)
            case .winddirection_20m:
                openmeteo_sdk_WeatherHourly.add(winddirection20m: offset, &fbb)
            case .winddirection_40m:
                openmeteo_sdk_WeatherHourly.add(winddirection40m: offset, &fbb)
            case .winddirection_50m:
                openmeteo_sdk_WeatherHourly.add(winddirection50m: offset, &fbb)
            case .windspeed_100m:
                openmeteo_sdk_WeatherHourly.add(windspeed100m: offset, &fbb)
            case .windspeed_150m:
                openmeteo_sdk_WeatherHourly.add(windspeed150m: offset, &fbb)
            case .windspeed_200m:
                openmeteo_sdk_WeatherHourly.add(windspeed200m: offset, &fbb)
            case .windspeed_20m:
                openmeteo_sdk_WeatherHourly.add(windspeed20m: offset, &fbb)
            case .windspeed_40m:
                openmeteo_sdk_WeatherHourly.add(windspeed40m: offset, &fbb)
            case .windspeed_50m:
                openmeteo_sdk_WeatherHourly.add(windspeed50m: offset, &fbb)
            case .temperature:
                openmeteo_sdk_WeatherHourly.add(temperature2m: offset, &fbb)
            case .windspeed:
                openmeteo_sdk_WeatherHourly.add(windspeed10m: offset, &fbb)
            case .winddirection:
                openmeteo_sdk_WeatherHourly.add(winddirection10m: offset, &fbb)
            case .temperature_100m:
                openmeteo_sdk_WeatherHourly.add(temperature100m: offset, &fbb)
            case .temperature_150m:
                openmeteo_sdk_WeatherHourly.add(temperature150m: offset, &fbb)
            case .temperature_20m:
                openmeteo_sdk_WeatherHourly.add(temperature20m: offset, &fbb)
            case .temperature_200m:
                openmeteo_sdk_WeatherHourly.add(temperature200m: offset, &fbb)
            case .temperature_50m:
                openmeteo_sdk_WeatherHourly.add(temperature50m: offset, &fbb)
            case .lifted_index:
                openmeteo_sdk_WeatherHourly.add(liftedIndex: offset, &fbb)
            case .wet_bulb_temperature_2m:
                openmeteo_sdk_WeatherHourly.add(wetBulbTemperature2m: offset, &fbb)
            }
        }
        for (pressure, offset) in offsets.pressure {
            switch pressure {
            case .temperature:
                openmeteo_sdk_WeatherHourly.add(pressureLevelTemperature: offset, &fbb)
            case .geopotential_height:
                openmeteo_sdk_WeatherHourly.add(pressureLevelGeopotentialHeight: offset, &fbb)
            case .relativehumidity:
                openmeteo_sdk_WeatherHourly.add(pressureLevelRelativehumidity: offset, &fbb)
            case .windspeed:
                openmeteo_sdk_WeatherHourly.add(pressureLevelWindspeed: offset, &fbb)
            case .winddirection:
                openmeteo_sdk_WeatherHourly.add(pressureLevelWinddirection: offset, &fbb)
            case .dewpoint:
                openmeteo_sdk_WeatherHourly.add(pressureLevelDewpoint: offset, &fbb)
            case .cloudcover:
                openmeteo_sdk_WeatherHourly.add(pressureLevelCloudcover: offset, &fbb)
            case .vertical_velocity:
                openmeteo_sdk_WeatherHourly.add(pressureLevelVerticalVelocity: offset, &fbb)
            case .relative_humidity:
                openmeteo_sdk_WeatherHourly.add(pressureLevelRelativehumidity: offset, &fbb)
            }
        }
        return openmeteo_sdk_WeatherHourly.endWeatherHourly(&fbb, start: start)
    }
    
    static func encodeCurrent(section: ApiSectionSingle<ForecastapiResult<Self>.SurfaceAndPressureVariable>, _ fbb: inout FlatBufferBuilder) throws -> Offset {
        let start = openmeteo_sdk_WeatherCurrent.startWeatherCurrent(&fbb)
        openmeteo_sdk_WeatherCurrent.add(time: Int64(section.time.timeIntervalSince1970), &fbb)
        openmeteo_sdk_WeatherCurrent.add(interval: Int32(section.dtSeconds), &fbb)
        for column in section.columns {
            switch column.variable {
            case .surface(let surface):
                let v = openmeteo_sdk_ValueAndUnit(value: column.value, unit: column.unit)
                switch surface {
                case .temperature_2m:
                    openmeteo_sdk_WeatherCurrent.add(temperature2m: v, &fbb)
                case .cloudcover:
                    openmeteo_sdk_WeatherCurrent.add(cloudcover: v, &fbb)
                case .cloudcover_low:
                    openmeteo_sdk_WeatherCurrent.add(cloudcoverLow: v, &fbb)
                case .cloudcover_mid:
                    openmeteo_sdk_WeatherCurrent.add(cloudcoverMid: v, &fbb)
                case .cloudcover_high:
                    openmeteo_sdk_WeatherCurrent.add(cloudcoverHigh: v, &fbb)
                case .pressure_msl:
                    openmeteo_sdk_WeatherCurrent.add(pressureMsl: v, &fbb)
                case .relativehumidity_2m:
                    openmeteo_sdk_WeatherCurrent.add(relativehumidity2m: v, &fbb)
                case .precipitation:
                    openmeteo_sdk_WeatherCurrent.add(precipitation: v, &fbb)
                case .precipitation_probability:
                    openmeteo_sdk_WeatherCurrent.add(precipitationProbability: v, &fbb)
                case .weathercode:
                    openmeteo_sdk_WeatherCurrent.add(weathercode: v, &fbb)
                case .temperature_80m:
                    openmeteo_sdk_WeatherCurrent.add(temperature80m: v, &fbb)
                case .temperature_120m:
                    openmeteo_sdk_WeatherCurrent.add(temperature120m: v, &fbb)
                case .temperature_180m:
                    openmeteo_sdk_WeatherCurrent.add(temperature180m: v, &fbb)
                case .soil_temperature_0cm:
                    openmeteo_sdk_WeatherCurrent.add(soilTemperature0cm: v, &fbb)
                case .soil_temperature_6cm:
                    openmeteo_sdk_WeatherCurrent.add(soilTemperature6cm: v, &fbb)
                case .soil_temperature_18cm:
                    openmeteo_sdk_WeatherCurrent.add(soilTemperature18cm: v, &fbb)
                case .soil_temperature_54cm:
                    openmeteo_sdk_WeatherCurrent.add(soilTemperature54cm: v, &fbb)
                case .soil_moisture_0_1cm:
                    fallthrough
                case .soil_moisture_0_to_1cm:
                    openmeteo_sdk_WeatherCurrent.add(soilMoisture0To1cm: v, &fbb)
                case .soil_moisture_1_3cm:
                    fallthrough
                case .soil_moisture_1_to_3cm:
                    openmeteo_sdk_WeatherCurrent.add(soilMoisture1To3cm: v, &fbb)
                case .soil_moisture_3_9cm:
                    fallthrough
                case .soil_moisture_3_to_9cm:
                    openmeteo_sdk_WeatherCurrent.add(soilMoisture3To9cm: v, &fbb)
                case .soil_moisture_9_27cm:
                    fallthrough
                case .soil_moisture_9_to_27cm:
                    openmeteo_sdk_WeatherCurrent.add(soilMoisture9To27cm: v, &fbb)
                case .soil_moisture_27_81cm:
                    fallthrough
                case .soil_moisture_27_to_81cm:
                    openmeteo_sdk_WeatherCurrent.add(soilMoisture27To81cm: v, &fbb)
                case .snow_depth:
                    openmeteo_sdk_WeatherCurrent.add(snowDepth: v, &fbb)
                case .snow_height:
                    openmeteo_sdk_WeatherCurrent.add(snowHeight: v, &fbb)
                case .sensible_heatflux:
                    openmeteo_sdk_WeatherCurrent.add(sensibleHeatflux: v, &fbb)
                case .latent_heatflux:
                    openmeteo_sdk_WeatherCurrent.add(latentHeatflux: v, &fbb)
                case .showers:
                    openmeteo_sdk_WeatherCurrent.add(showers: v, &fbb)
                case .rain:
                    openmeteo_sdk_WeatherCurrent.add(rain: v, &fbb)
                case .windgusts_10m:
                    openmeteo_sdk_WeatherCurrent.add(windgusts10m: v, &fbb)
                case .freezinglevel_height:
                    openmeteo_sdk_WeatherCurrent.add(freezinglevelHeight: v, &fbb)
                case .dewpoint_2m:
                    openmeteo_sdk_WeatherCurrent.add(dewpoint2m: v, &fbb)
                case .diffuse_radiation:
                    openmeteo_sdk_WeatherCurrent.add(diffuseRadiation: v, &fbb)
                case .direct_radiation:
                    openmeteo_sdk_WeatherCurrent.add(directRadiation: v, &fbb)
                case .apparent_temperature:
                    openmeteo_sdk_WeatherCurrent.add(apparentTemperature: v, &fbb)
                case .windspeed_10m:
                    openmeteo_sdk_WeatherCurrent.add(windspeed10m: v, &fbb)
                case .winddirection_10m:
                    openmeteo_sdk_WeatherCurrent.add(winddirection10m: v, &fbb)
                case .windspeed_80m:
                    openmeteo_sdk_WeatherCurrent.add(windspeed80m: v, &fbb)
                case .winddirection_80m:
                    openmeteo_sdk_WeatherCurrent.add(winddirection80m: v, &fbb)
                case .windspeed_120m:
                    openmeteo_sdk_WeatherCurrent.add(windspeed120m: v, &fbb)
                case .winddirection_120m:
                    openmeteo_sdk_WeatherCurrent.add(winddirection120m: v, &fbb)
                case .windspeed_180m:
                    openmeteo_sdk_WeatherCurrent.add(windspeed180m: v, &fbb)
                case .winddirection_180m:
                    openmeteo_sdk_WeatherCurrent.add(winddirection180m: v, &fbb)
                case .direct_normal_irradiance:
                    openmeteo_sdk_WeatherCurrent.add(directNormalIrradiance: v, &fbb)
                case .evapotranspiration:
                    openmeteo_sdk_WeatherCurrent.add(evapotranspiration: v, &fbb)
                case .et0_fao_evapotranspiration:
                    openmeteo_sdk_WeatherCurrent.add(et0FaoEvapotranspiration: v, &fbb)
                case .vapor_pressure_deficit:
                    openmeteo_sdk_WeatherCurrent.add(vaporPressureDeficit: v, &fbb)
                case .shortwave_radiation:
                    openmeteo_sdk_WeatherCurrent.add(shortwaveRadiation: v, &fbb)
                case .snowfall:
                    openmeteo_sdk_WeatherCurrent.add(snowfall: v, &fbb)
                case .snowfall_height:
                    openmeteo_sdk_WeatherCurrent.add(snowfallHeight: v, &fbb)
                case .surface_pressure:
                    openmeteo_sdk_WeatherCurrent.add(surfacePressure: v, &fbb)
                case .terrestrial_radiation:
                    openmeteo_sdk_WeatherCurrent.add(terrestrialRadiation: v, &fbb)
                case .terrestrial_radiation_instant:
                    openmeteo_sdk_WeatherCurrent.add(terrestrialRadiationInstant: v, &fbb)
                case .shortwave_radiation_instant:
                    openmeteo_sdk_WeatherCurrent.add(shortwaveRadiationInstant: v, &fbb)
                case .diffuse_radiation_instant:
                    openmeteo_sdk_WeatherCurrent.add(diffuseRadiationInstant: v, &fbb)
                case .direct_radiation_instant:
                    openmeteo_sdk_WeatherCurrent.add(directRadiationInstant: v, &fbb)
                case .direct_normal_irradiance_instant:
                    openmeteo_sdk_WeatherCurrent.add(directNormalIrradianceInstant: v, &fbb)
                case .visibility:
                    openmeteo_sdk_WeatherCurrent.add(visibility: v, &fbb)
                case .cape:
                    openmeteo_sdk_WeatherCurrent.add(cape: v, &fbb)
                case .uv_index:
                    openmeteo_sdk_WeatherCurrent.add(uvIndex: v, &fbb)
                case .uv_index_clear_sky:
                    openmeteo_sdk_WeatherCurrent.add(uvIndexClearSky: v, &fbb)
                case .is_day:
                    openmeteo_sdk_WeatherCurrent.add(isDay: v, &fbb)
                case .lightning_potential:
                    openmeteo_sdk_WeatherCurrent.add(lightningPotential: v, &fbb)
                case .growing_degree_days_base_0_limit_50:
                    openmeteo_sdk_WeatherCurrent.add(growingDegreeDaysBase0Limit50: v, &fbb)
                case .leaf_wetness_probability:
                    openmeteo_sdk_WeatherCurrent.add(leafWetnessProbability: v, &fbb)
                case .runoff:
                    openmeteo_sdk_WeatherCurrent.add(runoff: v, &fbb)
                case .skin_temperature:
                    openmeteo_sdk_WeatherCurrent.add(surfaceTemperature: v, &fbb)
                case .snowfall_water_equivalent:
                    openmeteo_sdk_WeatherCurrent.add(snowfallWaterEquivalent: v, &fbb)
                case .soil_moisture_0_to_100cm:
                    openmeteo_sdk_WeatherCurrent.add(soilMoisture0To100cm: v, &fbb)
                case .soil_moisture_0_to_10cm:
                    openmeteo_sdk_WeatherCurrent.add(soilMoisture0To10cm: v, &fbb)
                case .soil_moisture_0_to_7cm:
                    openmeteo_sdk_WeatherCurrent.add(soilMoisture0To7cm: v, &fbb)
                case .soil_moisture_100_to_200cm:
                    openmeteo_sdk_WeatherCurrent.add(soilMoisture100To200cm: v, &fbb)
                case .soil_moisture_100_to_255cm:
                    openmeteo_sdk_WeatherCurrent.add(soilMoisture100To255cm: v, &fbb)
                case .soil_moisture_10_to_40cm:
                    openmeteo_sdk_WeatherCurrent.add(soilMoisture10To40cm: v, &fbb)
                case .soil_moisture_28_to_100cm:
                    openmeteo_sdk_WeatherCurrent.add(soilMoisture28To100cm: v, &fbb)
                case .soil_moisture_40_to_100cm:
                    openmeteo_sdk_WeatherCurrent.add(soilMoisture40To100cm: v, &fbb)
                case .soil_moisture_7_to_28cm:
                    openmeteo_sdk_WeatherCurrent.add(soilMoisture7To28cm: v, &fbb)
                case .soil_moisture_index_0_to_100cm:
                    openmeteo_sdk_WeatherCurrent.add(soilMoistureIndex0To100cm: v, &fbb)
                case .soil_moisture_index_0_to_7cm:
                    openmeteo_sdk_WeatherCurrent.add(soilMoistureIndex0To7cm: v, &fbb)
                case .soil_moisture_index_100_to_255cm:
                    openmeteo_sdk_WeatherCurrent.add(soilMoistureIndex100To255cm: v, &fbb)
                case .soil_moisture_index_28_to_100cm:
                    openmeteo_sdk_WeatherCurrent.add(soilMoistureIndex28To100cm: v, &fbb)
                case .soil_moisture_index_7_to_28cm:
                    openmeteo_sdk_WeatherCurrent.add(soilMoistureIndex7To28cm: v, &fbb)
                case .soil_temperature_0_to_100cm:
                    openmeteo_sdk_WeatherCurrent.add(soilTemperature0To100cm: v, &fbb)
                case .soil_temperature_0_to_10cm:
                    openmeteo_sdk_WeatherCurrent.add(soilTemperature0To10cm: v, &fbb)
                case .soil_temperature_0_to_7cm:
                    openmeteo_sdk_WeatherCurrent.add(soilTemperature0To7cm: v, &fbb)
                case .soil_temperature_100_to_200cm:
                    openmeteo_sdk_WeatherCurrent.add(soilTemperature100To200cm: v, &fbb)
                case .soil_temperature_100_to_255cm:
                    openmeteo_sdk_WeatherCurrent.add(soilTemperature100To255cm: v, &fbb)
                case .soil_temperature_10_to_40cm:
                    openmeteo_sdk_WeatherCurrent.add(soilTemperature10To40cm: v, &fbb)
                case .soil_temperature_28_to_100cm:
                    openmeteo_sdk_WeatherCurrent.add(soilTemperature28To100cm: v, &fbb)
                case .soil_temperature_40_to_100cm:
                    openmeteo_sdk_WeatherCurrent.add(soilTemperature40To100cm: v, &fbb)
                case .soil_temperature_7_to_28cm:
                    openmeteo_sdk_WeatherCurrent.add(soilTemperature7To28cm: v, &fbb)
                case .surface_air_pressure:
                    openmeteo_sdk_WeatherCurrent.add(surfacePressure: v, &fbb)
                case .surface_temperature:
                    openmeteo_sdk_WeatherCurrent.add(surfaceTemperature: v, &fbb)
                case .temperature_40m:
                    openmeteo_sdk_WeatherCurrent.add(temperature40m: v, &fbb)
                case .total_column_integrated_water_vapour:
                    openmeteo_sdk_WeatherCurrent.add(totalColumnIntegratedWaterVapour: v, &fbb)
                case .updraft:
                    openmeteo_sdk_WeatherCurrent.add(updraft: v, &fbb)
                case .winddirection_100m:
                    openmeteo_sdk_WeatherCurrent.add(winddirection100m: v, &fbb)
                case .winddirection_150m:
                    openmeteo_sdk_WeatherCurrent.add(winddirection150m: v, &fbb)
                case .winddirection_200m:
                    openmeteo_sdk_WeatherCurrent.add(winddirection200m: v, &fbb)
                case .winddirection_20m:
                    openmeteo_sdk_WeatherCurrent.add(winddirection20m: v, &fbb)
                case .winddirection_40m:
                    openmeteo_sdk_WeatherCurrent.add(winddirection40m: v, &fbb)
                case .winddirection_50m:
                    openmeteo_sdk_WeatherCurrent.add(winddirection50m: v, &fbb)
                case .windspeed_100m:
                    openmeteo_sdk_WeatherCurrent.add(windspeed100m: v, &fbb)
                case .windspeed_150m:
                    openmeteo_sdk_WeatherCurrent.add(windspeed150m: v, &fbb)
                case .windspeed_200m:
                    openmeteo_sdk_WeatherCurrent.add(windspeed200m: v, &fbb)
                case .windspeed_20m:
                    openmeteo_sdk_WeatherCurrent.add(windspeed20m: v, &fbb)
                case .windspeed_40m:
                    openmeteo_sdk_WeatherCurrent.add(windspeed40m: v, &fbb)
                case .windspeed_50m:
                    openmeteo_sdk_WeatherCurrent.add(windspeed50m: v, &fbb)
                case .temperature:
                    openmeteo_sdk_WeatherCurrent.add(temperature2m: v, &fbb)
                case .windspeed:
                    openmeteo_sdk_WeatherCurrent.add(windspeed10m: v, &fbb)
                case .winddirection:
                    openmeteo_sdk_WeatherCurrent.add(winddirection10m: v, &fbb)
                case .temperature_100m:
                    openmeteo_sdk_WeatherCurrent.add(temperature100m: v, &fbb)
                case .temperature_150m:
                    openmeteo_sdk_WeatherCurrent.add(temperature150m: v, &fbb)
                case .temperature_20m:
                    openmeteo_sdk_WeatherCurrent.add(temperature20m: v, &fbb)
                case .temperature_200m:
                    openmeteo_sdk_WeatherCurrent.add(temperature200m: v, &fbb)
                case .lifted_index:
                    openmeteo_sdk_WeatherCurrent.add(liftedIndex: v, &fbb)
                case .temperature_50m:
                    openmeteo_sdk_WeatherCurrent.add(temperature50m: v, &fbb)
                case .wet_bulb_temperature_2m:
                    openmeteo_sdk_WeatherCurrent.add(wetBulbTemperature2m: v, &fbb)
                }
            case .pressure(_):
                throw ForecastapiError.generic(message: "Pressure level variables currently not supported for flatbuffers encoding in current block")
            }
        }
        return openmeteo_sdk_WeatherCurrent.endWeatherCurrent(&fbb, start: start)
    }
    
    static func encodeDaily(section: ApiSection<DailyVariable>, _ fbb: inout FlatBufferBuilder) -> Offset {
        let offsets = ForecastapiResult<Self>.encode(section: section, &fbb)
        let start = openmeteo_sdk_WeatherDaily.startWeatherDaily(&fbb)
        openmeteo_sdk_WeatherDaily.add(time: section.timeFlatBuffers(), &fbb)
        for (variable, offset) in zip(section.columns, offsets) {
            switch variable.variable {
            case .temperature_2m_max:
                openmeteo_sdk_WeatherDaily.add(temperature2mMax: offset, &fbb)
            case .temperature_2m_min:
                openmeteo_sdk_WeatherDaily.add(temperature2mMin: offset, &fbb)
            case .temperature_2m_mean:
                openmeteo_sdk_WeatherDaily.add(temperature2mMean: offset, &fbb)
            case .apparent_temperature_max:
                openmeteo_sdk_WeatherDaily.add(apparentTemperatureMax: offset, &fbb)
            case .apparent_temperature_min:
                openmeteo_sdk_WeatherDaily.add(apparentTemperatureMin: offset, &fbb)
            case .apparent_temperature_mean:
                openmeteo_sdk_WeatherDaily.add(apparentTemperatureMean: offset, &fbb)
            case .precipitation_sum:
                openmeteo_sdk_WeatherDaily.add(precipitationSum: offset, &fbb)
            case .precipitation_probability_max:
                openmeteo_sdk_WeatherDaily.add(precipitationProbabilityMax: offset, &fbb)
            case .precipitation_probability_min:
                openmeteo_sdk_WeatherDaily.add(precipitationProbabilityMin: offset, &fbb)
            case .precipitation_probability_mean:
                openmeteo_sdk_WeatherDaily.add(precipitationProbabilityMean: offset, &fbb)
            case .snowfall_sum:
                openmeteo_sdk_WeatherDaily.add(snowfallSum: offset, &fbb)
            case .rain_sum:
                openmeteo_sdk_WeatherDaily.add(rainSum: offset, &fbb)
            case .showers_sum:
                openmeteo_sdk_WeatherDaily.add(showersSum: offset, &fbb)
            case .weathercode:
                openmeteo_sdk_WeatherDaily.add(weathercode: offset, &fbb)
            case .shortwave_radiation_sum:
                openmeteo_sdk_WeatherDaily.add(shortwaveRadiationSum: offset, &fbb)
            case .windspeed_10m_max:
                openmeteo_sdk_WeatherDaily.add(windspeed10mMax: offset, &fbb)
            case .windspeed_10m_min:
                openmeteo_sdk_WeatherDaily.add(windspeed10mMin: offset, &fbb)
            case .windspeed_10m_mean:
                openmeteo_sdk_WeatherDaily.add(windspeed10mMean: offset, &fbb)
            case .windgusts_10m_max:
                openmeteo_sdk_WeatherDaily.add(windgusts10mMax: offset, &fbb)
            case .windgusts_10m_min:
                openmeteo_sdk_WeatherDaily.add(windgusts10mMin: offset, &fbb)
            case .windgusts_10m_mean:
                openmeteo_sdk_WeatherDaily.add(windgusts10mMean: offset, &fbb)
            case .winddirection_10m_dominant:
                openmeteo_sdk_WeatherDaily.add(winddirection10mDominant: offset, &fbb)
            case .precipitation_hours:
                openmeteo_sdk_WeatherDaily.add(precipitationSum: offset, &fbb)
            case .sunrise:
                openmeteo_sdk_WeatherDaily.add(sunrise: offset, &fbb)
            case .sunset:
                openmeteo_sdk_WeatherDaily.add(sunset: offset, &fbb)
            case .et0_fao_evapotranspiration:
                openmeteo_sdk_WeatherDaily.add(et0FaoEvapotranspiration: offset, &fbb)
            case .visibility_max:
                openmeteo_sdk_WeatherDaily.add(visibilityMax: offset, &fbb)
            case .visibility_min:
                openmeteo_sdk_WeatherDaily.add(visibilityMin: offset, &fbb)
            case .visibility_mean:
                openmeteo_sdk_WeatherDaily.add(visibilityMean: offset, &fbb)
            case .pressure_msl_max:
                openmeteo_sdk_WeatherDaily.add(pressureMslMax: offset, &fbb)
            case .pressure_msl_min:
                openmeteo_sdk_WeatherDaily.add(pressureMslMin: offset, &fbb)
            case .pressure_msl_mean:
                openmeteo_sdk_WeatherDaily.add(pressureMslMean: offset, &fbb)
            case .surface_pressure_max:
                openmeteo_sdk_WeatherDaily.add(surfacePressureMax: offset, &fbb)
            case .surface_pressure_min:
                openmeteo_sdk_WeatherDaily.add(surfacePressureMin: offset, &fbb)
            case .surface_pressure_mean:
                openmeteo_sdk_WeatherDaily.add(surfacePressureMean: offset, &fbb)
            case .cape_max:
                openmeteo_sdk_WeatherDaily.add(capeMax: offset, &fbb)
            case .cape_min:
                openmeteo_sdk_WeatherDaily.add(capeMin: offset, &fbb)
            case .cape_mean:
                openmeteo_sdk_WeatherDaily.add(capeMean: offset, &fbb)
            case .cloudcover_max:
                openmeteo_sdk_WeatherDaily.add(cloudcoverMax: offset, &fbb)
            case .cloudcover_min:
                openmeteo_sdk_WeatherDaily.add(cloudcoverMin: offset, &fbb)
            case .cloudcover_mean:
                openmeteo_sdk_WeatherDaily.add(cloudcoverMean: offset, &fbb)
            case .uv_index_max:
                openmeteo_sdk_WeatherDaily.add(uvIndexMax: offset, &fbb)
            case .uv_index_clear_sky_max:
                openmeteo_sdk_WeatherDaily.add(uvIndexClearSkyMax: offset, &fbb)
            case .dewpoint_2m_max:
                openmeteo_sdk_WeatherDaily.add(dewpoint2mMax: offset, &fbb)
            case .dewpoint_2m_mean:
                openmeteo_sdk_WeatherDaily.add(dewpoint2mMean: offset, &fbb)
            case .dewpoint_2m_min:
                openmeteo_sdk_WeatherDaily.add(dewpoint2mMin: offset, &fbb)
            case .et0_fao_evapotranspiration_sum:
                openmeteo_sdk_WeatherDaily.add(et0FaoEvapotranspirationSum: offset, &fbb)
            case .growing_degree_days_base_0_limit_50:
                openmeteo_sdk_WeatherDaily.add(growingDegreeDaysBase0Limit50: offset, &fbb)
            case .leaf_wetness_probability_mean:
                openmeteo_sdk_WeatherDaily.add(leafWetnessProbabilityMean: offset, &fbb)
            case .relative_humidity_2m_max:
                openmeteo_sdk_WeatherDaily.add(relativeHumidity2mMax: offset, &fbb)
            case .relative_humidity_2m_mean:
                openmeteo_sdk_WeatherDaily.add(relativeHumidity2mMean: offset, &fbb)
            case .relative_humidity_2m_min:
                openmeteo_sdk_WeatherDaily.add(relativeHumidity2mMin: offset, &fbb)
            case .snowfall_water_equivalent_sum:
                openmeteo_sdk_WeatherDaily.add(snowfallWaterEquivalentSum: offset, &fbb)
            case .soil_moisture_0_to_100cm_mean:
                openmeteo_sdk_WeatherDaily.add(soilMoisture0To100cmMean: offset, &fbb)
            case .soil_moisture_0_to_10cm_mean:
                openmeteo_sdk_WeatherDaily.add(soilMoisture0To10cmMean: offset, &fbb)
            case .soil_moisture_0_to_7cm_mean:
                openmeteo_sdk_WeatherDaily.add(soilMoisture0To7cmMean:  offset, &fbb)
            case .soil_moisture_28_to_100cm_mean:
                openmeteo_sdk_WeatherDaily.add(soilMoisture28To100cmMean: offset, &fbb)
            case .soil_moisture_7_to_28cm_mean:
                openmeteo_sdk_WeatherDaily.add(soilMoisture7To28cmMean: offset, &fbb)
            case .soil_moisture_index_0_to_100cm_mean:
                openmeteo_sdk_WeatherDaily.add(soilMoistureIndex0To100cmMean: offset, &fbb)
            case .soil_moisture_index_0_to_7cm_mean:
                openmeteo_sdk_WeatherDaily.add(soilMoistureIndex0To7cmMean: offset, &fbb)
            case .soil_moisture_index_100_to_255cm_mean:
                openmeteo_sdk_WeatherDaily.add(soilMoistureIndex100To255cmMean: offset, &fbb)
            case .soil_moisture_index_28_to_100cm_mean:
                openmeteo_sdk_WeatherDaily.add(soilMoistureIndex28To100cmMean: offset, &fbb)
            case .soil_moisture_index_7_to_28cm_mean:
                openmeteo_sdk_WeatherDaily.add(soilMoistureIndex7To28cmMean: offset, &fbb)
            case .soil_temperature_0_to_100cm_mean:
                openmeteo_sdk_WeatherDaily.add(soilTemperature0To100cmMean: offset, &fbb)
            case .soil_temperature_0_to_7cm_mean:
                openmeteo_sdk_WeatherDaily.add(soilTemperature0To7cmMean: offset, &fbb)
            case .soil_temperature_28_to_100cm_mean:
                openmeteo_sdk_WeatherDaily.add(soilTemperature28To100cmMean: offset, &fbb)
            case .soil_temperature_7_to_28cm_mean:
                openmeteo_sdk_WeatherDaily.add(soilTemperature7To28cmMean: offset, &fbb)
            case .updraft_max:
                openmeteo_sdk_WeatherDaily.add(updraftMax: offset, &fbb)
            case .vapor_pressure_deficit_max:
                openmeteo_sdk_WeatherDaily.add(vaporPressureDeficitMax: offset, &fbb)
            case .wet_bulb_temperature_2m_max:
                openmeteo_sdk_WeatherDaily.add(wetBulbTemperature2mMax: offset, &fbb)
            case .wet_bulb_temperature_2m_mean:
                openmeteo_sdk_WeatherDaily.add(wetBulbTemperature2mMean: offset, &fbb)
            case .wet_bulb_temperature_2m_min:
                openmeteo_sdk_WeatherDaily.add(wetBulbTemperature2mMin: offset, &fbb)
            }
        }
        return openmeteo_sdk_WeatherDaily.endWeatherDaily(&fbb, start: start)
    }
    
    static func writeToFlatbuffer(section: ForecastapiResult<Self>.PerModel, _ fbb: inout FlatBufferBuilder, timezone: TimezoneWithOffset, fixedGenerationTime: Double?) throws {
        let generationTimeStart = Date()
        let hourly = (try section.hourly?()).map { encodeHourly(section: $0, &fbb) } ?? Offset()
        let minutely15 = (try section.minutely15?()).map { encodeHourly(section: $0, &fbb) } ?? Offset()
        let sixHourly = (try section.sixHourly?()).map { encodeHourly(section: $0, &fbb) } ?? Offset()
        let daily = (try section.daily?()).map { encodeDaily(section: $0, &fbb) } ?? Offset()
        let current = try (try section.current?()).map { try encodeCurrent(section: $0, &fbb) } ?? Offset()
        let generationTimeMs = fixedGenerationTime ?? (Date().timeIntervalSince(generationTimeStart) * 1000)
        
        let result = openmeteo_sdk_WeatherApiResponse.createWeatherApiResponse(
            &fbb,
            latitude: section.latitude,
            longitude: section.longitude,
            elevation: section.elevation ?? .nan,
            model: section.model.flatBufferModel,
            generationtimeMs: Float32(generationTimeMs),
            utcOffsetSeconds: Int32(timezone.utcOffsetSeconds),
            timezoneOffset: timezone.identifier == "GMT" ? Offset() : fbb.create(string: timezone.identifier),
            timezoneAbbreviationOffset: timezone.abbreviation == "GMT" ? Offset() : fbb.create(string: timezone.abbreviation),
            dailyOffset: daily,
            hourlyOffset: hourly,
            sixHourlyOffset: sixHourly,
            minutely15Offset: minutely15,
            currentOffset: current
        )
        fbb.finish(offset: result, addPrefix: true)
    }
    
    var flatBufferModel: openmeteo_sdk_WeatherModel {
        switch self {
        case .best_match:
            return .bestMatch
        case .gfs_seamless:
            return .gfsSeamless
        case .gfs_mix:
            fallthrough
        case .gfs_global:
            return .gfsGlobal
        case .gfs_hrrr:
            return .gfsHrrr
        case .meteofrance_seamless:
            return .meteofranceSeamless
        case .meteofrance_mix:
            return .meteofranceSeamless
        case .meteofrance_arpege_world:
            return .meteofranceArpegeWorld
        case .meteofrance_arpege_europe:
            return .meteofranceArpegeEurope
        case .meteofrance_arome_france:
            return .meteofranceAromeFrance
        case .meteofrance_arome_france_hd:
            return .meteofranceAromeFranceHd
        case .jma_seamless:
           fallthrough
        case .jma_mix:
            return .jmaSeamless
        case .jma_msm:
            return .jmaMsm
        case .jms_gsm:
            fallthrough
        case .jma_gsm:
            return .jmaGsm
        case .gem_seamless:
            return .gemSeamless
        case .gem_global:
            return .gemGlobal
        case .gem_regional:
            return .gemGlobal
        case .gem_hrdps_continental:
            return .gemHrdpsContinental
        case .icon_mix:
            fallthrough
        case .icon_seamless:
            return .iconSeamless
        case .icon_global:
            return .iconGlobal
        case .icon_eu:
            return .iconEu
        case .icon_d2:
            return .iconD2
        case .ecmwf_ifs04:
            return .ecmwfIfs04
        case .metno_nordic:
            return .metnoNordic
        case .era5_seamless:
            return .era5Seamless
        case .era5:
            return .era5
        case .cerra:
            return .cerra
        case .era5_land:
            return .era5Land
        case .ecmwf_ifs:
            return .ecmwfIfs
        case .meteofrance_arpege_seamless:
            return .meteofranceArpegeSeamless
        case .meteofrance_arome_seamless:
            return .meteofranceAromeSeamless
        case .arpege_seamless:
            return .meteofranceArpegeSeamless
        case .arpege_world:
            return .meteofranceArpegeEurope
        case .arpege_europe:
            return .meteofranceArpegeEurope
        case .arome_seamless:
            return .meteofranceAromeSeamless
        case .arome_france:
            return .meteofranceAromeFrance
        case .arome_france_hd:
            return .meteofranceAromeFranceHd
        }
    }
}
