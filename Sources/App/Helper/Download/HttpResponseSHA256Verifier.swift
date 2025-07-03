import NIOCore
import Crypto

enum HttpResponseSHA256VerifierError: Error {
    case checksumMismatch
}

extension AsyncSequence where Element == ByteBuffer {
    /// Check the checksum of a byte stream. Throw at the end of the stream. If no checksum is provided, do nothing
    func sha256verify(_ checksum: String?) -> HttpResponseSHA256Verifier<Self> {
        return HttpResponseSHA256Verifier(sequence: self, checksum: checksum)
    }
}

/// Check the checksum of a byte stream. Throw at the end of the stream. If no checksum is provided, do nothing
struct HttpResponseSHA256Verifier<T: AsyncSequence>: AsyncSequence where T.Element == ByteBuffer {
    public typealias Element = AsyncIterator.Element

    let sequence: T
    let checksum: String?

    public init(sequence: T, checksum: String?) {
        self.sequence = sequence
        self.checksum = checksum
    }

    public final class AsyncIterator: AsyncIteratorProtocol {
        private let checksum: String?
        private var sha256fn: SHA256 = SHA256.init()
        private var iterator: T.AsyncIterator

        fileprivate init(checksum: String?, iterator: T.AsyncIterator) {
            self.iterator = iterator
            self.checksum = checksum
        }

        public func next() async throws -> ByteBuffer? {
            guard let checksum else {
                return try await self.iterator.next()
            }
            guard let data = try await self.iterator.next() else {
                let expected = sha256fn.finalize().hex
                guard expected == checksum else {
                    throw HttpResponseSHA256VerifierError.checksumMismatch
                }
                return nil
            }
            sha256fn.update(data: data.readableBytesView)
            return data
        }
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(checksum: checksum, iterator: sequence.makeAsyncIterator())
    }
}

fileprivate extension SHA256.Digest {
    var hex: String {
        return map { String(format: "%02x", $0) }.joined()
    }
}
