import Foundation
import Testing
import OmFileFormat
@testable import App

@Suite struct RepairIconD2RucSnowTests {
    @Test func temperatureChunks() {
        let domain = IconNativeDomains.iconD2RucNative
        let duration = domain.omFileLength * domain.dtSeconds
        #expect(RepairIconD2RucSnowCommand.chunks(for: 0..<duration, domain: domain) == 0..<1)
        #expect(RepairIconD2RucSnowCommand.chunks(for: duration - 900..<duration + 900, domain: domain) == 0..<2)
        #expect(RepairIconD2RucSnowCommand.chunks(for: duration..<duration + 900, domain: domain) == 1..<2)
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
        #expect(!fm.fileExists(atPath: source.path))
        #expect(!fm.fileExists(atPath: live.path + "~"))
        #expect(RepairIconD2RucSnowCommand.localChunkPath("data/model/snow/chunk_1.om", dataDirectory: "/live/data/") == "/live/data/model/snow/chunk_1.om")
        #expect(RepairIconD2RucSnowCommand.localChunkPath("data_run/model/run/snow.om") == nil)

    }

    @Test func residual() {
        func fix(_ snow: Float, _ precipitation: Float, _ rain: Float, _ hail: Float, _ temperature: Float) -> Float {
            var stats = RepairIconD2RucSnowCommand.RepairStats()
            return RepairIconD2RucSnowCommand.correctedSnow(snow: snow, precipitation: precipitation, rain: rain, hail: hail, temperature: temperature, stats: &stats)
        }
        #expect(fix(1, 5, 1, 0.5, 1.5) == 1)
        #expect(fix(1, 5, 1, 0, -2) == 1)
        #expect(fix(1, 5, 1, 0.5, 1.6) == 1)
        #expect(fix(4, 5, 1, 0.5, -2) == 4)
        #expect(fix(1, .nan, 1, 0, -2) == 1)
        #expect(fix(1, 5, 1, .nan, -2) == 4)
        #expect(fix(1, 5, 1, 0, .nan) == 1)
        #expect(fix(3.5, 5, 1, 0.5, -2) == 3.5)
    }

