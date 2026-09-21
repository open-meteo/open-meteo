import Foundation

/// Invalid artifact input or layout. Filesystem failures are propagated as their original errors.
package enum ReducedLatLonArtifactError: Error, Equatable, CustomStringConvertible {
    /// The file does not identify a reduced latitude–longitude artifact.
    case invalidMagic
    /// The stored format version is not supported by this reader.
    case unsupportedVersion(UInt32)
    /// Metadata, counts, or section contents violate the format's structural invariants.
    case invalidHeader
    /// The point at this canonical ID is not a finite, approximately unit-length direction.
    case invalidPoint(Int)
    /// The artifact exceeds the configured byte limit or representable bucket count.
    case artifactTooLarge

    /// A diagnostic suitable for artifact generation and loading logs.
    package var description: String {
        switch self {
        case .invalidMagic: "Invalid reduced latitude–longitude artifact magic"
        case .unsupportedVersion(let version): "Unsupported reduced latitude–longitude artifact version \(version)"
        case .invalidHeader: "Invalid reduced latitude–longitude artifact metadata or section layout"
        case .invalidPoint(let id): "Invalid unit direction at canonical point ID \(id)"
        case .artifactTooLarge: "Reduced latitude–longitude artifact exceeds its size limit"
        }
    }
}

/// Portable LATBAND1 format for global or regional, approximately homogeneous point sets.
/// Stores little-endian Float32 directions in latitude-band buckets with a canonical-ID reverse
/// directory. Dataset identity is opaque; provider-specific distance policies belong to callers.
package enum ReducedLatLonArtifact {
    /// Opaque dataset identity and storage coverage, independent of any weather provider.
    package struct Metadata: Sendable, Equatable {
        /// Caller-assigned dataset number.
        package let number: UInt32
        /// Caller-assigned 16-byte dataset identifier, validated by the writer.
        package let uuid: [UInt8]
        /// Whether to materialize every bucket, rather than only occupied regional spans.
        /// This does not impose a geographic acceptance boundary on queries.
        package let coversWholeSphere: Bool

        /// Creates metadata; the writer requires exactly 16 UUID bytes.
        package init(number: UInt32, uuid: [UInt8], coversWholeSphere: Bool) {
            self.number = number
            self.uuid = uuid
            self.coversWholeSphere = coversWholeSphere
        }
    }

    /// A cyclic longitude span within one whole-sphere latitude band. Empty regional interior
    /// bands have zero stored columns; firstBucket indexes the shared prefix directory.
    struct Band: Sendable {
        let longitudeColumnCount: Int
        let startColumn: Int
        let storedColumnCount: Int
        let firstBucket: Int

        @inline(__always) func localColumn(_ column: Int) -> Int {
            let local = column - startColumn
            return local < 0 ? local + longitudeColumnCount : local
        }
    }

    static let magic = Array("LATBAND1".utf8)
    static let version: UInt32 = 1
    static let headerBytes = 64
    static let bandStride = 16
    static let pointStride = 16
    static let integerBytes = 4

    /// Derived section positions on supported 64-bit platforms. All inputs come from bounded
    /// UInt32 counts; the reader checks the exact file length before accessing any section.
    struct Layout {
        let directoryOffset: Int
        let pointsOffset: Int
        let reverseOffset: Int
        let fileBytes: Int

        init(storedBandCount: Int, bucketCount: Int, pointCount: Int) {
            directoryOffset = headerBytes + storedBandCount * bandStride
            pointsOffset = (directoryOffset + (bucketCount + 1) * integerBytes + pointStride - 1) / pointStride * pointStride
            reverseOffset = pointsOffset + pointCount * pointStride
            fileBytes = reverseOffset + pointCount * integerBytes
        }
    }

    static func columns(band: Int, bandCount: Int) -> Int {
        let h = Double.pi / Double(bandCount)
        return max(1, Int((2 * .pi * cos(-.pi / 2 + (Double(band) + 0.5) * h) / h).rounded()))
    }

    @inline(__always) static func band(latitude: Double, count: Int) -> Int {
        min(count - 1, max(0, Int(floor((latitude + .pi / 2) * Double(count) / .pi))))
    }

    @inline(__always) static func column(longitude: Double, count: Int) -> Int {
        let value = Int(floor((longitude + .pi) * Double(count) / (2 * .pi)))
        return value >= count ? 0 : max(0, value)
    }

    @inline(__always) static func uint(_ bytes: borrowing RawSpan, _ offset: Int) -> UInt32 {
        UInt32(littleEndian: bytes.unsafeLoadUnaligned(fromByteOffset: offset, as: UInt32.self))
    }

    @inline(__always) static func point(_ bytes: borrowing RawSpan, _ offset: Int) -> ReducedLatLonPoint {
        ReducedLatLonPoint(x: Float(bitPattern: uint(bytes, offset)),
                           y: Float(bitPattern: uint(bytes, offset + 4)),
                           z: Float(bitPattern: uint(bytes, offset + 8)))
    }

    static func put(_ bytes: inout MutableRawSpan, _ offset: Int, _ value: UInt32) {
        bytes.storeBytes(of: value.littleEndian, toByteOffset: offset, as: UInt32.self)
    }

}
