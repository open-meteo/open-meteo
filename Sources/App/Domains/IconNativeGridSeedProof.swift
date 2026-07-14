import Foundation

/// Offline proof for the seed raster used by `IconNativeGrid`.
///
/// For a bin centre `q`, let `d1` be the distance to its nearest candidate and `r` the greatest
/// distance from `q` to a bin corner. Any centre that can be nearest somewhere in the bin must be
/// within `d1 + 2r` of `q`. Artifact creation therefore rejects a bin if that cap contains a cell
/// outside the seed's two topology rings. The temporary CSR index keeps proof generation linear in
/// the number of bins for a suitably fine raster; it is not stored or used by production lookup.
enum IconNativeGridSeedProof {
    static func validate(
        metadata: IconNativeGridArtifact.Metadata,
        centers: [IconNativeGridPoint],
        neighbours: [[UInt32]],
        seeds: [UInt32],
        coverage: [UInt8]?
    ) throws {
        let index = try CenterIndex(metadata: metadata, centers: centers)
        let binCount = metadata.seedNx * metadata.seedNy
        for bin in 0..<binCount {
            if let coverage, coverage[bin] == 0 {
                continue
            }
            let seed = seeds[bin]
            guard seed != IconNativeGrid.missingIndex else {
                throw IconNativeGridError.invalidSeed(bin: bin, seed: seed)
            }
            let candidates = twoRingCandidates(seed: Int(seed), neighbours: neighbours)
            let query = binCenter(bin: bin, metadata: metadata)
            var nearestDistance = Float.pi
            for position in 0..<candidates.count {
                nearestDistance = min(nearestDistance, angularDistance(query, centers[candidates.cells[position]]))
            }
            let radius = binRadius(bin: bin, center: query, metadata: metadata)
            let proofRadius = min(Float.pi, nearestDistance + 2 * radius + 2e-6)
            var omittedCell: Int?
            index.forEachCenter(inCapOf: query, radius: proofRadius) { cell in
                for position in 0..<candidates.count where candidates.cells[position] == cell {
                    return true
                }
                if omittedCell == nil {
                    omittedCell = cell
                }
                return false
            }
            if let omittedCell {
                throw IconNativeGridError.seedProofFailed(bin: bin, omittedCell: omittedCell)
            }
        }
    }

    private static func twoRingCandidates(seed: Int, neighbours: [[UInt32]]) -> (cells: InlineArray<10, Int>, count: Int) {
        var candidates = InlineArray<10, Int>(repeating: -1)
        candidates[0] = seed
        var count = 1

        @inline(__always) func append(_ cell: Int, candidates: inout InlineArray<10, Int>, count: inout Int) {
            for position in 0..<count where candidates[position] == cell {
                return
            }
            precondition(count < IconNativeGrid.maximumCandidateCount)
            candidates[count] = cell
            count += 1
        }

        for neighbour in neighbours[seed] where neighbour != IconNativeGrid.missingIndex {
            append(Int(neighbour), candidates: &candidates, count: &count)
        }
        let firstRingEnd = count
        if firstRingEnd > 1 {
            for position in 1..<firstRingEnd {
                for neighbour in neighbours[candidates[position]] where neighbour != IconNativeGrid.missingIndex {
                    append(Int(neighbour), candidates: &candidates, count: &count)
                }
            }
        }
        return (candidates, count)
    }

    private static func binCenter(bin: Int, metadata: IconNativeGridArtifact.Metadata) -> IconNativeGridPoint {
        let x = bin % metadata.seedNx
        let y = bin / metadata.seedNx
        return IconNativeGridPoint(
            latitude: metadata.seedLatMin + (Float(y) + 0.5) * metadata.seedDy,
            longitude: metadata.seedLonMin + (Float(x) + 0.5) * metadata.seedDx
        )
    }

    private static func binRadius(bin: Int, center: IconNativeGridPoint, metadata: IconNativeGridArtifact.Metadata) -> Float {
        let x = bin % metadata.seedNx
        let y = bin / metadata.seedNx
        let latitude = metadata.seedLatMin + Float(y) * metadata.seedDy
        let longitude = metadata.seedLonMin + Float(x) * metadata.seedDx
        let southWest = IconNativeGridPoint(latitude: latitude, longitude: longitude)
        let southEast = IconNativeGridPoint(latitude: latitude, longitude: longitude + metadata.seedDx)
        let northWest = IconNativeGridPoint(latitude: latitude + metadata.seedDy, longitude: longitude)
        let northEast = IconNativeGridPoint(latitude: latitude + metadata.seedDy, longitude: longitude + metadata.seedDx)
        return max(
            max(angularDistance(center, southWest), angularDistance(center, southEast)),
            max(angularDistance(center, northWest), angularDistance(center, northEast))
        )
    }

    @inline(__always) private static func angularDistance(_ lhs: IconNativeGridPoint, _ rhs: IconNativeGridPoint) -> Float {
        acos(max(-1, min(1, lhs.dot(rhs))))
    }
}

