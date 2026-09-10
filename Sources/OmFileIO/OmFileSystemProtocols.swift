import OmFileFormat
import Foundation

public protocol OmFileSystemFile {
    
}

public protocol OmFileSystemDirectory {
    associatedtype Directory: OmFileSystemDirectory
    associatedtype File: OmFileSystemFile
    func getDirectory(fullPath: String) async throws -> Directory?
    func getFile(fullPath: String) async throws -> File?
    
    func getDirectory(name: String) async throws -> Directory?
    func getFile(name: String) async -> File?
}

public protocol OmFileManagable {
    associatedtype Payload: OmFilePayload
    
    /// Get the relative file prefixed with `data/` or `data_spatial` like `data/dwd_icon/temperature_2m/chunk_1234.om`
    func getRelativeFilePathWithData() -> String
    
    /// Get absolute local file path
    func getFilePath() -> String
}

public protocol OmFilePayload: OmRemotePayload, OmLocalPayload {
    
}

public protocol OmRemotePayload: Sendable {
    /// Initialise from remote source
    init(file: OmHttpReaderBackend) async throws
    func remoteUpdated(file: OmHttpReaderBackend) async throws -> Self
    func remoteDeleted() async throws
}

public protocol OmLocalPayload: Sendable {
    /// Payload can retain a reference to FileHandle to ensure the file stays open
    init(fd: FileHandle, size: Int64) async throws
}


public extension OmFileManagable {
    /// Copy a backend to a local file and atomically publish it without validation.
    func materialize<Backend: OmFileReaderBackend>(file: Backend) async throws -> FileHandle
    where Backend.DataType: DataProtocol {
        try await materialize(file: file, validate: { $0 })
    }

    /// Copy to a temporary local file, then validate it before atomically publishing it.
    /// If validation throws, the destination remains unchanged. The result may retain the handle or its mapping.
    func materialize<Backend: OmFileReaderBackend, Result>(
        file: Backend,
        validate: (FileHandle) throws -> Result
    ) async throws -> Result where Backend.DataType: DataProtocol {
        try createDirectory()
        let path = getFilePath()
        let handle = try FileHandle.createNewFile(
            file: path,
            size: file.count,
            overwrite: true,
            temporary: true
        )
        for offset in stride(from: 0, to: file.count, by: 8 * 1_024 * 1_024) {
            let count = min(8 * 1_024 * 1_024, file.count - offset)
            try handle.write(contentsOf: await file.getData(offset: offset, count: count))
        }
        let result = try validate(handle)
        try handle.linkTemporary(file: path)
        return result
    }

    func createDirectory() throws {
        let file = getFilePath()
        guard let last = file.lastIndex(of: "/") else {
            return
        }
        let path = "\(file[file.startIndex..<last])"
        try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
    }
    
    func exists() -> Bool {
        let file = getFilePath()
        return FileManager.default.fileExists(atPath: file)
    }
}
