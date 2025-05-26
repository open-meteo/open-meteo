import Foundation
import OmFileFormat
import Synchronization

extension MmapFile: @unchecked @retroactive Sendable {
    
}

/**
 Keys and timestemps are used as atomic 64 bit integers
 
 https://gist.github.com/glampert/2c462bcc77d326526787708c0f2cceff
 
 N * 64 bit for keys, 000000 for update bit
 N * 64 bit for last used timestamp
 N * M for data
 */
final class MmapBlockCache: KVCache {
    let mmap: MmapFile
    let blockSize: Int
    let blockCount: Int
    
    init(file: String, blockSize: Int, blockCount: Int) async throws {
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
    
    func set(key: Int, value: Data) async {
        let emptySlot = 0
        let inFlightkey = key &+ 1000000
        // randomise parts?
        let time = Timestamp.now().timeIntervalSince1970
        let a = mmap.data.withMemoryRebound(to: Atomic<Int>.self) { keys in
            let hash = key % blockCount
            for slot in hash ..< hash + 1024 {
                let slot = slot % blockCount
                let keyInSlot = keys[slot].load(ordering: .relaxed)
                guard keyInSlot == emptySlot || keyInSlot == key else {
                    continue
                }
                let timeInSlow = keys[slot + blockCount].load(ordering: .relaxed)
                // take slot using CAS
                let cas = keys[slot].compareExchange(expected: keyInSlot, desired: inFlightkey, ordering: .relaxed)
                guard cas.exchanged else {
                    // another thread stole the slot
                    continue
                }
                // update time using CAS
                let casTime = keys[slot + blockCount].compareExchange(expected: timeInSlow, desired: time, ordering: .relaxed)
                guard casTime.exchanged else {
                    // another thread stole the slot
                    continue
                }
                
                //
            }
            
            //keys[0].compareExchange(expected: <#T##Int#>, desired: <#T##Int#>, ordering: <#T##AtomicUpdateOrdering#>)
            return 1
        }
        
        // find slot within 1k slots, otherwise overwrite lowest LRU, may overweite existing key
        // set key to 0000000
        // set LRU
        // set data
        // set key
    }
    
    func get(key: Int) async -> Data? {
        // find key
        // check LRU for inflight bit
        // increment LRU
        // return data pointer
        
        fatalError()
    }
    
    
}
