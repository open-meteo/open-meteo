import Foundation
import FlatBuffers
import Vapor

extension ForecastapiResult {
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

extension ForecastapiResult {
    static func encode(section: ApiSection<Model.DailyVariable>, _ fbb: inout FlatBufferBuilder) -> [Offset] {
        let offsets: [Offset] = section.columns.map { v in
            switch v.variables[0] {
            case .float(let float):
                return com_openmeteo_ValuesAndUnit.createValuesAndUnit(&fbb, valuesVectorOffset: fbb.createVector(float), unit: v.unit)
            case .timestamp(let time):
                return fbb.createVector(time.map({$0.timeIntervalSince1970}))
            }
        }
        return offsets
    }
    
    
    static func encode(section: ApiSection<SurfaceAndPressureVariable>, _ fbb: inout FlatBufferBuilder) -> (surface: [(variable: Model.HourlyVariable, offset: Offset)], pressure: [(variable: Model.HourlyPressureType, offset: Offset)]) {
        var surfaces = [(variable: Model.HourlyVariable, offset: Offset)]()
        surfaces.reserveCapacity(section.columns.count)
        var pressures = [(variable: Model.HourlyPressureType, unit: SiUnit, offsets: [Offset])]()
        
        for v in section.columns {
            switch v.variable {
            case .surface(let surface):
                let offset = com_openmeteo_ValuesAndUnit.createValuesAndUnit(&fbb, valuesVectorOffset: v.variables[0].expectFloatArray(&fbb), unit: v.unit)
                surfaces.append((surface, offset))
            case .pressure(let pressure):
                let offset = com_openmeteo_ValuesAndLevel.createValuesAndLevel(&fbb, level: Int32(pressure.level), valuesVectorOffset: v.variables[0].expectFloatArray(&fbb))
                if let pos = pressures.firstIndex(where: {$0.variable == pressure.variable}) {
                    pressures[pos].offsets.append(offset)
                } else {
                    pressures.append((pressure.variable, v.unit, [offset]))
                }
            }
        }
        
        let pressureVectors: [(variable: Model.HourlyPressureType, offset: Offset)] = pressures.map { (variable, unit, offsets) in
            return (variable, com_openmeteo_ValuesUnitPressureLevel.createValuesUnitPressureLevel(&fbb, unit: unit, valuesVectorOffset: fbb.createVector(ofOffsets: offsets)))
        }
        
        return (surfaces, pressureVectors)
    }
}

extension MultiDomains: ModelFlatbufferSerialisable {
    typealias HourlyVariable = ForecastSurfaceVariable
    
    typealias HourlyPressureType = ForecastPressureVariableType
    
    typealias DailyVariable = ForecastVariableDaily
    
