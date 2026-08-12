import Foundation
import OmFileFormat

enum SphericalCubeArtifactError: Error, Equatable, CustomStringConvertible {
    case invalidMagic
    case unsupportedVersion(UInt32)
    case invalidHeader
    case invalidPoint(Int)
    case artifactTooLarge(actual: Int, maximum: Int)

    var description: String {
        switch self {
        case .invalidMagic: "Invalid spherical cube artifact magic"
        case .unsupportedVersion(let version):
            "Unsupported spherical cube artifact version \(version)"
        case .invalidHeader: "Invalid spherical cube artifact header or section layout"
        case .invalidPoint(let position): "Invalid spherical point at position \(position)"
        case .artifactTooLarge(let actual, let maximum):
            "Spherical cube artifact requires \(actual) bytes; limit is \(maximum) bytes"
        }
    }
}

/// Portable `SPHCUBE1` binary-format definitions shared by offline writers and mmap-backed readers.
///
/// All integers and IEEE-754 values are little-endian. The 144-byte header contains only counts,
/// lookup policy, an opaque dataset identity, and six occupied cube-face rectangles. Section
/// offsets are derived from those values; no native pointers or Swift layouts are serialized.
/// The payload contains, in order:
///
/// 1. a compact bucket prefix directory;
/// 2. aligned `Float32 XYZ + UInt32 point ID` records in bucket order;
/// 3. one reverse `UInt32` position per canonical point ID.
///
/// Consequently the same artifact can be generated and memory-mapped by other languages.
enum SphericalCubeArtifact {
    /// Opaque producer-defined identity copied into the artifact and checked by its integration.
    struct DatasetIdentity: Sendable, Equatable {
        let number: UInt32
        let uuid: [UInt8]
    }

    /// Validated mmap and the derived offsets needed by the runtime index.
    struct Mapping {
        let mapped: MmapFile
        let faceSections: [FaceSection]
        let directoryBasesOffset: Int
        let directoryLocalsOffset: Int
        let pointsOffset: Int
        let positionsByIDOffset: Int
        let coversWholeSphere: Bool
        let maximumChordDistanceSquared: Float
        let pointCount: Int
        let level: Int
        let resolution: Int
        let bucketCount: Int
        let identity: DatasetIdentity
    }

    /// Writer-supplied policy and identity; it is not involved in spatial partitioning.
    struct Metadata: Sendable {
        let identity: DatasetIdentity
        let coversWholeSphere: Bool
        let maximumChordDistanceSquared: Float
    }

    /// Stored leaf rectangle for one cube face.
    ///
    /// Whole-sphere datasets use the complete `resolution × resolution` rectangle on all faces.
    /// Partial datasets store only each face's occupied bounding rectangle. Buckets inside every
    /// rectangle use the same 8×8 tiled ordering, including partial edge tiles.
    struct FaceSection: Sendable {
        let minimumX: Int
        let minimumY: Int
        let columns: Int
        let rows: Int
        let firstBucket: Int

        /// Returns the artifact-wide bucket number, or `nil` outside the stored rectangle.
        @inline(__always)
        func bucket(x: Int, y: Int) -> Int? {
            let localX = x - minimumX
            let localY = y - minimumY
            guard localX >= 0, localX < columns, localY >= 0, localY < rows else { return nil }
            let tileShift = SphericalCubeArtifact.tileShift
            let tileSize = SphericalCubeArtifact.tileSize
            let tileX = localX >> tileShift
            let tileY = localY >> tileShift
            let tileHeight = min(tileSize, rows - tileY * tileSize)
            let tileWidth = min(tileSize, columns - tileX * tileSize)
            return firstBucket
                + tileY * tileSize * columns
                + tileX * tileSize * tileHeight
                + (localY & (tileSize - 1)) * tileWidth
                + (localX & (tileSize - 1))
        }

        @inline(__always)
        func intersects(
            minimumX otherMinimumX: Int,
            maximumX otherMaximumX: Int,
            minimumY otherMinimumY: Int,
            maximumY otherMaximumY: Int
        ) -> Bool {
            columns > 0 && rows > 0
                && otherMaximumX >= minimumX
                && otherMinimumX < minimumX + columns
                && otherMaximumY >= minimumY
                && otherMinimumY < minimumY + rows
        }
    }

    /// Derives every payload position from `pointCount` and the face-derived bucket count.
    struct SectionLayout {
        let directoryBasesOffset: Int
        let directoryLocalsOffset: Int
        let pointsOffset: Int
        let positionsByIDOffset: Int
        let fileBytes: Int

