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
        let reduction = EnsembleReduction(members: 0..<3, statistic: statistic, requireFirstMemberData: true)
        let data: [[Float]] = [[.nan, 2, .nan], [4, .nan, .nan], [8, 6, .nan]]
        let result = reduction.calculate(data.map { DataAndUnit($0, .cubicMetrePerSecond) })
        for (actual, expected) in zip(result.data, expected) {
            #expect(actual == expected || (actual.isNaN && expected.isNaN))
        }
    }

    @Test func missingControlPolicy() {
        let data = [DataAndUnit([.nan, .nan], .cubicMetrePerSecond), DataAndUnit([10, 20], .cubicMetrePerSecond)]
        let required = EnsembleReduction(members: 0..<2, statistic: .minimum, requireFirstMemberData: true)
        let optional = EnsembleReduction(members: 0..<2, statistic: .minimum)
        #expect(required.calculate(data).data.onlyNaN())
        #expect(optional.calculate(data).data == [10, 20])
    }

    private var time: TimerangeDtAndSettings {
        TimerangeDt(start: Timestamp(2026, 1, 1), nTime: 2, dtSeconds: 86400)
            .toSettings(ensembleMember: 2, previousDay: 1, ensembleMemberLevel: 3)
    }

    @Test func requiredExecutorSharesMemberDependencies() async throws {
        let reader = MemberReader(values: [[0, 0], [2, 12], [4, 14]])
        let derived = MemberDeriver(reader: reader, members: 1..<3)
        #expect(try await derived.get(variable: .river_discharge_mean, time: time)?.data == [3, 13])
        #expect(try await derived.prefetchData(variable: .river_discharge_mean, time: time))
        let dependencies = (1..<3).map { time.with(ensembleMember: $0) }
        #expect(reader.reads == dependencies)
        #expect(reader.prefetches == dependencies)
    }

    @Test func optionalExecutorReportsUnavailableMembers() async throws {
        let reader = OptionalMemberReader()
        let derived = OptionalDeriver(reader: reader)
        #expect(try await derived.get(variable: .river_discharge_mean, time: time)?.data == [3, 13])
        #expect(try await derived.prefetchData(variable: .river_discharge_mean, time: time))
        let dependencies = (1..<4).map { time.with(ensembleMember: $0) }
        #expect(reader.reads == dependencies)
        #expect(reader.prefetches == dependencies)

        reader.unavailableMember = 2
        reader.prefetches = []
        #expect(try await derived.get(variable: .river_discharge_mean, time: time) == nil)
        #expect(try await derived.prefetchData(variable: .river_discharge_mean, time: time) == false)
        // Prefetch must still visit members after the unavailable one.
        #expect(reader.prefetches == dependencies)
    }

    @Test func statisticsAreCalculatedBeforeSourceFallback() async throws {
        let lower = MemberDeriver(reader: MemberReader(values: [[2, 2], [10, 10]]), members: 0..<2)
        let higher = MemberDeriver(reader: MemberReader(values: [[.nan, 20], [100, 40]]), members: 0..<2)
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
        func prefetchData(variable: GloFasVariable, time: TimerangeDtAndSettings) async throws {
            prefetches.append(time)
        }
    }

    private struct MemberDeriver: GenericDeriverProtocol {
        typealias VariableOpt = ForecastVariableDaily
        let reader: MemberReader
        let members: Range<Int>

        func getDeriverMap(variable: ForecastVariableDaily) -> DerivedMapping<GloFasVariable>? {
            .ensemble(.river_discharge, EnsembleReduction(members: members, statistic: .mean, requireFirstMemberData: true))
        }
    }

    private final class OptionalMemberReader: GenericReaderOptionalProtocol {
        let modelLat: Float = 45
        let modelLon: Float = 10
        let modelElevation: ElevationOrSea = .elevation(100)
        let targetElevation: Float = 100
        let modelDtSeconds = 86400
        var unavailableMember: Int?
        var reads: [TimerangeDtAndSettings] = []
        var prefetches: [TimerangeDtAndSettings] = []

        func getStatic(type: ReaderStaticVariable) async throws -> Float? { nil }
        func get(variable: ForecastVariableDaily, time: TimerangeDtAndSettings) async throws -> DataAndUnit? {
            reads.append(time)
            guard time.ensembleMember != unavailableMember else { return nil }
            return DataAndUnit([Float(time.ensembleMember) + 1, Float(time.ensembleMember) + 11], .cubicMetrePerSecond)
        }
        func prefetchData(variable: ForecastVariableDaily, time: TimerangeDtAndSettings) async throws -> Bool {
            prefetches.append(time)
            return time.ensembleMember != unavailableMember
        }
    }

    private struct OptionalDeriver: GenericDeriverOptionalProtocol {
        typealias VariableOpt = ForecastVariableDaily
        let reader: any GenericReaderOptionalProtocol<ForecastVariableDaily>

        func getDeriverMap(variable: ForecastVariableDaily) -> DerivedMapping<ForecastVariableDaily>? {
            .ensemble(.river_discharge, EnsembleReduction(members: 1..<4, statistic: .mean))
        }
    }
}
