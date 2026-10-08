import Foundation
import Testing
@testable import App

@Suite struct ReaderRunFallbackTests {
    private let variable = ForecastVariable.surface(.init(.temperature_2m, 0))

    private func time(singleRun: Bool = true) throws -> TimerangeDtAndSettings {
        let params = try JSONDecoder().decode(ApiQueryParameter.self, from: Data(#"{"run":"2026-06-01T06:00"}"#.utf8))
        return TimerangeDt(start: Timestamp(2026, 6, 1, 6), nTime: 2, dtSeconds: 900)
            .toSettings(run: singleRun ? params.run : nil)
    }

    private func mixers(_ readers: [RunFixtureReader]) -> [any GenericReaderOptionalProtocol<ForecastVariable>] {
        [
            GenericReaderMulti<ForecastVariable>(reader: readers),
            GenericReaderMultiSameType<ForecastVariable>(reader: readers.map { $0.asOptionalReader }, prefetchAllReaders: true),
            GenericReaderMixerSameVariableType(reader: readers).asOptionalReader,
            GenericReaderMixerByVariableName<IconVariable>(reader: readers).asOptionalReader
        ]
    }

    @Test(arguments: [true, false])
    func unavailableReadersAreSkipped(preferredUnavailable: Bool) async throws {
        let time = try time()
        let available = RunFixtureReader(values: [10, 20])
        let missing = RunFixtureReader(error: ForecastApiError.modelRunUnavailable(model: .dwd_icon_d2, run: time.run!.toTimestamp()))
        for mixer in mixers(preferredUnavailable ? [available, missing] : [missing, available]) {
            #expect(try await mixer.prefetchData(variable: variable, time: time))
            #expect(try await mixer.get(variable: variable, time: time)?.data == [10, 20])
        }
    }

    @Test func availableQuarterHourlyReaderKeepsPriority() async throws {
        for mixer in mixers([RunFixtureReader(values: [10, 10]), RunFixtureReader(values: [20, 21])]) {
            #expect(try await mixer.get(variable: variable, time: time())?.data == [20, 21])
        }
    }

    @Test func rucPriorityFallsBackAfterHorizon() async throws {
        let readers = [RunFixtureReader(values: [10, 20]), RunFixtureReader(values: [30, .nan])]
        let mixer = GenericReaderMultiSameType<ForecastVariable>(reader: readers.map { $0.asOptionalReader }, prefetchAllReaders: true, smoothTransitions: false)
        #expect(try await mixer.get(variable: variable, time: time())?.data == [30, 20])
    }

    @Test func availableReadersStillFillGaps() async throws {
        for mixer in mixers([RunFixtureReader(values: [10, 20]), RunFixtureReader(values: [.nan, .nan])]) {
            #expect(try await mixer.get(variable: variable, time: time())?.data == [10, 20])
        }
    }

    @Test(arguments: [true, false])
    func unavailableRunIsReportedWhenNoReaderSucceeds(singleRun: Bool) async throws {
        let time = try time(singleRun: singleRun)
        let error = ForecastApiError.modelRunUnavailable(model: .dwd_icon_d2, run: time.time.range.lowerBound)
        for mixer in mixers([RunFixtureReader(error: error), RunFixtureReader(error: error)]) {
            await #expect(throws: ForecastApiError.self) {
                _ = try await mixer.prefetchData(variable: variable, time: time)
            }
            await #expect(throws: ForecastApiError.self) {
                _ = try await mixer.get(variable: variable, time: time)
            }
        }
    }

    @Test func otherErrorsAreNotSuppressed() async throws {
        enum ReadError: Error { case corrupt }
        for mixer in mixers([RunFixtureReader(error: ReadError.corrupt), RunFixtureReader(error: ReadError.corrupt)]) {
            await #expect(throws: ReadError.self) {
                _ = try await mixer.prefetchData(variable: variable, time: time())
            }
            await #expect(throws: ReadError.self) {
                _ = try await mixer.get(variable: variable, time: time())
            }
        }
    }

    @Test func unsupportedVariableDoesNotHideUnavailableRun() async throws {
        let time = try time()
        var fallback = ReaderRunFallback(time: time)
        let _: Bool? = try await fallback.read { nil }
        let _: Bool? = try await fallback.read {
            throw ForecastApiError.modelRunUnavailable(model: .dwd_icon_d2, run: time.run!.toTimestamp())
        }
        #expect(throws: ForecastApiError.self) { try fallback.finish() }
    }

    @Test func requestsWithoutRunDoNotSuppressErrors() async throws {
        var fallback = ReaderRunFallback(time: try time(singleRun: false))
        await #expect(throws: ForecastApiError.self) {
            let _: Bool? = try await fallback.read {
                throw ForecastApiError.modelRunUnavailable(model: .dwd_icon_d2, run: Timestamp(2026, 6, 1, 6))
            }
        }
    }
}

private struct RunFixtureReader: GenericReaderProtocol {
    typealias MixingVar = IconVariable
    var values: [Float] = []
    var error: (any Error)?
    let modelLat: Float = 45
    let modelLon: Float = 8
    let modelElevation = ElevationOrSea.elevation(100)
    let targetElevation: Float = 100
    let modelDtSeconds = 900

    func getStatic(type: ReaderStaticVariable) async throws -> Float? { nil }
    func prefetchData(variable: IconVariable, time: TimerangeDtAndSettings) async throws {
        if let error { throw error }
    }
    func get(variable: IconVariable, time: TimerangeDtAndSettings) async throws -> DataAndUnit {
        if let error { throw error }
        return DataAndUnit(values, .celsius)
    }
}
