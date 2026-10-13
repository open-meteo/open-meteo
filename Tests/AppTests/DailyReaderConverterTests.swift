import Foundation
import Testing
@testable import App

@Suite struct DailyReaderConverterTests {
    private let start = Timestamp(2026, 1, 1)

    private var dailyTime: TimerangeDtAndSettings {
        TimerangeDt(start: start, to: start.add(hours: 48), dtSeconds: 86400)
            .toSettings(ensembleMember: 2, previousDay: 1, ensembleMemberLevel: 3)
    }

    @Test(arguments: [3600, 10800, 21600])
    func temperatureMinimumUsesIntervalsEndingWithinDay(modelDt: Int) async throws {
        let reader = FixtureReader(modelDtSeconds: modelDt, start: start)
        let converter = DailyReaderConverter<FixtureReader, ForecastVariableDaily>(reader: reader)

        let result = try #require(await converter.get(variable: .temperature_2m_min, time: dailyTime))
        // The starting midnight belongs to the previous day. Each following midnight
        // supplies the coldest interval of the day that just ended.
        #expect(result.data == [-5, -2])
        #expect(result.unit == .celsius)
        #expect(reader.reads.map(\.variable) == ["temperature_2m_min"])
        let expectedTime = dailyTime.with(time: TimerangeDt(start: start.add(modelDt), to: start.add(hours: 48).add(modelDt), dtSeconds: modelDt))
        #expect(reader.reads.map(\.time) == [expectedTime])

        _ = try await converter.prefetchData(variable: .temperature_2m_min, time: dailyTime)
        #expect(reader.prefetches.map(\.variable) == ["temperature_2m_min", "temperature_2m"])
        #expect(reader.prefetches.map(\.time) == [expectedTime, dailyTime.with(dtSeconds: modelDt)])
    }

    @Test(arguments: [3600, 10800, 21600])
    func precipitationSumUsesIntervalsEndingWithinDay(modelDt: Int) async throws {
        let reader = FixtureReader(modelDtSeconds: modelDt, start: start)
        let converter = DailyReaderConverter<FixtureReader, ForecastVariableDaily>(reader: reader)

        let result = try #require(await converter.get(variable: .precipitation_sum, time: dailyTime))
        // Each day has 1 mm per interval, except its final interval (7 and 11 mm).
        // The 100 mm at the starting midnight must never enter either daily total.
        let steps = Float(86400 / modelDt)
        #expect(result.data == [steps + 6, steps + 10])
        #expect(result.unit == .millimetre)
        #expect(reader.reads.map(\.variable) == ["precipitation"])
        let expectedTime = dailyTime.with(time: TimerangeDt(start: start.add(modelDt), to: start.add(hours: 48).add(modelDt), dtSeconds: modelDt))
        #expect(reader.reads.map(\.time) == [expectedTime])

        _ = try await converter.prefetchData(variable: .precipitation_sum, time: dailyTime)
        #expect(reader.prefetches.map(\.variable) == ["precipitation"])
        #expect(reader.prefetches.map(\.time) == [expectedTime])
    }

    private final class FixtureReader: GenericReaderOptionalProtocol {
        let modelLat: Float = 0
        let modelLon: Float = 0
        let modelElevation: ElevationOrSea = .sea
        let targetElevation: Float = 0
        let modelDtSeconds: Int
        let start: Timestamp
        var reads: [(variable: String, time: TimerangeDtAndSettings)] = []
        var prefetches: [(variable: String, time: TimerangeDtAndSettings)] = []

        init(modelDtSeconds: Int, start: Timestamp) {
            self.modelDtSeconds = modelDtSeconds
            self.start = start
        }

        func getStatic(type: ReaderStaticVariable) async throws -> Float? { nil }

        func get(variable: ForecastVariable, time: TimerangeDtAndSettings) async throws -> DataAndUnit? {
            reads.append((variable.rawValue, time))
            switch variable.rawValue {
            case "temperature_2m_min":
                let values: [Float] = time.time.map { timestamp in
                    if timestamp == start { return -100 }
                    if timestamp == start.add(hours: 24) { return -5 }
                    if timestamp == start.add(hours: 48) { return -2 }
                    return 10
                }
                return DataAndUnit(values, .celsius)
            case "precipitation":
                let values: [Float] = time.time.map { timestamp in
                    if timestamp == start { return 100 }
                    if timestamp == start.add(hours: 24) { return 7 }
                    if timestamp == start.add(hours: 48) { return 11 }
                    return 1
                }
                return DataAndUnit(values, .millimetre)
            default:
                Issue.record("Unexpected variable: \(variable.rawValue)")
                return nil
            }
        }

        func prefetchData(variable: ForecastVariable, time: TimerangeDtAndSettings) async throws -> Bool {
            prefetches.append((variable.rawValue, time))
            return true
        }
    }
}
