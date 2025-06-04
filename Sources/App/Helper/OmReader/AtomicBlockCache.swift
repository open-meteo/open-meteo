import Foundation
import OmFileFormat
import Synchronization

/**
 Needs to be some kind of writeable memory region
 */
public protocol AtomicBlockCacheStorable: Sendable {
    var count: Int { get }
    func withMutableUnsafeBytes<R>(_ body: (UnsafeMutableRawBufferPointer) throws -> R) rethrows -> R
    func prefetchData(offset: Int, count: Int)
}

extension MmapFile: AtomicBlockCacheStorable {
    public func prefetchData(offset: Int, count: Int) {
        self.prefetchData(offset: offset, count: count, advice: .willneed)
    }
    
    public func withMutableUnsafeBytes<R>(_ body: (UnsafeMutableRawBufferPointer) throws -> R) rethrows -> R {
        return try data.withUnsafeBytes {
            return try body(.init(mutating: $0))
        }
    }
}

extension DataAsClass: AtomicBlockCacheStorable {
    public func prefetchData(offset: Int, count: Int) {
        // Not necessary
    }
    
    public func withMutableUnsafeBytes<R>(_ body: (UnsafeMutableRawBufferPointer) throws -> R) rethrows -> R {
        try data.withUnsafeMutableBytes(body)
    }
}

extension AtomicBlockCache where Backend == MmapFile {
    init(file: String, blockSize: Int, blockCount: Int) throws {
        let size = (MemoryLayout<WordPair>.size + blockSize) * blockCount
        if FileManager.default.fileExists(atPath: file) {
            let fn = try FileHandle.openFileReadWrite(file: file)
            if try fn.seekToEnd() == size {
                self = .init(data: try MmapFile(fn: fn, mode: .readWrite), blockSize: blockSize)
                return
            }
        }
        let fn = try FileHandle.createNewFile(file: file, size: size, overwrite: true)
        self = .init(data: try MmapFile(fn: fn, mode: .readWrite), blockSize: blockSize)
    }
}


/**
 Key-value cache for fixed block sizes and a fixed amount of blocks. Uses a hash map with LRU strategy.
 The entire cache size is preallocated. Due to the fixed number of elements, the hash map does not need rebalancing
 
 Uses Atomics for thread safety. The beginning of the cache contains N key entries. Each key entry is the 64 bit key and a 64 bit timestamp in nanoseconds.
 
 The data block contains than N block of `blockSize` length. Key entries and data blocks are allocated as a file and mmaped
 
 Basic principle here https://gist.github.com/glampert/2c462bcc77d326526787708c0f2cceff
 
 N * 128 bit for keys and timestamps. Timestamp of 0 means empty
 N * M for data
 */
public struct AtomicBlockCache<Backend: AtomicBlockCacheStorable>: Sendable {
    let data: Backend
    let blockSize: Int
    
    var blockCount: Int {
        return data.count / (blockSize + MemoryLayout<WordPair>.size)
    }
    
    @discardableResult
    func set<DataIn: ContiguousBytes & Sendable>(key: UInt64, value: DataIn) -> UnsafeRawBufferPointer {
        let time = UInt(Date().timeIntervalSince1970 * 1_000_000_000)
        /// For in-flight requests set bit 0 to zero
        let inFlightKey = WordPair(first: UInt(key), second: time & ~0x1)
        /// For committed requests set bit 0 to zero
        let committedKey = WordPair(first: UInt(key), second: time | 0x1)
        /// The maximum number of slots to check for an empty space. Afterwards overwrite LRU value
        let lookAheadCount: UInt64 = 1024
        let blockCount = blockCount
        return data.withMutableUnsafeBytes { bytes in
            let entries = bytes.assumingMemoryBound(to: Atomic<WordPair>.self)
            for lookAhead in 0..<lookAheadCount {
                let slot = Int((key &+ lookAhead) % UInt64(blockCount))
                while true {
                    let entry = entries[slot].load(ordering: .relaxed)
                    guard entry.second == 0 || entry.first == key else {
                        break
                    }
                    guard entries[slot].compareExchange(expected: entry, desired: inFlightKey, ordering: .relaxed).exchanged else {
                        continue // another thread stole the slot
                    }
                    let dest = bytes.baseAddress?.advanced(by: blockCount * MemoryLayout<WordPair>.size + blockSize * slot)
                    value.withUnsafeBytes {
                        let destBuffer = UnsafeMutableRawBufferPointer(start: UnsafeMutableRawPointer(mutating: dest), count: $0.count)
                        $0.copyBytes(to: destBuffer)
                    }
                    guard entries[slot].compareExchange(expected: inFlightKey, desired: committedKey, ordering: .relaxed).exchanged else {
                        continue // another thread stole the slot
                    }
                    return UnsafeRawBufferPointer(start: dest, count: blockSize)
                }
            }
            // If we are here, no slots were free. Search lowest timestamp and overwrite this slot
            // Remember that other threads might do the same at the same time
            while true {
                let (slot, entry) = (0..<lookAheadCount).reduce((0, WordPair(first: 0, second: UInt.max)), { (compare, lookAhead) in
                    let slot = Int((key &+ lookAhead) % UInt64(blockCount))
                    let entry = entries[slot].load(ordering: .relaxed)
                    return entry.second < compare.1.second ? (slot,entry) : compare
                })
                guard entries[slot].compareExchange(expected: entry, desired: inFlightKey, ordering: .relaxed).exchanged else {
                    continue // another thread stole the slot
                }
                let dest = bytes.baseAddress?.advanced(by: blockCount * MemoryLayout<WordPair>.size + blockSize * slot)
                value.withUnsafeBytes {
                    let destBuffer = UnsafeMutableRawBufferPointer(start: UnsafeMutableRawPointer(mutating: dest), count: $0.count)
                    $0.copyBytes(to: destBuffer)
                }
                guard entries[slot].compareExchange(expected: inFlightKey, desired: committedKey, ordering: .relaxed).exchanged else {
                    continue // another thread stole the slot
                }
                return UnsafeRawBufferPointer(start: dest, count: blockSize)
            }
        }
    }
    
