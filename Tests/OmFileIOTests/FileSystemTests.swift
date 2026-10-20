import Foundation
@testable import OmFileIO
import Testing
import OmTime

@Suite(.serialized) struct FileSystemTests {
    @Test func seriesIndexRangesAndMissingFiles() {
        let index = OmFileSeriesIndex(files: [
            "chunk_-2.om": 1, "chunk_0.om": 2,
            "year_2020.om": 3, "year_2022.om": 4,
            "master_0.om": 5, "rolling.om": 6,
            "chunk_100.om~": 7, "year_invalid.om": 8
        ])
        #expect(index.chunkRange == -2..<1)
        #expect(index.yearRange == 2020..<2023)
        #expect(index.chunks[-2] == 1)
        #expect(index.chunks[-1] == nil)
        #expect(index.years[2021] == nil)
        #expect(index.master == 5)
        #expect(index.rolling == 6)
        #expect(OmFileSeriesIndex<Int>(files: [:]).chunkRange.isEmpty)
    }

    @Test func seriesIndexRefreshAndEviction() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: url) }
        let chunk = url.appendingPathComponent("chunk_10.om")
        try Data("old".utf8).write(to: chunk)
        let directory = try OmFileSystemLocal.Directory(path: url.path)
        await directory.updateIfRequired()
        let old = await directory.getSeriesIndex()
        #expect(old.chunkRange == 10..<11)
        try Data("replacement".utf8).write(to: chunk, options: .atomic)
        try Data().write(to: url.appendingPathComponent("year_2024.om"))
        await directory.updateIfRequired(force: true)
        let updated = await directory.getSeriesIndex()
        #expect(updated.chunks[10] !== old.chunks[10])
        #expect(updated.yearRange == 2024..<2025)
        try FileManager.default.removeItem(at: chunk)
        await directory.updateIfRequired(force: true)
        #expect(await directory.getSeriesIndex().chunkRange.isEmpty)
        #expect(old.chunks[10] != nil)
        await directory.updateRecursivelyIfRequired(now: Timestamp.now().add(OmFileSystemLocal.revalidateBackgroundEjectInterval + 1))
        #expect(await directory.getSeriesIndex().yearRange.isEmpty)
    }

    @Test func fileSystemCache() async throws {
        let directoryUrl = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let nestedDirectoryUrl = directoryUrl.appendingPathComponent("dir1/dir2")
        try FileManager.default.createDirectory(at: nestedDirectoryUrl, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directoryUrl) }
        FileManager.default.createFile(atPath: nestedDirectoryUrl.appendingPathComponent("file").path, contents: Data("Hello".utf8))
        let directory = try OmFileSystemLocal.Directory(path: directoryUrl.path)
        await directory.updateIfRequired()

        #expect(await directory.getDirectory(name: "dir1")?.getDirectory(name: "dir2")?.getFile(name: "file")?.size == 5)
        #expect(await directory.getDirectory(fullPath: "dir1/dir2/")?.getFile(name: "file")?.size == 5)
        #expect(await directory.getFile(fullPath: "dir1/dir2/file")?.size == 5)
    }

    @Test func fileSystemCacheReloadsAtomicallyReplacedFile() async throws {
        let directoryUrl = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directoryUrl, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directoryUrl) }

        let fileUrl = directoryUrl.appendingPathComponent("file")
        try Data("old".utf8).write(to: fileUrl)
        let directory = try OmFileSystemLocal.Directory(path: directoryUrl.path)
        await directory.updateIfRequired()
        let oldFile = try #require(await directory.getFile(name: "file"))
        let oldInode = await oldFile.inode

        let replacementUrl = directoryUrl.appendingPathComponent("replacement~")
        try Data("replacement".utf8).write(to: replacementUrl)
        try FileManager.default.moveFileOverwrite(from: replacementUrl.path, to: fileUrl.path)
        await directory.updateIfRequired(force: true)

        let replacementFile = try #require(await directory.getFile(name: "file"))
        #expect(await replacementFile.inode != oldInode)
        #expect(try await replacementFile.fd.readToEnd() == Data("replacement".utf8))
    }

    @Test func fileSystemCacheBackgroundRefreshTraversesSyntheticRoot() async throws {
        let directoryUrl = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directoryUrl, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directoryUrl) }

        let dataDirectory = try OmFileSystemLocal.Directory(path: directoryUrl.path)
        await dataDirectory.updateIfRequired()
        let root = OmFileSystemLocal.Directory(directories: ["data": dataDirectory])
        try Data("new".utf8).write(to: directoryUrl.appendingPathComponent("new-file"))

        let refreshTime = Timestamp.now().add(OmFileSystemLocal.revalidateBackgroundInterval + 1)
        await root.updateRecursivelyIfRequired(now: refreshTime)
        #expect(await dataDirectory.getFile(name: "new-file") != nil)
    }
}
