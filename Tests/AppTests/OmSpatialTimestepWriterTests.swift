import Foundation
import Logging
import OmFileIO
import Testing
@testable import App

struct OmSpatialTimestepWriterTests {
    @Test func ifsEnsembleChunksMatchConversionBlocks() {
        for domain in [EcmwfDomain.ifs01_ensemble, .ifs01_ensemble_pressure_levels] {
            let chunks = OmFileSplitter(domain).spatialReadChunkDimensions
            #expect(chunks.y == 1)
            #expect(chunks.x == 377)
            let control = OmFileSplitter(domain, nMembers: 1).spatialReadChunkDimensions
            #expect(control.y == 5)
            #expect(control.x == 3600)
        }
    }

    @Test func multistepWriterPreservesChunksAndMemberIdentity() async throws {
        try FileManager.default.createDirectory(atPath: OpenMeteo.tempDirectory, withIntermediateDirectories: true)
        let domain = ChunkTestDomain()
        let run = Timestamp(2026, 11, 17)
        let writer = OmSpatialMultistepWriter(domain: domain, run: run, storeOnDisk: false, realm: nil, logger: Logger(label: "multistep-chunks-test"), chunkDimensions: [1, 377])
        let variable = EcmwfVariable.temperature_2m
        for (hour, member) in [(6, 0), (3, 0), (3, 1)] {
            try await writer.write(time: run.add(hours: hour), member: member, variable: variable, data: Array(repeating: Float(hour + member), count: domain.grid.count))
        }
        let handles = try await writer.finalise()
        #expect(handles.count == 3)
        #expect(handles.map { $0.time.range.lowerBound } == [run.add(hours: 3), run.add(hours: 3), run.add(hours: 6)])
        for handle in handles {
            #expect(handle.reader.getChunkDimensions() == [1, 377])
            let hour = (handle.time.range.lowerBound.timeIntervalSince1970 - run.timeIntervalSince1970) / 3600
            #expect(try await handle.reader.read(range: [0..<1, 0..<1]) == [Float(hour + handle.member)])
        }
    }

    @Test func conversionAlignedChunksRoundTripAcrossChunkAndRowBoundaries() async throws {
        try FileManager.default.createDirectory(atPath: OpenMeteo.tempDirectory, withIntermediateDirectories: true)
        let domain = ChunkTestDomain()
        let chunks = OmFileSplitter(domain).spatialReadChunkDimensions
        let run = Timestamp(2026, 11, 17)
        let writer = OmSpatialTimestepWriter(
            domain: domain, run: run, time: run, storeOnDisk: false, realm: nil,
            logger: Logger(label: "spatial-chunks-test"), chunkDimensions: [chunks.y, chunks.x]
        )
        let values = (0..<domain.grid.count).map { Float($0 % 100) }
        try await writer.write(member: 0, variable: EcmwfVariable.temperature_2m, data: values)
        let handles = try await writer.finalise()
        let reader = try #require(handles.first?.reader)
        #expect(reader.getDimensions() == [3, 800])
        #expect(reader.getChunkDimensions() == [1, 377])
        for lower in stride(from: 0, to: 800, by: chunks.x) {
            let upper = min(lower + chunks.x, 800)
            let read = try await reader.read(range: [0..<3, UInt64(lower)..<UInt64(upper)])
            let expected = (0..<3).flatMap { row in Array(values[(row * 800 + lower)..<(row * 800 + upper)]) }
            #expect(read == expected)
        }
        let crossing = try await reader.read(range: [1..<3, 370..<390])
        #expect(crossing == Array(values[1170..<1190]) + Array(values[1970..<1990]))
    }
}

private struct ChunkTestDomain: GenericDomain {
    var countEnsembleMember: Int { 51 }
    var grid: any Gridable { RegularGrid(nx: 800, ny: 3, latMin: 0, lonMin: 0, dx: 0.1, dy: 0.1) }
    var domainRegistry: DomainRegistry { .ecmwf_ifs01_ensemble }
    var domainRegistryStatic: DomainRegistry? { nil }
    var dtSeconds: Int { 10800 }
    var updateIntervalSeconds: Int { 21600 }
    var masterTimeRange: Range<Timestamp>? { nil }
    var omFileLength: Int { 104 }
}
