import Foundation
import FlatBuffers
import OpenMeteo


extension MultiDomains: ModelFlatbufferSerialisable {
    typealias HourlyVariable = ForecastSurfaceVariable
    
    typealias HourlyPressureType = ForecastPressureVariableType
    
    typealias DailyVariable = ForecastVariableDaily
    
    static func encodeHourly(section: ApiSection<ForecastapiResult<Self>.SurfaceAndPressureVariable>, _ fbb: inout FlatBufferBuilder) -> Offset {
        let offsets = ForecastapiResult.encode(section: section, &fbb)
        let start = WeatherHourly.startWeatherHourly(&fbb)
        WeatherHourly.add(time: section.timeFlatBuffers(), &fbb)
        for (surface, offset) in offsets.surface {
            switch surface {
            case .temperature_2m:
                WeatherHourly.add(temperature2m: offset, &fbb)
            case .cloudcover:
                WeatherHourly.add(cloudcover: offset, &fbb)
            case .cloudcover_low:
                WeatherHourly.add(cloudcoverLow: offset, &fbb)
            case .cloudcover_mid:
                WeatherHourly.add(cloudcoverMid: offset, &fbb)
            case .cloudcover_high:
                WeatherHourly.add(cloudcoverHigh: offset, &fbb)
            case .pressure_msl:
                WeatherHourly.add(pressureMsl: offset, &fbb)
            case .relativehumidity_2m:
                WeatherHourly.add(relativehumidity2m: offset, &fbb)
            case .precipitation:
                WeatherHourly.add(precipitation: offset, &fbb)
            case .precipitation_probability:
                WeatherHourly.add(precipitationProbability: offset, &fbb)
            case .weathercode:
                WeatherHourly.add(weathercode: offset, &fbb)
            case .temperature_80m:
                WeatherHourly.add(temperature80m: offset, &fbb)
            case .temperature_120m:
                WeatherHourly.add(temperature120m: offset, &fbb)
            case .temperature_180m:
                WeatherHourly.add(temperature180m: offset, &fbb)
            case .soil_temperature_0cm:
                WeatherHourly.add(soilTemperature0cm: offset, &fbb)
            case .soil_temperature_6cm:
                WeatherHourly.add(soilTemperature6cm: offset, &fbb)
            case .soil_temperature_18cm:
                WeatherHourly.add(soilTemperature18cm: offset, &fbb)
            case .soil_temperature_54cm:
                WeatherHourly.add(soilTemperature54cm: offset, &fbb)
            case .soil_moisture_0_1cm:
                fallthrough
            case .soil_moisture_0_to_1cm:
                WeatherHourly.add(soilMoisture0To1cm: offset, &fbb)
            case .soil_moisture_1_3cm:
                fallthrough
            case .soil_moisture_1_to_3cm:
                WeatherHourly.add(soilMoisture1To3cm: offset, &fbb)
            case .soil_moisture_3_9cm:
                fallthrough
            case .soil_moisture_3_to_9cm:
                WeatherHourly.add(soilMoisture3To9cm: offset, &fbb)
            case .soil_moisture_9_27cm:
                fallthrough
            case .soil_moisture_9_to_27cm:
                WeatherHourly.add(soilMoisture9To27cm: offset, &fbb)
            case .soil_moisture_27_81cm:
                fallthrough
            case .soil_moisture_27_to_81cm:
                WeatherHourly.add(soilMoisture27To81cm: offset, &fbb)
            case .snow_depth:
                WeatherHourly.add(snowDepth: offset, &fbb)
            case .snow_height:
                WeatherHourly.add(snowHeight: offset, &fbb)
            case .sensible_heatflux:
                WeatherHourly.add(sensibleHeatflux: offset, &fbb)
            case .latent_heatflux:
                WeatherHourly.add(latentHeatflux: offset, &fbb)
            case .showers:
                WeatherHourly.add(showers: offset, &fbb)
            case .rain:
                WeatherHourly.add(rain: offset, &fbb)
            case .windgusts_10m:
                WeatherHourly.add(windgusts10m: offset, &fbb)
            case .freezinglevel_height:
                WeatherHourly.add(freezinglevelHeight: offset, &fbb)
            case .dewpoint_2m:
                WeatherHourly.add(dewpoint2m: offset, &fbb)
            case .diffuse_radiation:
                WeatherHourly.add(diffuseRadiation: offset, &fbb)
            case .direct_radiation:
                WeatherHourly.add(directRadiation: offset, &fbb)
            case .apparent_temperature:
                WeatherHourly.add(apparentTemperature: offset, &fbb)
            case .windspeed_10m:
                WeatherHourly.add(windspeed10m: offset, &fbb)
            case .winddirection_10m:
                WeatherHourly.add(winddirection10m: offset, &fbb)
            case .windspeed_80m:
                WeatherHourly.add(windspeed80m: offset, &fbb)
            case .winddirection_80m:
                WeatherHourly.add(winddirection80m: offset, &fbb)
            case .windspeed_120m:
                WeatherHourly.add(windspeed120m: offset, &fbb)
            case .winddirection_120m:
                WeatherHourly.add(winddirection120m: offset, &fbb)
            case .windspeed_180m:
                WeatherHourly.add(windspeed180m: offset, &fbb)
            case .winddirection_180m:
                WeatherHourly.add(winddirection180m: offset, &fbb)
            case .direct_normal_irradiance:
                WeatherHourly.add(directNormalIrradiance: offset, &fbb)
            case .evapotranspiration:
                WeatherHourly.add(evapotranspiration: offset, &fbb)
            case .et0_fao_evapotranspiration:
                WeatherHourly.add(et0FaoEvapotranspiration: offset, &fbb)
            case .vapor_pressure_deficit:
                WeatherHourly.add(vaporPressureDeficit: offset, &fbb)
            case .shortwave_radiation:
                WeatherHourly.add(shortwaveRadiation: offset, &fbb)
            case .snowfall:
                WeatherHourly.add(snowfall: offset, &fbb)
            case .snowfall_height:
                WeatherHourly.add(snowfallHeight: offset, &fbb)
            case .surface_pressure:
                WeatherHourly.add(surfacePressure: offset, &fbb)
            case .terrestrial_radiation:
                WeatherHourly.add(terrestrialRadiation: offset, &fbb)
            case .terrestrial_radiation_instant:
                WeatherHourly.add(terrestrialRadiationInstant: offset, &fbb)
            case .shortwave_radiation_instant:
                WeatherHourly.add(shortwaveRadiationInstant: offset, &fbb)
            case .diffuse_radiation_instant:
                WeatherHourly.add(diffuseRadiationInstant: offset, &fbb)
            case .direct_radiation_instant:
                WeatherHourly.add(directRadiationInstant: offset, &fbb)
            case .direct_normal_irradiance_instant:
                WeatherHourly.add(directNormalIrradianceInstant: offset, &fbb)
            case .visibility:
                WeatherHourly.add(visibility: offset, &fbb)
            case .cape:
                WeatherHourly.add(cape: offset, &fbb)
            case .uv_index:
                WeatherHourly.add(uvIndex: offset, &fbb)
            case .uv_index_clear_sky:
                WeatherHourly.add(uvIndexClearSky: offset, &fbb)
            case .is_day:
                WeatherHourly.add(isDay: offset, &fbb)
            case .lightning_potential:
                WeatherHourly.add(lightningPotential: offset, &fbb)
            case .growing_degree_days_base_0_limit_50:
                WeatherHourly.add(growingDegreeDaysBase0Limit50: offset, &fbb)
            case .leaf_wetness_probability:
                WeatherHourly.add(leafWetnessProbability: offset, &fbb)
            case .runoff:
                WeatherHourly.add(runoff: offset, &fbb)
            case .skin_temperature:
                WeatherHourly.add(surfaceTemperature: offset, &fbb)
            case .snowfall_water_equivalent:
                WeatherHourly.add(snowfallWaterEquivalent: offset, &fbb)
            case .soil_moisture_0_to_100cm:
                WeatherHourly.add(soilMoisture0To100cm: offset, &fbb)
            case .soil_moisture_0_to_10cm:
                WeatherHourly.add(soilMoisture0To10cm: offset, &fbb)
            case .soil_moisture_0_to_7cm:
                WeatherHourly.add(soilMoisture0To7cm: offset, &fbb)
            case .soil_moisture_100_to_200cm:
                WeatherHourly.add(soilMoisture100To200cm: offset, &fbb)
            case .soil_moisture_100_to_255cm:
                WeatherHourly.add(soilMoisture100To255cm: offset, &fbb)
            case .soil_moisture_10_to_40cm:
                WeatherHourly.add(soilMoisture10To40cm: offset, &fbb)
            case .soil_moisture_28_to_100cm:
                WeatherHourly.add(soilMoisture28To100cm: offset, &fbb)
            case .soil_moisture_40_to_100cm:
                WeatherHourly.add(soilMoisture40To100cm: offset, &fbb)
            case .soil_moisture_7_to_28cm:
                WeatherHourly.add(soilMoisture7To28cm: offset, &fbb)
            case .soil_moisture_index_0_to_100cm:
                WeatherHourly.add(soilMoistureIndex0To100cm: offset, &fbb)
            case .soil_moisture_index_0_to_7cm:
                WeatherHourly.add(soilMoistureIndex0To7cm: offset, &fbb)
            case .soil_moisture_index_100_to_255cm:
                WeatherHourly.add(soilMoistureIndex100To255cm: offset, &fbb)
            case .soil_moisture_index_28_to_100cm:
                WeatherHourly.add(soilMoistureIndex28To100cm: offset, &fbb)
            case .soil_moisture_index_7_to_28cm:
                WeatherHourly.add(soilMoistureIndex7To28cm: offset, &fbb)
            case .soil_temperature_0_to_100cm:
                WeatherHourly.add(soilTemperature0To100cm: offset, &fbb)
            case .soil_temperature_0_to_10cm:
                WeatherHourly.add(soilTemperature0To10cm: offset, &fbb)
            case .soil_temperature_0_to_7cm:
                WeatherHourly.add(soilTemperature0To7cm: offset, &fbb)
            case .soil_temperature_100_to_200cm:
                WeatherHourly.add(soilTemperature100To200cm: offset, &fbb)
            case .soil_temperature_100_to_255cm:
                WeatherHourly.add(soilTemperature100To255cm: offset, &fbb)
            case .soil_temperature_10_to_40cm:
                WeatherHourly.add(soilTemperature10To40cm: offset, &fbb)
            case .soil_temperature_28_to_100cm:
                WeatherHourly.add(soilTemperature28To100cm: offset, &fbb)
            case .soil_temperature_40_to_100cm:
                WeatherHourly.add(soilTemperature40To100cm: offset, &fbb)
            case .soil_temperature_7_to_28cm:
                WeatherHourly.add(soilTemperature7To28cm: offset, &fbb)
            case .surface_air_pressure:
                WeatherHourly.add(surfacePressure: offset, &fbb)
            case .surface_temperature:
                WeatherHourly.add(surfaceTemperature: offset, &fbb)
            case .temperature_40m:
                WeatherHourly.add(temperature40m: offset, &fbb)
            case .total_column_integrated_water_vapour:
                WeatherHourly.add(totalColumnIntegratedWaterVapour: offset, &fbb)
            case .updraft:
                WeatherHourly.add(updraft: offset, &fbb)
            case .winddirection_100m:
                WeatherHourly.add(winddirection100m: offset, &fbb)
            case .winddirection_150m:
                WeatherHourly.add(winddirection150m: offset, &fbb)
            case .winddirection_200m:
                WeatherHourly.add(winddirection200m: offset, &fbb)
            case .winddirection_20m:
                WeatherHourly.add(winddirection20m: offset, &fbb)
            case .winddirection_40m:
                WeatherHourly.add(winddirection40m: offset, &fbb)
            case .winddirection_50m:
                WeatherHourly.add(winddirection50m: offset, &fbb)
            case .windspeed_100m:
                WeatherHourly.add(windspeed100m: offset, &fbb)
            case .windspeed_150m:
                WeatherHourly.add(windspeed150m: offset, &fbb)
            case .windspeed_200m:
                WeatherHourly.add(windspeed200m: offset, &fbb)
            case .windspeed_20m:
                WeatherHourly.add(windspeed20m: offset, &fbb)
            case .windspeed_40m:
                WeatherHourly.add(windspeed40m: offset, &fbb)
            case .windspeed_50m:
                WeatherHourly.add(windspeed50m: offset, &fbb)
            case .temperature:
                WeatherHourly.add(temperature2m: offset, &fbb)
            case .windspeed:
                WeatherHourly.add(windspeed10m: offset, &fbb)
            case .winddirection:
                WeatherHourly.add(winddirection10m: offset, &fbb)
            case .temperature_100m:
                WeatherHourly.add(temperature100m: offset, &fbb)
            case .temperature_150m:
                WeatherHourly.add(temperature150m: offset, &fbb)
            case .temperature_20m:
                WeatherHourly.add(temperature20m: offset, &fbb)
            case .temperature_200m:
                WeatherHourly.add(temperature200m: offset, &fbb)
            case .temperature_50m:
                WeatherHourly.add(temperature50m: offset, &fbb)
            case .lifted_index:
                WeatherHourly.add(liftedIndex: offset, &fbb)
            case .wet_bulb_temperature_2m:
                WeatherHourly.add(wetBulbTemperature2m: offset, &fbb)
            }
        }
        for (pressure, offset) in offsets.pressure {
            switch pressure {
            case .temperature:
                WeatherHourly.add(pressureLevelTemperature: offset, &fbb)
            case .geopotential_height:
                WeatherHourly.add(pressureLevelGeopotentialHeight: offset, &fbb)
            case .relativehumidity:
                WeatherHourly.add(pressureLevelRelativehumidity: offset, &fbb)
            case .windspeed:
                WeatherHourly.add(pressureLevelWindspeed: offset, &fbb)
            case .winddirection:
                WeatherHourly.add(pressureLevelWinddirection: offset, &fbb)
            case .dewpoint:
                WeatherHourly.add(pressureLevelDewpoint: offset, &fbb)
            case .cloudcover:
                WeatherHourly.add(pressureLevelCloudcover: offset, &fbb)
            case .vertical_velocity:
                WeatherHourly.add(pressureLevelVerticalVelocity: offset, &fbb)
            case .relative_humidity:
                WeatherHourly.add(pressureLevelRelativehumidity: offset, &fbb)
            }
        }
        return WeatherHourly.endWeatherHourly(&fbb, start: start)
    }
    
