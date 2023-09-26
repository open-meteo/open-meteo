import Foundation
import FlatBuffers
import Vapor

extension ForecastapiResultSet {
    /// Convert data into a FlatBuffers scheme far fast binary encoding and transfer
    /// Each `ForecastapiResult` is converted indifuavually into an flatbuffer message -> very long time-series require a lot of memory
    /// Data is using `size prefixed` flatbuffers to allow streaming of multiple messages for multiple locations
    func toFlatbuffersResponse(fixedGenerationTime: Double?) throws -> Response {
        // First excution outside stream, to capture potential errors better
        //var first = try self.first?()
        if results.count > 1000 {
            throw ForecastapiError.generic(message: "Only up to 1000 locations can be requested at once")
        }
        let response = Response(body: .init(stream: { writer in
            writer.submit {
                // TODO: Zero-copy for flatbuffer to NIO bytebuffer conversion. Probably writing an optimised flatbuffer encoder would be better.
                // TODO: Estimate initial buffer size
                let initialSize = Int32(4096) // Int32(((first?.estimatedFlatbufferSize ?? 4096)/4096+1)*4096)
                var fbb = FlatBufferBuilder(initialSize: initialSize)
                var b = BufferAndWriter(writer: writer)
                //if let first {
                //    first.writeToFlatbuffer(&fbb)
                //    b.buffer.writeBytes(fbb.buffer.unsafeRawBufferPointer)
                //    fbb.clear()
                //}
                //first = nil
                try await b.flushIfRequired()
                for location in results {
                    for model in location.results {
                        try Model.writeToFlatbuffer(section: model, &fbb, timezone: location.timezone, fixedGenerationTime: fixedGenerationTime)
                        b.buffer.writeBytes(fbb.buffer.unsafeRawBufferPointer)
                        fbb.clear()
                        try await b.flushIfRequired()
                    }
                }
                try await b.flush()
                try await b.end()
            }
        }))
        response.headers.replaceOrAdd(name: .contentType, value: "application/octet-stream")
        return response
    }
}

/*fileprivate extension ForecastapiResultMulti {
    /// Write data into `FlatBufferBuilder` and finish the message
    func writeToFlatbuffer(_ fbb: inout FlatBufferBuilder, fixedGenerationTime: Double?) throws {
        fatalError()
        /*let generationTimeStart = Date()
        let current_weather = try current_weather?()
        let current = try current?()
        let sections = try runAllSections()
        let generationTimeMs = fixedGenerationTime ?? (Date().timeIntervalSince(generationTimeStart) * 1000)
        
        let currentWeather = current_weather.map { c in
            com_openmeteo_api_result_CurrentWeather(
                time: Int64(c.time.timeIntervalSince1970),
                temperature: c.temperature,
                weathercode: c.weathercode,
                windspeed: c.windspeed,
                winddirection: c.winddirection,
                isDay: c.is_day
            )
        }
        let time = sections.first?.time.range.lowerBound.timeIntervalSince1970 ?? 0
        let hourly = sections.first(where: {$0.name == "hourly"})?.toFlatbuffers(&fbb) ?? Offset()
        let daily = sections.first(where: {$0.name == "daily"})?.toFlatbuffers(&fbb) ?? Offset()
        let minutely15 = sections.first(where: {$0.name == "minutely_15"})?.toFlatbuffers(&fbb) ?? Offset()
        let sixHourly = sections.first(where: {$0.name == "six_hourly"})?.toFlatbuffers(&fbb) ?? Offset()
        let result = com_openmeteo_api_result_Result.createResult(
            &fbb,
            latitude: self.latitude,
            longitude: self.longitude,
            elevation: self.elevation ?? .nan,
            generationtimeMs: Float32(generationTimeMs),
            utcOffsetSeconds: Int32(self.utc_offset_seconds),
            timezoneOffset: fbb.create(string: self.timezone.identifier),
            timezoneAbbreviationOffset: fbb.create(string: self.timezone.abbreviation),
            currentWeather: currentWeather,
            timeStart: Int64(time),
            dailyVectorOffset: daily,
            hourlyVectorOffset: hourly,
            sixHourlyVectorOffset: sixHourly,
            minutely15VectorOffset: minutely15,
            currentVectorOffset: current?.toFlatbuffers(&fbb) ?? Offset(),
            currentTime: (current?.time.timeIntervalSince1970).map(Int64.init) ?? 0,
            currentIntervalSeconds: (current?.dtSeconds).map(Int32.init) ?? 0
        )
        fbb.finish(offset: result, addPrefix: true)*/
    }
    
    /// Roughly estimate the required size to keep the flatbuffer message in memory. Overestimation is expected.
    /*var estimatedFlatbufferSize: Int {
        let dataSize = 24 + sections.reduce(0, {$0 + $1.estimatedFlatbufferSize})
        return dataSize + 512
    }*/
}*/

