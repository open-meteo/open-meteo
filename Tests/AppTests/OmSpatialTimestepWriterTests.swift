import Foundation
import Logging
import OmFileIO
import Testing
@testable import App

struct OmSpatialTimestepWriterTests {
    @Test func multistepWriterPreservesTimeAndMemberIdentity() async throws {
        try FileManager.default.createDirectory(atPath: OpenMeteo.tempDirectory, withIntermediateDirectories: true)
        let domain = MultistepTestDomain()
        let run = Timestamp(2026, 11, 17)
        let writer = OmSpatialMultistepWriter(domain: domain, run: run, storeOnDisk: false, realm: nil, logger: Logger(label: "multistep-test"))
        let variable = EcmwfVariable.temperature_2m
        for (hour, member) in [(6, 0), (3, 0), (3, 1)] {
            try await writer.write(time: run.add(hours: hour), member: member, variable: variable, data: Array(repeating: Float(hour + member), count: domain.grid.count))
        }
        let handles = try await writer.finalise()
        #expect(handles.count == 3)
        #expect(handles.map { $0.time.range.lowerBound } == [run.add(hours: 3), run.add(hours: 3), run.add(hours: 6)])
        for handle in handles {
            let hour = (handle.time.range.lowerBound.timeIntervalSince1970 - run.timeIntervalSince1970) / 3600
            #expect(try await handle.reader.read(range: [0..<1, 0..<1]) == [Float(hour + handle.member)])
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
