import Foundation
import OmFileFormat
import Synchronization

extension MmapFile: @unchecked @retroactive Sendable {
    
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
final class MmapBlockCache: KVCache {
    let mmap: MmapFile
    let blockSize: Int
    let blockCount: Int
    
    init(file: String, blockSize: Int, blockCount: Int) throws {
        let fn: FileHandle
        let size = (8 + 8 + blockSize) * blockCount
        if FileManager.default.fileExists(atPath: file) {
            fn = try .openFileReading(file: file)
            guard try fn.seekToEnd() == size else {
                fatalError()
            }
        } else {
            fn = try .createNewFile(file: file, size: size, overwrite: false)
        }
        self.mmap = try MmapFile(fn: fn, mode: .readWrite)
        self.blockCount = blockCount
        self.blockSize = blockSize
    }
    
    func set(key: Int, value: Data) {
        let time = UInt(Date().timeIntervalSince1970 * 1_000_000_000)
        /// For in-flight requests set bit 0 to zero
        let inFlightkey = WordPair(first: UInt(key), second: time & 0xFFFFFFFFFFFFFFFE)
        /// For commired requests set bit 0 to zero
        let commitedkey = WordPair(first: UInt(key), second: time | 0x1)
        /// The maximum number of slots to check for an empty space. Afterwards use LRU
        let lookAheadCount = 1024
        mmap.data.withMemoryRebound(to: Atomic<WordPair>.self) { keys in
            let hash = key % blockCount
            for slot in hash ..< hash + lookAheadCount {
                let slot = slot % blockCount
                let keyInSlot = keys[slot].load(ordering: .relaxed)
                guard keyInSlot.second == 0 || keyInSlot.first == key else {
                    continue
                }
                // take slot using CAS
                guard keys[slot].compareExchange(expected: keyInSlot, desired: inFlightkey, ordering: .relaxed).exchanged else {
                    // another thread stole the slot
                    continue
                }
                let dest = mmap.data.baseAddress!.advanced(by: blockCount * MemoryLayout<WordPair>.size + blockSize * Int(slot))
                value.copyBytes(to: UnsafeMutablePointer(mutating: dest), count: value.count)
                guard keys[slot].compareExchange(expected: inFlightkey, desired: commitedkey, ordering: .relaxed).exchanged else {
                    // another thread stole the slot
                    continue
                }
                return
            }
            
            // If we are here, no slots were free. Search lowest timestamp and overwrite this slot
            // Remember that other threads might do the same at the same time
            while true {
                var overwriteKey = WordPair(first: 0, second: UInt.max)
                var overwritePos: Int = -1
                for slot in hash ..< hash + lookAheadCount {
                    let slot = slot % blockCount
                    let keyInSlot = keys[slot].load(ordering: .relaxed)
                    if keyInSlot.second < overwriteKey.second {
                        overwriteKey = keyInSlot
                        overwritePos = slot
                    }
                }
                // take slot using CAS
                guard keys[overwritePos].compareExchange(expected: overwriteKey, desired: inFlightkey, ordering: .relaxed).exchanged else {
                    // another thread stole the slot
                    continue
                }
                let dest = mmap.data.baseAddress!.advanced(by: blockCount * MemoryLayout<WordPair>.size + blockSize * Int(overwritePos))
                value.copyBytes(to: UnsafeMutablePointer(mutating: dest), count: value.count)
                guard keys[overwritePos].compareExchange(expected: inFlightkey, desired: commitedkey, ordering: .relaxed).exchanged else {
                    // another thread stole the slot
                    continue
                }
                return
            }
        }
    }
    
    func get(key: Int) -> Data? {
        // find key
        // check LRU for inflight bit
        // increment LRU
        // return data pointer
        
        fatalError()
    }
    
    
}