fileprivate extension FlatBuffers.ByteBuffer {
    /// Create a pointer to the data region. Flatbuffer is filling the buffer backwards.
    var unsafeRawBufferPointer: UnsafeRawBufferPointer {
        .init(start: memory.advanced(by: self.capacity - Int(self.size)), count: Int(size))
    }
}

fileprivate extension ApiSection {
    /*var estimatedFlatbufferSize: Int {
        24 + columns.reduce(0, {$0 + $1.unit.abbreviation.count + $1.variable.count + $1.data.count * 4 + 24})
    }*/
        
    func toFlatbuffers(_ fbb: inout FlatBufferBuilder) -> Offset {
        return fbb.createVector(ofOffsets: columns.compactMap({ $0.toFlatbuffers(&fbb, timerange: time) }))
    }
}

/*fileprivate extension ApiSectionSingle {
    func toFlatbuffers(_ fbb: inout FlatBufferBuilder) -> Offset {
        return fbb.createVector(ofOffsets: columns.compactMap({ $0.toFlatbuffers(&fbb) }))
    }
}*/

fileprivate extension ApiColumn {
    func toFlatbuffers(_ fbb: inout FlatBufferBuilder, timerange: TimerangeDt) -> Offset? {
        fatalError()
        /*switch data {
        //case .string(_):
        //    return nil
        case .float(let data):
            return com_openmeteo_api_result_Variable.createVariable(&fbb, variableOffset: fbb.create(string: variable), unit: unit, valuesVectorOffset: fbb.createVector(data))
        //case .int(_):
        //    return nil
        case .timestamp(let times):
            /// only used for sunrise / sunset
            /// convert unixtimestamp to seconds after midnight
            let secondsAfterMidnight = zip(timerange, times).map { (midnight, time) in
                return Float(time.timeIntervalSince1970 - midnight.timeIntervalSince1970)
            }
            return com_openmeteo_api_result_Variable.createVariable(&fbb, variableOffset: fbb.create(string: variable), unit: unit, valuesVectorOffset: fbb.createVector(secondsAfterMidnight))
        }*/
    }
}

/*fileprivate extension ApiColumnSingle {
    func toFlatbuffers(_ fbb: inout FlatBufferBuilder) -> Offset? {
        return com_openmeteo_api_result_VariableSingle.createVariableSingle(&fbb, variableOffset: fbb.create(string: variable), unit: unit, value: value)
    }
}*/

