import Foundation
import Testing
@testable import App

/// CPU-only benchmark, excluding archive I/O and compression:
/// SARAH_CORRECTION_BENCHMARK=1 swift test -c release --filter SarahCorrectionBenchmark
@Suite struct SarahCorrectionBenchmark {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["SARAH_CORRECTION_BENCHMARK"] == "1"))
    func spatialWorkers() async throws {
        let grid = RegularGrid(nx: 96, ny: 8, latMin: -60, lonMin: -60, dx: 1.25, dy: 15)
        let start = Timestamp(2024, 1, 1).timeIntervalSince1970 / 1800
        let days = (0..<366).map { EumetsatSarahCorrect.CorrectionDay(start: start + $0 * 48, count: 48) }
        let offsets = [Double](repeating: 0.18, count: 6)
        let shifted = offsets.map { $0 - 0.5 }
        let input = (0..<288).map { i -> Float in
            if i % 11 == 0 { return .nan }
            if i % 7 == 0 { return 0 }
            return Float(100 + i)
        }
        var reference: [Float]?
        for (workers, cached) in [(1, false), (1, true), (8, true)] {
            let begin = DispatchTime.now()
            var checksums = [Float]()
            try await EumetsatSarahCorrect.processOrdered(count: grid.count / 6, concurrent: workers, process: { index in
                var checksum: Float = 0
                for day in days {
                    var data = input
                    EumetsatSarahCorrect.correct(data: &data, grid: grid, locations: index * 6 ..< (index + 1) * 6,
                        time: day.time, offsets: offsets, geometry: cached ? day.geometry : nil,
                        shiftedGeometry: cached ? day.shiftedGeometry : nil, shiftedOffsets: shifted)
                    for value in data where value.isFinite { checksum += value }
                }
                return checksum
            }, consume: { _, checksum in checksums.append(checksum) })
            let seconds = EumetsatSarahCorrect.elapsedSeconds(since: begin)
            print("SARAH CPU benchmark workers=\(workers) cached=\(cached): \(seconds)s, \(Double(grid.count * 366 * 48) / seconds / 1e6) million samples/s")
            if let reference { #expect(checksums == reference) } else { reference = checksums }
        }
    }
}
