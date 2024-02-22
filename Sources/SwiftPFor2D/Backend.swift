import Foundation

/// OmFileWriter can write data to this backend
public protocol OmFileWriterBackend {
    func write<T>(contentsOf data: T) throws where T : DataProtocol
    func write<T>(contentsOf data: T, atOffset: Int) throws where T : DataProtocol
    func synchronize() throws
}

/// OmFileReader can read data from this backend
public protocol OmFileReaderBackend {
    /// Length in bytes
    var count: Int { get }
    var needsPrefetch: Bool { get }
    func prefetchData(offset: Int, count: Int)
    func preRead(offset: Int, count: Int)
    
    func withUnsafeBytes<ResultType>(_ body: (UnsafeRawBufferPointer) throws -> ResultType) rethrows -> ResultType
}

/// Need to maintain a strong reference
public final class DataAsClass {
    public var data: Data
    
    public init(data: Data) {
        self.data = data
    }
}

/// Make `Data` work as writer
extension DataAsClass: OmFileWriterBackend {
    public func synchronize() throws {
        
    }
    
    public func write<T>(contentsOf data: T) throws where T : DataProtocol {
        self.data.append(contentsOf: data)
    }
    
    public func write<T>(contentsOf data: T, atOffset: Int) throws where T : DataProtocol {
        self.data.reserveCapacity(atOffset + data.count)
        let _ = self.data.withUnsafeMutableBytes {
            data.copyBytes(to: UnsafeMutableRawBufferPointer(rebasing: $0[atOffset ..< atOffset+data.count]))
        }
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
    public func prefetchData(offset: Int, count: Int) {
        self.prefetchData(offset: offset, count: count, advice: .willneed)
    }
    
    public func preRead(offset: Int, count: Int) {
        
    }
    
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
extension DataAsClass: OmFileReaderBackend {
    public func preRead(offset: Int, count: Int) {
        
    }
    
    public var count: Int {
        return data.count
    }
    
    public func withUnsafeBytes<ResultType>(_ body: (UnsafeRawBufferPointer) throws -> ResultType) rethrows -> ResultType {
        return try data.withUnsafeBytes(body)
    }
    
    public var needsPrefetch: Bool {
        return false
    }
    
    public func prefetchData(offset: Int, count: Int) {
        
    }
}
