import Foundation
import OmFileFormat
import Testing
@testable import App

@Suite struct PrefetchCoverageTests {
    private static func range(_ start: Int, _ end: Int) -> Range<Timestamp> {
        Timestamp(start * 3600)..<Timestamp(end * 3600)
    }

    private static func result(_ start: Int, _ end: Int) -> PrefetchResult {
        PrefetchResult(range(start, end))
    }

    private let time = TimerangeDt(start: Timestamp(0), nTime: 6, dtSeconds: 3600).toSettings()

    @Test(arguments: [(Optional<Int>.none, 16), (9, 10), (10, 11), (12, 13), (15, 16), (20, 16)])
    func forecastHorizonCapsFileCoverage(lastValidIndex: Int?, expectedEnd: Int) async throws {
        let reader = try await makeReader(lastValidTime: lastValidIndex.map { Timestamp($0 * 3600) })
        let available = reader.prefetchTimeRange(fileTime: 10..<16, dtSeconds: 3600)
        #expect(available == 10..<expectedEnd)
        var coverage = PrefetchCoverage(requested: TimerangeDt(range: Self.range(10, 16), dtSeconds: 3600))
        coverage.insert(available)
        #expect(coverage.result == Self.result(10, expectedEnd))
    }

    @Test func forecastHorizonIncludesLastSampleAndPreservesOffsets() async throws {
        let reader = try await makeReader(lastValidTime: Timestamp(12 * 3600))
        let available = reader.prefetchTimeRange(fileTime: 10..<16, dtSeconds: 3600)
        let offsets = try #require((11..<15).intersect(fileTime: available))
        #expect(offsets.file == 1..<3)
        #expect(offsets.array == 0..<2)
        #expect((13..<16).intersect(fileTime: available) == nil)
        var coverage = PrefetchCoverage(requested: TimerangeDt(range: Self.range(12, 13), dtSeconds: 3600))
        coverage.insert(available)
        #expect(coverage.result.range == Self.range(12, 13))
    }

    @Test func fileCoverageReportsContiguousRangeWithoutHidingGaps() {
        var coverage = PrefetchCoverage(requested: time.time)
        coverage.insert(0..<2)
        coverage.insert(4..<6)
        #expect(coverage.result.range == Self.range(0, 2))
        #expect(!coverage.result.covers(time.range))
        coverage.insert(1..<6)
        #expect(coverage.result.covers(time.range))
    }

    @Test func monthlyCoverageUsesCalendarTimestamps() {
        let start = Timestamp(2026, 1, 1)
        let end = Timestamp(2026, 4, 1)
        let time = TimerangeDt(start: start, to: end, dtSeconds: .dtSecondsMonthly)
        var coverage = PrefetchCoverage(requested: time)
        coverage.insert(time.toIndexTime())
        #expect(coverage.result.range == start..<end)
    }

    @Test func dependenciesIntersectCoverage() {
        var coverage = PrefetchResult(time.range)
        #expect(coverage.range == time.range)
        coverage.formIntersection(Self.result(0, 4))
        coverage.formIntersection(Self.result(2, 6))
        #expect(coverage.range == Self.range(2, 4))
        coverage.formIntersection(PrefetchResult())
        #expect(coverage.range.isEmpty)
    }

    @Test func emptyCoverageHasNoEffectOnOtherRanges() {
        let empty = PrefetchResult()
        #expect(empty.range.isEmpty)
        #expect(empty == Self.result(10, 10))
        #expect(!empty.covers(time.range))
        #expect(empty.covers(Self.range(10, 10)))
        var coverage = empty
        coverage.include(Self.result(2, 4))
        coverage.include(empty)
        #expect(coverage.range == Self.range(2, 4))
        #expect(coverage.intersecting(empty).range.isEmpty)
        #expect(empty.intersecting(coverage).range.isEmpty)
    }

    @Test func adjacentModelCoverageJoinsInEitherOrder() {
        var forward = Self.result(0, 2)
        forward.include(Self.result(2, 6))
        var reverse = Self.result(2, 6)
        reverse.include(Self.result(0, 2))
        #expect(forward.range == time.range)
        #expect(reverse == forward)
    }

    @Test func shiftedDependencyCoverageMapsToOutputTime() {
        let shifted = time.time.add(-86400)
        let coverage = PrefetchResult(shifted.range.lowerBound..<shifted.range.lowerBound.add(3 * 3600))
        #expect(coverage.mapped(from: shifted, to: time.time).range == Self.range(0, 3))
    }

    @Test func interpolationPaddingDoesNotCountAsOutputCoverage() {
        let input = TimerangeDt(range: Self.range(-1, 8), dtSeconds: 3600)
        #expect(Self.result(-1, 8).mapped(from: input, to: time.time).range == time.range)
        #expect(Self.result(-1, 5).mapped(from: input, to: time.time).range == Self.range(0, 3))
        #expect(Self.result(0, 1).mapped(from: input, to: time.time).range.isEmpty)
    }

    @Test func multiReaderStopsWhenComplementaryRangesCoverRequest() async throws {
        let unnecessary = Reader(result: PrefetchResult(time.range))
        let fallback = Reader(result: Self.result(2, 6))
        let preferred = Reader(result: Self.result(0, 2))
        let multi = GenericReaderMulti<GemVariable>(reader: [unnecessary, fallback, preferred])
        let result = try await multi.prefetchData(variable: .temperature_2m, time: time)
        #expect(result.range == time.range)
        #expect(preferred.calls == 1)
        #expect(fallback.calls == 1)
        #expect(unnecessary.calls == 0)
    }