extension MultiDomains: ModelFlatbufferSerialisable {
    static func writeToFlatbuffer<HourlyVariable: VariableFlatbufferSerialisable, DailyVariable: VariableFlatbufferSerialisable>(section: ForecastapiResult<Self, HourlyVariable, DailyVariable>, _ fbb: inout FlatBufferBuilder, timezone: TimezoneWithOffset, fixedGenerationTime: Double?) throws {
        
        let generationTimeStart = Date()
        let current_weather = try section.current_weather?()
        let current = try section.current?()
        
        // TODO current
        
        let currentWeather = current_weather.map { c in
            com_openmeteo_CurrentWeather(
                time: Int64(c.time.timeIntervalSince1970),
                temperature: c.temperature,
                weathercode: c.weathercode,
                windspeed: c.windspeed,
                winddirection: c.winddirection,
                isDay: c.is_day
            )
        }
        //let time = section. section.sections.first?.time.range.lowerBound.timeIntervalSince1970 ?? 0
        let minutely15 = (try section.minutely15?()).map { HourlyVariable.toFlatbuffers(section: $0, &fbb) } ?? Offset()
        let sixHourly = (try section.sixHourly?()).map { HourlyVariable.toFlatbuffers(section: $0, &fbb) } ?? Offset()
        let hourly = (try section.hourly?()).map { HourlyVariable.toFlatbuffers(section: $0, &fbb) } ?? Offset()
        let daily = (try section.daily?()).map { DailyVariable.toFlatbuffers(section: $0, &fbb) } ?? Offset()
        
        let generationTimeMs = fixedGenerationTime ?? (Date().timeIntervalSince(generationTimeStart) * 1000)
        
        let result = com_openmeteo_WeatherApi.createWeatherApi(
            &fbb,
            latitude: section.latitude,
            longitude: section.longitude,
            elevation: section.elevation ?? .nan,
            model: section.model.flatBufferModel,
            generationtimeMs: Float32(generationTimeMs),
            utcOffsetSeconds: Int32(timezone.utcOffsetSeconds),
            timezoneOffset: fbb.create(string: timezone.identifier),
            timezoneAbbreviationOffset: fbb.create(string: timezone.abbreviation),
            currentWeather: currentWeather,
            //timeStart: Int64(time),
            dailyOffset: daily,
            hourlyOffset: hourly,
            sixHourlyOffset: sixHourly,
            minutely15Offset: minutely15
            //currentVectorOffset: current?.toFlatbuffers(&fbb) ?? Offset(),
            //currentTime: (current?.time.timeIntervalSince1970).map(Int64.init) ?? 0,
            //currentIntervalSeconds: (current?.dtSeconds).map(Int32.init) ?? 0
        )
        fbb.finish(offset: result, addPrefix: true)
    }
    
    var flatBufferModel: com_openmeteo_WeatherModel {
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
        }
    }
}