    /// Prefetch data
    func prefetch(key: UInt64) {
        let lookAheadCount: UInt64 = 1024
        let blockCount = blockCount
        data.withMutableUnsafeBytes { bytes in
            let entries = bytes.assumingMemoryBound(to: Atomic<WordPair>.self)
            for lookAhead in 0..<lookAheadCount {
                let slot = (key &+ lookAhead) % UInt64(blockCount)
                while true {
                    let entry = entries[Int(slot)].load(ordering: .relaxed)
                    // check if keys match
                    // ignore any entries that are being modified right now
                    guard entry.first == key && entry.second & 0x1 == 1 else {
                        break
                    }
                    let offset = blockCount * MemoryLayout<WordPair>.size + blockSize * Int(slot)
                    data.prefetchData(offset: offset, count: blockSize)
                    return
                }
            }
        }
    }
    
    /// Find key in cache, updates the LRU timestamp and returns a pointer to the memory region. There is a slight chance, that data is modified while reading, but it should practically never happen
    func get(key: UInt64) -> UnsafeRawBufferPointer? {
        let time = UInt(Date().timeIntervalSince1970 * 1_000_000_000)
        let lookAheadCount: UInt64 = 1024
        let blockCount = blockCount
        return data.withMutableUnsafeBytes { bytes in
            let entries = bytes.assumingMemoryBound(to: Atomic<WordPair>.self)
            for lookAhead in 0..<lookAheadCount {
                let slot = Int((key &+ lookAhead) % UInt64(blockCount))
                while true {
                    let entry = entries[slot].load(ordering: .relaxed)
                    // check if keys match
                    // ignore any entries that are being modified right now
                    guard entry.first == key && entry.second & 0x1 == 1 else {
                        break
                    }
                    // Update last modified timestamp
                    let updateTimestamp = WordPair(first: UInt(key), second: time | 0x1)
                    let updated = entries[slot].compareExchange(expected: entry, desired: updateTimestamp, ordering: .relaxed)
                    guard updated.exchanged || (updated.original.first == key && updated.original.second & 0x1 == 1 ) else {
                        // Another thread changed the key or started an update
                        continue
                    }
                    
                    // Get data pointer and execute closure on data
                    // There is a slight chance, that data is modified while reading, but it should practically never happen
                    let dest = bytes.baseAddress?.advanced(by: blockCount * MemoryLayout<WordPair>.size + blockSize * slot)
                    return UnsafeRawBufferPointer(start: dest, count: blockSize)
                }
            }
            return nil
        }
    }
    
    /// Return if all keys are available sequentially in the cache
    func get(key: UInt64, count: UInt64) -> UnsafeRawBufferPointer? {
        let time = UInt(Date().timeIntervalSince1970 * 1_000_000_000)
        let lookAheadCount: UInt64 = 1024
        let blockCount = blockCount
        return data.withMutableUnsafeBytes { bytes in
            let entries = bytes.assumingMemoryBound(to: Atomic<WordPair>.self)
            outer: for lookAhead in 0..<lookAheadCount {
                let slot = UInt64(key &+ lookAhead) % UInt64(blockCount)
                if slot + count > blockCount {
                    continue // Key range would hit the end of the cache block
                }
                for i in 0..<count {
                    let slot = Int((slot &+ i) % UInt64(blockCount))
                    let key = (key &+ UInt64(i))
                    while true {
                        let entry = entries[slot].load(ordering: .relaxed)
                        // check if keys match
                        // ignore any entries that are being modified right now
                        guard entry.first == key && entry.second & 0x1 == 1 else {
                            continue outer
                        }
                        // Update last modified timestamp
                        let updateTimestamp = WordPair(first: UInt(key), second: time | 0x1)
                        let updated = entries[slot].compareExchange(expected: entry, desired: updateTimestamp, ordering: .relaxed)
                        guard updated.exchanged || (updated.original.first == key && updated.original.second & 0x1 == 1 ) else {
                            // Another thread changed the key or started an update
                            continue
                        }
                        // Slot ok
                        break
                    }
                }
                // Get data pointer and execute closure on data
                // There is a slight chance, that data is modified while reading, but it should practically never happen
                let dest = bytes.baseAddress?.advanced(by: blockCount * MemoryLayout<WordPair>.size + blockSize * Int(slot))
                return UnsafeRawBufferPointer(start: dest, count: blockSize * Int(count))
            }
            return nil
        }
    }
}

extension UnsafeRawBufferPointer {
    /// Copy pointer to new Data
    var data: Data {
        return Data(self)
    }
}
