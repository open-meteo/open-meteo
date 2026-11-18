import Foundation
import Logging
import OmFileIO
@preconcurrency import OmFileFormat
import Testing
@testable import App

struct ParallelSpatialConversionTests {
    @Test
    func concurrentTemporaryWritePreservesTimeFastData() async throws {
        let values = (0..<3 * 17 * 7).map { $0.isMultiple(of: 19) ? Float.nan : Float($0 % 101) }
        let writer = OmFileWriterHelper(dimensions: [3, 17, 7], chunks: [1, 8, 7])
        let fn = try await writer.writeTemporary(compressionType: .pfor_delta2d_int16, scalefactor: 1, all: values, nConcurrent: 4)
        let reader = try await OmFileReader(fn: try MmapFile(fn: fn)).expectArray(of: Float.self)
        #expect(reader.getDimensions() == [3, 17, 7])
        let actual = try await reader.read()
        #expect(actual.count == values.count)
        for (actual, expected) in zip(actual, values) {
            #expect(actual == expected || (actual.isNaN && expected.isNaN))
        }
    }

    private actor Work {
        var active = 0
        var peak = 0
        func start() { active += 1; peak = max(peak, active) }
        func finish() { active -= 1 }
    }
    private struct StatisticsDomain: GenericDomain {
        var countEnsembleMember: Int { 1 }
        var grid: any Gridable { RegularGrid(nx: 800, ny: 4, latMin: 0, lonMin: 0, dx: 0.1, dy: 0.1) }
        var domainRegistry: DomainRegistry { .ecmwf_ifs01_ensemble_mean }
        var domainRegistryStatic: DomainRegistry? { nil }
        var dtSeconds: Int { 3600 }
        var updateIntervalSeconds: Int { 21600 }
        var masterTimeRange: Range<Timestamp>? { nil }
        var omFileLength: Int { 1024 }
    }

    enum Failure: Error { case expected }

