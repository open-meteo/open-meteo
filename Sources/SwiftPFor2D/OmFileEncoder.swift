@_implementationOnly import CTurboPFor
@_implementationOnly import CHelper
import Foundation

/// Write an om file and write multiple chunks of data
public final class OmFileEncoder {
    /// The scalefactor that is applied to all write data
    public let scalefactor: Float
    
    /// Type of compression and coding. E.g. delta, zigzag coding is then implemented in different compression routines
    public let compression: CompressionType
    
    /// The dimensions of the file
    let dims: [Int]
    
    /// How the dimensions are chunked
    let chunks: [Int]
    
    
    /// Store all byte offsets where our compressed chunks start. Later, we want to decompress chunk 1234 and know it starts at byte offset 5346545
    private var chunkOffsetBytes: [Int]
    
    /// Buffer where chunks are moved to, before compression them. => input for compression call
    private var readBuffer: UnsafeMutableRawBufferPointer
    
    /// All data is written to this buffer. The current offset is in `writeBufferPos`. This buffer must be written out before it is full.
    private var writeBuffer: UnsafeMutableBufferPointer<UInt8>
        
    public var writeBufferPos = 0
    
    public var totalBytesWritten = 0
    
    /// Position of last chunk that has been written
    public var c0: Int = 0

    
    /// Return the total number of chunks in this file
    func number_of_chunks() -> Int {
        var n = 1
        for i in 0..<dims.count {
            n *= dims[i].divideRoundedUp(divisor: chunks[i])
        }
        return n
    }
    
    
    /**
     Write new or overwrite new compressed file. Data must be supplied with a closure which supplies the current position in dimension 0. Typically this is the location offset. The closure must return either an even number of elements of `chunk0 * dim1` elements or all remainig elements at once.
     
     One chunk should be around 2'000 to 16'000 elements. Fewer or more are not usefull!
     
     Note: `chunk0` can be a uneven multiple of `dim0`. E.g. for 10 location, we can use chunks of 3, so the last chunk will only cover 1 location.
     */
    public init(dimensions: [Int], chunkDimensions: [Int], compression: CompressionType, scalefactor: Float) throws {
        var nChunks = 1
        for i in 0..<dimensions.count {
            nChunks *= dimensions[i].divideRoundedUp(divisor: chunkDimensions[i])
        }
        
        let chunkSizeByte = chunkDimensions.reduce(1, *) * 4
        if chunkSizeByte > 1024 * 1024 * 4 {
            print("WARNING: Chunk size greater than 4 MB (\(Float(chunkSizeByte) / 1024 / 1024) MB)!")
        }
        
        self.chunkOffsetBytes = .init(repeating: 0, count: nChunks)
        self.dims = dimensions
        self.chunks = chunkDimensions
        self.scalefactor = scalefactor
        self.compression = compression
        
        let bufferSize = P4NENC256_BOUND(n: chunkDimensions.reduce(1, *), bytesPerElement: 4)
        
        // Read buffer needs to be a bit larger for AVX 256 bit alignment
        self.readBuffer = UnsafeMutableRawBufferPointer.allocate(byteCount: bufferSize, alignment: 4)
        self.writeBuffer = .allocate(capacity: max(1024 * 1024, bufferSize))
    }
    
    public func write(array: [Float], fn: FileHandle) {
        // write header
        
        // loop over all chunks
        //   extract chunk from array and write in temporary array
        //   compress and write chunk
        
        // write LUT
        // write trailer
    }
    
    /// Data must be exactly of the size of the next chunk!
    public func writeNextChunk(data: [Float]) {
        
    }
    
    deinit {
        readBuffer.deallocate()
        writeBuffer.deallocate()
    }
    
    /// Write header, return `nil` if the buffer is too small, otherwise returns bytes written.
    public func writeHeader() throws -> Int? {
        guard writeBuffer.count - writeBufferPos >= 3 else {
            return nil
        }
        writeBuffer[writeBufferPos + 0] = OmHeader.magicNumber1
        writeBuffer[writeBufferPos + 1] = OmHeader.magicNumber2
        writeBuffer[writeBufferPos + 2] = 3
        return 3
    }
}

