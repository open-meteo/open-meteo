import Foundation
import SwiftNetCDF

enum IconNativeGridSourceError: Error, CustomStringConvertible {
    case couldNotOpen(String)
    case io(path: String, reason: String)
    case missingAttribute(String)
    case invalidAttribute(name: String, actual: String)
    case missingVariable(String)
    case invalidDimensions(variable: String, actual: [String])
    case invalidValue(variable: String, index: Int)
    case invalidTopology(String)

    var description: String {
        switch self {
        case .couldNotOpen(let path): "Could not open ICON grid NetCDF at \(path)"
        case .io(let path, let reason): "Could not read ICON grid NetCDF at \(path): \(reason)"
        case .missingAttribute(let name): "Missing ICON grid NetCDF attribute '\(name)'"
        case .invalidAttribute(let name, let actual):
            "Invalid ICON grid NetCDF attribute '\(name)': \(actual)"
        case .missingVariable(let name): "Missing ICON grid NetCDF variable '\(name)'"
        case .invalidDimensions(let variable, let actual):
            "Invalid dimensions for ICON grid variable '\(variable)': \(actual.joined(separator: ","))"
        case .invalidValue(let variable, let index):
            "Invalid value in ICON grid variable '\(variable)' at index \(index)"
        case .invalidTopology(let reason): "Invalid ICON grid topology: \(reason)"
        }
    }
}

/// Float precision is sufficient for the offline regional coverage mask and halves the temporary
/// vertex footprint compared with the Double center vectors used by nearest-cell lookup.
private struct IconNativeVertex: Sendable {
    let x: Float
    let y: Float
    let z: Float

    init(x: Float, y: Float, z: Float) {
        self.x = x
        self.y = y
        self.z = z
    }

    init(latitude: Float, longitude: Float) {
        if latitude >= 90 {
            self.init(x: 0, y: 0, z: 1)
            return
        }
        if latitude <= -90 {
            self.init(x: 0, y: 0, z: -1)
            return
        }
        let latitudeRadians = latitude * .pi / 180
        let longitudeRadians = longitude * .pi / 180
        let cosineLatitude = cos(latitudeRadians)
        self.init(
            x: cosineLatitude * cos(longitudeRadians),
            y: cosineLatitude * sin(longitudeRadians),
            z: sin(latitudeRadians)
        )
    }

    @inline(__always)
    func dot(_ other: Self) -> Float {
        x * other.x + y * other.y + z * other.z
    }

    @inline(__always)
    func cross(_ other: Self) -> Self {
        Self(
            x: y * other.z - z * other.y,
            y: z * other.x - x * other.z,
            z: x * other.y - y * other.x
        )
    }
}

/// Offline converter from DWD's official ICON grid NetCDF to the compact, mmap-oriented runtime
/// artifact. Expensive topology and spatial-index work belongs here, never in API coordinate lookup.
extension IconNativeGrid {
    enum Generator {
        struct SourceData {
            /// Cell arrays remain in NetCDF/GRIB order; this makes a cell index directly usable as the
            /// location offset in native forecast files.
            let centers: [IconNativeCenter]
            let coverage: IconNativeGrid.CubeArtifact.Coverage
        }

        static func generate(
            sourceFile: String,
            identity: IconNativeGridIdentity,
            artifactFile: String
        )
            throws -> IconNativeGrid
        {
            let source = try readSource(file: sourceFile, identity: identity)
            let maximumFileSize = identity.isGlobal ? 128 * 1_024 * 1_024 : 32 * 1_024 * 1_024
            let metadata = IconNativeGrid.CubeArtifact.Metadata(
                gridNumber: identity.gridNumber,
                gridUUID: identity.gridUUID,
                isGlobal: identity.isGlobal,
                coverage: source.coverage
            )
            try IconNativeGrid.Generator.ArtifactWriter.write(
                to: URL(fileURLWithPath: artifactFile),
                metadata: metadata,
                centers: source.centers,
                level: identity.isGlobal ? 9 : 11,
                maximumFileSize: maximumFileSize
            )
            return try IconNativeGrid.load(file: URL(fileURLWithPath: artifactFile))
        }