    static func encodeCurrent(section: ApiSectionSingle<ForecastapiResult<Self>.SurfaceAndPressureVariable>, _ fbb: inout FlatBufferBuilder) throws -> Offset {
        let start = WeatherCurrent.startWeatherCurrent(&fbb)
        WeatherCurrent.add(time: Int64(section.time.timeIntervalSince1970), &fbb)
        WeatherCurrent.add(interval: Int32(section.dtSeconds), &fbb)
        for column in section.columns {
            switch column.variable {
            case .surface(let surface):
                let v = ValueAndUnit(value: column.value, unit: column.unit)
                switch surface {
                case .temperature_2m:
                    WeatherCurrent.add(temperature2m: v, &fbb)
                case .cloudcover:
                    WeatherCurrent.add(cloudcover: v, &fbb)
                case .cloudcover_low:
                    WeatherCurrent.add(cloudcoverLow: v, &fbb)
                case .cloudcover_mid:
                    WeatherCurrent.add(cloudcoverMid: v, &fbb)
                case .cloudcover_high:
                    WeatherCurrent.add(cloudcoverHigh: v, &fbb)
                case .pressure_msl:
                    WeatherCurrent.add(pressureMsl: v, &fbb)
                case .relativehumidity_2m:
                    WeatherCurrent.add(relativehumidity2m: v, &fbb)
                case .precipitation:
                    WeatherCurrent.add(precipitation: v, &fbb)
                case .precipitation_probability:
                    WeatherCurrent.add(precipitationProbability: v, &fbb)
                case .weathercode:
                    WeatherCurrent.add(weathercode: v, &fbb)
                case .temperature_80m:
                    WeatherCurrent.add(temperature80m: v, &fbb)
                case .temperature_120m:
                    WeatherCurrent.add(temperature120m: v, &fbb)
                case .temperature_180m:
                    WeatherCurrent.add(temperature180m: v, &fbb)
                case .soil_temperature_0cm:
                    WeatherCurrent.add(soilTemperature0cm: v, &fbb)
                case .soil_temperature_6cm:
                    WeatherCurrent.add(soilTemperature6cm: v, &fbb)
                case .soil_temperature_18cm:
                    WeatherCurrent.add(soilTemperature18cm: v, &fbb)
                case .soil_temperature_54cm:
                    WeatherCurrent.add(soilTemperature54cm: v, &fbb)
                case .soil_moisture_0_1cm:
                    fallthrough
                case .soil_moisture_0_to_1cm:
                    WeatherCurrent.add(soilMoisture0To1cm: v, &fbb)
                case .soil_moisture_1_3cm:
                    fallthrough
                case .soil_moisture_1_to_3cm:
                    WeatherCurrent.add(soilMoisture1To3cm: v, &fbb)
                case .soil_moisture_3_9cm:
                    fallthrough
                case .soil_moisture_3_to_9cm:
                    WeatherCurrent.add(soilMoisture3To9cm: v, &fbb)
                case .soil_moisture_9_27cm:
                    fallthrough
                case .soil_moisture_9_to_27cm:
                    WeatherCurrent.add(soilMoisture9To27cm: v, &fbb)
                case .soil_moisture_27_81cm:
                    fallthrough
                case .soil_moisture_27_to_81cm:
                    WeatherCurrent.add(soilMoisture27To81cm: v, &fbb)
                case .snow_depth:
                    WeatherCurrent.add(snowDepth: v, &fbb)
                case .snow_height:
                    WeatherCurrent.add(snowHeight: v, &fbb)
                case .sensible_heatflux:
                    WeatherCurrent.add(sensibleHeatflux: v, &fbb)
                case .latent_heatflux:
                    WeatherCurrent.add(latentHeatflux: v, &fbb)
                case .showers:
                    WeatherCurrent.add(showers: v, &fbb)
                case .rain:
                    WeatherCurrent.add(rain: v, &fbb)
                case .windgusts_10m:
                    WeatherCurrent.add(windgusts10m: v, &fbb)
                case .freezinglevel_height:
                    WeatherCurrent.add(freezinglevelHeight: v, &fbb)
                case .dewpoint_2m:
                    WeatherCurrent.add(dewpoint2m: v, &fbb)
                case .diffuse_radiation:
                    WeatherCurrent.add(diffuseRadiation: v, &fbb)
                case .direct_radiation:
                    WeatherCurrent.add(directRadiation: v, &fbb)
                case .apparent_temperature:
                    WeatherCurrent.add(apparentTemperature: v, &fbb)
                case .windspeed_10m:
                    WeatherCurrent.add(windspeed10m: v, &fbb)
                case .winddirection_10m:
                    WeatherCurrent.add(winddirection10m: v, &fbb)
                case .windspeed_80m:
                    WeatherCurrent.add(windspeed80m: v, &fbb)
                case .winddirection_80m:
                    WeatherCurrent.add(winddirection80m: v, &fbb)
                case .windspeed_120m:
                    WeatherCurrent.add(windspeed120m: v, &fbb)
                case .winddirection_120m:
                    WeatherCurrent.add(winddirection120m: v, &fbb)
                case .windspeed_180m:
                    WeatherCurrent.add(windspeed180m: v, &fbb)
                case .winddirection_180m:
                    WeatherCurrent.add(winddirection180m: v, &fbb)
                case .direct_normal_irradiance:
                    WeatherCurrent.add(directNormalIrradiance: v, &fbb)
                case .evapotranspiration:
                    WeatherCurrent.add(evapotranspiration: v, &fbb)
                case .et0_fao_evapotranspiration:
                    WeatherCurrent.add(et0FaoEvapotranspiration: v, &fbb)
                case .vapor_pressure_deficit:
                    WeatherCurrent.add(vaporPressureDeficit: v, &fbb)
                case .shortwave_radiation:
                    WeatherCurrent.add(shortwaveRadiation: v, &fbb)
                case .snowfall:
                    WeatherCurrent.add(snowfall: v, &fbb)
                case .snowfall_height:
                    WeatherCurrent.add(snowfallHeight: v, &fbb)
                case .surface_pressure:
                    WeatherCurrent.add(surfacePressure: v, &fbb)
                case .terrestrial_radiation:
                    WeatherCurrent.add(terrestrialRadiation: v, &fbb)
                case .terrestrial_radiation_instant:
                    WeatherCurrent.add(terrestrialRadiationInstant: v, &fbb)
                case .shortwave_radiation_instant:
                    WeatherCurrent.add(shortwaveRadiationInstant: v, &fbb)
                case .diffuse_radiation_instant:
                    WeatherCurrent.add(diffuseRadiationInstant: v, &fbb)
                case .direct_radiation_instant:
                    WeatherCurrent.add(directRadiationInstant: v, &fbb)
                case .direct_normal_irradiance_instant:
                    WeatherCurrent.add(directNormalIrradianceInstant: v, &fbb)
                case .visibility:
                    WeatherCurrent.add(visibility: v, &fbb)
                case .cape:
                    WeatherCurrent.add(cape: v, &fbb)
                case .uv_index:
                    WeatherCurrent.add(uvIndex: v, &fbb)
                case .uv_index_clear_sky:
                    WeatherCurrent.add(uvIndexClearSky: v, &fbb)
                case .is_day:
                    WeatherCurrent.add(isDay: v, &fbb)
                case .lightning_potential:
                    WeatherCurrent.add(lightningPotential: v, &fbb)
                case .growing_degree_days_base_0_limit_50:
                    WeatherCurrent.add(growingDegreeDaysBase0Limit50: v, &fbb)
                case .leaf_wetness_probability:
                    WeatherCurrent.add(leafWetnessProbability: v, &fbb)
                case .runoff:
                    WeatherCurrent.add(runoff: v, &fbb)
                case .skin_temperature:
                    WeatherCurrent.add(surfaceTemperature: v, &fbb)
                case .snowfall_water_equivalent:
                    WeatherCurrent.add(snowfallWaterEquivalent: v, &fbb)
                case .soil_moisture_0_to_100cm:
                    WeatherCurrent.add(soilMoisture0To100cm: v, &fbb)
                case .soil_moisture_0_to_10cm:
                    WeatherCurrent.add(soilMoisture0To10cm: v, &fbb)
                case .soil_moisture_0_to_7cm:
                    WeatherCurrent.add(soilMoisture0To7cm: v, &fbb)
                case .soil_moisture_100_to_200cm:
                    WeatherCurrent.add(soilMoisture100To200cm: v, &fbb)
                case .soil_moisture_100_to_255cm:
                    WeatherCurrent.add(soilMoisture100To255cm: v, &fbb)
                case .soil_moisture_10_to_40cm:
                    WeatherCurrent.add(soilMoisture10To40cm: v, &fbb)
                case .soil_moisture_28_to_100cm:
                    WeatherCurrent.add(soilMoisture28To100cm: v, &fbb)
                case .soil_moisture_40_to_100cm:
                    WeatherCurrent.add(soilMoisture40To100cm: v, &fbb)
                case .soil_moisture_7_to_28cm:
                    WeatherCurrent.add(soilMoisture7To28cm: v, &fbb)
                case .soil_moisture_index_0_to_100cm:
                    WeatherCurrent.add(soilMoistureIndex0To100cm: v, &fbb)
                case .soil_moisture_index_0_to_7cm:
                    WeatherCurrent.add(soilMoistureIndex0To7cm: v, &fbb)
                case .soil_moisture_index_100_to_255cm:
                    WeatherCurrent.add(soilMoistureIndex100To255cm: v, &fbb)
                case .soil_moisture_index_28_to_100cm:
                    WeatherCurrent.add(soilMoistureIndex28To100cm: v, &fbb)
                case .soil_moisture_index_7_to_28cm:
                    WeatherCurrent.add(soilMoistureIndex7To28cm: v, &fbb)
                case .soil_temperature_0_to_100cm:
                    WeatherCurrent.add(soilTemperature0To100cm: v, &fbb)
                case .soil_temperature_0_to_10cm:
                    WeatherCurrent.add(soilTemperature0To10cm: v, &fbb)
                case .soil_temperature_0_to_7cm:
                    WeatherCurrent.add(soilTemperature0To7cm: v, &fbb)
                case .soil_temperature_100_to_200cm:
                    WeatherCurrent.add(soilTemperature100To200cm: v, &fbb)
                case .soil_temperature_100_to_255cm:
                    WeatherCurrent.add(soilTemperature100To255cm: v, &fbb)
                case .soil_temperature_10_to_40cm:
                    WeatherCurrent.add(soilTemperature10To40cm: v, &fbb)
                case .soil_temperature_28_to_100cm:
                    WeatherCurrent.add(soilTemperature28To100cm: v, &fbb)
                case .soil_temperature_40_to_100cm:
                    WeatherCurrent.add(soilTemperature40To100cm: v, &fbb)
                case .soil_temperature_7_to_28cm:
                    WeatherCurrent.add(soilTemperature7To28cm: v, &fbb)
                case .surface_air_pressure:
                    WeatherCurrent.add(surfacePressure: v, &fbb)
                case .surface_temperature:
                    WeatherCurrent.add(surfaceTemperature: v, &fbb)
                case .temperature_40m:
                    WeatherCurrent.add(temperature40m: v, &fbb)
                case .total_column_integrated_water_vapour:
                    WeatherCurrent.add(totalColumnIntegratedWaterVapour: v, &fbb)
                case .updraft:
                    WeatherCurrent.add(updraft: v, &fbb)
                case .winddirection_100m:
                    WeatherCurrent.add(winddirection100m: v, &fbb)
                case .winddirection_150m:
                    WeatherCurrent.add(winddirection150m: v, &fbb)
                case .winddirection_200m:
                    WeatherCurrent.add(winddirection200m: v, &fbb)
                case .winddirection_20m:
                    WeatherCurrent.add(winddirection20m: v, &fbb)
                case .winddirection_40m:
                    WeatherCurrent.add(winddirection40m: v, &fbb)
                case .winddirection_50m:
                    WeatherCurrent.add(winddirection50m: v, &fbb)
                case .windspeed_100m:
                    WeatherCurrent.add(windspeed100m: v, &fbb)
                case .windspeed_150m:
                    WeatherCurrent.add(windspeed150m: v, &fbb)
                case .windspeed_200m:
                    WeatherCurrent.add(windspeed200m: v, &fbb)
                case .windspeed_20m:
                    WeatherCurrent.add(windspeed20m: v, &fbb)
                case .windspeed_40m:
                    WeatherCurrent.add(windspeed40m: v, &fbb)
                case .windspeed_50m:
                    WeatherCurrent.add(windspeed50m: v, &fbb)
                case .temperature:
                    WeatherCurrent.add(temperature2m: v, &fbb)
                case .windspeed:
                    WeatherCurrent.add(windspeed10m: v, &fbb)
                case .winddirection:
                    WeatherCurrent.add(winddirection10m: v, &fbb)
                case .temperature_100m:
                    WeatherCurrent.add(temperature100m: v, &fbb)
                case .temperature_150m:
                    WeatherCurrent.add(temperature150m: v, &fbb)
                case .temperature_20m:
                    WeatherCurrent.add(temperature20m: v, &fbb)
                case .temperature_200m:
                    WeatherCurrent.add(temperature200m: v, &fbb)
                case .lifted_index:
                    WeatherCurrent.add(liftedIndex: v, &fbb)
                case .temperature_50m:
                    WeatherCurrent.add(temperature50m: v, &fbb)
                case .wet_bulb_temperature_2m:
                    WeatherCurrent.add(wetBulbTemperature2m: v, &fbb)
                }
            case .pressure(_):
                throw ForecastapiError.generic(message: "Pressure level variables currently not supported for flatbuffers encoding in current block")
            }
        }
        return WeatherCurrent.endWeatherCurrent(&fbb, start: start)
    }
    