    static func encodeHourly(section: ApiSection<ForecastapiResult<Self>.SurfaceAndPressureVariable>, _ fbb: inout FlatBufferBuilder) -> Offset {
        let offsets = ForecastapiResult.encode(section: section, &fbb)
        let start = com_openmeteo_WeatherHourly.startWeatherHourly(&fbb)
        com_openmeteo_WeatherHourly.add(time: section.timeFlatBuffers(), &fbb)
        for (surface, offset) in offsets.surface {
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
                fallthrough
            case .soil_moisture_0_to_1cm:
                com_openmeteo_WeatherHourly.add(soilMoisture0To1cm: offset, &fbb)
            case .soil_moisture_1_3cm:
                fallthrough
            case .soil_moisture_1_to_3cm:
                com_openmeteo_WeatherHourly.add(soilMoisture1To3cm: offset, &fbb)
            case .soil_moisture_3_9cm:
                fallthrough
            case .soil_moisture_3_to_9cm:
                com_openmeteo_WeatherHourly.add(soilMoisture3To9cm: offset, &fbb)
            case .soil_moisture_9_27cm:
                fallthrough
            case .soil_moisture_9_to_27cm:
                com_openmeteo_WeatherHourly.add(soilMoisture9To27cm: offset, &fbb)
            case .soil_moisture_27_81cm:
                fallthrough
            case .soil_moisture_27_to_81cm:
                com_openmeteo_WeatherHourly.add(soilMoisture27To81cm: offset, &fbb)
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
            case .growing_degree_days_base_0_limit_50:
                com_openmeteo_WeatherHourly.add(growingDegreeDaysBase0Limit50: offset, &fbb)
            case .leaf_wetness_probability:
                com_openmeteo_WeatherHourly.add(leafWetnessProbability: offset, &fbb)
            case .runoff:
                com_openmeteo_WeatherHourly.add(runoff: offset, &fbb)
            case .skin_temperature:
                com_openmeteo_WeatherHourly.add(skinTemperature: offset, &fbb)
            case .snowfall_water_equivalent:
                com_openmeteo_WeatherHourly.add(snowfallWaterEquivalent: offset, &fbb)
            case .soil_moisture_0_to_100cm:
                com_openmeteo_WeatherHourly.add(soilMoisture0To100cm: offset, &fbb)
            case .soil_moisture_0_to_10cm:
                com_openmeteo_WeatherHourly.add(soilMoisture0To10cm: offset, &fbb)
            case .soil_moisture_0_to_7cm:
                com_openmeteo_WeatherHourly.add(soilMoisture0To7cm: offset, &fbb)
            case .soil_moisture_100_to_200cm:
                com_openmeteo_WeatherHourly.add(soilMoisture100To200cm: offset, &fbb)
            case .soil_moisture_100_to_255cm:
                com_openmeteo_WeatherHourly.add(soilMoisture100To255cm: offset, &fbb)
            case .soil_moisture_10_to_40cm:
                com_openmeteo_WeatherHourly.add(soilMoisture10To40cm: offset, &fbb)
            case .soil_moisture_28_to_100cm:
                com_openmeteo_WeatherHourly.add(soilMoisture28To100cm: offset, &fbb)
            case .soil_moisture_40_to_100cm:
                com_openmeteo_WeatherHourly.add(soilMoisture40To100cm: offset, &fbb)
            case .soil_moisture_7_to_28cm:
                com_openmeteo_WeatherHourly.add(soilMoisture7To28cm: offset, &fbb)
            case .soil_moisture_index_0_to_100cm:
                com_openmeteo_WeatherHourly.add(soilMoistureIndex0To100cm: offset, &fbb)
            case .soil_moisture_index_0_to_7cm:
                com_openmeteo_WeatherHourly.add(soilMoistureIndex0To7cm: offset, &fbb)
            case .soil_moisture_index_100_to_255cm:
                com_openmeteo_WeatherHourly.add(soilMoistureIndex100To255cm: offset, &fbb)
            case .soil_moisture_index_28_to_100cm:
                com_openmeteo_WeatherHourly.add(soilMoistureIndex28To100cm: offset, &fbb)
            case .soil_moisture_index_7_to_28cm:
                com_openmeteo_WeatherHourly.add(soilMoistureIndex7To28cm: offset, &fbb)
            case .soil_temperature_0_to_100cm:
                com_openmeteo_WeatherHourly.add(soilTemperature0To100cm: offset, &fbb)
            case .soil_temperature_0_to_10cm:
                com_openmeteo_WeatherHourly.add(soilTemperature0To10cm: offset, &fbb)
            case .soil_temperature_0_to_7cm:
                com_openmeteo_WeatherHourly.add(soilTemperature0To7cm: offset, &fbb)
            case .soil_temperature_100_to_200cm:
                com_openmeteo_WeatherHourly.add(soilTemperature100To200cm: offset, &fbb)
            case .soil_temperature_100_to_255cm:
                com_openmeteo_WeatherHourly.add(soilTemperature100To255cm: offset, &fbb)
            case .soil_temperature_10_to_40cm:
                com_openmeteo_WeatherHourly.add(soilTemperature10To40cm: offset, &fbb)
            case .soil_temperature_28_to_100cm:
                com_openmeteo_WeatherHourly.add(soilTemperature28To100cm: offset, &fbb)
            case .soil_temperature_40_to_100cm:
                com_openmeteo_WeatherHourly.add(soilTemperature40To100cm: offset, &fbb)
            case .soil_temperature_7_to_28cm:
                com_openmeteo_WeatherHourly.add(soilTemperature7To28cm: offset, &fbb)
            case .surface_air_pressure:
                com_openmeteo_WeatherHourly.add(surfaceAirPressure: offset, &fbb)
            case .surface_temperature:
                com_openmeteo_WeatherHourly.add(surfaceTemperature: offset, &fbb)
            case .temperature_40m:
                com_openmeteo_WeatherHourly.add(temperature40m: offset, &fbb)
            case .total_column_integrated_water_vapour:
                com_openmeteo_WeatherHourly.add(totalColumnIntegratedWaterVapour: offset, &fbb)
            case .updraft:
                com_openmeteo_WeatherHourly.add(updraft: offset, &fbb)
            case .winddirection_100m:
                com_openmeteo_WeatherHourly.add(winddirection100m: offset, &fbb)
            case .winddirection_150m:
                com_openmeteo_WeatherHourly.add(winddirection150m: offset, &fbb)
            case .winddirection_200m:
                com_openmeteo_WeatherHourly.add(winddirection200m: offset, &fbb)
            case .winddirection_20m:
                com_openmeteo_WeatherHourly.add(winddirection20m: offset, &fbb)
            case .winddirection_40m:
                com_openmeteo_WeatherHourly.add(winddirection40m: offset, &fbb)
            case .winddirection_50m:
                com_openmeteo_WeatherHourly.add(winddirection50m: offset, &fbb)
            case .windspeed_100m:
                com_openmeteo_WeatherHourly.add(windspeed100m: offset, &fbb)
            case .windspeed_150m:
                com_openmeteo_WeatherHourly.add(windspeed150m: offset, &fbb)
            case .windspeed_200m:
                com_openmeteo_WeatherHourly.add(windspeed200m: offset, &fbb)
            case .windspeed_20m:
                com_openmeteo_WeatherHourly.add(windspeed20m: offset, &fbb)
            case .windspeed_40m:
                com_openmeteo_WeatherHourly.add(windspeed40m: offset, &fbb)
            case .windspeed_50m:
                com_openmeteo_WeatherHourly.add(windspeed50m: offset, &fbb)
            }
        }
        for (pressure, offset) in offsets.pressure {
            switch pressure {
            case .temperature:
                com_openmeteo_WeatherHourly.add(pressureLevelTemperature: offset, &fbb)
            case .geopotential_height:
                com_openmeteo_WeatherHourly.add(pressureLevelGeopotentialHeight: offset, &fbb)
            case .relativehumidity:
                com_openmeteo_WeatherHourly.add(pressureLevelRelativehumidity: offset, &fbb)
            case .windspeed:
                com_openmeteo_WeatherHourly.add(pressureLevelWindspeed: offset, &fbb)
            case .winddirection:
                com_openmeteo_WeatherHourly.add(pressureLevelWinddirection: offset, &fbb)
            case .dewpoint:
                com_openmeteo_WeatherHourly.add(pressureLevelDewpoint: offset, &fbb)
            case .cloudcover:
                com_openmeteo_WeatherHourly.add(pressureLevelCloudcover: offset, &fbb)
            }
        }
        return com_openmeteo_WeatherHourly.endWeatherHourly(&fbb, start: start)
    }
    
