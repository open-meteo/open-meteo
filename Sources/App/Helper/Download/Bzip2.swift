import Foundation
import NIO
//import CBz2lib
import AsyncAlgorithms
import SwiftParallelBzip2

extension AsyncSequence where Element == ByteBuffer, Self: Sendable {
    /// Decompress incoming data using bzip2. Processing takes place in detached task
    func decompressBzip2() -> Bzip2AsyncStream<Self> {
        return self.decodeBzip2()
    }
}