        static func readSource(file: String, identity: IconNativeGridIdentity) throws -> SourceData {
            do {
                return try readSourceUnchecked(file: file, identity: identity)
            } catch let error as IconNativeGridSourceError {
                throw error
            } catch {
                throw IconNativeGridSourceError.io(path: file, reason: String(describing: error))
            }
        }

        private static func readSourceUnchecked(
            file: String,
            identity: IconNativeGridIdentity
        ) throws
            -> SourceData
        {
            guard let group = try NetCDF.open(path: file, allowUpdate: false) else {
                throw IconNativeGridSourceError.couldNotOpen(file)
            }
            try validateAttributes(group: group, identity: identity)

            let cellCount = identity.cellCount
            let dimensions = Dictionary(
                uniqueKeysWithValues: group.getDimensions().map { ($0.name, $0.length) }
            )
            guard dimensions["cell"] == cellCount else {
                throw IconNativeGridSourceError.invalidAttribute(
                    name: "cell dimension",
                    actual: String(describing: dimensions["cell"])
                )
            }
            guard dimensions["nv"] == 3, let vertexCount = dimensions["vertex"], vertexCount > 0 else {
                throw IconNativeGridSourceError.invalidAttribute(
                    name: "nv/vertex dimensions",
                    actual: String(describing: dimensions)
                )
            }

            let clon = try readDouble(group: group, name: "clon", dimensions: ["cell"])
            let clat = try readDouble(group: group, name: "clat", dimensions: ["cell"])
            guard clon.count == cellCount, clat.count == cellCount else {
                throw IconNativeGridSourceError.invalidTopology("coordinate array length mismatch")
            }

            let centers = try makeCenters(longitudes: clon, latitudes: clat)

            let coverage: IconNativeGrid.CubeArtifact.Coverage
            if identity.isGlobal {
                // Global acceptance needs no raster, so vlat/vlon and vertex connectivity are not read.
                coverage = .global
            } else {
                let vlon = try readDouble(group: group, name: "vlon", dimensions: ["vertex"])
                let vlat = try readDouble(group: group, name: "vlat", dimensions: ["vertex"])
                guard vlon.count == vertexCount, vlat.count == vertexCount else {
                    throw IconNativeGridSourceError.invalidTopology("vertex coordinate array length mismatch")
                }
                let (vertices, bounds) = try makeVertices(longitudes: vlon, latitudes: vlat)
                let verticesRaw = try readInt32(
                    group: group,
                    name: "vertex_of_cell",
                    dimensions: ["nv", "cell"]
                )
                let vertexIndices = try transposeConnectivity(
                    verticesRaw,
                    cellCount: cellCount,
                    upperBound: vertexCount,
                    variable: "vertex_of_cell"
                )
                // Build the acceptance policy while temporary vertex geometry is in scope. SourceData
                // retains only the compact mask, reducing peak memory during artifact serialization.
                coverage = try makeCoverageRaster(
                    vertices: vertices,
                    vertexIndices: vertexIndices,
                    bounds: bounds,
                    step: 0.02
                )
            }

            return SourceData(
                centers: centers,
                coverage: coverage
            )
        }