        init(pointCount: Int, bucketCount: Int) {
            directoryBasesOffset = SphericalCubeArtifact.headerBytes
            directoryLocalsOffset = directoryBasesOffset + (bucketCount / 256 + 1) * 4
            pointsOffset = SphericalCubeArtifact.alignedEnd(
                offset: directoryBasesOffset,
                length: SphericalCubeArtifact.directoryBytes(bucketCount: bucketCount),
                alignment: 16
            )
            positionsByIDOffset = SphericalCubeArtifact.alignedEnd(
                offset: pointsOffset,
                length: pointCount * SphericalCubeArtifact.pointStride
            )
            fileBytes = SphericalCubeArtifact.alignedEnd(
                offset: positionsByIDOffset,
                length: pointCount * 4
            )
        }
    }

    // Header layout:
    //   0: magic[8], 8: version, 12: pointCount, 16: level,
    //   20: maximumChordDistanceSquared, 24: identity number, 28: identity UUID[16],
    //   44: padding[4], 48: six face rectangles of four UInt32 values each.
    static let magic = Array("SPHCUBE1".utf8)
    static let version: UInt32 = 1
    static let headerBytes = 144
    static let faceSectionsOffset = 48
    static let faceSectionStride = 16
    static let pointStride = 16
    static let tileShift = 3
    static let tileSize = 1 << tileShift

    @inline(__always)
    private static func pointOffset(position: Int, pointsOffset: Int) -> Int {
        pointsOffset + position * pointStride
    }

    /// Double-precision normalized dot product used by exact fallback and deterministic ties.
    @inline(__always)
    static func score(
        position: Int,
        query: SphericalPoint,
        bytes: borrowing RawSpan,
        pointsOffset: Int
    ) -> Double {
        let offset = pointOffset(position: position, pointsOffset: pointsOffset)
        let x = Double(readFloat(bytes, at: offset))
        let y = Double(readFloat(bytes, at: offset + 4))
        let z = Double(readFloat(bytes, at: offset + 8))
        let rawScore =
            query.x * x
            + query.y * y
            + query.z * z
        return rawScore / sqrt(x * x + y * y + z * z)
    }

    /// Float squared chord distance used by the allocation-free hot path.
    @inline(__always)
    static func squaredDistance(
        position: Int,
        query: SphericalLookupVector,
        bytes: borrowing RawSpan,
        pointsOffset: Int
    ) -> Float {
        let offset = pointOffset(position: position, pointsOffset: pointsOffset)
        let dx = query.x - readFloat(bytes, at: offset)
        let dy = query.y - readFloat(bytes, at: offset + 4)
        let dz = query.z - readFloat(bytes, at: offset + 8)
        return dx * dx + dy * dy + dz * dz
    }

    @inline(__always)
    static func pointID(position: Int, bytes: borrowing RawSpan, pointsOffset: Int) -> Int {
        Int(readUInt32(bytes, at: pointOffset(position: position, pointsOffset: pointsOffset) + 12))
    }

    @inline(__always)
    static func point(
        position: Int,
        bytes: borrowing RawSpan,
        pointsOffset: Int
    ) -> SphericalPoint {
        let offset = pointOffset(position: position, pointsOffset: pointsOffset)
        let x = Double(readFloat(bytes, at: offset))
        let y = Double(readFloat(bytes, at: offset + 4))
        let z = Double(readFloat(bytes, at: offset + 8))
        let inverseNorm = 1 / sqrt(x * x + y * y + z * z)
        return SphericalPoint(
            x: x * inverseNorm,
            y: y * inverseNorm,
            z: z * inverseNorm
        )
    }

    /// Decodes a bucket prefix position from one absolute base per 256 values plus a UInt16 delta.
    @inline(__always)
    static func directoryPosition(
        _ index: Int,
        bytes: borrowing RawSpan,
        basesOffset: Int,
        localsOffset: Int
    ) -> Int {
        let block = index >> 8
        let base = Int(readUInt32(bytes, at: basesOffset + block * 4))
        return base + Int(readUInt16(bytes, at: localsOffset + index * 2))
    }

    static func directoryBytes(bucketCount: Int) -> Int {
        (bucketCount / 256 + 1) * 4 + (bucketCount + 1) * 2
    }

    static func alignedEnd(offset: Int, length: Int, alignment: Int = 8) -> Int {
        (offset + length + alignment - 1) / alignment * alignment
    }

    @inline(__always)
    static func readUInt8(_ bytes: borrowing RawSpan, at offset: Int) -> UInt8 {
        bytes.unsafeLoad(fromByteOffset: offset, as: UInt8.self)
    }

    @inline(__always)
    static func readUInt32(_ bytes: borrowing RawSpan, at offset: Int) -> UInt32 {
        UInt32(littleEndian: bytes.unsafeLoadUnaligned(fromByteOffset: offset, as: UInt32.self))
    }

    @inline(__always)
    static func readUInt16(_ bytes: borrowing RawSpan, at offset: Int) -> UInt16 {
        UInt16(littleEndian: bytes.unsafeLoadUnaligned(fromByteOffset: offset, as: UInt16.self))
    }

