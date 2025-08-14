extension String {
    /// Get FNV hash of the string
    public var fnv1aHash64: UInt64 {
        return UInt64.fnvOffsetBasis.addFnv1aHash(self)
    }
}

extension UInt64 {
    public static let fnvPrime: UInt64 = 0x100000001b3
    public static let fnvOffsetBasis: UInt64 = 0xcbf29ce484222325
    
    /// If self is a FNV hash, hash another number into it
    @inlinable public func addFnv1aHash(_ other: UInt64) -> UInt64 {
        return (self ^ other) &* Self.fnvPrime
    }
    
    /// If self is a FNV hash, hash another string into it
    public func addFnv1aHash(_ other: String) -> UInt64 {
        return other.withContiguousStorageIfAvailable({ ptr in
            var hash = self
            for byte in UnsafeRawBufferPointer(ptr) {
                hash = hash.addFnv1aHash(UInt64(byte))
            }
            return hash
        }) ?? {
            var hash = self
            for byte in other.utf8 {
                hash = hash.addFnv1aHash(UInt64(byte))
            }
            return hash
        }()
    }
}