        private static func makeCoverageRaster(
            vertices: [IconNativeVertex],
            vertexIndices: [UInt32],
            bounds: GridBounds,
            step: Float
        ) throws -> IconNativeGrid.CubeArtifact.Coverage {
            guard !vertices.isEmpty, !vertexIndices.isEmpty, vertexIndices.count.isMultiple(of: 3),
                step.isFinite, step > 0
            else {
                throw IconNativeGridSourceError.invalidTopology("invalid regional coverage geometry")
            }
            let latitudeMinimum = floor(bounds.lat_bounds.lowerBound / step) * step
            let longitudeMinimum = floor(bounds.lon_bounds.lowerBound / step) * step
            let nx = Int(ceil((bounds.lon_bounds.upperBound - longitudeMinimum) / step))
            let ny = Int(ceil((bounds.lat_bounds.upperBound - latitudeMinimum) / step))
            let bitCountResult = nx.multipliedReportingOverflow(by: ny)
            guard nx > 0, ny > 0, !bitCountResult.overflow,
                let byteCount = IconNativeGrid.CubeArtifact.coverageByteCount(
                    bitCount: bitCountResult.partialValue
                )
            else {
                throw IconNativeGridSourceError.invalidTopology("regional coverage dimensions overflow")
            }
            var bits = [UInt8](repeating: 0, count: byteCount)
            for cell in 0..<(vertexIndices.count / 3) {
                try forEachOverlappingBin(
                    cell: cell,
                    vertices: vertices,
                    vertexIndices: vertexIndices,
                    nx: nx,
                    ny: ny,
                    latitudeMinimum: latitudeMinimum,
                    longitudeMinimum: longitudeMinimum,
                    step: step
                ) { bin in
                    bits[bin / 8] |= 1 << UInt8(bin % 8)
                }
            }
            return IconNativeGrid.CubeArtifact.Coverage(
                nx: nx,
                ny: ny,
                latitudeMinimum: Double(latitudeMinimum),
                longitudeMinimum: Double(longitudeMinimum),
                dx: Double(step),
                dy: Double(step),
                bits: bits
            )
        }

        private static func forEachOverlappingBin(
            cell: Int,
            vertices: [IconNativeVertex],
            vertexIndices: [UInt32],
            nx: Int,
            ny: Int,
            latitudeMinimum: Float,
            longitudeMinimum: Float,
            step: Float,
            body: (Int) -> Void
        ) throws {
            let offset = cell * 3
            let a = vertices[Int(vertexIndices[offset])]
            let b = vertices[Int(vertexIndices[offset + 1])]
            let c = vertices[Int(vertexIndices[offset + 2])]
            // A spherical cap centred on vertex `a` and reaching the other two vertices contains the
            // complete small, geodesically convex ICON triangle. Its bounding box may over-select bins
            // but cannot omit a bin that contains part of the triangle.
            let radius = max(angularDistance(a, b), angularDistance(a, c)) + 2e-6
            guard radius.isFinite, radius < .pi else {
                throw IconNativeGridSourceError.invalidTopology("invalid triangle at cell \(cell)")
            }

            // This only matters for deliberately coarse synthetic meshes. Operational ICON cells are
            // much smaller than a hemisphere, but assigning a large triangle to every bin is the safe
            // conservative fallback.
            if radius >= .pi / 2 {
                for y in 0..<ny {
                    for x in 0..<nx { body(y * nx + x) }
                }
                return
            }

            let latitudeRadians = asin(max(-1, min(1, a.z)))
            let latitudeLower = max(-90, (latitudeRadians - radius) * 180 / .pi)
            let latitudeUpper = min(90, (latitudeRadians + radius) * 180 / .pi)
            guard
                let yRange = binRange(
                    lower: latitudeLower,
                    upper: latitudeUpper,
                    origin: latitudeMinimum,
                    step: step,
                    count: ny
                )
            else { return }

            let reachesPole = latitudeRadians - radius <= -.pi / 2 || latitudeRadians + radius >= .pi / 2
            let xRanges: [ClosedRange<Int>]
            if reachesPole {
                xRanges = [0...(nx - 1)]
            } else {
                let ratio = min(1, max(0, sin(radius) / max(1e-12, cos(latitudeRadians))))
                let longitudeRadius = asin(ratio) * 180 / .pi
                let longitude = atan2(a.y, a.x) * 180 / .pi
                let lower = longitude - longitudeRadius
                let upper = longitude + longitudeRadius
                var longitudeRanges = [(Float, Float)]()
                // Longitude intervals crossing the antimeridian are split into the two stored ranges.
                if lower < -180 {
                    longitudeRanges.append((lower + 360, 180))
                    longitudeRanges.append((-180, upper))
                } else if upper > 180 {
                    longitudeRanges.append((lower, 180))
                    longitudeRanges.append((-180, upper - 360))
                } else {
                    longitudeRanges.append((lower, upper))
                }
                xRanges = longitudeRanges.compactMap {
                    binRange(lower: $0.0, upper: $0.1, origin: longitudeMinimum, step: step, count: nx)
                }
            }

            for y in yRange {
                for xRange in xRanges {
                    for x in xRange { body(y * nx + x) }
                }
            }
        }

