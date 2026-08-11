import Foundation
import OmFileFormat

extension IconNativeGrid {
    enum ArtifactError: Error, Equatable, CustomStringConvertible {
        case invalidMagic
        case unsupportedVersion(UInt32)
        case invalidHeader
        case invalidCenter(Int)
        case artifactTooLarge(actual: Int, maximum: Int)

        var description: String {
            switch self {
            case .invalidMagic: "Invalid ICON native cube artifact magic"
            case .unsupportedVersion(let version):
                "Unsupported ICON native cube artifact version \(version)"
            case .invalidHeader: "Invalid ICON native cube artifact header or section layout"
            case .invalidCenter(let position): "Invalid ICON native cube center at position \(position)"
            case .artifactTooLarge(let actual, let maximum):
                "ICON cube artifact requires \(actual) bytes; limit is \(maximum) bytes"
            }
        }
    }

    /// Portable binary-format definitions shared by the offline writer and mmap-backed reader.
    enum CubeArtifact {
        struct Mapping {
            let mapped: MmapFile
            let faceSections: [FaceSection]
            let offsetsOffset: Int
            let centersOffset: Int
            let canonicalPositionsOffset: Int
            let isGlobal: Bool
            let maximumDistanceMeters: Float
            let cellCount: Int
            let level: Int
            let resolution: Int
            let bucketCount: Int
            let artifactBytes: Int
            let gridNumber: UInt32
            let gridUUID: [UInt8]
        }

        struct Metadata: Sendable {
            let gridNumber: UInt32
            let gridUUID: [UInt8]
            let isGlobal: Bool
            let maximumDistanceMeters: Float
        }

        struct FaceSection: Sendable {
            let minimumX: Int
            let minimumY: Int
            let columns: Int
            let rows: Int
            let firstBucket: Int

