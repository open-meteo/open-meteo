import Testing

@testable import App

@Suite struct WeatherNext3Tests {
    @Test func rawPercentiles() async throws {
        let reader = VariableHourlyDeriver(
            reader: SampleReader<WeatherNext3Variable>(values: ["temperature_2m_p10": 18, "precipitation_p90": 12]),
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
        #expect(ForecastVariable(rawValue: "relative_humidity_2m_p90") == nil)
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
        typealias Station = WeatherNext3GridVariable<WeatherNext3StationGrid>
        typealias Surface = WeatherNext3GridVariable<WeatherNext3SurfaceGrid>
        #expect(Station(rawValue: "wind_speed_10m") == nil)
        #expect(Surface(rawValue: "temperature_2m") == nil)
        let mixer = GenericReaderMixerByVariableName<VariableSchemaUnion<Station, Surface>>(reader: [
            SampleReader<Surface>(values: [
                "wind_speed_10m": 8, "wind_u_component_10m": 3, "wind_v_component_10m": 4, "pressure_msl": 1013,
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
        for name in [
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
                reader: SampleReader<WeatherNext3Variable>(values: [
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