        private static func binRange(
            lower: Float,
            upper: Float,
            origin: Float,
            step: Float,
            count: Int
        )
            -> ClosedRange<Int>?
        {
            var first = Int(floor((lower - origin) / step))
            var last = Int(floor((upper - origin) / step))
            if last < 0 || first >= count { return nil }
            first = max(0, first)
            last = min(count - 1, last)
            return first <= last ? first...last : nil
        }

        private static func angularDistance(_ lhs: IconNativeVertex, _ rhs: IconNativeVertex) -> Float {
            // `acos(dot)` loses all precision for native D2 edges because their Float dot product can
            // round to exactly one. atan2(sin, cos) remains accurate for very small angular distances.
            let cross = lhs.cross(rhs)
            return atan2(sqrt(max(0, cross.dot(cross))), max(-1, min(1, lhs.dot(rhs))))
        }

        private static func validateAttributes(group: Group, identity: IconNativeGridIdentity) throws {
            guard let gridNumber: Int32 = try group.getAttribute("number_of_grid_used")?.read() else {
                throw IconNativeGridSourceError.missingAttribute("number_of_grid_used")
            }
            guard gridNumber == Int32(identity.gridNumber) else {
                throw IconNativeGridSourceError.invalidAttribute(
                    name: "number_of_grid_used",
                    actual: String(gridNumber)
                )
            }
            guard let uuid = try group.getAttribute("uuidOfHGrid")?.readString() else {
                throw IconNativeGridSourceError.missingAttribute("uuidOfHGrid")
            }
            let normalisedUUID = uuid.lowercased().filter { $0 != "-" }
            guard normalisedUUID == identity.gridUUIDHex else {
                throw IconNativeGridSourceError.invalidAttribute(name: "uuidOfHGrid", actual: uuid)
            }
            // DWD's published grid files do not consistently carry ICON's optional `global_grid`
            // attribute. Grid number, UUID, and the validated cell count uniquely identify the mesh.
        }

        private static func readDouble(
            group: Group,
            name: String,
            dimensions: [String]
        ) throws
            -> [Double]
        {
            guard let variable = group.getVariable(name: name), let typed = variable.asType(Double.self)
            else {
                throw IconNativeGridSourceError.missingVariable(name)
            }
            let actual = variable.dimensions.map(\.name)
            guard actual == dimensions else {
                throw IconNativeGridSourceError.invalidDimensions(variable: name, actual: actual)
            }
            return try typed.read()
        }

        private static func readInt32(
            group: Group,
            name: String,
            dimensions: [String]
        ) throws
            -> [Int32]
        {
            guard let variable = group.getVariable(name: name), let typed = variable.asType(Int32.self)
            else {
                throw IconNativeGridSourceError.missingVariable(name)
            }
            let actual = variable.dimensions.map(\.name)
            guard actual == dimensions else {
                throw IconNativeGridSourceError.invalidDimensions(variable: name, actual: actual)
            }
            return try typed.read()
        }

        private static func makeCenters(
            longitudes: [Double],
            latitudes: [Double]
        ) throws -> [IconNativeCenter] {
            guard longitudes.count == latitudes.count else {
                throw IconNativeGridSourceError.invalidTopology(
                    "coordinate array length mismatch for clon/clat"
                )
            }
            var centers = [IconNativeCenter]()
            centers.reserveCapacity(longitudes.count)
            for index in longitudes.indices {
                let longitude = longitudes[index]
                let latitude = latitudes[index]
                guard longitude.isFinite, latitude.isFinite,
                    longitude >= -.pi - 1e-8, longitude <= .pi + 1e-8,
                    latitude >= -.pi / 2 - 1e-8, latitude <= .pi / 2 + 1e-8
                else {
                    throw IconNativeGridSourceError.invalidValue(variable: "clon/clat", index: index)
                }
                centers.append(IconNativeCenter(latitudeRadians: latitude, longitudeRadians: longitude))
            }
            return centers
        }