    @Test func gapRequiresAnotherModel() async throws {
        let complete = Reader(result: PrefetchResult(time.range))
        let disconnected = Reader(result: Self.result(4, 6))
        let preferred = Reader(result: Self.result(0, 2))
        let multi = GenericReaderMulti<GemVariable>(reader: [complete, disconnected, preferred])
        #expect(try await multi.prefetchData(variable: .temperature_2m, time: time).range == time.range)
        #expect(complete.calls == 1)
        #expect(disconnected.calls == 1)
        #expect(preferred.calls == 1)
    }

    @Test(arguments: [false, true])
    func sameTypeReaderCombinesRangesAndHonorsPrefetchAll(prefetchAll: Bool) async throws {
        let unnecessary = Reader(result: PrefetchResult(time.range))
        let fallback = Reader(result: Self.result(2, 6))
        let preferred = Reader(result: Self.result(0, 2))
        let multi = GenericReaderMultiSameType<GemVariable>(
            reader: [Deriver(reader: unnecessary), Deriver(reader: fallback), Deriver(reader: preferred)],
            prefetchAllReaders: prefetchAll
        )
        #expect(try await multi.prefetchData(variable: .temperature_2m, time: time).range == time.range)
        #expect(preferred.calls == 1)
        #expect(fallback.calls == 1)
        #expect(unnecessary.calls == (prefetchAll ? 1 : 0))
    }

    @Test func rawMixersCombineCoverage() async throws {
        let unnecessary = Reader(result: PrefetchResult(time.range))
        let fallback = Reader(result: Self.result(0, 2))
        let preferred = Reader(result: Self.result(2, 6))
        let readers = [unnecessary, fallback, preferred]
        let byName = GenericReaderMixerByVariableName<GemVariable>(reader: readers)
        let sameType = GenericReaderMixerSameVariableType(reader: readers)
        #expect(try await byName.prefetchData(variable: .temperature_2m, time: time).range == time.range)
        #expect(try await sameType.prefetchData(variable: .temperature_2m, time: time).range == time.range)
        #expect(preferred.calls == 2)
        #expect(fallback.calls == 2)
        #expect(unnecessary.calls == 0)
    }

    @Test func emptyAndIncompleteReadersPreserveCoverage() async throws {
        let missing = Reader(result: PrefetchResult())
        let available = Reader(result: Self.result(0, 2))
        let multi = GenericReaderMulti<GemVariable>(reader: [missing, available])
        #expect(try await multi.prefetchData(variable: .temperature_2m, time: time).range == Self.range(0, 2))
        #expect(missing.calls == 1)
        let empty = GenericReaderMulti<GemVariable>(reader: [missing])
        #expect(try await empty.prefetchData(variable: .temperature_2m, time: time).range.isEmpty)
    }

    @Test func deriversPreserveCoverageAndTranslateShiftedVariables() async throws {
        let raw = Reader(result: Self.result(0, 3))
        let derived = Deriver(reader: raw)
        let mixed = GenericReaderMulti<GemVariable>(reader: [raw])
        let optional = OptionalDeriver(reader: mixed)
        #expect(try await derived.prefetchData(variable: .temperature_2m, time: time).range == Self.range(0, 3))
        #expect(try await optional.prefetchData(variable: .temperature_2m, time: time).range == Self.range(0, 3))
        #expect(try await Deriver(reader: raw, hasMapping: false).prefetchData(variable: .temperature_2m, time: time).range.isEmpty)
        #expect(try await OptionalDeriver(reader: mixed, hasMapping: false).prefetchData(variable: .temperature_2m, time: time).range.isEmpty)
        let shiftedRaw = Reader(result: Self.result(-24, -21))
        let shifted = Deriver(reader: shiftedRaw, shifted: true)
        #expect(try await shifted.prefetchData(variable: .temperature_2m, time: time).range == Self.range(0, 3))
    }

    private func makeReader(lastValidTime: Timestamp?) async throws -> OmFileLocalRemoteOmReader {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent("prefetch-\(UUID().uuidString).om").path
        defer { try? FileManager.default.removeItem(atPath: path) }
        let handle = try FileHandle.createNewFile(file: path)
        defer { try? handle.close() }
        let writer = OmFileWriter(fn: handle, initialCapacity: 4096)
        let array = try writer.writeArray(data: [Float(1)], dimensions: [1, 1, 1], chunkDimensions: [1, 1, 1], compression: .pfor_delta2d_int16, scale_factor: 1, add_offset: 0)
        let metadata = try lastValidTime.map {
            try writer.write(value: $0.timeIntervalSince1970, name: "forecast_last_valid_time", children: [])
        }
        let root = try writer.write(array: array, name: "", children: metadata.map { [$0] } ?? [])
        try writer.writeTrailer(rootVariable: root)
        let fd = try FileHandle.openFileReading(file: path)
        return try await OmFileLocalRemoteOmReader(fd: fd, size: Int64(fd.seekToEnd()))
    }

    private struct Deriver: GenericDeriverProtocol {
        let reader: Reader
        var hasMapping = true
        var shifted = false

        func getDeriverMap(variable: GemVariable) -> DerivedMapping<GemVariable>? {
            guard hasMapping else { return nil }
            return shifted ? .directShift24Hour(variable) : .direct(variable)
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
            return result.intersecting(PrefetchResult(time.range))
        }
    }
}
