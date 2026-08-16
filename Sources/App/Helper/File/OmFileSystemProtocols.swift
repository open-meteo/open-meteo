import OmFileFormat
import Foundation
import Vapor

protocol OmFileSystemFile {
    
}

protocol OmFileSystemDirectory {
    associatedtype Directory: OmFileSystemDirectory
    associatedtype File: OmFileSystemFile
    func getDirectory(fullPath: String) async throws -> Directory?
    func getFile(fullPath: String) async throws -> File?
    
    func getDirectory(name: String) async throws -> Directory?
    func getFile(name: String) async -> File?
}

protocol OmFileManagable {
    associatedtype Payload: OmFilePayload
    
    /// Get the relative file prefixed with `data/` or `data_spatial` like `data/dwd_icon/temperature_2m/chunk_1234.om`
    func getRelativeFilePathWithData() -> String
}

protocol OmFilePayload: OmRemotePayload, OmLocalPayload {
    
}

protocol OmRemotePayload: Sendable {
    /// Initialise from remote source
    init(file: OmReaderBlockCache<OmHttpReaderBackend, MmapFile>) async throws
    func remoteUpdated(file: OmReaderBlockCache<OmHttpReaderBackend, MmapFile>) async throws -> Self
    func remoteDeleted() async throws
}

protocol OmLocalPayload: Sendable {
    /// Payload can retain a reference to FileHandle to ensure the file stays open
    init(fd: FileHandle, size: Int64) async throws
}


extension OmFileManagable {
    /// Get the absolute file system path like `/var/lib/openmeteo-`
    func getFilePath() -> String {
        let path = getRelativeFilePathWithData()
        if path.starts(with: "data/") {
            return path.replacingOccurrences(of: "data/", with: OpenMeteo.dataDirectory)
        }
        if path.starts(with: "data_run/") {
            return path.replacingOccurrences(of: "data_run/", with: OpenMeteo.dataRunDirectory ?? OpenMeteo.dataDirectory)
        }
        if path.starts(with: "data_spatial/") {
            return path.replacingOccurrences(of: "data_spatial/", with: OpenMeteo.dataSpatialDirectory ?? OpenMeteo.dataDirectory)
        }
        fatalError("Unexpected data path \(path)")
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