        private static func makeVertices(
            longitudes: [Double],
            latitudes: [Double]
        ) throws -> ([IconNativeVertex], GridBounds) {
            guard longitudes.count == latitudes.count, !longitudes.isEmpty else {
                throw IconNativeGridSourceError.invalidTopology("empty vertex coordinate arrays")
            }
            let first = try makeCoordinate(
                longitude: longitudes[0],
                latitude: latitudes[0],
                variable: "vlon/vlat",
                index: 0
            )
            var latitudeMinimum = first.latitude
            var latitudeMaximum = first.latitude
            var longitudeMinimum = first.longitude
            var longitudeMaximum = first.longitude
            var vertices = [IconNativeVertex]()
            vertices.reserveCapacity(longitudes.count)
            for index in longitudes.indices {
                let coordinate =
                    index == 0
                    ? first
                    : try makeCoordinate(
                        longitude: longitudes[index],
                        latitude: latitudes[index],
                        variable: "vlon/vlat",
                        index: index
                    )
                latitudeMinimum = min(latitudeMinimum, coordinate.latitude)
                latitudeMaximum = max(latitudeMaximum, coordinate.latitude)
                longitudeMinimum = min(longitudeMinimum, coordinate.longitude)
                longitudeMaximum = max(longitudeMaximum, coordinate.longitude)
                vertices.append(
                    IconNativeVertex(latitude: coordinate.latitude, longitude: coordinate.longitude)
                )
            }
            return (
                vertices,
                GridBounds(
                    lat_bounds: latitudeMinimum...latitudeMaximum,
                    lon_bounds: longitudeMinimum...longitudeMaximum
                )
            )
        }

        private static func makeCoordinate(
            longitude: Double,
            latitude: Double,
            variable: String,
            index: Int
        ) throws -> LatLon {
            guard longitude.isFinite, latitude.isFinite,
                longitude >= -.pi - 1e-8, longitude <= .pi + 1e-8,
                latitude >= -.pi / 2 - 1e-8, latitude <= .pi / 2 + 1e-8
            else {
                throw IconNativeGridSourceError.invalidValue(variable: variable, index: index)
            }
            return (
                latitude: Float(latitude * 180 / .pi),
                longitude: Float(longitude * 180 / .pi)
            )
        }

        static func transposeConnectivity(
            _ values: [Int32],
            cellCount: Int,
            upperBound: Int,
            variable: String
        ) throws -> [UInt32] {
            guard values.count == cellCount * 3 else {
                throw IconNativeGridSourceError.invalidTopology("\(variable) length mismatch")
            }
            // NetCDF layout: position * cellCount + cell. Artifact layout: cell * 3 + position.
            var result = [UInt32](repeating: 0, count: values.count)
            for cell in 0..<cellCount {
                for position in 0..<3 {
                    let sourceIndex = position * cellCount + cell
                    let value = values[sourceIndex]
                    guard value > 0, value <= upperBound else {
                        throw IconNativeGridSourceError.invalidValue(variable: variable, index: sourceIndex)
                    }
                    result[cell * 3 + position] = UInt32(value - 1)
                }
            }
            return result
        }

    }
}

/// Offline serialization for the mmap-oriented native ICON cube index.
///
/// Keeping this beside the NetCDF generator prevents runtime lookup storage from also owning the
/// considerably larger artifact-construction implementation.
extension IconNativeGrid.Generator {
    enum ArtifactWriter {
        private typealias Artifact = IconNativeGrid.CubeArtifact
        private typealias BucketLayout = Artifact.BucketLayout
        private typealias FaceSection = Artifact.FaceSection

