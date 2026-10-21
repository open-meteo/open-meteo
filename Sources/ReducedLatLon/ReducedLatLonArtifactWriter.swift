import Foundation
import OmFileFormat

extension ReducedLatLonArtifact {
    /// Offline construction of portable artifacts. Point array offsets become canonical IDs.
    /// Generation allocates in proportion to point and bucket counts; lookup does not.
    package enum Writer {
        /// Writes to a temporary file and atomically replaces the destination on success.
        /// Existing mappings keep their original inode. The previous file survives write errors.
        package static func write(
            to file: URL, metadata: Metadata, points: [ReducedLatLonPoint],
            latitudeBandCount: Int, maximumFileSize: Int = .max
        ) throws {
            let handle = try FileHandle.createNewFile(file: file.path, overwrite: true, temporary: true)
            try write(to: handle, metadata: metadata, points: points,
                      latitudeBandCount: latitudeBandCount, maximumFileSize: maximumFileSize)
            try handle.linkTemporary(file: file.path)
        }

        /// Writes a complete artifact to a caller-owned empty handle at offset zero.
        /// Does not close or publish the handle; callers may map and validate it before publication.
        ///
        /// The point array must be nonempty, with finite Float32 directions whose squared norm is within four Float epsilons
        /// of one. Component bits and canonical IDs are preserved. The band count is in 1...65,536;
        /// metadata requires a 16-byte UUID. Coverage controls storage, not geographic acceptance.
        /// Throws on invalid input, an artifact exceeding the byte limit, or an I/O error.
        package static func write(
            to file: FileHandle, metadata: Metadata, points: [ReducedLatLonPoint],
            latitudeBandCount: Int, maximumFileSize: Int = .max
        ) throws {
            let bandCount = latitudeBandCount
            guard !points.isEmpty, points.count <= Int(UInt32.max),
                  bandCount > 0, bandCount <= 65_536, metadata.uuid.count == 16 else {
                throw ReducedLatLonArtifactError.invalidHeader
            }
            // Cache the quantized positions so regional span discovery does not repeat trigonometry.
            var positions = [(band: Int, column: Int)]()
            var occupied = [[Int]](repeating: [], count: metadata.coversWholeSphere ? 0 : bandCount)
            positions.reserveCapacity(points.count)
            for (id, point) in points.enumerated() {
                let norm = Double(point.x) * Double(point.x) + Double(point.y) * Double(point.y) + Double(point.z) * Double(point.z)
                guard norm.isFinite, abs(norm - 1) <= 4 * Double(Float.ulpOfOne) else {
                    throw ReducedLatLonArtifactError.invalidPoint(id)
                }
                let angles = point.radians
                let row = band(latitude: angles.latitude, count: bandCount)
                let column = column(longitude: angles.longitude, count: columns(band: row, bandCount: bandCount))
                positions.append((band: row, column: column))
                if !metadata.coversWholeSphere {
                    occupied[row].append(column)
                }
            }
            let firstBand = metadata.coversWholeSphere ? 0 : positions.min { $0.band < $1.band }!.band
            let lastBand = metadata.coversWholeSphere ? bandCount - 1 : positions.max { $0.band < $1.band }!.band
            var bands = [Band]()
            var bucketCount = 0
            for row in firstBand...lastBand {
                let n = columns(band: row, bandCount: bandCount)
                var start = 0
                var count = metadata.coversWholeSphere ? n : 0
                if !metadata.coversWholeSphere, !occupied[row].isEmpty {
                    let sorted = occupied[row].sorted()
                    var largestGap = -1
                    for i in sorted.indices {
                        let next = sorted[(i + 1) % sorted.count]
                        let gap = (i + 1 == sorted.count ? next + n : next) - sorted[i] - 1
                        if gap > largestGap || (gap == largestGap && next < start) {
                            largestGap = gap
                            start = next
                        }
                    }
                    count = n - largestGap
                }
                bands.append(Band(longitudeColumnCount: n, startColumn: start, storedColumnCount: count, firstBucket: bucketCount))
                bucketCount += count
            }
            guard bucketCount > 0, bucketCount <= Int(UInt32.max) else {
                throw ReducedLatLonArtifactError.artifactTooLarge
            }
            let layout = Layout(storedBandCount: bands.count, bucketCount: bucketCount, pointCount: points.count)
            let directoryOffset = layout.directoryOffset
            let pointsOffset = layout.pointsOffset
            let reverseOffset = layout.reverseOffset
            let fileBytes = layout.fileBytes
            guard fileBytes <= maximumFileSize else { throw ReducedLatLonArtifactError.artifactTooLarge }
            var offsets = [UInt32](repeating: 0, count: bucketCount + 1)
            for position in positions {
                let row = bands[position.band - firstBand]
                offsets[row.firstBucket + row.localColumn(position.column) + 1] += 1
            }
            for i in 1...bucketCount { offsets[i] += offsets[i - 1] }
            var cursors = offsets
            var data = Data(repeating: 0, count: fileBytes)
            data.withUnsafeMutableBytes { buffer in
                var bytes = MutableRawSpan(_unsafeBytes: buffer)
                for i in magic.indices { bytes.storeBytes(of: magic[i], toByteOffset: i, as: UInt8.self) }
                put(&bytes, 8, version)
                put(&bytes, 12, UInt32(points.count))
                put(&bytes, 16, UInt32(bandCount))
                put(&bytes, 20, UInt32(firstBand))
                put(&bytes, 24, UInt32(bands.count))
                put(&bytes, 28, UInt32(bucketCount))
                put(&bytes, 32, metadata.number)
                put(&bytes, 36, metadata.coversWholeSphere ? 1 : 0)
                for i in 0..<16 { bytes.storeBytes(of: metadata.uuid[i], toByteOffset: 40 + i, as: UInt8.self) }
                for (i, row) in bands.enumerated() {
                    let offset = headerBytes + i * 16
                    put(&bytes, offset, UInt32(row.longitudeColumnCount))
                    put(&bytes, offset + 4, UInt32(row.startColumn))
                    put(&bytes, offset + 8, UInt32(row.storedColumnCount))
                    put(&bytes, offset + 12, UInt32(row.firstBucket))
                }
                for i in offsets.indices { put(&bytes, directoryOffset + i * 4, offsets[i]) }
                for id in points.indices {
                    let row = bands[positions[id].band - firstBand]
                    let bucket = row.firstBucket + row.localColumn(positions[id].column)
                    let position = cursors[bucket]
                    cursors[bucket] += 1
                    let offset = pointsOffset + Int(position) * 16
                    put(&bytes, offset, points[id].x.bitPattern)
                    put(&bytes, offset + 4, points[id].y.bitPattern)
                    put(&bytes, offset + 8, points[id].z.bitPattern)
                    put(&bytes, offset + 12, UInt32(id))
                    put(&bytes, reverseOffset + id * 4, position)
                }
            }
            try file.write(contentsOf: data)
        }
    }
}