private extension IconNativeGridSeedProof {
    struct CenterIndex {
        let metadata: IconNativeGridArtifact.Metadata
        let centers: [IconNativeGridPoint]
        let offsets: [UInt32]
        let cells: [UInt32]

        init(metadata: IconNativeGridArtifact.Metadata, centers: [IconNativeGridPoint]) throws {
            self.metadata = metadata
            self.centers = centers
            let binCount = metadata.seedNx * metadata.seedNy
            var offsets = [UInt32](repeating: 0, count: binCount + 1)
            for (cell, center) in centers.enumerated() {
                guard let bin = Self.bin(latitude: Self.latitude(center), longitude: Self.longitude(center), metadata: metadata) else {
                    throw IconNativeGridError.invalidCenter(cell)
                }
                let count = offsets[bin + 1].addingReportingOverflow(1)
                guard !count.overflow else {
                    throw IconNativeGridError.invalidHeader
                }
                offsets[bin + 1] = count.partialValue
            }
            for bin in 0..<binCount {
                offsets[bin + 1] += offsets[bin]
            }
            var cursors = offsets
            var cells = [UInt32](repeating: 0, count: centers.count)
            for (cell, center) in centers.enumerated() {
                guard let bin = Self.bin(latitude: Self.latitude(center), longitude: Self.longitude(center), metadata: metadata) else {
                    throw IconNativeGridError.invalidCenter(cell)
                }
                let position = Int(cursors[bin])
                cells[position] = UInt32(cell)
                cursors[bin] += 1
            }
            self.offsets = offsets
            self.cells = cells
        }

        func forEachCenter(inCapOf query: IconNativeGridPoint, radius: Float, body: (Int) -> Bool) {
            let queryLatitude = Self.latitude(query)
            let queryLongitude = Self.longitude(query)
            let radiusDegrees = radius * 180 / .pi
            let latitudeLower = max(-90, queryLatitude - radiusDegrees)
            let latitudeUpper = min(90, queryLatitude + radiusDegrees)
            let yLower = max(0, Int(floor((latitudeLower - metadata.seedLatMin) / metadata.seedDy)))
            let yUpper = min(metadata.seedNy - 1, Int(floor((latitudeUpper - metadata.seedLatMin) / metadata.seedDy)))
            guard yLower <= yUpper else {
                return
            }

            let reachesPole = abs(queryLatitude) + radiusDegrees >= 90
            let longitudeRadius: Float
            if radius >= .pi || reachesPole {
                longitudeRadius = 180
            } else {
                let ratio = sin(radius) / max(1e-12, cos(queryLatitude * .pi / 180))
                longitudeRadius = asin(max(-1, min(1, ratio))) * 180 / .pi
            }
            let minimumDot = cos(radius) - 2e-6

            for y in yLower...yUpper {
                let xRange = longitudeBins(center: queryLongitude, radius: longitudeRadius)
                for rawX in xRange {
                    let x: Int
                    if metadata.isGlobal {
                        x = (rawX % metadata.seedNx + metadata.seedNx) % metadata.seedNx
                    } else {
                        guard rawX >= 0, rawX < metadata.seedNx else {
                            continue
                        }
                        x = rawX
                    }
                    let bin = y * metadata.seedNx + x
                    for position in Int(offsets[bin])..<Int(offsets[bin + 1]) {
                        let cell = Int(cells[position])
                        if centers[cell].dot(query) >= minimumDot, !body(cell) {
                            return
                        }
                    }
                }
            }
        }

        private func longitudeBins(center: Float, radius: Float) -> ClosedRange<Int> {
            if radius >= 180 {
                return 0...(metadata.seedNx - 1)
            }
            let lower = Int(floor((center - radius - metadata.seedLonMin) / metadata.seedDx))
            let upper = Int(floor((center + radius - metadata.seedLonMin) / metadata.seedDx))
            if metadata.isGlobal, upper - lower + 1 >= metadata.seedNx {
                return 0...(metadata.seedNx - 1)
            }
            return lower...upper
        }

        private static func bin(latitude: Float, longitude: Float, metadata: IconNativeGridArtifact.Metadata) -> Int? {
            var longitude = longitude
            if metadata.isGlobal {
                longitude = longitude.truncatingRemainder(dividingBy: 360)
                if longitude < -180 {
                    longitude += 360
                } else if longitude >= 180 {
                    longitude -= 360
                }
            }
            var x = Int(floor((longitude - metadata.seedLonMin) / metadata.seedDx))
            var y = Int(floor((latitude - metadata.seedLatMin) / metadata.seedDy))
            if metadata.isGlobal {
                x = (x % metadata.seedNx + metadata.seedNx) % metadata.seedNx
                y = max(0, min(metadata.seedNy - 1, y))
            }
            guard x >= 0, x < metadata.seedNx, y >= 0, y < metadata.seedNy else {
                return nil
            }
            return y * metadata.seedNx + x
        }

        private static func latitude(_ point: IconNativeGridPoint) -> Float {
            asin(max(-1, min(1, point.z))) * 180 / .pi
        }

        private static func longitude(_ point: IconNativeGridPoint) -> Float {
            atan2(point.y, point.x) * 180 / .pi
        }
    }
}
