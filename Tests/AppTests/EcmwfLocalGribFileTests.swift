import AsyncHTTPClient
import Foundation
import Logging
import Testing
@testable import App

struct EcmwfLocalGribFileTests {
    // One 2x2 GRIB2 physical message containing U=3 and V=4 submessages.
    private let fixture = "R1JJQv//AAIAAAAAAAAA9QAAABUBAGIAAAQAAQfXAxcMAAAAAgAAAEgDAAAAAAQAAAAABv///////////////////wAAAAIAAAACAAAAAP////8Dk4cAAAAAADAAAAAAAcnDgAAehIAAHoSAAAAAACIEAAAAAAICAP+AAAAAAQAAAAAB//////////////8AAAAVBQAAAAQAAEBAAAAAAAAAAAAAAAAGBv8AAAAFBwAAACIEAAAAAAIDAP+AAAAAAQAAAAAB//////////////8AAAAVBQAAAAQAAECAAAAAAAAAAAAAAAAGBv8AAAAFBzc3Nzc="

    @Test func scansAndReadsSubmessagesFromMultipleFilesConcurrently() async throws {
        let data = try #require(Data(base64Encoded: fixture))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try await withThrowingTaskGroup(of: Void.self) { group in
            for i in 0..<4 {
                let path = directory.appendingPathComponent("\(i).grib2")
                try (data + data).write(to: path)
                group.addTask {
                    let file = try EcmwfLocalGribFile(path: path.path)
                    #expect(file.fields.count == 4)
                    #expect(file.fields.map(\.submessage) == [0, 1, 0, 1])
                    #expect(file.fields.map(\.range) == [0..<data.count, 0..<data.count, data.count..<2 * data.count, data.count..<2 * data.count])
                    for index in [3, 0, 2, 1] {
                        let values = try file.withMessage(field: file.fields[index]) { try $0.getDouble() }
                        #expect(values == Array(repeating: index.isMultiple(of: 2) ? 3 : 4, count: 4))
                    }
                }
            }
            try await group.waitForAll()
        }
        let truncated = directory.appendingPathComponent("truncated.grib2")
        try data.dropLast().write(to: truncated)
        #expect(throws: EcmwfLocalGribFile.Failure.self) { try EcmwfLocalGribFile(path: truncated.path) }
    }

    @Test func existingFilesAreReusedWithoutAnyHTTPRequests() async throws {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let data = try #require(Data(base64Encoded: fixture))
        try data.write(to: path)
        defer { try? FileManager.default.removeItem(at: path) }
        let curl = Curl(logger: Logger(label: "cache-test"), client: HTTPClient.shared)
        // Any attempted HTTP request would fail with this invalid URL.
        let files = try await curl.download(files: [(url: "not a URL", path: path.path)], nConcurrent: 8).collect()
        #expect(files.count == 1)
        #expect(files.first?.path == path.path)
        #expect(files.first?.url == "not a URL")
        #expect(try Data(contentsOf: path) == data)
    }

    @Test func selectsProviderChunkSizes() {
        #expect(EcmwfOpenDataSource.fullFileChunkSizeMB(base: EcmwfOpenDataSource.aws.baseURL) == 8)
        #expect(EcmwfOpenDataSource.fullFileChunkSizeMB(base: EcmwfOpenDataSource.ecmwf.baseURL) == 64)
        #expect(EcmwfOpenDataSource.fullFileChunkSizeMB(base: EcmwfOpenDataSource.azure.baseURL) == 4)
        #expect(EcmwfOpenDataSource.fullFileChunkSizeMB(base: EcmwfOpenDataSource.google.baseURL) == 100)
    }
}
