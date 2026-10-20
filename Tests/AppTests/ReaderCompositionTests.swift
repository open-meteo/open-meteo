import Testing
@testable import App

@Suite struct ReaderCompositionTests {
    private let temperature: ForecastVariable = .surface(.init(.temperature_2m, 0))
    private let precipitation: ForecastVariable = .surface(.init(.precipitation, 0))
    private let time = TimerangeDt(start: Timestamp(2026, 1, 1), nTime: 9, dtSeconds: 3600).toSettings()

    @Test(arguments: [ReaderPrefetchPolicy.preferred, .all])
    func prefetchPolicySelectsSupportingSourcesWithoutChangingReadResults(policy: ReaderPrefetchPolicy) async throws {
        let fallback = FixtureReader(Array(repeating: 1, count: 9))
        let preferred = FixtureReader([2, 2, 2, 2, 2, .nan, .nan, .nan, .nan])
        let unrelated = FixtureReader(Array(repeating: 3, count: 9))
        let reader = ReaderComposition.mix([
            fallback.source(), preferred.source(), unrelated.source(field: .precipitation)
        ], prefetch: policy, smoothTransitions: false)

        #expect(try await reader.prefetchData(variable: temperature, time: time))
        #expect(preferred.prefetches == [.temperature_2m])
        #expect(fallback.prefetches.count == (policy == .all ? 1 : 0))
        #expect(unrelated.prefetches.isEmpty)
        let result = try #require(await reader.get(variable: temperature, time: time))
        #expect(result.data == [2, 2, 2, 2, 2, 1, 1, 1, 1])
        #expect(result.unit == .celsius)
        #expect(preferred.reads == [.temperature_2m])
        #expect(fallback.reads == [.temperature_2m])
        #expect(unrelated.reads.isEmpty)
    }

    @Test func completePreferredDataAvoidsFallbackReads() async throws {
        let fallback = FixtureReader(Array(repeating: 1, count: 9))
        let preferred = FixtureReader(Array(repeating: 2, count: 9))
        let reader = ReaderComposition.mix([fallback.source(), preferred.source()], prefetch: .all, smoothTransitions: true)
        let result = try #require(await reader.get(variable: temperature, time: time))
        #expect(result.data == preferred.values)
        #expect(fallback.reads.isEmpty)
    }

    @Test func unsupportedVariablesDoNotReadOrPrefetch() async throws {
        let raw = FixtureReader(Array(repeating: 1, count: 9))
        let reader = ReaderComposition.mix([raw.source()], prefetch: .all, smoothTransitions: false)
        #expect(try await !reader.prefetchData(variable: precipitation, time: time))
        #expect(try await reader.get(variable: precipitation, time: time) == nil)
        #expect(raw.reads.isEmpty)
        #expect(raw.prefetches.isEmpty)
    }

    @Test func preferredPrefetchPreservesAllPolicyInsideSelectedSource() async throws {
        let fallback = FixtureReader(Array(repeating: 1, count: 9))
        let regional = FixtureReader(Array(repeating: 2, count: 9))
        let local = FixtureReader(Array(repeating: 3, count: 9))
        let reader = ReaderComposition.mix([
            fallback.source(),
            .mix([regional.source(), local.source()], prefetch: .all, smoothTransitions: false)
        ], prefetch: .preferred, smoothTransitions: false)
        #expect(try await reader.prefetchData(variable: temperature, time: time))
        #expect(fallback.prefetches.isEmpty)
        #expect(regional.prefetches == [.temperature_2m])
        #expect(local.prefetches == [.temperature_2m])
    }

    @Test(arguments: [true, false])
    func nestedMixPreservesSmoothingOrderAndBoundaries(smoothInner: Bool) async throws {
        let global = FixtureReader(Array(repeating: 6, count: 9))
        let regional = FixtureReader([3, 3, 3, 3, 3, 3, 3, .nan, .nan])
        let local = FixtureReader([0, 0, 0, 0, 0, .nan, .nan, .nan, .nan])
        let reader = ReaderComposition.mix([
            global.source(),
            .mix([regional.source(), local.source()], prefetch: .all, smoothTransitions: smoothInner)
        ], prefetch: .all, smoothTransitions: true)
        let result = try #require(await reader.get(variable: temperature, time: time))
        // With equal smoothing policies, preserve the original flat contributor order.
        // A different inner policy keeps that group as a separate smoothing boundary.
        let expected: [Float] = smoothInner
            ? [0, 0, 0.75, 1.5, 3.1875, 4.5, 5.25, 6, 6]
            : [0, 0, 0, 0, 1.5, 4.5, 5.25, 6, 6]
        #expect(result.data == expected)
    }

    @Test func rawUnionRoutesReadsAndPrefetchesToVariableOwner() async throws {
        let primary = FixtureReader(Array(repeating: 1, count: 9))
        let supplemental = FixtureReader(Array(repeating: 2, count: 9))
        let reader = RawReaderUnion(primary: primary, supplemental: supplemental)
        try await reader.prefetchData(variable: .primary(.temperature_2m), time: time)
        try await reader.prefetchData(variable: .supplemental(.precipitation), time: time)
        let temperature = try await reader.get(variable: .primary(.temperature_2m), time: time)
        let precipitation = try await reader.get(variable: .supplemental(.precipitation), time: time)
        #expect(temperature.data == primary.values)
        #expect(precipitation.data == supplemental.values)
        #expect(primary.reads == [.temperature_2m])
        #expect(primary.prefetches == [.temperature_2m])
        #expect(supplemental.reads == [.precipitation])
        #expect(supplemental.prefetches == [.precipitation])
    }

    @Test func missingRawSupplementReturnsNaNsWithoutReadingPrimary() async throws {
        let primary = FixtureReader(Array(repeating: 1, count: 9))
        let reader = RawReaderUnion<FixtureReader, FixtureReader>(primary: primary, supplemental: nil)
        try await reader.prefetchData(variable: .supplemental(.precipitation), time: time)
        let result = try await reader.get(variable: .supplemental(.precipitation), time: time)
        #expect(result.data.count == time.time.count)
        #expect(result.data.allSatisfy { $0.isNaN })
        #expect(result.unit == GemSurfaceVariable.precipitation.unit)
        #expect(primary.reads.isEmpty)
        #expect(primary.prefetches.isEmpty)
    }

    private final class FixtureReader: GenericReaderProtocol {
        let modelLat: Float = 0
        let modelLon: Float = 0
        let modelElevation: ElevationOrSea = .sea
        let targetElevation: Float = 0
        let modelDtSeconds = 3600
        let values: [Float]
        var reads: [GemSurfaceVariable] = []
        var prefetches: [GemSurfaceVariable] = []

        init(_ values: [Float]) { self.values = values }

        func source(field: ForecastSurfaceVariable = .temperature_2m) -> ReaderComposition {
            .source(ForecastReaderLeaf(raw: self, field: field, variable: GemSurfaceVariable.temperature_2m))
        }

        func getStatic(type: ReaderStaticVariable) async throws -> Float? { nil }
        func get(variable: GemSurfaceVariable, time: TimerangeDtAndSettings) async throws -> DataAndUnit {
            reads.append(variable)
            return DataAndUnit(values, variable.unit)
        }
        func prefetchData(variable: GemSurfaceVariable, time: TimerangeDtAndSettings) async throws {
            prefetches.append(variable)
        }
    }
}