    @inline(__always)
    static func readFloat(_ bytes: borrowing RawSpan, at offset: Int) -> Float {
        Float(bitPattern: readUInt32(bytes, at: offset))
    }

    static func readBytes(_ bytes: borrowing RawSpan, range: Range<Int>) -> [UInt8] {
        range.map { readUInt8(bytes, at: $0) }
    }
}

extension SphericalCubeArtifact {
    /// Maps and validates an artifact before any unchecked hot-path reads are allowed.
    ///
    /// Validation proves the complete file layout and monotonic bucket directory. Expensive
    /// semantic checks such as point normalization and ID uniqueness belong to generator tests.
    static func open(file: URL) throws -> Mapping {
        let handle = try FileHandle.openFileReading(file: file.path)
        let mapped = try MmapFile(fn: handle)
        guard mapped.data.count >= headerBytes else { throw SphericalCubeArtifactError.invalidHeader }
        let bytes = RawSpan(_unsafeBytes: UnsafeRawBufferPointer(mapped.data))

        for offset in magic.indices where readUInt8(bytes, at: offset) != magic[offset] {
            throw SphericalCubeArtifactError.invalidMagic
        }
        let storedVersion = readUInt32(bytes, at: 8)
        guard storedVersion == version else {
            throw SphericalCubeArtifactError.unsupportedVersion(storedVersion)
        }

        let pointCount = Int(readUInt32(bytes, at: 12))
        let level = Int(readUInt32(bytes, at: 16))
        let maximumChordDistanceSquared = readFloat(bytes, at: 20)
        let identity = DatasetIdentity(
            number: readUInt32(bytes, at: 24),
            uuid: readBytes(bytes, range: 28..<44)
        )

        guard pointCount > 0, level >= tileShift, level <= 15,
            maximumChordDistanceSquared.isFinite, maximumChordDistanceSquared > 0,
            maximumChordDistanceSquared <= 4
        else {
            throw SphericalCubeArtifactError.invalidHeader
        }
        let resolution = 1 << level
        var faceSections = [FaceSection]()
        faceSections.reserveCapacity(6)
        var bucketCount = 0
        for face in 0..<6 {
            let offset = faceSectionsOffset + face * faceSectionStride
            let section = FaceSection(
                minimumX: Int(readUInt32(bytes, at: offset)),
                minimumY: Int(readUInt32(bytes, at: offset + 4)),
                columns: Int(readUInt32(bytes, at: offset + 8)),
                rows: Int(readUInt32(bytes, at: offset + 12)),
                firstBucket: bucketCount
            )
            let sectionBuckets = section.columns.multipliedReportingOverflow(by: section.rows)
            guard section.minimumX >= 0, section.minimumY >= 0,
                section.columns >= 0, section.rows >= 0,
                section.minimumX + section.columns <= resolution,
                section.minimumY + section.rows <= resolution,
                !sectionBuckets.overflow,
                bucketCount <= Int(UInt32.max) - sectionBuckets.partialValue
            else {
                throw SphericalCubeArtifactError.invalidHeader
            }
            bucketCount += sectionBuckets.partialValue
            faceSections.append(section)
        }
        guard bucketCount > 0 else { throw SphericalCubeArtifactError.invalidHeader }

        let coversWholeSphere = faceSections.allSatisfy {
            $0.minimumX == 0 && $0.minimumY == 0
                && $0.columns == resolution && $0.rows == resolution
        }
        let layout = SectionLayout(
            pointCount: pointCount,
            bucketCount: bucketCount
        )
        guard layout.fileBytes == mapped.data.count else {
            throw SphericalCubeArtifactError.invalidHeader
        }

        var previous = 0
        for bucket in 0...bucketCount {
            let current = directoryPosition(
                bucket,
                bytes: bytes,
                basesOffset: layout.directoryBasesOffset,
                localsOffset: layout.directoryLocalsOffset
            )
            guard current >= previous, current <= pointCount else {
                throw SphericalCubeArtifactError.invalidHeader
            }
            previous = current
        }
        guard previous == pointCount else { throw SphericalCubeArtifactError.invalidHeader }

        return Mapping(
            mapped: mapped,
            faceSections: faceSections,
            directoryBasesOffset: layout.directoryBasesOffset,
            directoryLocalsOffset: layout.directoryLocalsOffset,
            pointsOffset: layout.pointsOffset,
            positionsByIDOffset: layout.positionsByIDOffset,
            coversWholeSphere: coversWholeSphere,
            maximumChordDistanceSquared: maximumChordDistanceSquared,
            pointCount: pointCount,
            level: level,
            resolution: resolution,
            bucketCount: bucketCount,
            identity: identity
        )
    }
}
