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

    /// Owned structural description decoded from an artifact; retains no borrowed bytes.
    struct Parsed {
        let metadata: Metadata
        let bands: [Band]
        let layout: Layout
        let firstBand: Int
        let pointCount: Int
        let latitudeBandCount: Int
    }

    /// Decodes and validates the header, bands, directory, reverse offsets, and exact file size.
    /// Does not validate point norms, ID permutation, or bucket membership; input must come
    /// from a trusted writer. The caller keeps the backing storage alive during this borrow.
    static func parse(_ bytes: borrowing RawSpan) throws -> Parsed {
        guard bytes.byteCount >= headerBytes else { throw ReducedLatLonArtifactError.invalidHeader }
        guard magic.indices.allSatisfy({ bytes.unsafeLoad(fromByteOffset: $0, as: UInt8.self) == magic[$0] }) else {
            throw ReducedLatLonArtifactError.invalidMagic
        }
        let storedVersion = uint(bytes, 8)
        guard storedVersion == version else { throw ReducedLatLonArtifactError.unsupportedVersion(storedVersion) }
        let count = Int(uint(bytes, 12))
        let bandCount = Int(uint(bytes, 16))
        let first = Int(uint(bytes, 20))
        let stored = Int(uint(bytes, 24))
        let buckets = Int(uint(bytes, 28))
        let global = uint(bytes, 36)
        guard count > 0, bandCount > 0, bandCount <= 65_536,
              stored > 0, first + stored <= bandCount, buckets > 0, global <= 1,
              (56..<64).allSatisfy({ bytes.unsafeLoad(fromByteOffset: $0, as: UInt8.self) == 0 }) else { throw ReducedLatLonArtifactError.invalidHeader }
        // Counts are UInt32, bandCount is bounded, and the platform is 64-bit: these
        // sums/products cannot overflow Int before the exact file-size check.
        let layout = Layout(storedBandCount: stored, bucketCount: buckets, pointCount: count)
        let directory = layout.directoryOffset
        let reverse = layout.reverseOffset
        guard layout.fileBytes == bytes.byteCount else { throw ReducedLatLonArtifactError.invalidHeader }
        var bands = [Band]()
        var expectedBucket = 0
        for i in 0..<stored {
            let offset = headerBytes + i * 16
            let row = Band(longitudeColumnCount: Int(uint(bytes, offset)),
                           startColumn: Int(uint(bytes, offset + 4)),
                           storedColumnCount: Int(uint(bytes, offset + 8)),
                           firstBucket: Int(uint(bytes, offset + 12)))
            guard row.longitudeColumnCount == columns(band: first + i, bandCount: bandCount),
                  row.startColumn < row.longitudeColumnCount, row.storedColumnCount <= row.longitudeColumnCount,
                  row.firstBucket == expectedBucket,
                  global == 0 || (row.startColumn == 0 && row.storedColumnCount == row.longitudeColumnCount) else {
                throw ReducedLatLonArtifactError.invalidHeader
            }
            expectedBucket += row.storedColumnCount
            bands.append(row)
        }
        guard expectedBucket == buckets, global == 0 || (first == 0 && stored == bandCount),
              uint(bytes, directory) == 0 else { throw ReducedLatLonArtifactError.invalidHeader }
        var previous: UInt32 = 0
        for i in 0...buckets {
            let current = uint(bytes, directory + i * 4)
            guard current >= previous, current <= count else { throw ReducedLatLonArtifactError.invalidHeader }
            previous = current
        }
        guard previous == count else { throw ReducedLatLonArtifactError.invalidHeader }
        for id in 0..<count {
            guard uint(bytes, reverse + id * 4) < count else { throw ReducedLatLonArtifactError.invalidHeader }
        }
        let metadata = Metadata(number: uint(bytes, 32),
                                uuid: (40..<56).map { bytes.unsafeLoad(fromByteOffset: $0, as: UInt8.self) },
                                coversWholeSphere: global == 1)
        return Parsed(metadata: metadata, bands: bands, layout: layout, firstBand: first,
                      pointCount: count, latitudeBandCount: bandCount)
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
