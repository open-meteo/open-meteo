//
//  OmWriteBuffer.swift
//  OpenMeteoApi
//
//  Created by Patrick Zippenfenig on 30.10.2024.
//

import Foundation

/// All data is written to this buffer. It needs to be emptied periodically after writing large chunks of data.
public final class OmWriteBuffer {
    /// All data is written to this buffer. The current offset is in `writeBufferPos`. This buffer must be written out before it is full.
    public var buffer: UnsafeMutableRawBufferPointer
        
    public var writePosition = UInt64(0)
    
    public var totalBytesWritten = UInt64(0)
    
    public init(capacity: UInt64) {
        self.writePosition = 0
        self.totalBytesWritten = 0
        self.buffer = .allocate(byteCount: Int(capacity), alignment: 1)
    }
    
    func incrementWritePosition(by bytes: UInt64) {
        writePosition += bytes
        totalBytesWritten += bytes
    }
    
    func resetWritePosition() {
        writePosition = 0
    }
    
    /// How many bytes are left in the write buffer
    var remainingCapacity: UInt64 {
        return UInt64(buffer.count) - (writePosition)
    }
    
    /// A pointer to the current write position
    var bufferAtWritePosition: UnsafeMutableRawPointer {
        return buffer.baseAddress!.advanced(by: Int(writePosition))
    }
    
    /// Ensure the buffer has at least a minimum capacity
    public func reallocate(minimumCapacity: UInt64) {
        if remainingCapacity >= minimumCapacity {
            return
        }
        buffer = UnsafeMutableRawBufferPointer(start: realloc(buffer.baseAddress, Int(minimumCapacity)), count: Int(minimumCapacity))
    }
    
    /// Write buffer to file
    public func writeToFile<FileHandle: OmFileWriterBackend>(fn: FileHandle) throws {
        let readableBytes = UnsafeRawBufferPointer(start: buffer.baseAddress, count: Int(writePosition))
        try fn.write(contentsOf: readableBytes)
        resetWritePosition()
    }
    
    deinit {
        buffer.deallocate()
    }
}
