import Foundation
import Lbzip2
import NIOCore

//
//final class Bz2Decoder {
//    var decoder = decoder_state()
//    let headerCrc: UInt32
//    let bs100k: Int32
//    
//    public init(headerCrc: UInt32, bs100k: Int32) {
//        decoder_init(&decoder)
//        self.headerCrc = headerCrc
//        self.bs100k = bs100k
//    }
//    
//    func decode() {
//        // Decode can now run in a different thread
//        // Decoder does not need buffered input data anymore
//        Lbzip2.decode(&decoder)
//    }
//    
//    func emit() throws -> ByteBuffer {
//        var out = ByteBuffer()
//        // Reserve the maximum output block size
//        out.writeWithUnsafeMutableBytes(minimumWritableBytes: Int(bs100k*100_000)) { ptr in
//            var outsize: Int = ptr.count
//            guard Lbzip2.emit(&decoder, ptr.baseAddress, &outsize) == Lbzip2.OK.rawValue else {
//                // Emit should not fail because enough output capacity is available
//                fatalError("emit failed")
//            }
//            return ptr.count - outsize
//        }
//        guard decoder.crc == headerCrc else {
//            throw SwiftParallelBzip2Error.blockCRCMismatch
//        }
//        //print("emit \(out.readableBytes) bytes")
//        return out
//    }
//    
//    deinit {
//        decoder_free(&decoder)
//    }
//}

//extension decoder_state: @retroactive @unchecked Sendable {
//    
//}

extension Bzip2AsyncStream.AsyncIterator {
    func parseFileHeader() async throws -> Int32 {

    }
    
    /// Return true until all data is available
    func retrieve(decoder: UnsafeMutablePointer<decoder_state>) async throws -> Bool {
        let ret = buffer.readWithUnsafeReadableBytes { ptr in
            bitstream.pointee.data = ptr.baseAddress?.assumingMemoryBound(to: UInt32.self)
            bitstream.pointee.limit = ptr.baseAddress?.advanced(by: ptr.count).assumingMemoryBound(to: UInt32.self)
            //print("Bitstream IN \(bitstream.data!) \(bitstream.limit!)")
            let ret = Lbzip2.error(rawValue: UInt32(Lbzip2.retrieve(decoder, bitstream)))
            assert(bitstream.pointee.data <= bitstream.pointee.limit)
            //print("Bitstream OUT \(bitstream.data!) \(bitstream.limit!)")
            let bytesRead = ptr.baseAddress?.distance(to: UnsafeRawPointer(bitstream.pointee.data)) ?? 0
            //print("retrieve bytesRead \(bytesRead) ret=\(ret)")
            return (bytesRead, ret)
        }
        switch ret {
        case Lbzip2.OK:
            return false
        case Lbzip2.MORE:
            return true
        default:
            throw SwiftParallelBzip2Error.unexpectedDecoderError(ret.rawValue)
        }
    }
    
    func parse(parser: UnsafeMutablePointer<parser_state>)async throws -> UInt32? {
        /* Parse stream headers until a compressed block or end of stream is reached.

           Possible return codes:
             OK          - a compressed block was found
             FINISH      - end of stream was reached
             MORE        - more input is need, parsing was suspended
             ERR_HEADER  - invalid stream header
             ERR_STRMCRC - stream CRC does not match
             ERR_EOF     - unterminated stream (EOF reached before end of stream)

           garbage is set only when returning FINISH.  It is number of garbage bits
           consumed after end of stream was reached.
        */
        while true {
            var header = header()
            parserLoop: while true {
                let parserReturn = buffer.readWithUnsafeReadableBytes { ptr in
                    bitstream.pointee.data = ptr.baseAddress?.assumingMemoryBound(to: UInt32.self)
                    bitstream.pointee.limit = ptr.baseAddress?.advanced(by: ptr.count).assumingMemoryBound(to: UInt32.self)
                    var garbage: UInt32 = 0
                    let ret = Lbzip2.error(rawValue: UInt32(Lbzip2.parse(parser, &header, bitstream, &garbage)))
                    assert(garbage < 32)
                    assert(bitstream.pointee.data <= bitstream.pointee.limit)
                    let bytesRead = ptr.baseAddress?.distance(to: UnsafeRawPointer(bitstream.pointee.data)) ?? 0
                    //print("parser bytesRead \(bytesRead)")
                    return (bytesRead, ret)
                }
                switch parserReturn {
                case OK:
                    return header.crc
                case FINISH:
                    return nil
                case MORE:
                    try await more()
                    continue
                case ERR_HEADER:
                    throw SwiftParallelBzip2Error.invalidStreamHeader
                case ERR_STRMCRC:
                    throw SwiftParallelBzip2Error.streamCRCMismatch
                case ERR_EOF:
                    throw SwiftParallelBzip2Error.streamCRCMismatch
                default:
                    throw SwiftParallelBzip2Error.unexpectedParserError(parserReturn.rawValue)
                }
            }
        }
    }
}
