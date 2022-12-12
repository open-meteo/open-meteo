import Foundation

/// OmFileWriter can write data to this backend
public protocol OmFileWriterBackend {
    mutating func write<T>(contentsOf data: T) throws where T : DataProtocol
    mutating func write<T>(contentsOf data: T, atOffset: Int) throws where T : DataProtocol
    func synchronize() throws
}

/// OmFileReader can read data from this backend
public protocol OmFileReaderBackend {
    /// Length in bytes
    var count: Int { get }
    var needsPrefetch: Bool { get }
    func prefetchData(offset: Int, count: Int)
    
    func withUnsafeBytes<ResultType>(_ body: (UnsafeRawBufferPointer) throws -> ResultType) rethrows -> ResultType
}

/// Make `Data` work as writer
extension Data: OmFileWriterBackend {
    public func synchronize() throws {
        
    }
    
    public mutating func write<T>(contentsOf data: T) throws where T : DataProtocol {
        self.append(contentsOf: data)
    }
    
    public mutating func write<T>(contentsOf data: T, atOffset: Int) throws where T : DataProtocol {
        self.insert(contentsOf: data, at: atOffset)
    }
}

/// Make `FileHandle` work as writer
extension FileHandle: OmFileWriterBackend {
    public func write<T>(contentsOf data: T, atOffset: Int) throws where T : DataProtocol {
        try seek(toOffset: UInt64(atOffset))
        try write(contentsOf: data)
    }
}

/// Make `FileHandle` work as reader
extension MmapFile: OmFileReaderBackend {
    public var count: Int {
        return data.count
    }
    
    public func withUnsafeBytes<ResultType>(_ body: (UnsafeRawBufferPointer) throws -> ResultType) rethrows -> ResultType {
        try data.withUnsafeBytes(body)
    }
    
    public var needsPrefetch: Bool {
        return true
    }
}

/// Make `Data` work as reader
extension Data: OmFileReaderBackend {
    public var needsPrefetch: Bool {
        return false
    }
    
    public func prefetchData(offset: Int, count: Int) {
        
    }
}
