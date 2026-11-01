import Foundation
import Testing
import Vapor
import OmFileIO
import OmFileFormat
@testable import App

@Suite struct EumetsatSarahCorrectTests {
    @Test func daylightRoundTrip() {
        let grid = RegularGrid(nx: 2, ny: 1, latMin: 47, lonMin: 4.5, dx: 1, dy: 1)
        let time = TimerangeDt(start: Timestamp(2024, 6, 21, 10), nTime: 6, dtSeconds: 1800)
        let offsets = [0.18, 0.19]
        let instant: [Float] = [500, 700, 250, 900, 450, 700, 600, 650, 350, 800, 400, 600]
        var legacy = instant
        Zensun.instantaneousSolarRadiationToBackwardsAverages(timeOrientedData: &legacy, grid: grid,
            locationRange: 0..<2, timerange: time, sunDeclinationCutOffDegrees: 1, scanTimeDifferenceHours: offsets)
        var recovered = legacy
        Zensun.instantaneousSolarRadiationToBackwardsAverages(timeOrientedData: &recovered, grid: grid,
            locationRange: 0..<2, timerange: time, sunDeclinationCutOffDegrees: 1, scanTimeDifferenceHours: offsets, undoAveraging: true)
        for i in instant.indices { #expect(abs(recovered[i] - instant[i]) < 0.001) }
        var expected = instant
        Zensun.instantaneousSolarRadiationToBackwardsAverages(timeOrientedData: &expected, grid: grid,
            locationRange: 0..<2, timerange: TimerangeDt(start: time.range.lowerBound.add(1800), nTime: 6, dtSeconds: 1800),
            sunDeclinationCutOffDegrees: 1, scanTimeDifferenceHours: offsets.map { $0 - 0.5 })
        EumetsatSarahCorrect.correct(data: &legacy, grid: grid, locations: 0..<2, time: time, offsets: offsets)
        for i in expected.indices { #expect(abs(legacy[i] - expected[i]) < 0.001) }
    }

    @Test func missingAndNight() {
        let grid = RegularGrid(nx: 1, ny: 1, latMin: 47, lonMin: 4.5, dx: 1, dy: 1)
        let time = TimerangeDt(start: Timestamp(2024, 6, 21), nTime: 48, dtSeconds: 1800)
        var missing = [Float](repeating: .nan, count: 48)
        EumetsatSarahCorrect.correct(data: &missing, grid: grid, locations: 0..<1, time: time, offsets: [0.18])
        #expect(missing.allSatisfy { $0.isNaN })
        var zeros = [Float](repeating: 0, count: 48)
        EumetsatSarahCorrect.correct(data: &zeros, grid: grid, locations: 0..<1, time: time, offsets: [0.18])
        #expect(zeros.allSatisfy { $0 == 0 })
    }

    @Test func archiveNames() throws {
        let year = try #require(EumetsatSarahCorrect.file("year_2024.om"))
        #expect(year.time.count == 366 * 48)
        let chunk = try #require(EumetsatSarahCorrect.file("chunk_2869.om"))
        #expect(chunk.time == 2869 * 336 ..< 2870 * 336)
        #expect(EumetsatSarahCorrect.file("year_2024.om.partial") == nil)
    }

    @Test func streamingBoundariesAndResume() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
        defer { try? FileManager.default.removeItem(atPath: directory) }
        let variable = "shortwave_radiation"
        try FileManager.default.createDirectory(atPath: "\(directory)/\(variable)", withIntermediateDirectories: true)
        let grid = RegularGrid(nx: 3, ny: 2, latMin: 60, lonMin: 60, dx: 1, dy: 1)
        let firstChunk = Timestamp(2024, 6, 21).timeIntervalSince1970 / (1800 * 336)
        for chunk in firstChunk...firstChunk + 1 {
            let handle = try FileHandle.createNewFile(file: "\(directory)/\(variable)/chunk_\(chunk).om")
            let file = OmFileWriter(fn: handle, initialCapacity: 4096)
            // Exercise different 3D chunk layouts and partial spatial chunks.
            let dims: [UInt64] = [2, 3, 336]
            let chunks: [UInt64] = chunk == firstChunk ? [2, 2, 48] : [1, 2, 48]
            let writer = try file.prepareArray(type: Float.self, dimensions: dims, chunkDimensions: chunks,
                compression: .pfor_delta2d_int16, scale_factor: 1, add_offset: 0)
            let values: [Float] = (0..<6 * 336).map { i in
                Float(200 + (i / 336) * 10 + (i % 48) * 3 + (chunk - firstChunk) * 100)
            }
            try writer.writeData(array: values)
            let root = try file.write(array: try writer.finalise(), name: "", children: [])
            try file.writeTrailer(rootVariable: root)
            try handle.close()
        }
        let offsets = [Double](repeating: 0.18, count: 6)
        // Simulate an interrupted output. It must be replaced, never treated as completed.
        try FileManager.default.createDirectory(atPath: "\(directory)/\(variable)_corrected", withIntermediateDirectories: true)
        try Data([1, 2, 3]).write(to: URL(fileURLWithPath: "\(directory)/\(variable)_corrected/chunk_\(firstChunk).om.partial"))
        try await EumetsatSarahCorrect.repairArchive(directory: directory, variables: [variable], selectedFile: nil,
            grid: grid, mviri: offsets, seviri: offsets, logger: Logger(label: "test"))
        for chunk in firstChunk...firstChunk + 2 {
            let output = try await OmFileReader(mmapFile: "\(directory)/\(variable)_corrected/chunk_\(chunk).om").expectArray(of: Float.self)
            #expect(output.getDimensions() == [2, 3, 336])
            let data = try await output.read()
            for location in 0..<6 {
                for t in [0, 24] {
                    let sourceIndex = chunk * 336 + t - 1
                    guard sourceIndex >= firstChunk * 336 && sourceIndex < (firstChunk + 2) * 336 else { continue }
                    let sourceChunk = sourceIndex / 336
                    var expected = [Float(200 + location * 10 + (sourceIndex % 48) * 3 + (sourceChunk - firstChunk) * 100)]
                    EumetsatSarahCorrect.correct(data: &expected, grid: grid, locations: location..<location + 1,
                        time: TimerangeDt(start: Timestamp(sourceIndex * 1800), nTime: 1, dtSeconds: 1800), offsets: [0.18])
                    #expect(abs(data[location * 336 + t] - expected[0]) <= 1)
                }
            }
            if chunk == firstChunk {
                for location in 0..<6 { #expect(data[location * 336].isNaN) }
            } else if chunk == firstChunk + 2 {
                for location in 0..<6 {
                    #expect(!data[location * 336].isNaN)
                    #expect(data[(location * 336 + 1)..<((location + 1) * 336)].allSatisfy { $0.isNaN })
                }
            } else {
                // The preceding file supplies the first sample, not a NaN or repeated own sample.
                #expect(!data[0].isNaN)
            }
        }
        // A rerun must leave completed files untouched.
        let path = "\(directory)/\(variable)_corrected/chunk_\(firstChunk).om"
        let before = try Data(contentsOf: URL(fileURLWithPath: path))
        try await EumetsatSarahCorrect.repairArchive(directory: directory, variables: [variable], selectedFile: nil,
            grid: grid, mviri: offsets, seviri: offsets, logger: Logger(label: "test"))
        #expect(try Data(contentsOf: URL(fileURLWithPath: path)) == before)
        let outputDirectory = "\(directory)/\(variable)_corrected"
        let filenames = try FileManager.default.contentsOfDirectory(atPath: outputDirectory).filter { $0.hasSuffix(".om") }.sorted()
        let serial = try filenames.map { try Data(contentsOf: URL(fileURLWithPath: "\(outputDirectory)/\($0)")) }
        try FileManager.default.removeItem(atPath: outputDirectory)
        try await EumetsatSarahCorrect.repairArchive(directory: directory, variables: [variable], selectedFile: nil,
            grid: grid, mviri: offsets, seviri: offsets, logger: Logger(label: "test"), concurrent: 4)
        for (name, expected) in zip(filenames, serial) {
            #expect(try Data(contentsOf: URL(fileURLWithPath: "\(outputDirectory)/\(name)")) == expected)
        }
    }
    @Test func yearlyBoundaryUsesSourceSatellite() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
        defer { try? FileManager.default.removeItem(atPath: directory) }
        let variable = "direct_radiation"
        try FileManager.default.createDirectory(atPath: "\(directory)/\(variable)", withIntermediateDirectories: true)
        let grid = RegularGrid(nx: 1, ny: 1, latMin: -60, lonMin: 60, dx: 1, dy: 1)
        for year in 2005...2006 {
            let descriptor = try #require(EumetsatSarahCorrect.file("year_\(year).om"))
            let handle = try FileHandle.createNewFile(file: "\(directory)/\(variable)/\(descriptor.name)")
            let file = OmFileWriter(fn: handle, initialCapacity: 4096)
            let writer = try file.prepareArray(type: Float.self, dimensions: [1, 1, UInt64(descriptor.time.count)],
                chunkDimensions: [1, 1, 504], compression: .pfor_delta2d_int16, scale_factor: 10, add_offset: 0)
            try writer.writeData(array: [Float](repeating: year == 2005 ? 100 : 200, count: descriptor.time.count))
            let root = try file.write(array: try writer.finalise(), name: "", children: [])
            try file.writeTrailer(rootVariable: root)
            try handle.close()
        }
        try await EumetsatSarahCorrect.repairArchive(directory: directory, variables: [variable], selectedFile: "year_2006.om",
            grid: grid, mviri: [0.3], seviri: [0.18], logger: Logger(label: "test"))
        let reader = try await OmFileReader(mmapFile: "\(directory)/\(variable)_corrected/year_2006.om").expectArray(of: Float.self)
        let actual = try await reader.read(range: [0..<1, 0..<1, 0..<25])
        for t in [0, 24] {
            var expected: [Float] = [t == 0 ? 100 : 200]
            let sourceTime = Timestamp(2006, 1, 1).add((t - 1) * 1800)
            EumetsatSarahCorrect.correct(data: &expected, grid: grid, locations: 0..<1,
                time: TimerangeDt(start: sourceTime, nTime: 1, dtSeconds: 1800), offsets: [t == 0 ? 0.3 : 0.18])
            #expect(abs(actual[t] - expected[0]) < 0.11)
        }
        #expect(!FileManager.default.fileExists(atPath: "\(directory)/\(variable)_corrected/year_2005.om"))
    }

    @Test func orderedWorkersAndFailure() async throws {
        var written = [Int]()
        try await EumetsatSarahCorrect.processOrdered(count: 12, concurrent: 4, process: { index in
            // Force later tiles to finish before the first; output must still be ordered.
            if index == 0 { try await Task.sleep(for: .milliseconds(20)) }
            return [Float(index)]
        }, consume: { index, result in
            #expect(result == [Float(index)])
            written.append(index)
        })
        #expect(written == Array(0..<12))
        enum Failure: Error { case expected }
        do {
            try await EumetsatSarahCorrect.processOrdered(count: 12, concurrent: 4, process: { index in
                if index == 2 { throw Failure.expected }
                return [Float(index)]
            }, consume: { _, _ in })
            Issue.record("Worker failure must propagate")
        } catch Failure.expected { }
    }

    @Test func cachedGeometryMatchesUncached() {
        let grid = RegularGrid(nx: 3, ny: 2, latMin: -60, lonMin: -60, dx: 60, dy: 120)
        let offsets: [Double] = [0.1, 0.18, .nan, 0.2, 0.3, 0.15]
        for date in [Timestamp(2005, 12, 31), Timestamp(2024, 6, 21), Timestamp(2024, 3, 20)] {
            let day = EumetsatSarahCorrect.CorrectionDay(start: date.timeIntervalSince1970 / 1800, count: 48)
            var uncached: [Float] = (0..<grid.count * 48).map { i in
                i % 7 == 0 ? .nan : i % 5 == 0 ? 0 : Float(50 + i * 3)
            }
            var cached = uncached
            EumetsatSarahCorrect.correct(data: &uncached, grid: grid, locations: 0..<grid.count, time: day.time, offsets: offsets)
            EumetsatSarahCorrect.correct(data: &cached, grid: grid, locations: 0..<grid.count, time: day.time, offsets: offsets,
                geometry: day.geometry, shiftedGeometry: day.shiftedGeometry)
            for i in cached.indices {
                #expect(cached[i] == uncached[i] || (cached[i].isNaN && uncached[i].isNaN))
            }
        }
    }

}
