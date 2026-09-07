import Foundation
@testable import App
@testable import OmFileIO
import Testing

@Suite struct OmFileSystemManagerTests {
    @Test func opensConfiguredRoots() async throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: base) }
        for name in ["data", "data_run", "data_spatial"] {
            let directory = base.appendingPathComponent(name)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try Data(name.utf8).write(to: directory.appendingPathComponent("file"))
        }

        let manager = try OmFileSystemManager(
            dataDirectory: base.appendingPathComponent("data").path,
            dataRunDirectory: base.appendingPathComponent("data_run").path,
            dataSpatialDirectory: base.appendingPathComponent("data_spatial").path
        )
        for name in ["data", "data_run", "data_spatial"] {
            let file = try #require(await manager.localFileSystem.getFile(fullPath: "\(name)/file"))
            #expect(await file.size == Int64(name.utf8.count))
            #expect(await manager.localFileSystem.getFile(fullPath: "\(name)/missing") == nil)
        }
    }

    @Test func acceptsEmptyPrimaryRootWithoutOptionalRoots() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let manager = try OmFileSystemManager(dataDirectory: directory.path, dataRunDirectory: nil, dataSpatialDirectory: nil)
        #expect(await manager.localFileSystem.getDirectory(name: "data") != nil)
        #expect(await manager.localFileSystem.getDirectory(name: "data_run") == nil)
        #expect(await manager.localFileSystem.getDirectory(name: "data_spatial") == nil)
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty)
    }

    @Test(arguments: ["data", "data_run", "data_spatial"], [false, true])
    func rejectsInvalidRoot(root: String, isRegularFile: Bool) throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: base) }
        let invalidPath = base.appendingPathComponent(root).path
        for name in ["data", "data_run", "data_spatial"] where name != root {
            try FileManager.default.createDirectory(at: base.appendingPathComponent(name), withIntermediateDirectories: true)
        }
        if isRegularFile {
            try Data("not a directory".utf8).write(to: URL(fileURLWithPath: invalidPath))
        }

        do {
            _ = try OmFileSystemManager(
                dataDirectory: base.appendingPathComponent("data").path,
                dataRunDirectory: base.appendingPathComponent("data_run").path,
                dataSpatialDirectory: base.appendingPathComponent("data_spatial").path
            )
            Issue.record("Expected opening invalid root '\(root)' to throw")
        } catch let FileSystemCacheError.cannotOpenFile(name, code, error) {
            #expect(name == invalidPath)
            #expect(code != 0)
            #expect(!error.isEmpty)
        }
        #expect(FileManager.default.fileExists(atPath: invalidPath) == isRegularFile)
    }
}
