import Foundation
import OmFileFormat
import Synchronization

extension MmapFile: @unchecked @retroactive Sendable {
    
}

public protocol BlockCacheStorable: Sendable {
    var count: Int { get }
    func withMutableUnsafeBytes<R>(_ body: (UnsafeMutableRawBufferPointer) throws -> R) rethrows -> R
    func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R
}

extension MmapFile: BlockCacheStorable {
    public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
        return try data.withUnsafeBytes(body)
    }
    public func withMutableUnsafeBytes<R>(_ body: (UnsafeMutableRawBufferPointer) throws -> R) rethrows -> R {
        return try data.withUnsafeBytes {
            return try body(.init(mutating: $0))
        }
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
public struct MmapBlockCache<Backend: BlockCacheStorable>: Sendable {
    let data: Backend
    let blockSize: Int
    
    var blockCount: Int {
        return data.count / (blockSize + MemoryLayout<WordPair>.size)
    }
    
    func set<DataIn: ContiguousBytes & Sendable>(key: UInt64, value: DataIn) {
        let time = UInt(Date().timeIntervalSince1970 * 1_000_000_000)
        /// For in-flight requests set bit 0 to zero
        let inFlightKey = WordPair(first: UInt(key), second: time & ~0x1)
        /// For committed requests set bit 0 to zero
        let committedKey = WordPair(first: UInt(key), second: time | 0x1)
        /// The maximum number of slots to check for an empty space. Afterwards use LRU
        let lookAheadCount: UInt64 = 1024
        let blockCount = blockCount
        data.withUnsafeBytes { bytes in
            bytes.withMemoryRebound(to: Atomic<WordPair>.self) { entries in
                let hash = key % UInt64(blockCount)
                for slot in hash ..< hash + lookAheadCount {
                    let slot = slot % UInt64(blockCount)
                    while true {
                        let entry = entries[Int(slot)].load(ordering: .relaxed)
                        guard entry.second == 0 || entry.first == key else {
                            break
                        }
                        guard entries[Int(slot)].compareExchange(expected: entry, desired: inFlightKey, ordering: .relaxed).exchanged else {
                            // another thread stole the slot
                            continue
                        }
                        let dest = bytes.baseAddress?.advanced(by: blockCount * MemoryLayout<WordPair>.size + blockSize * Int(slot))
                        value.withUnsafeBytes {
                            let destBuffer = UnsafeMutableRawBufferPointer(start: UnsafeMutableRawPointer(mutating: dest), count: $0.count)
                            $0.copyBytes(to: destBuffer)
                        }
                        guard entries[Int(slot)].compareExchange(expected: inFlightKey, desired: committedKey, ordering: .relaxed).exchanged else {
                            // another thread stole the slot
                            continue
                        }
                        return
                    }
                }
                // If we are here, no slots were free. Search lowest timestamp and overwrite this slot
                // Remember that other threads might do the same at the same time
                while true {
                    var overwriteEntry = WordPair(first: 0, second: UInt.max)
                    var overwritePos: Int = -1
                    for slot in hash ..< hash + lookAheadCount {
                        let slot = slot % UInt64(blockCount)
                        let entry = entries[Int(slot)].load(ordering: .relaxed)
                        if entry.second < overwriteEntry.second {
                            overwriteEntry = entry
                            overwritePos = Int(slot)
                        }
                    }
                    guard entries[overwritePos].compareExchange(expected: overwriteEntry, desired: inFlightKey, ordering: .relaxed).exchanged else {
                        // another thread stole the slot
                        continue
                    }
                    let dest = bytes.baseAddress!.advanced(by: blockCount * MemoryLayout<WordPair>.size + blockSize * Int(overwritePos))
                    value.withUnsafeBytes {
                        let destBuffer = UnsafeMutableRawBufferPointer(start: UnsafeMutableRawPointer(mutating: dest), count: $0.count)
                        $0.copyBytes(to: destBuffer)
                    }
                    guard entries[overwritePos].compareExchange(expected: inFlightKey, desired: committedKey, ordering: .relaxed).exchanged else {
                        // another thread stole the slot
                        continue
                    }
                    return
                }
            }
        }
    }
    
    /// Find key in cache and return data. Updates the LRU timestamp.
    func get(key: UInt64) -> UnsafeRawBufferPointer? {
        let time = UInt(Date().timeIntervalSince1970 * 1_000_000_000)
        let lookAheadCount: UInt64 = 1024
        let blockCount = blockCount
        return data.withUnsafeBytes { bytes in
            return bytes.withMemoryRebound(to: Atomic<WordPair>.self) { entries in
                let hash = key % UInt64(blockCount)
                for slot in hash ..< hash + lookAheadCount {
                    let slot = slot % UInt64(blockCount)
                    while true {
                        let entry = entries[Int(slot)].load(ordering: .relaxed)
                        // check if keys match
                        // ignore any entries that are being modified right now
                        guard entry.first == key && entry.second & 0x1 == 1 else {
                            break
                        }
                        let updateTimestamp = WordPair(first: UInt(key), second: time | 0x1)
                        guard entries[Int(slot)].compareExchange(expected: entry, desired: updateTimestamp, ordering: .relaxed).exchanged else {
                            // another thread just updated the timestamp, or the key was changed
                            continue
                        }
                        let dest = bytes.baseAddress!.advanced(by: blockCount * MemoryLayout<WordPair>.size + blockSize * Int(slot))
                        return UnsafeRawBufferPointer(start: dest, count: blockSize)
                    }
                }
                return nil
            }
        }
    }
}


extension MmapBlockCache where Backend == MmapFile {
    init(file: String, blockSize: Int, blockCount: Int) throws {
        let fn: FileHandle
        let size = (MemoryLayout<WordPair>.size + blockSize) * blockCount
        if FileManager.default.fileExists(atPath: file) {
            fn = try .openFileReadWrite(file: file)
            guard try fn.seekToEnd() == size else {
                fatalError()
            }
        } else {
            fn = try .createNewFile(file: file, size: size, overwrite: false)
        }
        self = .init(data: try MmapFile(fn: fn, mode: .readWrite), blockSize: blockSize)
    }
}

extension UnsafeRawBufferPointer {
    var data: Data {
        return Data(self)
    }
}