    static func encodeDaily(section: ApiSection<DailyVariable>, _ fbb: inout FlatBufferBuilder) -> Offset {
        let offsets = ForecastapiResult<Self>.encode(section: section, &fbb)
        let start = WeatherDaily.startWeatherDaily(&fbb)
        WeatherDaily.add(time: section.timeFlatBuffers(), &fbb)
        for (variable, offset) in zip(section.columns, offsets) {
            switch variable.variable {
            case .temperature_2m_max:
                WeatherDaily.add(temperature2mMax: offset, &fbb)
            case .temperature_2m_min:
                WeatherDaily.add(temperature2mMin: offset, &fbb)
            case .temperature_2m_mean:
                WeatherDaily.add(temperature2mMean: offset, &fbb)
            case .apparent_temperature_max:
                WeatherDaily.add(apparentTemperatureMax: offset, &fbb)
            case .apparent_temperature_min:
                WeatherDaily.add(apparentTemperatureMin: offset, &fbb)
            case .apparent_temperature_mean:
                WeatherDaily.add(apparentTemperatureMean: offset, &fbb)
            case .precipitation_sum:
                WeatherDaily.add(precipitationSum: offset, &fbb)
            case .precipitation_probability_max:
                WeatherDaily.add(precipitationProbabilityMax: offset, &fbb)
            case .precipitation_probability_min:
                WeatherDaily.add(precipitationProbabilityMin: offset, &fbb)
            case .precipitation_probability_mean:
                WeatherDaily.add(precipitationProbabilityMean: offset, &fbb)
            case .snowfall_sum:
                WeatherDaily.add(snowfallSum: offset, &fbb)
            case .rain_sum:
                WeatherDaily.add(rainSum: offset, &fbb)
            case .showers_sum:
                WeatherDaily.add(showersSum: offset, &fbb)
            case .weathercode:
                WeatherDaily.add(weathercode: offset, &fbb)
            case .shortwave_radiation_sum:
                WeatherDaily.add(shortwaveRadiationSum: offset, &fbb)
            case .windspeed_10m_max:
                WeatherDaily.add(windspeed10mMax: offset, &fbb)
            case .windspeed_10m_min:
                WeatherDaily.add(windspeed10mMin: offset, &fbb)
            case .windspeed_10m_mean:
                WeatherDaily.add(windspeed10mMean: offset, &fbb)
            case .windgusts_10m_max:
                WeatherDaily.add(windgusts10mMax: offset, &fbb)
            case .windgusts_10m_min:
                WeatherDaily.add(windgusts10mMin: offset, &fbb)
            case .windgusts_10m_mean:
                WeatherDaily.add(windgusts10mMean: offset, &fbb)
            case .winddirection_10m_dominant:
                WeatherDaily.add(winddirection10mDominant: offset, &fbb)
            case .precipitation_hours:
                WeatherDaily.add(precipitationSum: offset, &fbb)
            case .sunrise:
                WeatherDaily.addVectorOf(sunrise: offset, &fbb)
            case .sunset:
                WeatherDaily.addVectorOf(sunset: offset, &fbb)
            case .et0_fao_evapotranspiration:
                WeatherDaily.add(et0FaoEvapotranspiration: offset, &fbb)
            case .visibility_max:
                WeatherDaily.add(visibilityMax: offset, &fbb)
            case .visibility_min:
                WeatherDaily.add(visibilityMin: offset, &fbb)
            case .visibility_mean:
                WeatherDaily.add(visibilityMean: offset, &fbb)
            case .pressure_msl_max:
                WeatherDaily.add(pressureMslMax: offset, &fbb)
            case .pressure_msl_min:
                WeatherDaily.add(pressureMslMin: offset, &fbb)
            case .pressure_msl_mean:
                WeatherDaily.add(pressureMslMean: offset, &fbb)
            case .surface_pressure_max:
                WeatherDaily.add(surfacePressureMax: offset, &fbb)
            case .surface_pressure_min:
                WeatherDaily.add(surfacePressureMin: offset, &fbb)
            case .surface_pressure_mean:
                WeatherDaily.add(surfacePressureMean: offset, &fbb)
            case .cape_max:
                WeatherDaily.add(capeMax: offset, &fbb)
            case .cape_min:
                WeatherDaily.add(capeMin: offset, &fbb)
            case .cape_mean:
                WeatherDaily.add(capeMean: offset, &fbb)
            case .cloudcover_max:
                WeatherDaily.add(cloudcoverMax: offset, &fbb)
            case .cloudcover_min:
                WeatherDaily.add(cloudcoverMin: offset, &fbb)
            case .cloudcover_mean:
                WeatherDaily.add(cloudcoverMean: offset, &fbb)
            case .uv_index_max:
                WeatherDaily.add(uvIndexMax: offset, &fbb)
            case .uv_index_clear_sky_max:
                WeatherDaily.add(uvIndexClearSkyMax: offset, &fbb)
            case .dewpoint_2m_max:
                WeatherDaily.add(dewpoint2mMax: offset, &fbb)
            case .dewpoint_2m_mean:
                WeatherDaily.add(dewpoint2mMean: offset, &fbb)
            case .dewpoint_2m_min:
                WeatherDaily.add(dewpoint2mMin: offset, &fbb)
            case .et0_fao_evapotranspiration_sum:
                WeatherDaily.add(et0FaoEvapotranspirationSum: offset, &fbb)
            case .growing_degree_days_base_0_limit_50:
                WeatherDaily.add(growingDegreeDaysBase0Limit50: offset, &fbb)
            case .leaf_wetness_probability_mean:
                WeatherDaily.add(leafWetnessProbabilityMean: offset, &fbb)
            case .relative_humidity_2m_max:
                WeatherDaily.add(relativeHumidity2mMax: offset, &fbb)
            case .relative_humidity_2m_mean:
                WeatherDaily.add(relativeHumidity2mMean: offset, &fbb)
            case .relative_humidity_2m_min:
                WeatherDaily.add(relativeHumidity2mMin: offset, &fbb)
            case .snowfall_water_equivalent_sum:
                WeatherDaily.add(snowfallWaterEquivalentSum: offset, &fbb)
            case .soil_moisture_0_to_100cm_mean:
                WeatherDaily.add(soilMoisture0To100cmMean: offset, &fbb)
            case .soil_moisture_0_to_10cm_mean:
                WeatherDaily.add(soilMoisture0To10cmMean: offset, &fbb)
            case .soil_moisture_0_to_7cm_mean:
                WeatherDaily.add(soilMoisture0To7cmMean:  offset, &fbb)
            case .soil_moisture_28_to_100cm_mean:
                WeatherDaily.add(soilMoisture28To100cmMean: offset, &fbb)
            case .soil_moisture_7_to_28cm_mean:
                WeatherDaily.add(soilMoisture7To28cmMean: offset, &fbb)
            case .soil_moisture_index_0_to_100cm_mean:
                WeatherDaily.add(soilMoistureIndex0To100cmMean: offset, &fbb)
            case .soil_moisture_index_0_to_7cm_mean:
                WeatherDaily.add(soilMoistureIndex0To7cmMean: offset, &fbb)
            case .soil_moisture_index_100_to_255cm_mean:
                WeatherDaily.add(soilMoistureIndex100To255cmMean: offset, &fbb)
            case .soil_moisture_index_28_to_100cm_mean:
                WeatherDaily.add(soilMoistureIndex28To100cmMean: offset, &fbb)
            case .soil_moisture_index_7_to_28cm_mean:
                WeatherDaily.add(soilMoistureIndex7To28cmMean: offset, &fbb)
            case .soil_temperature_0_to_100cm_mean:
                WeatherDaily.add(soilTemperature0To100cmMean: offset, &fbb)
            case .soil_temperature_0_to_7cm_mean:
                WeatherDaily.add(soilTemperature0To7cmMean: offset, &fbb)
            case .soil_temperature_28_to_100cm_mean:
                WeatherDaily.add(soilTemperature28To100cmMean: offset, &fbb)
            case .soil_temperature_7_to_28cm_mean:
                WeatherDaily.add(soilTemperature7To28cmMean: offset, &fbb)
            case .updraft_max:
                WeatherDaily.add(updraftMax: offset, &fbb)
            case .vapor_pressure_deficit_max:
                WeatherDaily.add(vaporPressureDeficitMax: offset, &fbb)
            case .wet_bulb_temperature_2m_max:
                WeatherDaily.add(wetBulbTemperature2mMax: offset, &fbb)
            case .wet_bulb_temperature_2m_mean:
                WeatherDaily.add(wetBulbTemperature2mMean: offset, &fbb)
            case .wet_bulb_temperature_2m_min:
                WeatherDaily.add(wetBulbTemperature2mMin: offset, &fbb)
            }
        }
        return WeatherDaily.endWeatherDaily(&fbb, start: start)
    }
    
    static func writeToFlatbuffer(section: ForecastapiResult<Self>.PerModel, _ fbb: inout FlatBufferBuilder, timezone: TimezoneWithOffset, fixedGenerationTime: Double?) throws {
        let generationTimeStart = Date()
        let hourly = (try section.hourly?()).map { encodeHourly(section: $0, &fbb) } ?? Offset()
        let minutely15 = (try section.minutely15?()).map { encodeHourly(section: $0, &fbb) } ?? Offset()
        let sixHourly = (try section.sixHourly?()).map { encodeHourly(section: $0, &fbb) } ?? Offset()
        let daily = (try section.daily?()).map { encodeDaily(section: $0, &fbb) } ?? Offset()
        let current = try (try section.current?()).map { try encodeCurrent(section: $0, &fbb) } ?? Offset()
        let generationTimeMs = fixedGenerationTime ?? (Date().timeIntervalSince(generationTimeStart) * 1000)
        
        let result = WeatherApiResponse.createWeatherApiResponse(
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
    
    var flatBufferModel: WeatherModel {
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
