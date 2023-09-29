import Foundation
import FlatBuffers


extension SeasonalForecastDomainApi: ModelFlatbufferSerialisable {
    typealias HourlyVariable = SeasonalForecastVariable
    
    typealias HourlyPressureType = EnsemblePressureVariableType
    
    typealias DailyVariable = DailyCfsVariable
    
    var flatBufferModel: com_openmeteo_EnsembleModel {
        switch self {
        case .cfsv2:
            return .cfsv2
        }
    }
    
    static func encodeHourly(section: ApiSection<ForecastapiResult<Self>.SurfaceAndPressureVariable>, _ fbb: inout FlatBufferBuilder) -> Offset {
        let offsets = ForecastapiResult.encodeEnsemble(section: section, &fbb)
        let start = com_openmeteo_EnsembleHourly.startEnsembleHourly(&fbb)
        com_openmeteo_EnsembleHourly.add(time: section.timeFlatBuffers(), &fbb)
        for (surface, offset) in offsets.surface {
            switch surface {
            case .raw(let v):
                switch v {
                case .temperature_2m:
                    com_openmeteo_EnsembleHourly.add(temperature2m: offset, &fbb)
                case .temperature_2m_max:
                    com_openmeteo_EnsembleHourly.add(temperature2mMax: offset, &fbb)
                case .temperature_2m_min:
                    com_openmeteo_EnsembleHourly.add(temperature2mMin: offset, &fbb)
                case .soil_moisture_0_to_10cm:
                    com_openmeteo_EnsembleHourly.add(soilMoisture0To10cm: offset, &fbb)
                case .soil_moisture_10_to_40cm:
                    com_openmeteo_EnsembleHourly.add(soilMoisture10To40cm: offset, &fbb)
                case .soil_moisture_40_to_100cm:
                    com_openmeteo_EnsembleHourly.add(soilMoisture40To100cm: offset, &fbb)
                case .soil_moisture_100_to_200cm:
                    com_openmeteo_EnsembleHourly.add(soilMoisture100To200cm: offset, &fbb)
                case .soil_temperature_0_to_10cm:
                    com_openmeteo_EnsembleHourly.add(soilTemperature0To10cm: offset, &fbb)
                case .shortwave_radiation:
                    com_openmeteo_EnsembleHourly.add(shortwaveRadiation: offset, &fbb)
                case .cloudcover:
                    com_openmeteo_EnsembleHourly.add(cloudcover: offset, &fbb)
                case .wind_u_component_10m:
                    continue
                case .wind_v_component_10m:
                    continue
                case .precipitation:
                    com_openmeteo_EnsembleHourly.add(precipitation: offset, &fbb)
                case .showers:
                    com_openmeteo_EnsembleHourly.add(showers: offset, &fbb)
                case .relativehumidity_2m:
                    com_openmeteo_EnsembleHourly.add(relativehumidity2m: offset, &fbb)
                case .pressure_msl:
                    com_openmeteo_EnsembleHourly.add(pressureMsl: offset, &fbb)
                }
            case .derived(let v):
                switch v {
                case .windspeed_10m:
                    com_openmeteo_EnsembleHourly.add(windspeed10m:  offset, &fbb)
                case .winddirection_10m:
                    com_openmeteo_EnsembleHourly.add(winddirection10m: offset, &fbb)
                }
            }
        }
        for (_, _) in offsets.pressure {
            fatalError("no pressure variables in seasonal forecast models")
        }
        return com_openmeteo_EnsembleHourly.endEnsembleHourly(&fbb, start: start)
    }
    
    static func encodeDaily(section: ApiSection<DailyVariable>, _ fbb: inout FlatBufferBuilder) -> Offset {
        let offsets = ForecastapiResult<Self>.encodeEnsemble(section: section, &fbb)
        let start = com_openmeteo_EnsembleDaily.startEnsembleDaily(&fbb)
        com_openmeteo_EnsembleDaily.add(time: section.timeFlatBuffers(), &fbb)
        for (variable, offset) in zip(section.columns, offsets) {
            switch variable.variable {
            case .temperature_2m_max:
                com_openmeteo_EnsembleDaily.add(temperature2mMax: offset, &fbb)
            case .temperature_2m_min:
                com_openmeteo_EnsembleDaily.add(temperature2mMin: offset, &fbb)
            case .precipitation_sum:
                com_openmeteo_EnsembleDaily.add(precipitationSum: offset, &fbb)
            case .showers_sum:
                com_openmeteo_EnsembleDaily.add(showersSum: offset, &fbb)
            case .shortwave_radiation_sum:
                com_openmeteo_EnsembleDaily.add(shortwaveRadiationSum: offset, &fbb)
            case .windspeed_10m_max:
                com_openmeteo_EnsembleDaily.add(windspeed10mMax: offset, &fbb)
            case .winddirection_10m_dominant:
                com_openmeteo_EnsembleDaily.add(winddirection10mDominant: offset, &fbb)
            case .precipitation_hours:
                com_openmeteo_EnsembleDaily.add(precipitationHours: offset, &fbb)
            }
        }
        return com_openmeteo_EnsembleDaily.endEnsembleDaily(&fbb, start: start)
    }
    
    static func writeToFlatbuffer(section: ForecastapiResult<Self>.PerModel, _ fbb: inout FlatBufferBuilder, timezone: TimezoneWithOffset, fixedGenerationTime: Double?) throws {
        let generationTimeStart = Date()
        let sixHourly = (try section.sixHourly?()).map { encodeHourly(section: $0, &fbb) } ?? Offset()
        let daily = (try section.daily?()).map { encodeDaily(section: $0, &fbb) } ?? Offset()
        let generationTimeMs = fixedGenerationTime ?? (Date().timeIntervalSince(generationTimeStart) * 1000)
        
        let result = com_openmeteo_EnsembleApi.createEnsembleApi(
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
            sixHourlyOffset: sixHourly
            
        )
        fbb.finish(offset: result, addPrefix: true)
    }
}
