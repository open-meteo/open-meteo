import Foundation
import Logging
import OmFileIO
import Testing
@testable import App

struct OmSpatialTimestepWriterTests {
    @Test func waveDragRetainsPrecisionThroughStorageAndFormatting() async throws {
        try FileManager.default.createDirectory(atPath: OpenMeteo.tempDirectory, withIntermediateDirectories: true)
        let domain = MultistepTestDomain()
        let run = Timestamp(2026, 11, 24)
        let variable = EcmwfWaveVariable.wave_drag_coefficient
        let writer = OmSpatialMultistepWriter(domain: domain, run: run, storeOnDisk: false, realm: nil, logger: Logger(label: "wave-drag-test"))
        try await writer.write(time: run, member: 0, variable: variable, data: Array(repeating: 0.00123, count: domain.grid.count))
        let handles = try await writer.finalise()
        let handle = try #require(handles.first)
        let values = try await handle.reader.read()
        #expect(values.allSatisfy { abs($0 - 0.00123) < 0.000005 })
        #expect(values[0].formatted(decimals: variable.unit.significantDigits) == "0.001")
        #expect(variable.unit.abbreviation == "fraction")
    }

    @Test func multistepWriterPreservesTimeAndMemberIdentity() async throws {
        try FileManager.default.createDirectory(atPath: OpenMeteo.tempDirectory, withIntermediateDirectories: true)
        let domain = MultistepTestDomain()
        let run = Timestamp(2026, 11, 17)
        let readChunks = OmFileSplitter(domain).spatialReadChunkDimensions
        let chunks = [readChunks.y, readChunks.x]
        let writer = OmSpatialMultistepWriter(domain: domain, run: run, storeOnDisk: false, realm: nil, logger: Logger(label: "multistep-test"), chunkDimensions: chunks)
        let variable = EcmwfVariable.temperature_2m
        try await withThrowingTaskGroup(of: Void.self) { group in
            for (hour, member) in [(6, 0), (3, 0), (3, 1)] {
                group.addTask {
                    try await writer.write(time: run.add(hours: hour), member: member, variable: variable, data: Array(repeating: Float(hour + member), count: domain.grid.count))
                }
            }
            try await group.waitForAll()
        }
        let handles = try await writer.finalise()
        #expect(await writer.writer.isEmpty)
        #expect(handles.count == 3)
        #expect(handles.map { $0.time.range.lowerBound } == [run.add(hours: 3), run.add(hours: 3), run.add(hours: 6)])
        for handle in handles {
            #expect(handle.reader.getChunkDimensions() == chunks.map(UInt64.init))
            let hour = (handle.time.range.lowerBound.timeIntervalSince1970 - run.timeIntervalSince1970) / 3600
            let data = try await handle.reader.read()
            #expect(data == Array(repeating: Float(hour + handle.member), count: domain.grid.count))
        }
    }
}

private struct MultistepTestDomain: GenericDomain {
    var countEnsembleMember: Int { 51 }
    var grid: any Gridable { RegularGrid(nx: 800, ny: 3, latMin: 0, lonMin: 0, dx: 0.1, dy: 0.1) }
    var domainRegistry: DomainRegistry { .ecmwf_ifs01_ensemble }
    var domainRegistryStatic: DomainRegistry? { nil }
    var dtSeconds: Int { 10800 }
    var updateIntervalSeconds: Int { 21600 }
    var masterTimeRange: Range<Timestamp>? { nil }
    var omFileLength: Int { 104 }
}
