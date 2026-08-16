

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