extension ForecastVariable: VariableFlatbufferSerialisable {
    static func toFlatbuffers(section: ApiSection<Self>, _ fbb: inout FlatBuffers.FlatBufferBuilder) -> FlatBuffers.Offset {
        let data = section.columns.map { v in
            let valuesVectorOffset: Offset
            switch v.data {
            case .float(let data):
                valuesVectorOffset = fbb.createVector(data)
            case .timestamp(_):
                fatalError()
            }
            return com_openmeteo_ValuesAndUnit.createValuesAndUnit(&fbb, valuesVectorOffset: valuesVectorOffset, unit: v.unit)
        }
        
        let start = com_openmeteo_WeatherHourly.startWeatherHourly(&fbb)
        com_openmeteo_WeatherHourly.add(time: section.timeFlatBuffers(), &fbb)
        for (v, offset) in zip(section.columns, data) {
            switch v.variable {
            case .surface(let surface):
                switch surface {
                case .temperature_2m:
                    com_openmeteo_WeatherHourly.add(temperature2m: offset, &fbb)
                case .cloudcover:
                    com_openmeteo_WeatherHourly.add(cloudcover: offset, &fbb)
                case .cloudcover_low:
                    com_openmeteo_WeatherHourly.add(cloudcoverLow: offset, &fbb)
                case .cloudcover_mid:
                    com_openmeteo_WeatherHourly.add(cloudcoverMid: offset, &fbb)
                case .cloudcover_high:
                    com_openmeteo_WeatherHourly.add(cloudcoverHigh: offset, &fbb)
                case .pressure_msl:
                    com_openmeteo_WeatherHourly.add(pressureMsl: offset, &fbb)
                case .relativehumidity_2m:
                    com_openmeteo_WeatherHourly.add(relativehumidity2m: offset, &fbb)
                case .precipitation:
                    com_openmeteo_WeatherHourly.add(precipitation: offset, &fbb)
                case .precipitation_probability:
                    com_openmeteo_WeatherHourly.add(precipitationProbability: offset, &fbb)
                case .weathercode:
                    com_openmeteo_WeatherHourly.add(weathercode: offset, &fbb)
                case .temperature_80m:
                    com_openmeteo_WeatherHourly.add(temperature80m: offset, &fbb)
                case .temperature_120m:
                    com_openmeteo_WeatherHourly.add(temperature120m: offset, &fbb)
                case .temperature_180m:
                    com_openmeteo_WeatherHourly.add(temperature180m: offset, &fbb)
                case .soil_temperature_0cm:
                    com_openmeteo_WeatherHourly.add(soilTemperature0cm: offset, &fbb)
                case .soil_temperature_6cm:
                    com_openmeteo_WeatherHourly.add(soilTemperature6cm: offset, &fbb)
                case .soil_temperature_18cm:
                    com_openmeteo_WeatherHourly.add(soilTemperature18cm: offset, &fbb)
                case .soil_temperature_54cm:
                    com_openmeteo_WeatherHourly.add(soilTemperature54cm: offset, &fbb)
                case .soil_moisture_0_1cm:
                    com_openmeteo_WeatherHourly.add(soilMoisture01cm: offset, &fbb)
                case .soil_moisture_1_3cm:
                    com_openmeteo_WeatherHourly.add(soilMoisture13cm: offset, &fbb)
                case .soil_moisture_3_9cm:
                    com_openmeteo_WeatherHourly.add(soilMoisture39cm: offset, &fbb)
                case .soil_moisture_9_27cm:
                    com_openmeteo_WeatherHourly.add(soilMoisture927cm: offset, &fbb)
                case .soil_moisture_27_81cm:
                    com_openmeteo_WeatherHourly.add(soilMoisture2781cm: offset, &fbb)
                case .snow_depth:
                    com_openmeteo_WeatherHourly.add(snowDepth: offset, &fbb)
                case .snow_height:
                    com_openmeteo_WeatherHourly.add(snowHeight: offset, &fbb)
                case .sensible_heatflux:
                    com_openmeteo_WeatherHourly.add(sensibleHeatflux: offset, &fbb)
                case .latent_heatflux:
                    com_openmeteo_WeatherHourly.add(latentHeatflux: offset, &fbb)
                case .showers:
                    com_openmeteo_WeatherHourly.add(showers: offset, &fbb)
                case .rain:
                    com_openmeteo_WeatherHourly.add(rain: offset, &fbb)
                case .windgusts_10m:
                    com_openmeteo_WeatherHourly.add(windgusts10m: offset, &fbb)
                case .freezinglevel_height:
                    com_openmeteo_WeatherHourly.add(freezinglevelHeight: offset, &fbb)
                case .dewpoint_2m:
                    com_openmeteo_WeatherHourly.add(dewpoint2m: offset, &fbb)
                case .diffuse_radiation:
                    com_openmeteo_WeatherHourly.add(diffuseRadiation: offset, &fbb)
                case .direct_radiation:
                    com_openmeteo_WeatherHourly.add(directRadiation: offset, &fbb)
                case .apparent_temperature:
                    com_openmeteo_WeatherHourly.add(apparentTemperature: offset, &fbb)
                case .windspeed_10m:
                    com_openmeteo_WeatherHourly.add(windspeed10m: offset, &fbb)
                case .winddirection_10m:
                    com_openmeteo_WeatherHourly.add(winddirection10m: offset, &fbb)
                case .windspeed_80m:
                    com_openmeteo_WeatherHourly.add(windspeed80m: offset, &fbb)
                case .winddirection_80m:
                    com_openmeteo_WeatherHourly.add(winddirection80m: offset, &fbb)
                case .windspeed_120m:
                    com_openmeteo_WeatherHourly.add(windspeed120m: offset, &fbb)
                case .winddirection_120m:
                    com_openmeteo_WeatherHourly.add(winddirection120m: offset, &fbb)
                case .windspeed_180m:
                    com_openmeteo_WeatherHourly.add(windspeed180m: offset, &fbb)
                case .winddirection_180m:
                    com_openmeteo_WeatherHourly.add(winddirection180m: offset, &fbb)
                case .direct_normal_irradiance:
                    com_openmeteo_WeatherHourly.add(directNormalIrradiance: offset, &fbb)
                case .evapotranspiration:
                    com_openmeteo_WeatherHourly.add(evapotranspiration: offset, &fbb)
                case .et0_fao_evapotranspiration:
                    com_openmeteo_WeatherHourly.add(et0FaoEvapotranspiration: offset, &fbb)
                case .vapor_pressure_deficit:
                    com_openmeteo_WeatherHourly.add(vaporPressureDeficit: offset, &fbb)
                case .shortwave_radiation:
                    com_openmeteo_WeatherHourly.add(shortwaveRadiation: offset, &fbb)
                case .snowfall:
                    com_openmeteo_WeatherHourly.add(snowfall: offset, &fbb)
                case .surface_pressure:
                    com_openmeteo_WeatherHourly.add(surfacePressure: offset, &fbb)
                case .terrestrial_radiation:
                    com_openmeteo_WeatherHourly.add(terrestrialRadiation: offset, &fbb)
                case .terrestrial_radiation_instant:
                    com_openmeteo_WeatherHourly.add(terrestrialRadiationInstant: offset, &fbb)
                case .shortwave_radiation_instant:
                    com_openmeteo_WeatherHourly.add(shortwaveRadiationInstant: offset, &fbb)
                case .diffuse_radiation_instant:
                    com_openmeteo_WeatherHourly.add(diffuseRadiationInstant: offset, &fbb)
                case .direct_radiation_instant:
                    com_openmeteo_WeatherHourly.add(directRadiationInstant: offset, &fbb)
                case .direct_normal_irradiance_instant:
                    com_openmeteo_WeatherHourly.add(directNormalIrradianceInstant: offset, &fbb)
                case .visibility:
                    com_openmeteo_WeatherHourly.add(visibility: offset, &fbb)
                case .cape:
                    com_openmeteo_WeatherHourly.add(cape: offset, &fbb)
                case .uv_index:
                    com_openmeteo_WeatherHourly.add(uvIndex: offset, &fbb)
                case .uv_index_clear_sky:
                    com_openmeteo_WeatherHourly.add(uvIndexClearSky: offset, &fbb)
                case .is_day:
                    com_openmeteo_WeatherHourly.add(isDay: offset, &fbb)
                case .lightning_potential:
                    com_openmeteo_WeatherHourly.add(lightningPotential: offset, &fbb)
                }
            case .pressure(let pressure):
                fatalError()
            }
        }
        return com_openmeteo_WeatherHourly.endWeatherHourly(&fbb, start: start)
    }
}
extension ForecastVariableDaily: VariableFlatbufferSerialisable {
    static func toFlatbuffers(section: ApiSection<Self>, _ fbb: inout FlatBuffers.FlatBufferBuilder) -> FlatBuffers.Offset {
        fatalError()
    }
}


extension ApiSection {
    func timeFlatBuffers() -> com_openmeteo_TimeRange {
        return .init(
            start: Int64(time.range.lowerBound.timeIntervalSince1970),
            end: Int64(time.range.upperBound.timeIntervalSince1970),
            interval: Int32(Int64(time.dtSeconds))
        )
    }
}
