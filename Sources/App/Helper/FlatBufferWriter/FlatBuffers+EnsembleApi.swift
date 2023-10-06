import Foundation
import FlatBuffers
import OpenMeteo


extension EnsembleMultiDomains: ModelFlatbufferSerialisable {
    typealias HourlyVariable = EnsembleSurfaceVariable
    
    typealias HourlyPressureType = EnsemblePressureVariableType
    
    typealias DailyVariable = ForecastVariableDaily
    
    var flatBufferModel: EnsembleModel {
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
        let start = EnsembleHourly.startEnsembleHourly(&fbb)
        EnsembleHourly.add(time: section.timeFlatBuffers(), &fbb)
        for (surface, offset) in offsets.surface {
            switch surface {
            case .weathercode:
                EnsembleHourly.add(weathercode: offset, &fbb)
            case .temperature_2m:
                EnsembleHourly.add(temperature2m: offset, &fbb)
            case .temperature_80m:
                EnsembleHourly.add(temperature80m: offset, &fbb)
            case .temperature_120m:
                EnsembleHourly.add(temperature120m: offset, &fbb)
            case .cloudcover:
                EnsembleHourly.add(cloudcover: offset, &fbb)
            case .pressure_msl:
                EnsembleHourly.add(pressureMsl: offset, &fbb)
            case .relativehumidity_2m:
                EnsembleHourly.add(relativehumidity2m: offset, &fbb)
            case .precipitation:
                EnsembleHourly.add(precipitation: offset, &fbb)
            case .rain:
                EnsembleHourly.add(rain: offset, &fbb)
            case .windgusts_10m:
                EnsembleHourly.add(windgusts10m: offset, &fbb)
            case .dewpoint_2m:
                EnsembleHourly.add(dewpoint2m: offset, &fbb)
            case .diffuse_radiation:
                EnsembleHourly.add(diffuseRadiation: offset, &fbb)
            case .direct_radiation:
                EnsembleHourly.add(directRadiation: offset, &fbb)
            case .apparent_temperature:
                EnsembleHourly.add(apparentTemperature: offset, &fbb)
            case .windspeed_10m:
                EnsembleHourly.add(windspeed10m: offset, &fbb)
            case .winddirection_10m:
                EnsembleHourly.add(winddirection10m: offset, &fbb)
            case .windspeed_80m:
                EnsembleHourly.add(windspeed80m: offset, &fbb)
            case .winddirection_80m:
                EnsembleHourly.add(winddirection80m: offset, &fbb)
            case .windspeed_120m:
                EnsembleHourly.add(windspeed120m: offset, &fbb)
            case .winddirection_120m:
                EnsembleHourly.add(winddirection120m: offset, &fbb)
            case .direct_normal_irradiance:
                EnsembleHourly.add(directNormalIrradiance: offset, &fbb)
            case .et0_fao_evapotranspiration:
                EnsembleHourly.add(et0FaoEvapotranspiration: offset, &fbb)
            case .vapor_pressure_deficit:
                EnsembleHourly.add(vaporPressureDeficit: offset, &fbb)
            case .shortwave_radiation:
                EnsembleHourly.add(shortwaveRadiation: offset, &fbb)
            case .snowfall:
                EnsembleHourly.add(snowfall: offset, &fbb)
            case .snow_depth:
                EnsembleHourly.add(snowDepth: offset, &fbb)
            case .surface_pressure:
                EnsembleHourly.add(surfacePressure: offset, &fbb)
            case .shortwave_radiation_instant:
                EnsembleHourly.add(shortwaveRadiationInstant: offset, &fbb)
            case .diffuse_radiation_instant:
                EnsembleHourly.add(diffuseRadiationInstant: offset, &fbb)
            case .direct_radiation_instant:
                EnsembleHourly.add(directRadiationInstant: offset, &fbb)
            case .direct_normal_irradiance_instant:
                EnsembleHourly.add(directNormalIrradianceInstant: offset, &fbb)
            case .is_day:
                EnsembleHourly.add(isDay: offset, &fbb)
            case .visibility:
                EnsembleHourly.add(visibility: offset, &fbb)
            case .freezinglevel_height:
                EnsembleHourly.add(freezinglevelHeight: offset, &fbb)
            case .uv_index:
                EnsembleHourly.add(uvIndex: offset, &fbb)
            case .uv_index_clear_sky:
                EnsembleHourly.add(uvIndexClearSky: offset, &fbb)
            case .cape:
                EnsembleHourly.add(cape: offset, &fbb)
            case .surface_temperature:
                EnsembleHourly.add(surfaceTemperature: offset, &fbb)
            case .soil_temperature_0_to_10cm:
                EnsembleHourly.add(soilTemperature0To10cm: offset, &fbb)
            case .soil_temperature_10_to_40cm:
                EnsembleHourly.add(soilTemperature10To40cm: offset, &fbb)
            case .soil_temperature_40_to_100cm:
                EnsembleHourly.add(soilTemperature40To100cm: offset, &fbb)
            case .soil_temperature_100_to_200cm:
                EnsembleHourly.add(soilTemperature100To200cm: offset, &fbb)
            case .soil_moisture_0_to_10cm:
                EnsembleHourly.add(soilMoisture0To10cm: offset, &fbb)
            case .soil_moisture_10_to_40cm:
                EnsembleHourly.add(soilMoisture10To40cm: offset, &fbb)
            case .soil_moisture_40_to_100cm:
                EnsembleHourly.add(soilMoisture40To100cm: offset, &fbb)
            case .soil_moisture_100_to_200cm:
                EnsembleHourly.add(soilTemperature100To200cm: offset, &fbb)
            }
        }
        for (pressure, offset) in offsets.pressure {
            switch pressure {
            case .temperature:
                EnsembleHourly.add(pressureLevelTemperature: offset, &fbb)
            case .geopotential_height:
                EnsembleHourly.add(pressureLevelGeopotentialHeight: offset, &fbb)
            case .relativehumidity:
                EnsembleHourly.add(pressureLevelRelativehumidity: offset, &fbb)
            case .windspeed:
                EnsembleHourly.add(pressureLevelWindspeed: offset, &fbb)
            case .winddirection:
                EnsembleHourly.add(pressureLevelWinddirection: offset, &fbb)
            case .dewpoint:
                EnsembleHourly.add(pressureLevelDewpoint: offset, &fbb)
            case .cloudcover:
                EnsembleHourly.add(pressureLevelCloudcover: offset, &fbb)
            case .vertical_velocity:
                EnsembleHourly.add(pressureLevelVerticalVelocity: offset, &fbb)
            }
        }
        return EnsembleHourly.endEnsembleHourly(&fbb, start: start)
    }
    
    static func writeToFlatbuffer(section: ForecastapiResult<Self>.PerModel, _ fbb: inout FlatBufferBuilder, timezone: TimezoneWithOffset, fixedGenerationTime: Double?) throws {
        let generationTimeStart = Date()
        let hourly = (try section.hourly?()).map { encodeHourly(section: $0, &fbb) } ?? Offset()
        let generationTimeMs = fixedGenerationTime ?? (Date().timeIntervalSince(generationTimeStart) * 1000)
        
        let result = EnsembleApiResponse.createEnsembleApiResponse(
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
