import Testing
@testable import App

@Suite struct PrefetchCoverageTests {
    @Test func fileCoverageTracksGapsAndOverlaps() {
        var coverage = PrefetchCoverage(requested: 10..<20)
        #expect(coverage.result == .noData)
        coverage.insert(0..<10)
        coverage.insert(20..<30)
        #expect(coverage.result == .noData)
        coverage.insert(5..<12)
        #expect(coverage.result == .partial)
        coverage.insert(11..<16)
        #expect(coverage.result == .partial)
        coverage.insert(16..<25)
        #expect(coverage.result == .full)
    }

    @Test func fileCoverageRetainsGaps() {
        var coverage = PrefetchCoverage(requested: 10..<20)
        coverage.insert(10..<12)
        coverage.insert(15..<20)
        #expect(coverage.result == .partial)
        // A rolling file covering the whole request supersedes earlier gaps.
        coverage.insert(5..<25)
        #expect(coverage.result == .full)
    }

    @Test func dependenciesPreserveMissingAndPartialCoverage() {
        var dependencies = PrefetchResult.Dependencies()
        #expect(dependencies.result == .full)
        dependencies.merge(.noData)
        #expect(dependencies.result == .noData)
        dependencies.merge(.noData)
        #expect(dependencies.result == .noData)
        dependencies.merge(.full)
        #expect(dependencies.result == .partial)
        dependencies.merge(.full)
        #expect(dependencies.result == .partial)
    }

    @Test(arguments: [PrefetchResult.noData, .partial, .full], [PrefetchResult.noData, .partial, .full])
    func dependencyMergeMatchesCoverage(first: PrefetchResult, second: PrefetchResult) {
        var dependencies = PrefetchResult.Dependencies()
        dependencies.merge(first)
        dependencies.merge(second)
        let expected: PrefetchResult = first == second ? first : .partial
        #expect(dependencies.result == expected)
        #expect(first.merged(with: second) == expected)
    }

    @Test(arguments: [PrefetchResult.noData, .partial, .full])
    func multiReaderStopsAtFirstAvailableCoverage(preferredResult: PrefetchResult) async throws {
        let fallback = Reader(result: .full)
        let preferred = Reader(result: preferredResult)
        let multi = GenericReaderMulti<GemVariable>(reader: [fallback, preferred])
        let time = TimerangeDt(start: Timestamp(2026, 1, 1), nTime: 3, dtSeconds: 3600).toSettings()
        #expect(try await multi.prefetchData(variable: .temperature_2m, time: time) == (preferredResult == .noData ? .full : preferredResult))
        #expect(preferred.calls == 1)
        #expect(fallback.calls == (preferredResult == .noData ? 1 : 0))
    }

    @Test func multiReaderReportsNoDataWhenAllReadersAreEmpty() async throws {
        let readers = [Reader(result: .noData), Reader(result: .noData)]
        let multi = GenericReaderMulti<GemVariable>(reader: readers)
        let time = TimerangeDt(start: Timestamp(2026, 1, 1), nTime: 3, dtSeconds: 3600).toSettings()
        #expect(try await multi.prefetchData(variable: .temperature_2m, time: time) == .noData)
        #expect(readers.allSatisfy { $0.calls == 1 })
    }

    @Test(arguments: [PrefetchResult.noData, .partial, .full])
    func deriversPreserveCoverage(result: PrefetchResult) async throws {
        let raw = Reader(result: result)
        let derived = Deriver(reader: raw)
        let mixed = GenericReaderMulti<GemVariable>(reader: [raw])
        let optional = OptionalDeriver(reader: mixed)
        let time = TimerangeDt(start: Timestamp(2026, 1, 1), nTime: 3, dtSeconds: 3600).toSettings()
        #expect(try await derived.prefetchData(variable: .temperature_2m, time: time) == result)
        #expect(try await optional.prefetchData(variable: .temperature_2m, time: time) == result)
        #expect(try await Deriver(reader: raw, hasMapping: false).prefetchData(variable: .temperature_2m, time: time) == .noData)
        #expect(try await OptionalDeriver(reader: mixed, hasMapping: false).prefetchData(variable: .temperature_2m, time: time) == .noData)
        #expect(raw.calls == 2)
    }

    private struct Deriver: GenericDeriverProtocol {
        let reader: Reader
        var hasMapping = true

        func getDeriverMap(variable: GemVariable) -> DerivedMapping<GemVariable>? {
            hasMapping ? .direct(variable) : nil
        }
    }

    private struct OptionalDeriver: GenericDeriverOptionalProtocol {
        let reader: any GenericReaderOptionalProtocol<GemVariable>
        var hasMapping = true

        func getDeriverMap(variable: GemVariable) -> DerivedMapping<GemVariable>? {
            hasMapping ? .direct(variable) : nil
        }
    }

    private final class Reader: GenericReaderProtocol {
        let result: PrefetchResult
        var calls = 0
        let modelLat: Float = 0
        let modelLon: Float = 0
        let modelElevation = ElevationOrSea.noData
        let targetElevation: Float = 0
        let modelDtSeconds = 3600

        init(result: PrefetchResult) { self.result = result }
        func getStatic(type: ReaderStaticVariable) async throws -> Float? { nil }
        func get(variable: GemVariable, time: TimerangeDtAndSettings) async throws -> DataAndUnit {
            DataAndUnit(Array(repeating: .nan, count: time.time.count), .celsius)
        }
        func prefetchData(variable: GemVariable, time: TimerangeDtAndSettings) async throws -> PrefetchResult {
            calls += 1
            return result
        }
    }
}
