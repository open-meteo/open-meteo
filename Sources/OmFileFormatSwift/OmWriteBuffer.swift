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
        
    public var writePosition: Int
    
    public var totalBytesWritten: Int
    
    public init(capacity: Int) {
        self.writePosition = 0
        self.totalBytesWritten = 0
        self.buffer = .allocate(byteCount: capacity, alignment: 1)
    }
    
    func incrementWritePosition(by bytes: Int) {
        writePosition += bytes
        totalBytesWritten += bytes
    }
    
    func resetWritePosition() {
        writePosition = 0
    }
    
    /// Add empty space if required to align to 64 bits
    func alignTo64Bytes() {
        let bytesToPadd = 8 - totalBytesWritten % 8
        if bytesToPadd == 0 {
            return
        }
        reallocate(minimumCapacity: bytesToPadd)
        bufferAtWritePosition.initializeMemory(as: UInt8.self, repeating: 0, count: bytesToPadd)
        incrementWritePosition(by: bytesToPadd)
    }
    
    /// How many bytes are left in the write buffer
    var remainingCapacity: Int {
        return buffer.count - (writePosition)
    }
    
    /// A pointer to the current write position
    var bufferAtWritePosition: UnsafeMutableRawPointer {
        return buffer.baseAddress!.advanced(by: writePosition)
    }
    
    /// Ensure the buffer has at least a minimum capacity
    public func reallocate(minimumCapacity: Int) {
        if remainingCapacity >= minimumCapacity {
            return
        }
        buffer = UnsafeMutableRawBufferPointer(start: realloc(buffer.baseAddress, minimumCapacity), count: minimumCapacity)
    }
    
    /// Write buffer to file
    public func writeToFile<FileHandle: OmFileWriterBackend>(fn: FileHandle) throws {
        let readableBytes = UnsafeRawBufferPointer(start: buffer.baseAddress, count: writePosition)
        try fn.write(contentsOf: readableBytes)
        resetWritePosition()
    }
    
    deinit {
        buffer.deallocate()
    }
}
