import Testing

@testable import App

@Suite struct WeatherNext3Tests {
    typealias Station = WeatherNext3Variable<WeatherNext3StationField>
    typealias Surface = WeatherNext3Variable<WeatherNext3SurfaceField>

    @Test func percentilesUseNativeHourlySamples() async throws {
        try await checkNativeSamples(.station, WeatherNext3StationField.self)
        try await checkNativeSamples(.surface, WeatherNext3SurfaceField.self)
    }

    private func checkNativeSamples<Field: WeatherNext3Field>(_ domain: WeatherNext3Domain, _: Field.Type) async throws {
        let start = Timestamp(2026, 11, 8)
        let hourly = TimerangeDt(start: start, nTime: 7, dtSeconds: 3600)
        let quarterHourly = TimerangeDt(start: start, nTime: 4, dtSeconds: 900)
        let offsetHourly = TimerangeDt(start: start.add(900), nTime: 2, dtSeconds: 3600)
        let hourlyValues: [Float] = [10, 8, 5, 4, 3, 7, 9]

        for field in Field.allCases {
            let reader = try await GenericReader<WeatherNext3Domain, WeatherNext3Variable<Field>>(domain: domain, position: 0, options: GenericReaderOptions())
            #expect(WeatherNext3Variable(field: field, statistic: .mean).supportsTimeRange(quarterHourly))
            for statistic in field.statistics where statistic != .mean {
                let variable = WeatherNext3Variable(field: field, statistic: statistic)
                #expect(variable.supportsTimeRange(hourly))
                var unsupported = [quarterHourly, offsetHourly]
                for hours in [3, 6] {
                    let time = TimerangeDt(start: start, nTime: 1 + 6 / hours, dtSeconds: hours * 3600)
                    switch field.rawValue {
                    case "precipitation", "shortwave_radiation", "direct_radiation":
                        unsupported.append(time)
                    default:
                        #expect(variable.supportsTimeRange(time))
                        let selected = hourlyValues.aggregate(type: variable.interpolation, timeOld: hourly, timeNew: time)
                        #expect(selected == (hours == 3 ? [10, 4, 9] : [10, 9]))
                    }
                }
                for time in unsupported {
                    #expect(!variable.supportsTimeRange(time))
                    let output = try await reader.get(variable: variable, time: time.toSettings())
                    #expect(output.unit == field.unit)
                    #expect(output.data.count == time.count && output.data.allSatisfy { $0.isNaN })
                }
            }
        }
    }

    @Test func rawPercentiles() async throws {
        let reader = VariableHourlyDeriver(
            reader: SampleReader<VariableSchemaUnion<Station, Surface>>(values: ["temperature_2m_p10": 18, "precipitation_p90": 12]),
            options: try GenericReaderOptions(),
            domainRegistry: .google_weathernext3_station_ensemble_mean
        )
        let time = TimerangeDt(start: Timestamp(2026, 11, 8), nTime: 1, dtSeconds: 3600).toSettings()
        for (name, value, unit) in [("temperature_2m_p10", Float(18), SiUnit.celsius), ("precipitation_p90", Float(12), SiUnit.millimetre)] {
            let variable = try #require(ForecastVariable(rawValue: name))
            let normalized = variable.variableAndPreviousDay.0
            #expect(normalized.rawValue == name)
            let output = try #require(await reader.get(variable: normalized, time: time))
            #expect(output.data == [value])
            #expect(output.unit == unit)
        }
        #expect(ForecastVariable(rawValue: "temperature_2m_p99") == nil)
        let humidity = try #require(ForecastVariable(rawValue: "relative_humidity_2m_p90"))
        #expect(try await reader.get(variable: humidity, time: time) == nil)

        let alias = try #require(ForecastVariable(rawValue: "temperature_p10"))
        #expect(alias.rawValue == "temperature_p10")
        let normalized = alias.variableAndPreviousDay.0
        #expect(normalized.rawValue == "temperature_2m_p10")
        #expect(try await reader.get(variable: normalized, time: time)?.data == [18])

        let otherModel = VariableHourlyDeriver(
            reader: SampleReader<WeatherNextVariable>(values: ["temperature_2m": 20]),
            options: try GenericReaderOptions(),
            domainRegistry: .google_weathernext2_ensemble_mean
        )
        let percentile = try #require(ForecastVariable(rawValue: "temperature_2m_p10"))
        #expect(try await otherModel.get(variable: percentile, time: time) == nil)
        let temperature = try #require(ForecastVariable(rawValue: "temperature_2m"))
        #expect(try await otherModel.get(variable: temperature, time: time)?.data == [20])
    }

    private struct SampleReader<V: GenericVariable>: GenericReaderProtocol {
        let modelLat: Float = 10
        let modelLon: Float = 100
        let modelElevation: ElevationOrSea = .noData
        let targetElevation: Float = 0
        let modelDtSeconds = 3600
        let values: [String: Float]