    @Test func roundingToleranceAndStatistics() {
        var stats = RepairIconD2RucSnowCommand.RepairStats()
        let unchanged = RepairIconD2RucSnowCommand.correctedSnow(snow: 0.1, precipitation: 0.3, rain: 0.2, hail: .nan, temperature: -2, stats: &stats)
        #expect(unchanged == 0.1)
        #expect(stats.changed == 0)
        let lightSnow = RepairIconD2RucSnowCommand.correctedSnow(snow: 0, precipitation: 0.1, rain: 0, hail: .nan, temperature: -2, stats: &stats)
        #expect(lightSnow == 0.1)
        #expect(stats.changed == 1)
        #expect(stats.maxAddition == 0.1)
        let corrected = RepairIconD2RucSnowCommand.correctedSnow(snow: 0.1, precipitation: 0.5, rain: 0.2, hail: .nan, temperature: 1.5, stats: &stats)
        #expect(corrected == 0.3)
        #expect(stats.changed == 2)
        #expect(stats.maxAddition == 0.2)
        let repeated = RepairIconD2RucSnowCommand.correctedSnow(snow: corrected, precipitation: 0.5, rain: 0.2, hail: .nan, temperature: 1.5, stats: &stats)
        #expect(repeated == corrected)
        #expect(stats.changed == 2)
        #expect(stats.skippedHail == 0)
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
        let temperature = try await make("temperature", [-1, 2, 1.5, 1.5, .nan, -2], nt: 2)
        let output = directory.appendingPathComponent("fixed").path
        let inputs = ["snowfall_water_equivalent": snow, "precipitation": precipitation, "rain": rain]
        // Snow starts at :15, exercising alignment across an hourly temperature file boundary.
        let laterTemperature = try await make("temperature-later", [2, 2, 1.5, 1.5, -2, -2], nt: 2)
        let temperatures = [(time: [0, 3600], reader: temperature), (time: [7200, 10800], reader: laterTemperature)]
        let changed = try await RepairIconD2RucSnowCommand.repair(inputs: inputs, temperatures: temperatures,
                                                               time: Array(stride(from: 900, to: 8100, by: 900)), selection: 1800..<7200, output: output)
        #expect(changed.changed == 12)
        #expect(changed.maxAddition == 3)
        #expect(changed.skippedHail == 0)
        let result = try await OmFileReader(mmapFile: output).expectArray(of: Float.self)
        let data = try await result.read()
        #expect(data == [1, 4, 4, 1, 1, 1, 1, 1,
                         1, 4, 4, 4, 4, 4, 4, 1,
                         1, 1, 1, 4, 4, 4, 4, 1])
        #expect(Array(result.getChunkDimensions()) == Array(snow.getChunkDimensions()))
        #expect(!FileManager.default.fileExists(atPath: output + "~"))
        let completed = try Data(contentsOf: URL(fileURLWithPath: output))
        let resumed = try await RepairIconD2RucSnowCommand.repair(inputs: inputs, temperatures: temperatures,
                                                                time: Array(stride(from: 900, to: 8100, by: 900)), selection: 1800..<7200, output: output)
        #expect(resumed.changed == 12)
        #expect(try Data(contentsOf: URL(fileURLWithPath: output)) == completed)
        var correctedInputs = inputs
        correctedInputs["snowfall_water_equivalent"] = result
        let again = try await RepairIconD2RucSnowCommand.repair(inputs: correctedInputs, temperatures: temperatures,
                                                              time: Array(stride(from: 900, to: 8100, by: 900)), selection: 1800..<7200,
                                                              output: directory.appendingPathComponent("again").path)
        #expect(again.changed == 0)

        // A single chunk can contain both old data and already-corrected data.
        var mixedInputs = inputs
        mixedInputs["hail"] = try await make("mixed-hail", (0..<24).map { i in
            i % 8 == 2 ? 0 : i % 8 == 3 ? 0.5 : Float.nan
        }, nt: 8)
        let mixedOutput = directory.appendingPathComponent("mixed").path
        let mixed = try await RepairIconD2RucSnowCommand.repair(inputs: mixedInputs, temperatures: temperatures,
            time: Array(stride(from: 900, to: 8100, by: 900)), selection: 1800..<7200, output: mixedOutput)
        #expect(mixed.changed == 8)
        #expect(mixed.skippedHail == 6)
        let mixedData = try await OmFileReader(mmapFile: mixedOutput).expectArray(of: Float.self).read()
        #expect(mixedData == data.enumerated().map { i, value in i % 8 == 2 || i % 8 == 3 ? 1 : value })

        // Run files may omit individual forecast steps. Preserve timestamps and metadata.
        let runTimes = [900, 1800, 2700, 4500, 5400, 6300, 7200, 8100]
        var runInputs = inputs
        runInputs["snowfall_water_equivalent"] = try await make("run-snow", Array(repeating: 1, count: 24), nt: 8, times: runTimes)
        let metadata = try await OmFileReader(mmapFile: directory.appendingPathComponent("run-snow").path)
        #expect(try await RepairIconD2RucSnowCommand.runTimes(metadata, run: 0) == runTimes)
        let runOutput = directory.appendingPathComponent("run-fixed").path
        let runChanged = try await RepairIconD2RucSnowCommand.repair(inputs: runInputs, temperatures: temperatures,
            time: runTimes, selection: 1800..<7200, output: runOutput, metadata: metadata)
        #expect(runChanged.changed == 10)
        let repairedRun = try await OmFileReader(mmapFile: runOutput)
        #expect(try await RepairIconD2RucSnowCommand.runTimes(repairedRun, run: 0) == runTimes)
        let created: Int? = try await repairedRun.getChild(name: "created_at")?.readScalar()
        #expect(created == 123)
        for (name, expected) in [("unit", "mm"), ("coordinates", "lat lon time"), ("crs_wkt", "test crs")] {
            let value: String? = try await repairedRun.getChild(name: name)?.readScalar()
            #expect(value == expected)
        }
        let runValues = try await repairedRun.expectArray(of: Float.self).read()
        #expect(runValues == [1, 4, 4, 1, 1, 1, 1, 1,
                              1, 4, 4, 4, 4, 4, 1, 1,
                              1, 1, 1, 4, 4, 4, 1, 1])

    }
}