    @Test(arguments: [1, 3])
    func parallelBlocksPreserveHistoryOrderAndAtomicReplacement(members: Int) async throws {
        let nx = 800
        let ny = 4
        let om = OmFileSplitter(domain: .ecmwf_ifs01_ensemble, nMembers: members, nx: nx, ny: ny, nTimePerFile: 1024, masterTimeRange: nil, chunknLocations: 8)
        // Cross a normal time-chunk boundary. For ensembles, use the same input
        // to exercise rolling retention and preservation of the old forecast tail.
        let hour = Timestamp(2026, 11, 17).timeIntervalSince1970 / 3600
        let run = Timestamp((hour / 1024 * 1024 + 1022) * 3600)
        let history = TimerangeDt(start: run.subtract(hours: 3), nTime: 9, dtSeconds: 3600)
        let forecast = TimerangeDt(start: run, nTime: 4, dtSeconds: 3600)
        var snapshots = [[Float]]()
        for concurrency in [1, 4] {
            let variable = "__parallel_conversion_test_\(UUID().uuidString)"
            let file: (Int?) -> OmFileType = { chunk in
                .domainChunk(domain: .ecmwf_ifs01_ensemble, variable: variable, type: members == 1 ? .chunk : .rolling, chunk: chunk, ensembleMember: 0, previousDay: 0)
            }
            let directory = URL(fileURLWithPath: file(nil).getFilePath()).deletingLastPathComponent()
            defer { try? FileManager.default.removeItem(at: directory) }
            try await om.updateFromTimeOrientedStreaming3D(variable: variable, run: history.range.lowerBound, time: history, scalefactor: 1, onlyGeneratePreviousDays: false) { y, x, memberRange in
                var data = [Float]()
                for row in y {
                    for column in x {
                        for member in memberRange {
                            for t in 0..<history.count {
                                data.append(Float(100 + (Int(row) * nx + Int(column)) % 13 + Int(member) * 20 + t))
                            }
                        }
                    }
                }
                return ArraySlice(data)
            }
            let work = Work()
            let statisticsWriter = try OmEnsembleStatisticsWriter(domain: StatisticsDomain(), variable: EcmwfVariable.temperature_2m, time: forecast, chunkLocations: 8)
            try await om.updateFromTimeOrientedStreaming3D(variable: variable, run: run, time: forecast, scalefactor: 1, onlyGeneratePreviousDays: false, concurrent: concurrency, statisticsWriter: statisticsWriter) { y, x, memberRange in
                await work.start()
                try await Task.sleep(for: .milliseconds(x.lowerBound == 0 ? 10 : 1))
                var data = [Float]()
                for row in y {
                    for column in x {
                        for member in memberRange {
                            for t in 0..<forecast.count {
                                data.append(t.isMultiple(of: 2) ? .nan : Float(200 + (Int(row) * nx + Int(column)) % 13 + Int(member) * 20 + t))
                            }
                        }
                    }
                }
                await work.finish()
                return ArraySlice(data)
            }
            let statistics = try await statisticsWriter.finalise()
            let means = try await statistics[0].reader.read()
            for location in 0..<nx * ny {
                for t in 0..<forecast.count {
                    let value = means[location * forecast.count + t]
                    if t.isMultiple(of: 2) {
                        #expect(value.isNaN)
                    } else {
                        #expect(value == Float(200 + location % 13 + (members - 1) * 10 + t))
                    }
                }
            }
            #expect(await work.peak <= concurrency)
            if concurrency > 1 { #expect(await work.peak > 1) }
            var snapshot = [Float]()
            var files = [String: Data]()
            for t in 0..<history.count {
                let timestamp = history.range.lowerBound.add(hours: t)
                let chunk = members == 1 ? timestamp.timeIntervalSince1970 / 3600 / 1024 : nil
                let path = file(chunk).getFilePath()
                let reader = try await OmFileReader<MmapFile>(mmapFile: path)
                let array = try reader.expectArray(of: Float.self)
                let index: Int
                if members == 1 {
                    #expect(array.getDimensions() == [UInt64(ny), UInt64(nx), 1024])
                    index = timestamp.timeIntervalSince1970 / 3600 % 1024
                } else {
                    let storedTime = try #require(try await reader.getTimeRangeDt())
                    index = (timestamp.timeIntervalSince1970 - storedTime.range.lowerBound.timeIntervalSince1970) / 3600
                    #expect(array.getDimensions() == [UInt64(ny), UInt64(nx), UInt64(members), UInt64(storedTime.count)])
                }
                let values = members == 1 ?
                    try await array.read(range: [0..<UInt64(ny), 0..<UInt64(nx), UInt64(index)..<UInt64(index + 1)]) :
                    try await array.read(range: [0..<UInt64(ny), 0..<UInt64(nx), 0..<UInt64(members), UInt64(index)..<UInt64(index + 1)])
                for location in 0..<nx * ny {
                    for member in 0..<members {
                        let newTime = t - 3
                        let expected = (0..<forecast.count).contains(newTime) && !newTime.isMultiple(of: 2) ?
                            Float(200 + location % 13 + member * 20 + newTime) : Float(100 + location % 13 + member * 20 + t)
                        #expect(values[location * members + member] == expected)
                    }
                }
                snapshot += values
                if files[path] == nil { files[path] = try Data(contentsOf: URL(fileURLWithPath: path)) }
            }
            snapshots.append(snapshot)
            // A failed worker must not publish partially rewritten destination files.
            await #expect(throws: Failure.self) {
                try await om.updateFromTimeOrientedStreaming3D(variable: variable, run: run, time: forecast, scalefactor: 1, onlyGeneratePreviousDays: false, concurrent: concurrency) { y, x, memberRange in
                    if y.lowerBound != 0 || x.lowerBound != 0 { throw Failure.expected }
                    let values = [Float](repeating: 999, count: y.count * x.count * memberRange.count * forecast.count)
                    return ArraySlice(values)
                }
            }
            for (path, original) in files {
                #expect(try Data(contentsOf: URL(fileURLWithPath: path)) == original)
            }
        }
        #expect(snapshots[0] == snapshots[1])
    }
}
