import Testing

@testable import App

@Suite struct WeatherNext3Tests {
    typealias Station = WeatherNext3Variable<WeatherNext3StationField>
    typealias Surface = WeatherNext3Variable<WeatherNext3SurfaceField>

    @Test func percentilesUseNativeHourlySamples() async throws {
        let start = Timestamp(2026, 11, 8)
        let hourly = TimerangeDt(start: start, nTime: 7, dtSeconds: 3600)
        let threeHourly = TimerangeDt(start: start, nTime: 3, dtSeconds: 3 * 3600)
        let temperature = Station(field: .temperature_2m, statistic: .p50)
        #expect(temperature.supportsTimeRange(threeHourly))
        #expect(!temperature.supportsTimeRange(TimerangeDt(start: start, nTime: 4, dtSeconds: 900)))
        #expect(!temperature.supportsTimeRange(TimerangeDt(start: start.add(900), nTime: 2, dtSeconds: 3600)))
        let precipitation = Surface(field: .precipitation, statistic: .p90)
        let radiation = Surface(field: .shortwave_radiation, statistic: .p25)
        for variable in [precipitation, radiation] {
            #expect(variable.supportsTimeRange(hourly))
            #expect(!variable.supportsTimeRange(threeHourly))
        }

        let reader = try await GenericReader<WeatherNext3Domain, Surface>(domain: .surface, position: 0, options: GenericReaderOptions())
        let output = try await reader.get(variable: precipitation, time: threeHourly.toSettings())
        #expect(output.unit == .millimetre)
        #expect(output.data.count == threeHourly.count && output.data.allSatisfy { $0.isNaN })
    }

    @Test func percentileNames() throws {
        let variable = try #require(ForecastVariable(rawValue: "temperature_2m_p10"))
        #expect(variable.rawValue == "temperature_2m_p10")
        #expect(variable.variableAndPreviousDay.0.rawValue == "temperature_2m_p10")
        #expect(ForecastVariable(rawValue: "temperature_p10") == nil)
        #expect(ForecastVariable(rawValue: "temperature_2m_p99") == nil)
        let previous = try #require(ForecastVariable(rawValue: "temperature_2m_p10_previous_day1"))
        #expect(previous.variableAndPreviousDay.0.rawValue == "temperature_2m_p10")
        #expect(previous.variableAndPreviousDay.1 == 1)
        let meta = VariableAndPreviousDay(.temperature_2m_p50, 1).getFlatBuffersMeta()
        #expect(meta.aggregation == .median)
        #expect(meta.altitude == 2)
        #expect(meta.previousDay == 1)
        #expect(WeatherNextVariable(rawValue: "temperature_2m_p10") == nil)
        #expect(WeatherNextVariable(rawValue: "temperature_2m") != nil)
    }

    @Test func readsStationAndSurfaceStatistics() async throws {
        let mixer = GenericReaderMixerByVariableName<VariableSchemaUnion<Station, Surface>>(reader: [
            SampleReader<Surface>(values: ["wind_speed_10m": 8, "wind_speed_10m_p90": 12]),
            SampleReader<Station>(values: ["temperature_2m_p10": 18, "temperature_2m_p90": 21.075724]),
        ])
        let reader = VariableHourlyDeriver(reader: mixer, options: try GenericReaderOptions(), domainRegistry: .google_weathernext3_station_ensemble_mean)
        let time = TimerangeDt(start: Timestamp(2026, 11, 8), nTime: 1, dtSeconds: 3600).toSettings()
        func read(_ name: String) async throws -> DataAndUnit? {
            let variable = try #require(ForecastVariable(rawValue: name))
            return try await reader.get(variable: variable.variableAndPreviousDay.0, time: time)
        }

        #expect(try await read("temperature_2m_p10")?.data == [18])
        #expect(try await read("wind_speed_10m")?.data == [8])
        #expect(try await read("wind_speed_10m_p90")?.data == [12])
        #expect(ForecastVariable(rawValue: "relative_humidity_2m_p90") == nil)
        #expect(try await read("precipitation_spread") == nil)
        let spread = try #require(await read("temperature_2m_spread"))
        #expect(spread.unit == .kelvin)
        #expect(abs(spread.data[0] - 1.2) < 0.00001)
        let missing = try #require(await read("wind_speed_10m_spread"))
        #expect(missing.data[0].isNaN)
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
}
