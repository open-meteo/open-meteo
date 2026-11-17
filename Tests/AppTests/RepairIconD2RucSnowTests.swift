import Foundation
import Testing
import OmFileFormat
@testable import App

@Suite struct RepairIconD2RucSnowTests {
    @Test func workspaceSelection() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fm = FileManager.default
        try RepairIconD2RucSnowCommand.prepareWorkspace(directory.path, selection: 0..<86400)
        let original = directory.appendingPathComponent("original")
        let corrected = directory.appendingPathComponent("corrected")
        for folder in [original, corrected] {
            try fm.createDirectory(at: folder, withIntermediateDirectories: true)
            try Data([1, 2, 3]).write(to: folder.appendingPathComponent("chunk.om"))
        }
        try RepairIconD2RucSnowCommand.prepareWorkspace(directory.path, selection: 0..<86400)
        #expect(fm.fileExists(atPath: original.appendingPathComponent("chunk.om").path))
        #expect(fm.fileExists(atPath: corrected.appendingPathComponent("chunk.om").path))
        try RepairIconD2RucSnowCommand.prepareWorkspace(directory.path, selection: 86400..<172800)
        #expect(!fm.fileExists(atPath: original.path))
        #expect(!fm.fileExists(atPath: corrected.path))
        #expect(try String(contentsOf: directory.appendingPathComponent("selection"), encoding: .utf8) == "86400-172800")
        // A missing marker (including an interrupted reset) also invalidates cached files.
        try fm.createDirectory(at: corrected, withIntermediateDirectories: true)
        try Data([1]).write(to: corrected.appendingPathComponent("chunk.om"))
        try fm.removeItem(at: directory.appendingPathComponent("selection"))
        try RepairIconD2RucSnowCommand.prepareWorkspace(directory.path, selection: 86400..<172800)
        #expect(!fm.fileExists(atPath: corrected.path))
        #expect(RepairIconD2RucSnowCommand.fileTime("year_2026.om", domain: .iconD2RucNative15min) == nil)
        let duration = IconNativeDomains.iconD2RucNative15min.omFileLength * 900
        #expect(RepairIconD2RucSnowCommand.fileTime("chunk_2.om", domain: .iconD2RucNative15min) == 2 * duration..<3 * duration)
    }

    @Test func installLocal() throws {
        let fm = FileManager.default
        let directory = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: directory) }
        let source = directory.appendingPathComponent("corrected.om")
        let live = directory.appendingPathComponent("live/snow.om")
        try Data([1, 2]).write(to: source)
        try RepairIconD2RucSnowCommand.install(from: source.path, to: live.path)
        let oldReader = try FileHandle(forReadingFrom: live)
        defer { try? oldReader.close() }
        try Data([3, 4]).write(to: source)
        try RepairIconD2RucSnowCommand.install(from: source.path, to: live.path)
        #expect(try oldReader.readToEnd() == Data([1, 2]))
        #expect(try Data(contentsOf: live) == Data([3, 4]))
        #expect(try Data(contentsOf: source) == Data([3, 4]))
        #expect(!fm.fileExists(atPath: live.path + ".repair.partial"))
        #expect(try RepairIconD2RucSnowCommand.livePath("data/model/snow/chunk_1.om", dataDirectory: "/live/data/") == "/live/data/model/snow/chunk_1.om")
        #expect(try RepairIconD2RucSnowCommand.livePath("data_run/model/run/snow.om", dataRunDirectory: "/live/runs/") == "/live/runs/model/run/snow.om")
        #expect(throws: (any Error).self) {
            try RepairIconD2RucSnowCommand.livePath("data_run/model/run/snow.om", dataRunDirectory: nil)
        }
        let workspace = directory.appendingPathComponent("workspace")
        try RepairIconD2RucSnowCommand.prepareWorkspace(workspace.path, selection: 0..<86400)
        let cache = workspace.appendingPathComponent("corrected")
        try fm.createDirectory(at: cache, withIntermediateDirectories: true)
        try RepairIconD2RucSnowCommand.prepareWorkspace(workspace.path, selection: 0..<86400, refresh: true)
        #expect(!fm.fileExists(atPath: cache.path))
    }

    @Test func residual() {
        let fix = RepairIconD2RucSnowCommand.correctedSnow
        #expect(fix(1, 5, 1, 0.5, 1.5) == 3.5)
        #expect(fix(1, 5, 1, 0.5, 1.6) == 1)
        #expect(fix(4, 5, 1, 0.5, -2) == 4)
        #expect(fix(1, .nan, 1, 0, -2) == 1)
        #expect(fix(1, 5, 1, .nan, -2) == 1)
        #expect(fix(1, 5, 1, 0, .nan) == 1)
        #expect(fix(3.5, 5, 1, 0.5, -2) == 3.5)
    }

    @Test func rewriteFile() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        func make(_ name: String, _ data: [Float], nt: UInt64, times: [Int]? = nil) async throws -> OmFileReaderArray<MmapFile, Float> {
            let path = directory.appendingPathComponent(name).path
            let handle = try FileHandle.createNewFile(file: path)
            let file = OmFileWriter(fn: handle, initialCapacity: 1024)
            let writer = try file.prepareArray(type: Float.self, dimensions: [1, 3, nt], chunkDimensions: [1, 2, 2],
                                              compression: .pfor_delta2d_int16, scale_factor: 10, add_offset: 0)
            try writer.writeData(array: data)
            let array = try writer.finalise()
            var children = [OmOffsetSize]()
            if let times {
                children.append(try file.write(value: Int(0), name: "forecast_reference_time", children: []))
                children.append(try file.write(value: Int(123), name: "created_at", children: []))
                for (name, value) in [("unit", "mm"), ("coordinates", "lat lon time"), ("crs_wkt", "test crs")] {
                    children.append(try file.write(value: value, name: name, children: []))
                }
                let timeArray = try file.writeArray(data: times, dimensions: [nt], chunkDimensions: [nt],
                                                   compression: .pfor_delta2d, scale_factor: 1, add_offset: 0)
                children.append(try file.write(array: timeArray, name: "time", children: []))
            }
            let root = try file.write(array: array, name: "", children: children)
            try file.writeTrailer(rootVariable: root)
            try handle.close()
            return try await OmFileReader(mmapFile: path).expectArray(of: Float.self)
        }
        let snow = try await make("snow", Array(repeating: 1, count: 24), nt: 8)
        let precipitation = try await make("precipitation", Array(repeating: 5, count: 24), nt: 8)
        let rain = try await make("rain", Array(repeating: 1, count: 24), nt: 8)
        let hail = try await make("hail", Array(repeating: 0.5, count: 24), nt: 8)
        let temperature = try await make("temperature", [-1, 2, 1.5, 1.5, .nan, -2], nt: 2)
        let output = directory.appendingPathComponent("fixed").path
        let inputs = ["snowfall_water_equivalent": snow, "precipitation": precipitation, "rain": rain, "hail": hail]
        // Snow starts at :15, exercising alignment across an hourly temperature file boundary.
        let laterTemperature = try await make("temperature-later", [2, 2, 1.5, 1.5, -2, -2], nt: 2)
        let temperatures = [(time: [0, 3600], reader: temperature), (time: [7200, 10800], reader: laterTemperature)]
        // An interrupted output is discarded and rebuilt.
        try Data([1, 2, 3]).write(to: URL(fileURLWithPath: output + ".partial"))
        let changed = try await RepairIconD2RucSnowCommand.repair(inputs: inputs, temperatures: temperatures,
                                                               time: Array(stride(from: 900, to: 8100, by: 900)), selection: 1800..<7200, output: output)
        #expect(changed == 12)
        let result = try await OmFileReader(mmapFile: output).expectArray(of: Float.self)
        let data = try await result.read()
        #expect(data == [1, 3.5, 3.5, 1, 1, 1, 1, 1,
                         1, 3.5, 3.5, 3.5, 3.5, 3.5, 3.5, 1,
                         1, 1, 1, 3.5, 3.5, 3.5, 3.5, 1])
        #expect(Array(result.getChunkDimensions()) == Array(snow.getChunkDimensions()))
        #expect(!FileManager.default.fileExists(atPath: output + ".partial"))
        let completed = try Data(contentsOf: URL(fileURLWithPath: output))
        let resumed = try await RepairIconD2RucSnowCommand.repair(inputs: inputs, temperatures: temperatures,
                                                                time: Array(stride(from: 900, to: 8100, by: 900)), selection: 1800..<7200, output: output)
        #expect(resumed == nil)
        #expect(try Data(contentsOf: URL(fileURLWithPath: output)) == completed)
        var correctedInputs = inputs
        correctedInputs["snowfall_water_equivalent"] = result
        let again = try await RepairIconD2RucSnowCommand.repair(inputs: correctedInputs, temperatures: temperatures,
                                                              time: Array(stride(from: 900, to: 8100, by: 900)), selection: 1800..<7200,
                                                              output: directory.appendingPathComponent("again").path)
        #expect(again == 0)

        // Run files may omit individual forecast steps. Preserve timestamps and metadata.
        let runTimes = [900, 1800, 2700, 4500, 5400, 6300, 7200, 8100]
        var runInputs = inputs
        runInputs["snowfall_water_equivalent"] = try await make("run-snow", Array(repeating: 1, count: 24), nt: 8, times: runTimes)
        let metadata = try await OmFileReader(mmapFile: directory.appendingPathComponent("run-snow").path)
        #expect(try await RepairIconD2RucSnowCommand.runTimes(metadata, run: 0) == runTimes)
        let runOutput = directory.appendingPathComponent("run-fixed").path
        let runChanged = try await RepairIconD2RucSnowCommand.repair(inputs: runInputs, temperatures: temperatures,
            time: runTimes, selection: 1800..<7200, output: runOutput, metadata: metadata)
        #expect(runChanged == 10)
        let repairedRun = try await OmFileReader(mmapFile: runOutput)
        #expect(try await RepairIconD2RucSnowCommand.runTimes(repairedRun, run: 0) == runTimes)
        let created: Int? = try await repairedRun.getChild(name: "created_at")?.readScalar()
        #expect(created == 123)
        for (name, expected) in [("unit", "mm"), ("coordinates", "lat lon time"), ("crs_wkt", "test crs")] {
            let value: String? = try await repairedRun.getChild(name: name)?.readScalar()
            #expect(value == expected)
        }
        let runValues = try await repairedRun.expectArray(of: Float.self).read()
        #expect(runValues == [1, 3.5, 3.5, 1, 1, 1, 1, 1,
                              1, 3.5, 3.5, 3.5, 3.5, 3.5, 1, 1,
                              1, 1, 1, 3.5, 3.5, 3.5, 1, 1])

    }
}
