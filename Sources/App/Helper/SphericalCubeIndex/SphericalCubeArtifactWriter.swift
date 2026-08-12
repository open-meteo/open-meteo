import Foundation

extension SphericalCubeArtifact {
    /// Offline builder for the portable artifact. Generation may allocate proportional to the
    /// number of points and buckets; none of this machinery participates in runtime lookup.
    enum Writer {
        private typealias FaceSection = SphericalCubeArtifact.FaceSection

        /// Partitions canonical points into cube buckets and writes an atomic, mmap-ready file.
        ///
        /// Point array position becomes the canonical point ID. `coversWholeSphere` controls only
        /// whether all face buckets or occupied face rectangles are materialized. The maximum chord
        /// distance rejects queries too far from every stored point, which gives partial datasets a
        /// cheap distance-based coverage rule without storing polygon topology.
        static func write(
            to file: URL,
            metadata: SphericalCubeArtifact.Metadata,
            points: [SphericalPoint],
            level: Int,
            maximumFileSize: Int = .max
        ) throws {
            guard !points.isEmpty, points.count <= Int(UInt32.max),
                level >= SphericalCubeArtifact.tileShift, level <= 15,
                metadata.identity.uuid.count == 16,
                metadata.maximumChordDistanceSquared.isFinite,
                metadata.maximumChordDistanceSquared > 0,
                metadata.maximumChordDistanceSquared <= 4
            else {
                throw SphericalCubeArtifactError.invalidHeader
            }

            // Bucket the exact Float32 value that will be written, so generation and lookup cannot
            // disagree at a cube-face or leaf boundary because of quantization.
            func storedPoint(_ point: SphericalPoint) -> SphericalPoint {
                SphericalPoint(
                    x: Double(Float(point.x)),
                    y: Double(Float(point.y)),
                    z: Double(Float(point.z))
                )
            }

            let resolution = 1 << level
            // First pass: derive the occupied rectangle of every face.
            var minimumX = [Int](repeating: resolution, count: 6)
            var minimumY = [Int](repeating: resolution, count: 6)
            var maximumX = [Int](repeating: -1, count: 6)
            var maximumY = [Int](repeating: -1, count: 6)
            for (position, point) in points.enumerated() {
                let normSquared = point.dot(point)
                guard point.x.isFinite, point.y.isFinite, point.z.isFinite,
                    abs(normSquared - 1) <= 2e-15
                else {
                    throw SphericalCubeArtifactError.invalidPoint(position)
                }
                let location = SphericalCubeGeometry.location(
                    for: storedPoint(point),
                    resolution: resolution
                )
                minimumX[location.face] = min(minimumX[location.face], location.x)
                minimumY[location.face] = min(minimumY[location.face], location.y)
                maximumX[location.face] = max(maximumX[location.face], location.x)
                maximumY[location.face] = max(maximumY[location.face], location.y)
            }

            var faceSections = [FaceSection]()
            faceSections.reserveCapacity(6)
            var bucketCount = 0
            for face in 0..<6 {
                let hasPoints = maximumX[face] >= 0
                let sectionMinimumX = metadata.coversWholeSphere ? 0 : (hasPoints ? minimumX[face] : 0)
                let sectionMinimumY = metadata.coversWholeSphere ? 0 : (hasPoints ? minimumY[face] : 0)
                let columns =
                    metadata.coversWholeSphere
                    ? resolution
                    : (hasPoints ? maximumX[face] - minimumX[face] + 1 : 0)
                let rows =
                    metadata.coversWholeSphere
                    ? resolution
                    : (hasPoints ? maximumY[face] - minimumY[face] + 1 : 0)
                faceSections.append(
                    FaceSection(
                        minimumX: sectionMinimumX,
                        minimumY: sectionMinimumY,
                        columns: columns,
                        rows: rows,
                        firstBucket: bucketCount
                    )
                )
                bucketCount += columns * rows
            }
            guard bucketCount > 0, bucketCount <= Int(UInt32.max) else {
                throw SphericalCubeArtifactError.invalidHeader
            }

            // Second pass: build prefix offsets for the bucket-ordered point section.
            var counts = [Int](repeating: 0, count: bucketCount)
            for point in points {
                let location = SphericalCubeGeometry.location(
                    for: storedPoint(point),
                    resolution: resolution
                )
                let bucket = faceSections[location.face].bucket(x: location.x, y: location.y)!
                counts[bucket] += 1
            }
            var offsets = [UInt32](repeating: 0, count: bucketCount + 1)
            for bucket in 0..<bucketCount {
                offsets[bucket + 1] = offsets[bucket] + UInt32(counts[bucket])
            }
            for blockStart in stride(from: 0, through: bucketCount, by: 256) {
                let blockEnd = min(bucketCount, blockStart + 256)
                guard offsets[blockEnd] - offsets[blockStart] <= UInt16.max else {
                    throw SphericalCubeArtifactError.invalidHeader
                }
            }

            // Third pass: construct both permutations. `order` maps storage position to canonical
            // ID; `positionsByID` provides the inverse mapping for coordinate access.
            var cursors = offsets.dropLast().map(Int.init)
            var order = [UInt32](repeating: 0, count: points.count)
            var positionsByID = [UInt32](repeating: 0, count: points.count)
            for pointID in points.indices {
                let location = SphericalCubeGeometry.location(
                    for: storedPoint(points[pointID]),
                    resolution: resolution
                )
                let bucket = faceSections[location.face].bucket(x: location.x, y: location.y)!
                order[cursors[bucket]] = UInt32(pointID)
                positionsByID[pointID] = UInt32(cursors[bucket])
                cursors[bucket] += 1
            }

            let layout = SectionLayout(pointCount: points.count, bucketCount: bucketCount)
            guard layout.fileBytes <= maximumFileSize else {
                throw SphericalCubeArtifactError.artifactTooLarge(
                    actual: layout.fileBytes,
                    maximum: maximumFileSize
                )
            }

            var data = Data(repeating: 0, count: layout.fileBytes)
            data.replaceSubrange(0..<magic.count, with: magic)
            data.writeSphericalCubeInteger(version, at: 8)
            data.writeSphericalCubeInteger(UInt32(points.count), at: 12)
            data.writeSphericalCubeInteger(UInt32(level), at: 16)
            data.writeSphericalCubeFloat(metadata.maximumChordDistanceSquared, at: 20)
            data.writeSphericalCubeInteger(metadata.identity.number, at: 24)
            data.replaceSubrange(28..<44, with: metadata.identity.uuid)

            for (face, section) in faceSections.enumerated() {
                let offset = faceSectionsOffset + face * faceSectionStride
                data.writeSphericalCubeInteger(UInt32(section.minimumX), at: offset)
                data.writeSphericalCubeInteger(UInt32(section.minimumY), at: offset + 4)
                data.writeSphericalCubeInteger(UInt32(section.columns), at: offset + 8)
                data.writeSphericalCubeInteger(UInt32(section.rows), at: offset + 12)
            }
            let baseCount = bucketCount / 256 + 1
            for block in 0..<baseCount {
                data.writeSphericalCubeInteger(
                    offsets[min(bucketCount, block * 256)],
                    at: layout.directoryBasesOffset + block * 4
                )
            }
            for index in offsets.indices {
                let base = offsets[(index >> 8) * 256]
                data.writeSphericalCubeInteger(
                    UInt16(offsets[index] - base),
                    at: layout.directoryLocalsOffset + index * 2
                )
            }
            for (position, pointID) in order.enumerated() {
                let point = points[Int(pointID)]
                let offset = layout.pointsOffset + position * pointStride
                data.writeSphericalCubeFloat(Float(point.x), at: offset)
                data.writeSphericalCubeFloat(Float(point.y), at: offset + 4)
                data.writeSphericalCubeFloat(Float(point.z), at: offset + 8)
                data.writeSphericalCubeInteger(pointID, at: offset + 12)
            }
            for (pointID, position) in positionsByID.enumerated() {
                data.writeSphericalCubeInteger(position, at: layout.positionsByIDOffset + pointID * 4)
            }
            try data.write(to: file, options: .atomic)
        }
    }
}

extension Data {
    fileprivate mutating func writeSphericalCubeInteger<T: FixedWidthInteger>(
        _ value: T,
        at offset: Int
    ) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) {
            replaceSubrange(offset..<(offset + $0.count), with: $0)
        }
    }

    fileprivate mutating func writeSphericalCubeFloat(_ value: Float, at offset: Int) {
        writeSphericalCubeInteger(value.bitPattern, at: offset)
    }
}
