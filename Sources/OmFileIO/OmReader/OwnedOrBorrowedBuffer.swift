import Foundation

/// Read result: owned allocations are released automatically; borrowed cache memory remains unpinned.
enum OwnedOrBorrowedBuffer: ~Copyable, Sendable {
    /// Only usable for a short time. Must not be freed.
    case borrowed(UnsafeRawBufferPointer)

    /// Exclusive ownership of the delivered bytes; the allocation is released on destruction.
    case owned(OwnedRawBuffer)

    /// Borrow either result synchronously without copying bytes. The pointer must not escape. O(1).
    borrowing func withUnsafeBytes<T>(_ body: (UnsafeRawBufferPointer) throws -> T) rethrows -> T {
        switch self {
        case .borrowed(let buffer): return try body(buffer)
        case .owned(let buffer): return try buffer.withUnsafeBytes(body)
        }
    }

    /// Copy borrowed bytes or transfer an owned allocation to Foundation.
    /// O(n) time and additional storage for n borrowed bytes; O(1) for an owned allocation.
    consuming func intoData() -> Data {
        switch consume self {
        case .borrowed(let buffer): return Data(buffer)
        case .owned(let buffer): return buffer.intoData()
        }
    }
}

/// Exclusive ownership of a raw allocation. Moving this value transfers ownership without copying bytes.
struct OwnedRawBuffer: ~Copyable, Sendable {
    private let buffer: UnsafeRawBufferPointer

    /// Take ownership of an allocation that must be deallocated exactly once. O(1).
    init(_ buffer: UnsafeRawBufferPointer) {
        self.buffer = buffer
    }

    deinit {
        buffer.deallocate()
    }

    /// Borrow bytes synchronously; the pointer must not escape the closure. O(1).
    borrowing func withUnsafeBytes<T>(_ body: (UnsafeRawBufferPointer) throws -> T) rethrows -> T {
        try body(buffer)
    }

    /// Transfer the allocation to Foundation, exposing only the delivered bytes without copying. O(1).
    consuming func intoData() -> Data {
        guard let baseAddress = buffer.baseAddress else {
            discard self
            return Data()
        }
        let data = Data(bytesNoCopy: UnsafeMutableRawPointer(mutating: baseAddress), count: buffer.count, deallocator: .free)
        discard self // Foundation now frees the allocation.
        return data
    }
}