            @inline(__always)
            func bucket(x: Int, y: Int) -> Int? {
                let localX = x - minimumX
                let localY = y - minimumY
                guard localX >= 0, localX < columns, localY >= 0, localY < rows else { return nil }
                let tileShift = CubeArtifact.tileShift
                let tileSize = CubeArtifact.tileSize
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

        struct SectionLayout {
            let offsetsOffset: Int
            let centersOffset: Int
            let canonicalPositionsOffset: Int
            let fileBytes: Int

            init(cellCount: Int, bucketCount: Int) {
                offsetsOffset = CubeArtifact.headerBytes
                centersOffset = CubeArtifact.alignedEnd(
                    offset: offsetsOffset,
                    length: CubeArtifact.directoryBytes(bucketCount: bucketCount),
                    alignment: 16
                )
                canonicalPositionsOffset = CubeArtifact.alignedEnd(
                    offset: centersOffset,
                    length: cellCount * CubeArtifact.centerStride
                )
                fileBytes = CubeArtifact.alignedEnd(
                    offset: canonicalPositionsOffset,
                    length: cellCount * 4
                )
            }
        }

        static let magic = Array("ICONCUB5".utf8)
        static let version: UInt32 = 5
        static let headerBytes = 144
        static let faceSectionsOffset = 48
        static let faceSectionStride = 16
        static let centerStride = 16
        static let globalFlag: UInt32 = 1
        static let tileShift = 3
        static let tileSize = 1 << tileShift

        @inline(__always)
        private static func centerOffset(position: Int, centersOffset: Int) -> Int {
            centersOffset + position * centerStride
        }

        @inline(__always)
        static func score(
            position: Int,
            query: IconNativeCenter,
            bytes: borrowing RawSpan,
            centersOffset: Int
        ) -> Double {
            let offset = centerOffset(position: position, centersOffset: centersOffset)
            let x = Double(readFloat(bytes, at: offset))
            let y = Double(readFloat(bytes, at: offset + 4))
            let z = Double(readFloat(bytes, at: offset + 8))
            let rawScore =
                query.x * x
                + query.y * y
                + query.z * z
            return rawScore / sqrt(x * x + y * y + z * z)
        }

        @inline(__always)
        static func squaredDistance(
            position: Int,
            query: IconNativeLookupVector,
            bytes: borrowing RawSpan,
            centersOffset: Int
        ) -> Float {
            let offset = centerOffset(position: position, centersOffset: centersOffset)
            let dx = query.x - readFloat(bytes, at: offset)
            let dy = query.y - readFloat(bytes, at: offset + 4)
            let dz = query.z - readFloat(bytes, at: offset + 8)
            return dx * dx + dy * dy + dz * dz
        }

        @inline(__always)
        static func cell(position: Int, bytes: borrowing RawSpan, centersOffset: Int) -> Int {
            Int(readUInt32(bytes, at: centerOffset(position: position, centersOffset: centersOffset) + 12))
        }

        @inline(__always)
        static func center(
            position: Int,
            bytes: borrowing RawSpan,
            centersOffset: Int
        ) -> IconNativeCenter {
            let offset = centerOffset(position: position, centersOffset: centersOffset)
            let x = Double(readFloat(bytes, at: offset))
            let y = Double(readFloat(bytes, at: offset + 4))
            let z = Double(readFloat(bytes, at: offset + 8))
            let inverseNorm = 1 / sqrt(x * x + y * y + z * z)
            return IconNativeCenter(
                x: x * inverseNorm,
                y: y * inverseNorm,
                z: z * inverseNorm
            )
        }

        @inline(__always)
        static func directoryPosition(
            _ index: Int,
            bytes: borrowing RawSpan,
            offsetsOffset: Int,
            bucketCount: Int
        ) -> Int {
            let baseCount = bucketCount / 256 + 1
            let block = index >> 8
            let base = Int(readUInt32(bytes, at: offsetsOffset + block * 4))
            let localOffset = offsetsOffset + baseCount * 4 + index * 2
            return base + Int(readUInt16(bytes, at: localOffset))
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
}

extension IconNativeGrid.CubeArtifact {
    static func open(file: URL) throws -> Mapping {
        let handle = try FileHandle.openFileReading(file: file.path)
        let mapped = try MmapFile(fn: handle)
        guard mapped.data.count >= headerBytes else { throw IconNativeGrid.ArtifactError.invalidHeader }
        let bytes = RawSpan(_unsafeBytes: UnsafeRawBufferPointer(mapped.data))

        for offset in magic.indices where readUInt8(bytes, at: offset) != magic[offset] {
            throw IconNativeGrid.ArtifactError.invalidMagic
        }
        let storedVersion = readUInt32(bytes, at: 8)
        guard storedVersion == version else {
            throw IconNativeGrid.ArtifactError.unsupportedVersion(storedVersion)
        }

        let flags = readUInt32(bytes, at: 12)
        guard flags & ~globalFlag == 0 else { throw IconNativeGrid.ArtifactError.invalidHeader }
        let isGlobal = flags & globalFlag != 0
        let gridNumber = readUInt32(bytes, at: 16)
        let cellCount = Int(readUInt32(bytes, at: 20))
        let level = Int(readUInt32(bytes, at: 24))
        let maximumDistanceMeters = readFloat(bytes, at: 28)
        let gridUUID = readBytes(bytes, range: 32..<48)

        guard cellCount > 0, level >= 0, level <= 15,
            maximumDistanceMeters.isFinite, maximumDistanceMeters > 0
        else {
            throw IconNativeGrid.ArtifactError.invalidHeader
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
                throw IconNativeGrid.ArtifactError.invalidHeader
            }
            bucketCount += sectionBuckets.partialValue
            faceSections.append(section)
        }
        guard bucketCount > 0 else { throw IconNativeGrid.ArtifactError.invalidHeader }

        let sectionsCoverGlobalFaces = faceSections.allSatisfy {
            $0.minimumX == 0 && $0.minimumY == 0
                && $0.columns == resolution && $0.rows == resolution
        }
        if isGlobal {
            guard sectionsCoverGlobalFaces else {
                throw IconNativeGrid.ArtifactError.invalidHeader
            }
        }

        let layout = SectionLayout(
            cellCount: cellCount,
            bucketCount: bucketCount
        )
        guard layout.fileBytes == mapped.data.count else {
            throw IconNativeGrid.ArtifactError.invalidHeader
        }

        var previous = 0
        for bucket in 0...bucketCount {
            let current = directoryPosition(
                bucket,
                bytes: bytes,
                offsetsOffset: layout.offsetsOffset,
                bucketCount: bucketCount
            )
            guard current >= previous, current <= cellCount else {
                throw IconNativeGrid.ArtifactError.invalidHeader
            }
            previous = current
        }
        guard previous == cellCount else { throw IconNativeGrid.ArtifactError.invalidHeader }

        return Mapping(
            mapped: mapped,
            faceSections: faceSections,
            offsetsOffset: layout.offsetsOffset,
            centersOffset: layout.centersOffset,
            canonicalPositionsOffset: layout.canonicalPositionsOffset,
            isGlobal: isGlobal,
            maximumDistanceMeters: maximumDistanceMeters,
            cellCount: cellCount,
            level: level,
            resolution: resolution,
            bucketCount: bucketCount,
            artifactBytes: layout.fileBytes,
            gridNumber: gridNumber,
            gridUUID: gridUUID
        )
    }
}