        func getStatic(type: ReaderStaticVariable) async throws -> Float? { nil }

        func prefetchData(variable: V, time: TimerangeDtAndSettings) async throws {}

        func get(variable: V, time: TimerangeDtAndSettings) async throws -> DataAndUnit {
            DataAndUnit([values[variable.rawValue] ?? .nan], variable.unit)
        }
    }

    @Test func composedReaderPreservesNativeMeansAndRestrictsSpreads() async throws {
        #expect(Station(rawValue: "wind_speed_10m") == nil)
        #expect(Surface(rawValue: "temperature_2m") == nil)
        let mixer = GenericReaderMixerByVariableName<VariableSchemaUnion<Station, Surface>>(reader: [
            SampleReader<Surface>(values: [
                "wind_speed_10m": 8, "pressure_msl": 1013,
                "wind_u_component_10m": 0, "wind_v_component_10m": 5,
                "wind_u_component_100m": -6, "wind_v_component_100m": 0,
                "wind_speed_10m_p10": 0, "wind_speed_10m_p25": 1, "wind_speed_10m_p50": 2,
                "wind_speed_10m_p75": 5, "wind_speed_10m_p90": 10,
                "wind_speed_100m_p10": 2, "wind_speed_100m_p25": 3, "wind_speed_100m_p50": 5,
                "wind_speed_100m_p75": 9, "wind_speed_100m_p90": 15,
            ]),
            SampleReader<Station>(values: [
                "temperature_2m": 20, "dew_point_2m": 20, "temperature_2m_p10": 18, "temperature_2m_p90": 21.075724,
            ]),
        ])
        let reader = VariableHourlyDeriver(
            reader: mixer,
            options: try GenericReaderOptions(),
            domainRegistry: .google_weathernext3_station_ensemble_mean
        )
        let time = TimerangeDt(start: Timestamp(2026, 11, 8), nTime: 1, dtSeconds: 3600).toSettings()
        for (name, expected) in [
            ("temperature_2m", Float(20)), ("wind_speed_10m", 8), ("relative_humidity_2m", 100),
            ("temperature_2m_spread", 1.2),
        ] {
            let variable = try #require(ForecastVariable(rawValue: name))
            let output = try await reader.get(variable: variable, time: time)
            #expect(abs((output?.data.first ?? .nan) - expected) < 0.00001)
        }
        for (height, percentiles, intervalWidth) in [(10, [Float(0), 1, 2, 5, 10], Float(10)), (100, [2, 3, 5, 9, 15], 13)] {
            for (suffix, expected) in zip(["p10", "p25", "p50", "p75", "p90"], percentiles) {
                let variable = try #require(ForecastVariable(rawValue: "wind_speed_\(height)m_\(suffix)"))
                let output = try #require(await reader.get(variable: variable, time: time))
                #expect(output.data == [expected])
                #expect(output.unit == .metrePerSecond)
            }
            let variable = try #require(ForecastVariable(rawValue: "wind_speed_\(height)m_spread"))
            let output = try #require(await reader.get(variable: variable, time: time))
            #expect(abs(output.data[0] - intervalWidth / 2.5631) < 0.00001)
            #expect(output.unit == .metrePerSecond)
        }
        for (height, expected) in [(10, Float(180)), (100, 90)] {
            let variable = try #require(ForecastVariable(rawValue: "wind_direction_\(height)m"))
            let output = try #require(await reader.get(variable: variable, time: time))
            #expect(output.data == [expected])
            #expect(output.unit == .degreeDirection)
        }
        for name in [
            "wind_u_component_10m_spread", "wind_v_component_10m_spread",
            "wind_u_component_100m_spread", "wind_v_component_100m_spread",
            "wind_direction_10m_spread", "relative_humidity_2m_spread", "precipitation_spread",
        ] {
            let variable = try #require(ForecastVariable(rawValue: name))
            let output = try await reader.get(variable: variable, time: time)
            #expect(output == nil)
        }
    }

    @Test func spreadHandlesMissingAndReversedPercentiles() async throws {
        let time = TimerangeDt(start: Timestamp(2026, 11, 8), nTime: 1, dtSeconds: 3600).toSettings()
        let variable = try #require(ForecastVariable(rawValue: "temperature_2m_spread"))
        for (low, high) in [(Float.nan, Float(20)), (21, 20), (20, Float.infinity), (20, 20)] {
            let reader = VariableHourlyDeriver(
                reader: SampleReader<Station>(values: [
                    "temperature_2m_p10": low, "temperature_2m_p90": high,
                ]),
                options: try GenericReaderOptions(),
                domainRegistry: .google_weathernext3_station_ensemble_mean
            )
            let output = try #require(await reader.get(variable: variable, time: time))
            #expect(output.unit == .kelvin)
            if low == high {
                #expect(output.data == [0])
            } else {
                #expect(output.data[0].isNaN)
            }
        }
    }
}
