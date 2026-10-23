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

    @Test(arguments: [3600, 10800, 21600], [ForecastVariableDaily.precipitation_sum, .shortwave_radiation_sum])
    func sumsUseUnshiftedHoursForBackwardsCompatibility(modelDt: Int, variable: ForecastVariableDaily) async throws {
        let reader = FixtureReader(modelDtSeconds: modelDt, start: start)
        let converter = DailyReaderConverter<FixtureReader, ForecastVariableDaily>(reader: reader)
        let steps = Float(86400 / modelDt)
        let isRadiation = variable == .shortwave_radiation_sum
        let factor: Float = isRadiation ? Float(modelDt) / 1000000 : 1
        let expectedUnit: SiUnit = isRadiation ? .megajoulePerSquareMetre : .millimetre

        let complete = try #require(await converter.get(variable: variable, time: dailyTime))
        #expect(complete.data == [steps + 99, steps + 6].map { $0 * factor }.round(digits: 2))
        #expect(complete.unit == expectedUnit)

        let expectedTime = dailyTime.with(dtSeconds: modelDt)
        #expect(reader.reads.map(\.time) == [expectedTime])
        _ = try await converter.prefetchData(variable: variable, time: dailyTime)
        #expect(reader.prefetches.map(\.time) == [expectedTime])
        #expect(reader.prefetches.map(\.variable) == reader.reads.map(\.variable))

        // The next midnight is outside the aggregation window and may be unavailable.
        reader.missingTimes = [start.add(hours: 48)]
        let missingLast = try #require(await converter.get(variable: variable, time: dailyTime))
        #expect(missingLast.data == complete.data)
        #expect(missingLast.unit == expectedUnit)

        // A missing interval inside the day, including its last interval, invalidates the total.
        reader.missingTimes = [start.add(hours: 48), start.add(hours: 48).add(-modelDt)]
        let missingEarlier = try #require(await converter.get(variable: variable, time: dailyTime))
        #expect(missingEarlier.data[0] == complete.data[0])
        #expect(missingEarlier.data[1].isNaN)

        reader.missingTimes = Array(expectedTime.time)
        let missingAll = try #require(await converter.get(variable: variable, time: dailyTime))
        #expect(missingAll.data.count == 2)
        #expect(missingAll.data.allSatisfy { $0.isNaN })
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
        var missingTimes: [Timestamp] = []

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
            case "precipitation", "shortwave_radiation":
                let values: [Float] = time.time.map { timestamp in
                    if missingTimes.contains(timestamp) { return .nan }
                    if timestamp == start { return 100 }
                    if timestamp == start.add(hours: 24) { return 7 }
                    if timestamp == start.add(hours: 48) { return 11 }
                    return 1
                }
                return DataAndUnit(values, variable.rawValue == "precipitation" ? .millimetre : .wattPerSquareMetre)
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