    static func encodeDaily(section: ApiSection<DailyVariable>, _ fbb: inout FlatBufferBuilder) -> Offset {
        let offsets = ForecastapiResult<Self>.encode(section: section, &fbb)
        let start = com_openmeteo_WeatherDaily.startWeatherDaily(&fbb)
        com_openmeteo_WeatherDaily.add(time: section.timeFlatBuffers(), &fbb)
        for (variable, offset) in zip(section.columns, offsets) {
            switch variable.variable {
            case .temperature_2m_max:
                com_openmeteo_WeatherDaily.add(temperature2mMax: offset, &fbb)
            case .temperature_2m_min:
                com_openmeteo_WeatherDaily.add(temperature2mMin: offset, &fbb)
            case .temperature_2m_mean:
                com_openmeteo_WeatherDaily.add(temperature2mMean: offset, &fbb)
            case .apparent_temperature_max:
                com_openmeteo_WeatherDaily.add(apparentTemperatureMax: offset, &fbb)
            case .apparent_temperature_min:
                com_openmeteo_WeatherDaily.add(apparentTemperatureMin: offset, &fbb)
            case .apparent_temperature_mean:
                com_openmeteo_WeatherDaily.add(apparentTemperatureMean: offset, &fbb)
            case .precipitation_sum:
                com_openmeteo_WeatherDaily.add(precipitationSum: offset, &fbb)
            case .precipitation_probability_max:
                com_openmeteo_WeatherDaily.add(precipitationProbabilityMax: offset, &fbb)
            case .precipitation_probability_min:
                com_openmeteo_WeatherDaily.add(precipitationProbabilityMin: offset, &fbb)
            case .precipitation_probability_mean:
                com_openmeteo_WeatherDaily.add(precipitationProbabilityMean: offset, &fbb)
            case .snowfall_sum:
                com_openmeteo_WeatherDaily.add(snowfallSum: offset, &fbb)
            case .rain_sum:
                com_openmeteo_WeatherDaily.add(rainSum: offset, &fbb)
            case .showers_sum:
                com_openmeteo_WeatherDaily.add(showersSum: offset, &fbb)
            case .weathercode:
                com_openmeteo_WeatherDaily.add(weathercode: offset, &fbb)
            case .shortwave_radiation_sum:
                com_openmeteo_WeatherDaily.add(shortwaveRadiationSum: offset, &fbb)
            case .windspeed_10m_max:
                com_openmeteo_WeatherDaily.add(windspeed10mMax: offset, &fbb)
            case .windspeed_10m_min:
                com_openmeteo_WeatherDaily.add(windspeed10mMin: offset, &fbb)
            case .windspeed_10m_mean:
                com_openmeteo_WeatherDaily.add(windspeed10mMean: offset, &fbb)
            case .windgusts_10m_max:
                com_openmeteo_WeatherDaily.add(windgusts10mMax: offset, &fbb)
            case .windgusts_10m_min:
                com_openmeteo_WeatherDaily.add(windgusts10mMin: offset, &fbb)
            case .windgusts_10m_mean:
                com_openmeteo_WeatherDaily.add(windgusts10mMean: offset, &fbb)
            case .winddirection_10m_dominant:
                com_openmeteo_WeatherDaily.add(winddirection10mDominant: offset, &fbb)
            case .precipitation_hours:
                com_openmeteo_WeatherDaily.add(precipitationSum: offset, &fbb)
            case .sunrise:
                com_openmeteo_WeatherDaily.addVectorOf(sunrise: offset, &fbb)
            case .sunset:
                com_openmeteo_WeatherDaily.addVectorOf(sunset: offset, &fbb)
            case .et0_fao_evapotranspiration:
                com_openmeteo_WeatherDaily.add(et0FaoEvapotranspiration: offset, &fbb)
            case .visibility_max:
                com_openmeteo_WeatherDaily.add(visibilityMax: offset, &fbb)
            case .visibility_min:
                com_openmeteo_WeatherDaily.add(visibilityMin: offset, &fbb)
            case .visibility_mean:
                com_openmeteo_WeatherDaily.add(visibilityMean: offset, &fbb)
            case .pressure_msl_max:
                com_openmeteo_WeatherDaily.add(pressureMslMax: offset, &fbb)
            case .pressure_msl_min:
                com_openmeteo_WeatherDaily.add(pressureMslMin: offset, &fbb)
            case .pressure_msl_mean:
                com_openmeteo_WeatherDaily.add(pressureMslMean: offset, &fbb)
            case .surface_pressure_max:
                com_openmeteo_WeatherDaily.add(surfacePressureMax: offset, &fbb)
            case .surface_pressure_min:
                com_openmeteo_WeatherDaily.add(surfacePressureMin: offset, &fbb)
            case .surface_pressure_mean:
                com_openmeteo_WeatherDaily.add(surfacePressureMean: offset, &fbb)
            case .cape_max:
                com_openmeteo_WeatherDaily.add(capeMax: offset, &fbb)
            case .cape_min:
                com_openmeteo_WeatherDaily.add(capeMin: offset, &fbb)
            case .cape_mean:
                com_openmeteo_WeatherDaily.add(capeMean: offset, &fbb)
            case .cloudcover_max:
                com_openmeteo_WeatherDaily.add(cloudcoverMax: offset, &fbb)
            case .cloudcover_min:
                com_openmeteo_WeatherDaily.add(cloudcoverMin: offset, &fbb)
            case .cloudcover_mean:
                com_openmeteo_WeatherDaily.add(cloudcoverMean: offset, &fbb)
            case .uv_index_max:
                com_openmeteo_WeatherDaily.add(uvIndexMax: offset, &fbb)
            case .uv_index_clear_sky_max:
                com_openmeteo_WeatherDaily.add(uvIndexClearSkyMax: offset, &fbb)
            case .dewpoint_2m_max:
                com_openmeteo_WeatherDaily.add(dewpoint2mMax: offset, &fbb)
            case .dewpoint_2m_mean:
                com_openmeteo_WeatherDaily.add(dewpoint2mMean: offset, &fbb)
            case .dewpoint_2m_min:
                com_openmeteo_WeatherDaily.add(dewpoint2mMin: offset, &fbb)
            case .et0_fao_evapotranspiration_sum:
                com_openmeteo_WeatherDaily.add(et0FaoEvapotranspirationSum: offset, &fbb)
            case .growing_degree_days_base_0_limit_50:
                com_openmeteo_WeatherDaily.add(growingDegreeDaysBase0Limit50: offset, &fbb)
            case .leaf_wetness_probability_mean:
                com_openmeteo_WeatherDaily.add(leafWetnessProbabilityMean: offset, &fbb)
            case .relative_humidity_2m_max:
                com_openmeteo_WeatherDaily.add(relativeHumidity2mMax: offset, &fbb)
            case .relative_humidity_2m_mean:
                com_openmeteo_WeatherDaily.add(relativeHumidity2mMean: offset, &fbb)
            case .relative_humidity_2m_min:
                com_openmeteo_WeatherDaily.add(relativeHumidity2mMin: offset, &fbb)
            case .snowfall_water_equivalent_sum:
                com_openmeteo_WeatherDaily.add(snowfallWaterEquivalentSum: offset, &fbb)
            case .soil_moisture_0_to_100cm_mean:
                com_openmeteo_WeatherDaily.add(soilMoisture0To100cmMean: offset, &fbb)
            case .soil_moisture_0_to_10cm_mean:
                com_openmeteo_WeatherDaily.add(soilMoisture0To10cmMean: offset, &fbb)
            case .soil_moisture_0_to_7cm_mean:
                com_openmeteo_WeatherDaily.add(soilMoisture0To7cmMean:  offset, &fbb)
            case .soil_moisture_28_to_100cm_mean:
                com_openmeteo_WeatherDaily.add(soilMoisture28To100cmMean: offset, &fbb)
            case .soil_moisture_7_to_28cm_mean:
                com_openmeteo_WeatherDaily.add(soilMoisture7To28cmMean: offset, &fbb)
            case .soil_moisture_index_0_to_100cm_mean:
                com_openmeteo_WeatherDaily.add(soilMoistureIndex0To100cmMean: offset, &fbb)
            case .soil_moisture_index_0_to_7cm_mean:
                com_openmeteo_WeatherDaily.add(soilMoistureIndex0To7cmMean: offset, &fbb)
            case .soil_moisture_index_100_to_255cm_mean:
                com_openmeteo_WeatherDaily.add(soilMoistureIndex100To255cmMean: offset, &fbb)
            case .soil_moisture_index_28_to_100cm_mean:
                com_openmeteo_WeatherDaily.add(soilMoistureIndex28To100cmMean: offset, &fbb)
            case .soil_moisture_index_7_to_28cm_mean:
                com_openmeteo_WeatherDaily.add(soilMoistureIndex7To28cmMean: offset, &fbb)
            case .soil_temperature_0_to_100cm_mean:
                com_openmeteo_WeatherDaily.add(soilTemperature0To100cmMean: offset, &fbb)
            case .soil_temperature_0_to_7cm_mean:
                com_openmeteo_WeatherDaily.add(soilTemperature0To7cmMean: offset, &fbb)
            case .soil_temperature_28_to_100cm_mean:
                com_openmeteo_WeatherDaily.add(soilTemperature28To100cmMean: offset, &fbb)
            case .soil_temperature_7_to_28cm_mean:
                com_openmeteo_WeatherDaily.add(soilTemperature7To28cmMean: offset, &fbb)
            case .updraft_max:
                com_openmeteo_WeatherDaily.add(updraftMax: offset, &fbb)
            case .vapor_pressure_deficit_max:
                com_openmeteo_WeatherDaily.add(vaporPressureDeficitMax: offset, &fbb)
            }
        }
        return com_openmeteo_WeatherDaily.endWeatherDaily(&fbb, start: start)
    }
    
