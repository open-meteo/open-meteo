import Testing
@testable import App

@Suite struct EnsembleReductionTests {
    @Test(arguments: [
        (EnsembleReduction.Statistic.mean, [Float(16) / 3, 26.0 / 3]),
        (.minimum, [2, 6]), (.maximum, [10, 12]),
        (.percentile(0.25), [3, 7]), (.percentile(0.5), [4, 8]), (.percentile(0.75), [7, 10])
    ] as [(EnsembleReduction.Statistic, [Float])])
    func statistics(statistic: EnsembleReduction.Statistic, expected: [Float]) {
        let reduction = EnsembleReduction(members: 0..<3, statistic: statistic)
        let result = reduction.calculate([[2, 6], [4, 8], [10, 12]].map { DataAndUnit($0, .cubicMetrePerSecond) })
        #expect(result.data == expected)
        #expect(result.unit == .cubicMetrePerSecond)
    }

    @Test(arguments: [
        (EnsembleReduction.Statistic.mean, [Float.nan, .nan, .nan]),
        (.minimum, [4, 2, .nan]), (.maximum, [8, 6, .nan])
    ] as [(EnsembleReduction.Statistic, [Float])])
    func missingSamples(statistic: EnsembleReduction.Statistic, expected: [Float]) {
        let reduction = EnsembleReduction(members: 0..<3, statistic: statistic)
        let data: [[Float]] = [[.nan, 2, .nan], [4, .nan, .nan], [8, 6, .nan]]
        let result = reduction.calculate(data.map { DataAndUnit($0, .cubicMetrePerSecond) })
        for (actual, expected) in zip(result.data, expected) {
            #expect(actual == expected || (actual.isNaN && expected.isNaN))
        }
    }

    @Test func missingControlMakesSourceUnavailable() {
        let data = [DataAndUnit([.nan, .nan], .cubicMetrePerSecond), DataAndUnit([10, 20], .cubicMetrePerSecond)]
        let reduction = EnsembleReduction(members: 0..<2, statistic: .minimum)
        #expect(reduction.calculate(data).data.onlyNaN())
    }

    private var time: TimerangeDtAndSettings {
        TimerangeDt(start: Timestamp(2026, 1, 1), nTime: 2, dtSeconds: 86400)
            .toSettings(ensembleMember: 2, previousDay: 1, ensembleMemberLevel: 3)
    }

    @Test func dailyDeriverSharesMemberDependencies() async throws {
        let reader = MemberReader(values: [[2, 12], [4, 14]])
        let derived = VariableDailyDeriver(reader: reader, countEnsembleMember: 2)
        #expect(try await derived.get(variable: .river_discharge_mean, time: time)?.data == [3, 13])
        #expect(try await derived.prefetchData(variable: .river_discharge_mean, time: time) == PrefetchResult(time.range))
        let dependencies = (0..<2).map { time.with(ensembleMember: $0) }
        #expect(reader.reads == dependencies)
        #expect(reader.prefetches == dependencies)
    }

    @Test func statisticsAreCalculatedBeforeSourceFallback() async throws {
        let lower = VariableDailyDeriver(reader: MemberReader(values: [[2, 2], [10, 10]]), countEnsembleMember: 2)
        let higher = VariableDailyDeriver(reader: MemberReader(values: [[.nan, 20], [100, 40]]), countEnsembleMember: 2)
        let mixed = GenericReaderMultiSameType<ForecastVariableDaily>(reader: [lower, higher], prefetchAllReaders: true)
        // Raw-member fallback would produce 51 at the first sample instead of 6.
        #expect(try await mixed.get(variable: .river_discharge_mean, time: time)?.data == [6, 30])
    }

    private final class MemberReader: GenericReaderProtocol {
        let values: [[Float]]
        let modelLat: Float = 45
        let modelLon: Float = 10
        let modelElevation: ElevationOrSea = .elevation(100)
        let targetElevation: Float = 100
        let modelDtSeconds = 86400
        var reads: [TimerangeDtAndSettings] = []
        var prefetches: [TimerangeDtAndSettings] = []

        init(values: [[Float]]) {
            self.values = values
        }

        func getStatic(type: ReaderStaticVariable) async throws -> Float? { nil }
        func get(variable: GloFasVariable, time: TimerangeDtAndSettings) async throws -> DataAndUnit {
            reads.append(time)
            return DataAndUnit(values[time.ensembleMember], .cubicMetrePerSecond)
        }
        func prefetchData(variable: GloFasVariable, time: TimerangeDtAndSettings) async throws -> PrefetchResult {
            prefetches.append(time)
            return PrefetchResult(time.range)
        }
    }
}
