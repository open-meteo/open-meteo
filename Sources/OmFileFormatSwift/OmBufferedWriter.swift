//
//  OmBufferedWriter.swift
//  OpenMeteoApi
//
//  Created by Patrick Zippenfenig on 30.10.2024.
//

import Foundation

/// All data is written to a buffer before flushed to a backend
public final class OmBufferedWriter<FileHandle: OmFileWriterBackend> {
    /// All data is written to this buffer. The current offset is in `writeBufferPos`. This buffer must be written out before it is full.
    public var buffer: UnsafeMutableRawBufferPointer
    
    /// The final backing store to write data to
    public var backend: FileHandle
        
    public var writePosition: Int
    
    public var totalBytesWritten: Int
    
    private var initialCapacity: Int
    
    public init(backend: FileHandle, initialCapacity: Int = 1024) {
        self.writePosition = 0
        self.totalBytesWritten = 0
        self.backend = backend
        self.buffer = .allocate(byteCount: initialCapacity, alignment: 1)
        buffer.initializeMemory(as: UInt8.self, repeating: 0)
        self.initialCapacity = initialCapacity
    }
    
    func incrementWritePosition(by bytes: Int) {
        writePosition += bytes
        totalBytesWritten += bytes
    }
    
    func resetWritePosition() {
        writePosition = 0
    }
    
    /// Add empty space if required to align to 64 bits
    func alignTo64Bytes() throws {
        let bytesToPadd = 8 - totalBytesWritten % 8
        if bytesToPadd == 0 {
            return
        }
        try reallocate(minimumCapacity: bytesToPadd)
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
    
    /// Ensure the buffer has at least a minimum capacity. Write to backend if too much data is in the buffer
    public func reallocate(minimumCapacity: Int) throws {
        if remainingCapacity >= minimumCapacity {
            return // enough remaining space
        }
        try writeToFile()
        if buffer.count >= minimumCapacity {
            return // enugh space in buffer
        }
        // Need to grow buffer to a multiple of the initial capacity
        let newCapacity = minimumCapacity.divideRoundedUp(divisor: initialCapacity) * initialCapacity
        buffer = UnsafeMutableRawBufferPointer(start: realloc(buffer.baseAddress, newCapacity), count: newCapacity)
        bufferAtWritePosition.initializeMemory(as: UInt8.self, repeating: 0, count: remainingCapacity)
    }
    
    /// Write buffer to file
    public func writeToFile() throws {
        let readableBytes = UnsafeRawBufferPointer(start: buffer.baseAddress, count: writePosition)
        try backend.write(contentsOf: readableBytes)
        resetWritePosition()
        // zero fill buffer
        bufferAtWritePosition.initializeMemory(as: UInt8.self, repeating: 0, count: readableBytes.count)
    }
    
    deinit {
        buffer.deallocate()
    }
}
