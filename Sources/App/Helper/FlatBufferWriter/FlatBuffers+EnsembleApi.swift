import Foundation
import FlatBuffers
import OpenMeteoSdk


extension EnsembleMultiDomains: ModelFlatbufferSerialisable {
    typealias HourlyVariable = EnsembleSurfaceVariable
    
    typealias HourlyPressureType = EnsemblePressureVariableType
    
    typealias DailyVariable = ForecastVariableDaily
    
    var flatBufferModel: openmeteo_sdk_EnsembleModel {
        switch self {
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
        case .gem_global:
            return .gemGlobal
        case .gfs_seamless:
            return .gfsSeamless
        case .gfs025:
            return .gfs025
        case .gfs05:
            return .gfs025
        }
    }
    
    static func encodeHourly(section: ApiSection<ForecastapiResult<Self>.SurfaceAndPressureVariable>, _ fbb: inout FlatBufferBuilder) -> Offset {
        let offsets = ForecastapiResult.encodeEnsemble(section: section, &fbb)
        let start = openmeteo_sdk_EnsembleHourly.startEnsembleHourly(&fbb)
        openmeteo_sdk_EnsembleHourly.add(time: section.timeFlatBuffers(), &fbb)
        for (surface, offset) in offsets.surface {
            switch surface {
            case .weathercode:
                openmeteo_sdk_EnsembleHourly.add(weathercode: offset, &fbb)
            case .temperature_2m:
                openmeteo_sdk_EnsembleHourly.add(temperature2m: offset, &fbb)
            case .temperature_80m:
                openmeteo_sdk_EnsembleHourly.add(temperature80m: offset, &fbb)
            case .temperature_120m:
                openmeteo_sdk_EnsembleHourly.add(temperature120m: offset, &fbb)
            case .cloudcover:
                openmeteo_sdk_EnsembleHourly.add(cloudcover: offset, &fbb)
            case .pressure_msl:
                openmeteo_sdk_EnsembleHourly.add(pressureMsl: offset, &fbb)
            case .relativehumidity_2m:
                openmeteo_sdk_EnsembleHourly.add(relativehumidity2m: offset, &fbb)
            case .precipitation:
                openmeteo_sdk_EnsembleHourly.add(precipitation: offset, &fbb)
            case .rain:
                openmeteo_sdk_EnsembleHourly.add(rain: offset, &fbb)
            case .windgusts_10m:
                openmeteo_sdk_EnsembleHourly.add(windgusts10m: offset, &fbb)
            case .dewpoint_2m:
                openmeteo_sdk_EnsembleHourly.add(dewpoint2m: offset, &fbb)
            case .diffuse_radiation:
                openmeteo_sdk_EnsembleHourly.add(diffuseRadiation: offset, &fbb)
            case .direct_radiation:
                openmeteo_sdk_EnsembleHourly.add(directRadiation: offset, &fbb)
            case .apparent_temperature:
                openmeteo_sdk_EnsembleHourly.add(apparentTemperature: offset, &fbb)
            case .windspeed_10m:
                openmeteo_sdk_EnsembleHourly.add(windspeed10m: offset, &fbb)
            case .winddirection_10m:
                openmeteo_sdk_EnsembleHourly.add(winddirection10m: offset, &fbb)
            case .windspeed_80m:
                openmeteo_sdk_EnsembleHourly.add(windspeed80m: offset, &fbb)
            case .winddirection_80m:
                openmeteo_sdk_EnsembleHourly.add(winddirection80m: offset, &fbb)
            case .windspeed_120m:
                openmeteo_sdk_EnsembleHourly.add(windspeed120m: offset, &fbb)
            case .winddirection_120m:
                openmeteo_sdk_EnsembleHourly.add(winddirection120m: offset, &fbb)
            case .direct_normal_irradiance:
                openmeteo_sdk_EnsembleHourly.add(directNormalIrradiance: offset, &fbb)
            case .et0_fao_evapotranspiration:
                openmeteo_sdk_EnsembleHourly.add(et0FaoEvapotranspiration: offset, &fbb)
            case .vapor_pressure_deficit:
                openmeteo_sdk_EnsembleHourly.add(vaporPressureDeficit: offset, &fbb)
            case .shortwave_radiation:
                openmeteo_sdk_EnsembleHourly.add(shortwaveRadiation: offset, &fbb)
            case .snowfall:
                openmeteo_sdk_EnsembleHourly.add(snowfall: offset, &fbb)
            case .snow_depth:
                openmeteo_sdk_EnsembleHourly.add(snowDepth: offset, &fbb)
            case .surface_pressure:
                openmeteo_sdk_EnsembleHourly.add(surfacePressure: offset, &fbb)
            case .shortwave_radiation_instant:
                openmeteo_sdk_EnsembleHourly.add(shortwaveRadiationInstant: offset, &fbb)
            case .diffuse_radiation_instant:
                openmeteo_sdk_EnsembleHourly.add(diffuseRadiationInstant: offset, &fbb)
            case .direct_radiation_instant:
                openmeteo_sdk_EnsembleHourly.add(directRadiationInstant: offset, &fbb)
            case .direct_normal_irradiance_instant:
                openmeteo_sdk_EnsembleHourly.add(directNormalIrradianceInstant: offset, &fbb)
            case .is_day:
                openmeteo_sdk_EnsembleHourly.add(isDay: offset, &fbb)
            case .visibility:
                openmeteo_sdk_EnsembleHourly.add(visibility: offset, &fbb)
            case .freezinglevel_height:
                openmeteo_sdk_EnsembleHourly.add(freezinglevelHeight: offset, &fbb)
            case .uv_index:
                openmeteo_sdk_EnsembleHourly.add(uvIndex: offset, &fbb)
            case .uv_index_clear_sky:
                openmeteo_sdk_EnsembleHourly.add(uvIndexClearSky: offset, &fbb)
            case .cape:
                openmeteo_sdk_EnsembleHourly.add(cape: offset, &fbb)
            case .surface_temperature:
                openmeteo_sdk_EnsembleHourly.add(surfaceTemperature: offset, &fbb)
            case .soil_temperature_0_to_10cm:
                openmeteo_sdk_EnsembleHourly.add(soilTemperature0To10cm: offset, &fbb)
            case .soil_temperature_10_to_40cm:
                openmeteo_sdk_EnsembleHourly.add(soilTemperature10To40cm: offset, &fbb)
            case .soil_temperature_40_to_100cm:
                openmeteo_sdk_EnsembleHourly.add(soilTemperature40To100cm: offset, &fbb)
            case .soil_temperature_100_to_200cm:
                openmeteo_sdk_EnsembleHourly.add(soilTemperature100To200cm: offset, &fbb)
            case .soil_moisture_0_to_10cm:
                openmeteo_sdk_EnsembleHourly.add(soilMoisture0To10cm: offset, &fbb)
            case .soil_moisture_10_to_40cm:
                openmeteo_sdk_EnsembleHourly.add(soilMoisture10To40cm: offset, &fbb)
            case .soil_moisture_40_to_100cm:
                openmeteo_sdk_EnsembleHourly.add(soilMoisture40To100cm: offset, &fbb)
            case .soil_moisture_100_to_200cm:
                openmeteo_sdk_EnsembleHourly.add(soilTemperature100To200cm: offset, &fbb)
            }
        }
        for (pressure, offset) in offsets.pressure {
            switch pressure {
            case .temperature:
                openmeteo_sdk_EnsembleHourly.add(pressureLevelTemperature: offset, &fbb)
            case .geopotential_height:
                openmeteo_sdk_EnsembleHourly.add(pressureLevelGeopotentialHeight: offset, &fbb)
            case .relativehumidity:
                openmeteo_sdk_EnsembleHourly.add(pressureLevelRelativehumidity: offset, &fbb)
            case .windspeed:
                openmeteo_sdk_EnsembleHourly.add(pressureLevelWindspeed: offset, &fbb)
            case .winddirection:
                openmeteo_sdk_EnsembleHourly.add(pressureLevelWinddirection: offset, &fbb)
            case .dewpoint:
                openmeteo_sdk_EnsembleHourly.add(pressureLevelDewpoint: offset, &fbb)
            case .cloudcover:
                openmeteo_sdk_EnsembleHourly.add(pressureLevelCloudcover: offset, &fbb)
            case .vertical_velocity:
                openmeteo_sdk_EnsembleHourly.add(pressureLevelVerticalVelocity: offset, &fbb)
            }
        }
        return openmeteo_sdk_EnsembleHourly.endEnsembleHourly(&fbb, start: start)
    }
    
    static func writeToFlatbuffer(section: ForecastapiResult<Self>.PerModel, _ fbb: inout FlatBufferBuilder, timezone: TimezoneWithOffset, fixedGenerationTime: Double?) throws {
        let generationTimeStart = Date()
        let hourly = (try section.hourly?()).map { encodeHourly(section: $0, &fbb) } ?? Offset()
        let generationTimeMs = fixedGenerationTime ?? (Date().timeIntervalSince(generationTimeStart) * 1000)
        
        let result = openmeteo_sdk_EnsembleApiResponse.createEnsembleApiResponse(
            &fbb,
            latitude: section.latitude,
            longitude: section.longitude,
            elevation: section.elevation ?? .nan,
            model: section.model.flatBufferModel,
            generationtimeMs: Float32(generationTimeMs),
            utcOffsetSeconds: Int32(timezone.utcOffsetSeconds),
            timezoneOffset: timezone.identifier == "GMT" ? Offset() : fbb.create(string: timezone.identifier),
            timezoneAbbreviationOffset: timezone.abbreviation == "GMT" ? Offset() : fbb.create(string: timezone.abbreviation),
            hourlyOffset: hourly
        )
        fbb.finish(offset: result, addPrefix: true)
    }
}
