import Foundation
@testable import OmFileIO
import Testing
import OmTime

@Suite(.serialized) struct FileSystemTests {
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