    static func writeToFlatbuffer(section: ForecastapiResult<Self>.PerModel, _ fbb: inout FlatBufferBuilder, timezone: TimezoneWithOffset, fixedGenerationTime: Double?) throws {
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
        let hourly = (try section.hourly?()).map { encodeHourly(section: $0, &fbb) } ?? Offset()
        
        //let time = section. section.sections.first?.time.range.lowerBound.timeIntervalSince1970 ?? 0
        let minutely15 = (try section.minutely15?()).map { encodeHourly(section: $0, &fbb) } ?? Offset()
        let sixHourly = (try section.sixHourly?()).map { encodeHourly(section: $0, &fbb) } ?? Offset()
        let daily = (try section.daily?()).map { encodeDaily(section: $0, &fbb) } ?? Offset()
        
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

extension ApiArray {
    func expectFloatArray(_ fbb: inout FlatBuffers.FlatBufferBuilder) -> Offset {
        switch self {
        case .float(let array):
            return fbb.createVector(array)
        case .timestamp(_):
            fatalError("Expected float array and not timestamps")
        }
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


extension EnsembleSurfaceVariable {

}


extension EnsembleMultiDomains: ModelFlatbufferSerialisable {
    typealias HourlyVariable = EnsembleSurfaceVariable
    
    typealias HourlyPressureType = EnsemblePressureVariableType
    
    typealias DailyVariable = ForecastVariableDaily
    
    
    
    var flatBufferModel: com_openmeteo_EnsembleModel {
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
    
    static func writeToFlatbuffer(section: ForecastapiResult<Self>.PerModel, _ fbb: inout FlatBuffers.FlatBufferBuilder, timezone: TimezoneWithOffset, fixedGenerationTime: Double?) throws {
        fatalError()
    }
}