        static func write(
            to file: URL,
            metadata: IconNativeGrid.CubeArtifact.Metadata,
            centers: [IconNativeCenter],
            level: Int,
            maximumFileSize: Int = .max
        ) throws {
            guard !centers.isEmpty, centers.count <= Int(UInt32.max), level >= 0, level <= 15,
                metadata.gridUUID.count == 16,
                metadata.isGlobal == metadata.coverage.bits.isEmpty
            else {
                throw IconNativeGrid.ArtifactError.invalidHeader
            }
            let bucketLayout: BucketLayout = metadata.isGlobal ? .tiled8 : .rowMajor
            var maximumQuantizationErrorMeters = 0.0
            for center in centers {
                let x = Double(Float(center.x))
                let y = Double(Float(center.y))
                let z = Double(Float(center.z))
                let inverseNorm = 1 / sqrt(x * x + y * y + z * z)
                let approximated = IconNativeCenter(
                    x: x * inverseNorm,
                    y: y * inverseNorm,
                    z: z * inverseNorm
                )
                let chord = sqrt(max(0, center.squaredDistance(to: approximated)))
                maximumQuantizationErrorMeters = max(
                    maximumQuantizationErrorMeters,
                    2 * asin(min(1, chord * 0.5)) * 6_371_229
                )
            }
            guard maximumQuantizationErrorMeters <= 2 else {
                throw IconNativeGrid.ArtifactError.invalidHeader
            }

            @inline(__always)
            func storedDirection(_ center: IconNativeCenter) -> IconNativeCenter {
                let x = Float(center.x)
                let y = Float(center.y)
                let z = Float(center.z)
                let inverseNorm =
                    1 / sqrt(Double(x) * Double(x) + Double(y) * Double(y) + Double(z) * Double(z))
                return IconNativeCenter(
                    x: Double(x) * inverseNorm,
                    y: Double(y) * inverseNorm,
                    z: Double(z) * inverseNorm
                )
            }

            let resolution = 1 << level
            var minimumX = [Int](repeating: resolution, count: 6)
            var minimumY = [Int](repeating: resolution, count: 6)
            var maximumX = [Int](repeating: -1, count: 6)
            var maximumY = [Int](repeating: -1, count: 6)
            for (position, center) in centers.enumerated() {
                let normSquared = center.dot(center)
                guard center.x.isFinite, center.y.isFinite, center.z.isFinite,
                    abs(normSquared - 1) <= 2e-15
                else {
                    throw IconNativeGrid.ArtifactError.invalidCenter(position)
                }
                let location = IconNativeGrid.CubeGeometry.location(
                    for: storedDirection(center),
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
                let hasCenters = maximumX[face] >= 0
                let sectionMinimumX = metadata.isGlobal ? 0 : (hasCenters ? minimumX[face] : 0)
                let sectionMinimumY = metadata.isGlobal ? 0 : (hasCenters ? minimumY[face] : 0)
                let columns =
                    metadata.isGlobal
                    ? resolution
                    : (hasCenters ? maximumX[face] - minimumX[face] + 1 : 0)
                let rows =
                    metadata.isGlobal
                    ? resolution
                    : (hasCenters ? maximumY[face] - minimumY[face] + 1 : 0)
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
                throw IconNativeGrid.ArtifactError.invalidHeader
            }

            var counts = [Int](repeating: 0, count: bucketCount)
            for center in centers {
                let location = IconNativeGrid.CubeGeometry.location(
                    for: storedDirection(center),
                    resolution: resolution
                )
                let bucket = faceSections[location.face].bucket(
                    x: location.x,
                    y: location.y,
                    tileShift: bucketLayout.tileShift
                )!
                counts[bucket] += 1
            }
            var offsets = [UInt32](repeating: 0, count: bucketCount + 1)
            for bucket in 0..<bucketCount {
                offsets[bucket + 1] = offsets[bucket] + UInt32(counts[bucket])
            }
            for blockStart in stride(from: 0, through: bucketCount, by: 256) {
                let blockEnd = min(bucketCount, blockStart + 256)
                guard offsets[blockEnd] - offsets[blockStart] <= UInt16.max else {
                    throw IconNativeGrid.ArtifactError.invalidHeader
                }
            }

            var cursors = offsets.dropLast().map(Int.init)
            var order = [UInt32](repeating: 0, count: centers.count)
            var canonicalPositions = [UInt32](repeating: 0, count: centers.count)
            for cell in centers.indices {
                let location = IconNativeGrid.CubeGeometry.location(
                    for: storedDirection(centers[cell]),
                    resolution: resolution
                )
                let bucket = faceSections[location.face].bucket(
                    x: location.x,
                    y: location.y,
                    tileShift: bucketLayout.tileShift
                )!
                order[cursors[bucket]] = UInt32(cell)
                canonicalPositions[cell] = UInt32(cursors[bucket])
                cursors[bucket] += 1
            }

            let coverageBytes = metadata.coverage.bits.count
            let layout = Artifact.SectionLayout(
                cellCount: centers.count,
                bucketCount: bucketCount,
                coverageBytes: coverageBytes
            )
            guard layout.fileBytes <= maximumFileSize else {
                throw IconNativeGrid.ArtifactError.artifactTooLarge(
                    actual: layout.fileBytes,
                    maximum: maximumFileSize
                )
            }

            var data = Data(repeating: 0, count: layout.fileBytes)
            data.replaceSubrange(0..<Artifact.magic.count, with: Artifact.magic)
            data.writeCubeInteger(Artifact.version, at: 8)
            data.writeCubeInteger(metadata.isGlobal ? Artifact.globalFlag : 0, at: 12)
            data.writeCubeInteger(metadata.gridNumber, at: 16)
            data.writeCubeInteger(UInt32(centers.count), at: 20)
            data.writeCubeInteger(UInt32(level), at: 24)
            data.writeCubeInteger(UInt32(metadata.coverage.nx), at: 28)
            data.writeCubeInteger(UInt32(metadata.coverage.ny), at: 32)
            data.replaceSubrange(36..<52, with: metadata.gridUUID)
            data.writeCubeDouble(metadata.coverage.latitudeMinimum, at: 56)
            data.writeCubeDouble(metadata.coverage.longitudeMinimum, at: 64)
            data.writeCubeDouble(metadata.coverage.dx, at: 72)
            data.writeCubeDouble(metadata.coverage.dy, at: 80)

            for (face, section) in faceSections.enumerated() {
                let offset = Artifact.faceSectionsOffset + face * Artifact.faceSectionStride
                data.writeCubeInteger(UInt32(section.minimumX), at: offset)
                data.writeCubeInteger(UInt32(section.minimumY), at: offset + 4)
                data.writeCubeInteger(UInt32(section.columns), at: offset + 8)
                data.writeCubeInteger(UInt32(section.rows), at: offset + 12)
            }
            let baseCount = bucketCount / 256 + 1
            for block in 0..<baseCount {
                data.writeCubeInteger(
                    offsets[min(bucketCount, block * 256)],
                    at: layout.offsetsOffset + block * 4
                )
            }
            let localsOffset = layout.offsetsOffset + baseCount * 4
            for index in offsets.indices {
                let base = offsets[(index >> 8) * 256]
                data.writeCubeInteger(UInt16(offsets[index] - base), at: localsOffset + index * 2)
            }
            for (position, cellValue) in order.enumerated() {
                let center = centers[Int(cellValue)]
                let offset = layout.centersOffset + position * Artifact.centerStride
                let x = Float(center.x)
                let y = Float(center.y)
                let z = Float(center.z)
                data.writeCubeFloat(x, at: offset)
                data.writeCubeFloat(y, at: offset + 4)
                data.writeCubeFloat(z, at: offset + 8)
                data.writeCubeInteger(cellValue, at: offset + 12)
            }
            for (cell, position) in canonicalPositions.enumerated() {
                data.writeCubeInteger(position, at: layout.canonicalPositionsOffset + cell * 4)
            }
            data.replaceSubrange(
                layout.coverageOffset..<(layout.coverageOffset + coverageBytes),
                with: metadata.coverage.bits
            )
            try data.write(to: file, options: .atomic)
        }
    }
}

extension Data {
    fileprivate mutating func writeCubeInteger<T: FixedWidthInteger>(_ value: T, at offset: Int) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) {
            replaceSubrange(offset..<(offset + $0.count), with: $0)
        }
    }

    fileprivate mutating func writeCubeDouble(_ value: Double, at offset: Int) {
        writeCubeInteger(value.bitPattern, at: offset)
    }

    fileprivate mutating func writeCubeFloat(_ value: Float, at offset: Int) {
        writeCubeInteger(value.bitPattern, at: offset)
    }
}
