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
        case .invalidAttribute(let name, let actual): "Invalid ICON grid NetCDF attribute '\(name)': \(actual)"
        case .missingVariable(let name): "Missing ICON grid NetCDF variable '\(name)'"
        case .invalidDimensions(let variable, let actual): "Invalid dimensions for ICON grid variable '\(variable)': \(actual.joined(separator: ","))"
        case .invalidValue(let variable, let index): "Invalid value in ICON grid variable '\(variable)' at index \(index)"
        case .invalidTopology(let reason): "Invalid ICON grid topology: \(reason)"
        }
    }
}

/// Offline converter from DWD's official ICON grid NetCDF to the compact, mmap-oriented runtime
/// artifact. Expensive topology and spatial-index work belongs here, never in API coordinate lookup.
enum IconNativeGridGenerator {
    struct SourceData {
        /// Cell arrays remain in NetCDF/GRIB order; this makes a cell index directly usable as the
        /// location offset in native forecast files.
        let centers: [LatLon]
        let neighbourIndices: [UInt32]
        let vertexIndices: [UInt32]
        let vertices: [SphericalPoint]
        let bounds: GridBounds
    }

    struct SpatialIndex: Sendable {
        let nx: Int
        let ny: Int
        let latitudeMinimum: Float
        let longitudeMinimum: Float
        let dx: Float
        let dy: Float
        let offsets: [UInt32]
        let cells: [UInt32]
    }

    static func generate(sourceFile: String, identity: IconNativeGridIdentity, artifactFile: String) throws -> IconNativeGrid {
        let source = try readSource(file: sourceFile, identity: identity)
        let bounds = source.bounds
        // Budgets catch accidental index explosions caused by malformed geometry or an unsuitable
        // bin resolution before a very large artifact is installed.
        let maximumFileSize = identity.isGlobal ? 256 * 1_024 * 1_024 : 64 * 1_024 * 1_024
        let fixedBytes = estimatedFixedArtifactBytes(cellCount: source.centers.count, vertexCount: source.vertices.count)
        let index = try makeSpatialIndex(
            vertices: source.vertices,
            vertexIndices: source.vertexIndices,
            isGlobal: identity.isGlobal,
            bounds: bounds,
            step: identity.isGlobal ? 0.25 : 0.04,
            fixedArtifactBytes: fixedBytes,
            maximumFileSize: maximumFileSize
        )
        let metadata = IconNativeGridArtifact.Metadata(
            gridNumber: identity.gridNumber,
            gridUUID: identity.gridUUID,
            isGlobal: identity.isGlobal,
            bounds: bounds,
            binNx: index.nx,
            binNy: index.ny,
            binLatMin: index.latitudeMinimum,
            binLonMin: index.longitudeMinimum,
            binDx: index.dx,
            binDy: index.dy
        )
        try IconNativeGridArtifact.write(
            to: artifactFile,
            metadata: metadata,
            centers: source.centers,
            vertices: source.vertices,
            vertexIndices: source.vertexIndices,
            neighbourIndices: source.neighbourIndices,
            binOffsets: index.offsets,
            binCells: index.cells,
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

    private static func readSourceUnchecked(file: String, identity: IconNativeGridIdentity) throws -> SourceData {
        guard let group = try NetCDF.open(path: file, allowUpdate: false) else {
            throw IconNativeGridSourceError.couldNotOpen(file)
        }
        try validateAttributes(group: group, identity: identity)

        let cellCount = identity.cellCount
        let dimensions = Dictionary(uniqueKeysWithValues: group.getDimensions().map { ($0.name, $0.length) })
        guard dimensions["cell"] == cellCount else {
            throw IconNativeGridSourceError.invalidAttribute(name: "cell dimension", actual: String(describing: dimensions["cell"]))
        }
        guard dimensions["nv"] == 3, let vertexCount = dimensions["vertex"], vertexCount > 0 else {
            throw IconNativeGridSourceError.invalidAttribute(name: "nv/vertex dimensions", actual: String(describing: dimensions))
        }

        let clon = try readDouble(group: group, name: "clon", dimensions: ["cell"])
        let clat = try readDouble(group: group, name: "clat", dimensions: ["cell"])
        let vlon = try readDouble(group: group, name: "vlon", dimensions: ["vertex"])
        let vlat = try readDouble(group: group, name: "vlat", dimensions: ["vertex"])
        guard clon.count == cellCount, clat.count == cellCount,
              vlon.count == vertexCount, vlat.count == vertexCount else {
            throw IconNativeGridSourceError.invalidTopology("coordinate array length mismatch")
        }

        let centers = try makeCoordinates(longitudes: clon, latitudes: clat, variable: "clon/clat")
        let (vertices, vertexBounds) = try makeVertices(longitudes: vlon, latitudes: vlat)

        // ICON stores connectivity as three complete `(nv, cell)` planes with one-based indices.
        // The artifact uses cell-major, zero-based triples for direct random access at runtime.
        let neighboursRaw = try readInt32(group: group, name: "neighbor_cell_index", dimensions: ["nv", "cell"])
        let verticesRaw = try readInt32(group: group, name: "vertex_of_cell", dimensions: ["nv", "cell"])
        let neighbourIndices = try transposeConnectivity(
            neighboursRaw,
            cellCount: cellCount,
            upperBound: cellCount,
            variable: "neighbor_cell_index",
            allowsMissing: true
        )
        let vertexIndices = try transposeConnectivity(
            verticesRaw,
            cellCount: cellCount,
            upperBound: vertexCount,
            variable: "vertex_of_cell",
            allowsMissing: false
        )
        try validateTopology(neighbourIndices: neighbourIndices, cellCount: cellCount)

        return SourceData(
            centers: centers,
            neighbourIndices: neighbourIndices,
            vertexIndices: vertexIndices,
            vertices: vertices,
            bounds: identity.isGlobal
                ? GridBounds(lat_bounds: -90...90, lon_bounds: -180...180)
                : vertexBounds
        )
    }

    /// Build a conservative triangle-to-bin CSR index. The operation is deliberately offline;
    /// production lookup reads one already-bounded candidate range directly from the mmap.
    static func makeSpatialIndex(
        vertices: [SphericalPoint],
        vertexIndices: [UInt32],
        isGlobal: Bool,
        bounds: GridBounds,
        step: Float,
        fixedArtifactBytes: Int = 0,
        maximumFileSize: Int = .max
    ) throws -> SpatialIndex {
        guard !vertices.isEmpty,
              !vertexIndices.isEmpty,
              vertexIndices.count.isMultiple(of: 3),
              step.isFinite,
              step > 0 else {
            throw IconNativeGridError.invalidHeader
        }
        let cellCount = vertexIndices.count / 3
        for cell in 0..<cellCount {
            for position in 0..<3 where vertexIndices[cell * 3 + position] >= UInt32(vertices.count) {
                throw IconNativeGridError.invalidTriangle(cell)
            }
            let offset = cell * 3
            let triangle = SphericalTriangle(
                a: vertices[Int(vertexIndices[offset])],
                b: vertices[Int(vertexIndices[offset + 1])],
                c: vertices[Int(vertexIndices[offset + 2])]
            )
            guard triangle.isValid else {
                throw IconNativeGridError.invalidTriangle(cell)
            }
        }

        let latitudeMinimum: Float
        let longitudeMinimum: Float
        let nx: Int
        let ny: Int
        if isGlobal {
            latitudeMinimum = -90
            longitudeMinimum = -180
            nx = Int((360 / step).rounded())
            ny = Int((180 / step).rounded())
        } else {
            latitudeMinimum = floor(bounds.lat_bounds.lowerBound / step) * step
            longitudeMinimum = floor(bounds.lon_bounds.lowerBound / step) * step
            nx = Int(ceil((bounds.lon_bounds.upperBound - longitudeMinimum) / step))
            ny = Int(ceil((bounds.lat_bounds.upperBound - latitudeMinimum) / step))
        }
        let binCountResult = nx.multipliedReportingOverflow(by: ny)
        guard nx > 0, ny > 0, !binCountResult.overflow else { throw IconNativeGridError.invalidHeader }
        let binCount = binCountResult.partialValue
        let offsetBytes = (binCount + 1).multipliedReportingOverflow(by: 4)
        guard !offsetBytes.overflow else { throw IconNativeGridError.invalidHeader }
        let minimumSize = fixedArtifactBytes.addingReportingOverflow(offsetBytes.partialValue)
        guard !minimumSize.overflow, minimumSize.partialValue <= maximumFileSize else {
            throw IconNativeGridError.artifactTooLarge(actual: minimumSize.partialValue, maximum: maximumFileSize)
        }

        // First pass counts triangle references per bin. It determines both the work bound and
        // the exact CSR allocation without building millions of small Swift arrays.
        var counts = [UInt32](repeating: 0, count: binCount)
        for cell in 0..<cellCount {
            try forEachOverlappingBin(
                cell: cell,
                vertices: vertices,
                vertexIndices: vertexIndices,
                nx: nx,
                ny: ny,
                latitudeMinimum: latitudeMinimum,
                longitudeMinimum: longitudeMinimum,
                step: step,
                isGlobal: isGlobal
            ) { bin in
                let increment = counts[bin].addingReportingOverflow(1)
                guard !increment.overflow else { throw IconNativeGridError.invalidBinOffset(bin) }
                counts[bin] = increment.partialValue
            }
        }
        var maximum = 0
        var maximumBin = 0
        for bin in counts.indices where Int(counts[bin]) > maximum {
            maximum = Int(counts[bin])
            maximumBin = bin
        }
        if isGlobal, let empty = counts.firstIndex(of: 0) {
            throw IconNativeGridError.invalidBinOffset(empty)
        }
        guard maximum <= IconNativeGrid.maximumCandidateCount else {
            throw IconNativeGridError.candidateLimit(bin: maximumBin, count: maximum)
        }

        // Prefix sums form the CSR offsets. Candidate cell identifiers are UInt32 because both
        // operational grids are far below that limit and the native GRIB index is also linear.
        var offsets = [UInt32](repeating: 0, count: binCount + 1)
        var total: UInt64 = 0
        for bin in counts.indices {
            total += UInt64(counts[bin])
            guard total <= UInt64(UInt32.max) else { throw IconNativeGridError.invalidBinOffset(bin) }
            offsets[bin + 1] = UInt32(total)
        }
        let candidateBytes = Int(total).multipliedReportingOverflow(by: 4)
        let actualSize = minimumSize.partialValue.addingReportingOverflow(candidateBytes.partialValue)
        guard !candidateBytes.overflow, !actualSize.overflow, actualSize.partialValue <= maximumFileSize else {
            throw IconNativeGridError.artifactTooLarge(actual: actualSize.partialValue, maximum: maximumFileSize)
        }

        // Reuse the count array as insertion cursors for the second pass. Cells are visited in
        // ascending order, so every bin's candidate range is already sorted and deterministic.
        for bin in counts.indices { counts[bin] = offsets[bin] }
        var cells = [UInt32](repeating: 0, count: Int(total))
        for cell in 0..<cellCount {
            try forEachOverlappingBin(
                cell: cell,
                vertices: vertices,
                vertexIndices: vertexIndices,
                nx: nx,
                ny: ny,
                latitudeMinimum: latitudeMinimum,
                longitudeMinimum: longitudeMinimum,
                step: step,
                isGlobal: isGlobal
            ) { bin in
                let destination = Int(counts[bin])
                cells[destination] = UInt32(cell)
                counts[bin] += 1
            }
        }
        return SpatialIndex(
            nx: nx,
            ny: ny,
            latitudeMinimum: latitudeMinimum,
            longitudeMinimum: longitudeMinimum,
            dx: step,
            dy: step,
            offsets: offsets,
            cells: cells
        )
    }

    private static func forEachOverlappingBin(
        cell: Int,
        vertices: [SphericalPoint],
        vertexIndices: [UInt32],
        nx: Int,
        ny: Int,
        latitudeMinimum: Float,
        longitudeMinimum: Float,
        step: Float,
        isGlobal: Bool,
        body: (Int) throws -> Void
    ) throws {
        let offset = cell * 3
        let a = vertices[Int(vertexIndices[offset])]
        let b = vertices[Int(vertexIndices[offset + 1])]
        let c = vertices[Int(vertexIndices[offset + 2])]
        // A spherical cap centred on vertex `a` and reaching the other two vertices contains the
        // complete small, geodesically convex ICON triangle. Its bounding box may over-select bins
        // but cannot omit a bin that contains part of the triangle.
        let radius = max(angularDistance(a, b), angularDistance(a, c)) + 2e-6
        guard radius.isFinite, radius < .pi else { throw IconNativeGridError.invalidTriangle(cell) }

        // This only matters for deliberately coarse synthetic meshes. Operational ICON cells are
        // much smaller than a hemisphere, but assigning a large triangle to every bin is the safe
        // conservative fallback.
        if radius >= .pi / 2 {
            for y in 0..<ny {
                for x in 0..<nx { try body(y * nx + x) }
            }
            return
        }

        let latitudeRadians = asin(max(-1, min(1, a.z)))
        let latitudeLower = max(-90, (latitudeRadians - radius) * 180 / .pi)
        let latitudeUpper = min(90, (latitudeRadians + radius) * 180 / .pi)
        guard let yRange = binRange(
            lower: latitudeLower,
            upper: latitudeUpper,
            origin: latitudeMinimum,
            step: step,
            count: ny
        ) else { return }

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
            if isGlobal, lower < -180 {
                longitudeRanges.append((lower + 360, 180))
                longitudeRanges.append((-180, upper))
            } else if isGlobal, upper > 180 {
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
                for x in xRange { try body(y * nx + x) }
            }
        }
    }

    private static func binRange(lower: Float, upper: Float, origin: Float, step: Float, count: Int) -> ClosedRange<Int>? {
        var first = Int(floor((lower - origin) / step))
        var last = Int(floor((upper - origin) / step))
        if last < 0 || first >= count { return nil }
        first = max(0, first)
        last = min(count - 1, last)
        return first <= last ? first...last : nil
    }

    private static func angularDistance(_ lhs: SphericalPoint, _ rhs: SphericalPoint) -> Float {
        // `acos(dot)` loses all precision for native D2 edges because their Float dot product can
        // round to exactly one. atan2(sin, cos) remains accurate for very small angular distances.
        let cross = lhs.cross(rhs)
        return atan2(sqrt(max(0, cross.dot(cross))), max(-1, min(1, lhs.dot(rhs))))
    }

    private static func estimatedFixedArtifactBytes(cellCount: Int, vertexCount: Int) -> Int {
        func aligned(_ value: Int) -> Int { (value + 7) / 8 * 8 }
        return aligned(IconNativeGridArtifact.headerSize)
            + aligned(cellCount * 8)
            + aligned(vertexCount * 12)
            + aligned(cellCount * 12)
            + aligned(cellCount * 12)
    }

    private static func validateAttributes(group: Group, identity: IconNativeGridIdentity) throws {
        guard let gridNumber: Int32 = try group.getAttribute("number_of_grid_used")?.read() else {
            throw IconNativeGridSourceError.missingAttribute("number_of_grid_used")
        }
        guard gridNumber == Int32(identity.gridNumber) else {
            throw IconNativeGridSourceError.invalidAttribute(name: "number_of_grid_used", actual: String(gridNumber))
        }
        guard let uuid = try group.getAttribute("uuidOfHGrid")?.readString() else {
            throw IconNativeGridSourceError.missingAttribute("uuidOfHGrid")
        }
        let normalisedUUID = uuid.lowercased().filter { $0 != "-" }
        guard normalisedUUID == identity.gridUUIDHex else {
            throw IconNativeGridSourceError.invalidAttribute(name: "uuidOfHGrid", actual: uuid)
        }
        guard let globalGrid: Int32 = try group.getAttribute("global_grid")?.read() else {
            throw IconNativeGridSourceError.missingAttribute("global_grid")
        }
        guard (globalGrid != 0) == identity.isGlobal else {
            throw IconNativeGridSourceError.invalidAttribute(name: "global_grid", actual: String(globalGrid))
        }
    }

    private static func readDouble(group: Group, name: String, dimensions: [String]) throws -> [Double] {
        guard let variable = group.getVariable(name: name), let typed = variable.asType(Double.self) else {
            throw IconNativeGridSourceError.missingVariable(name)
        }
        let actual = variable.dimensions.map(\.name)
        guard actual == dimensions else { throw IconNativeGridSourceError.invalidDimensions(variable: name, actual: actual) }
        return try typed.read()
    }

    private static func readInt32(group: Group, name: String, dimensions: [String]) throws -> [Int32] {
        guard let variable = group.getVariable(name: name), let typed = variable.asType(Int32.self) else {
            throw IconNativeGridSourceError.missingVariable(name)
        }
        let actual = variable.dimensions.map(\.name)
        guard actual == dimensions else { throw IconNativeGridSourceError.invalidDimensions(variable: name, actual: actual) }
        return try typed.read()
    }

    private static func makeCoordinates(
        longitudes: [Double],
        latitudes: [Double],
        variable: String
    ) throws -> [LatLon] {
        guard longitudes.count == latitudes.count else {
            throw IconNativeGridSourceError.invalidTopology("coordinate array length mismatch for \(variable)")
        }
        var coordinates = [LatLon]()
        coordinates.reserveCapacity(longitudes.count)

        for index in longitudes.indices {
            coordinates.append(try makeCoordinate(
                longitude: longitudes[index],
                latitude: latitudes[index],
                variable: variable,
                index: index
            ))
        }
        return coordinates
    }

    private static func makeVertices(
        longitudes: [Double],
        latitudes: [Double]
    ) throws -> ([SphericalPoint], GridBounds) {
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
        var vertices = [SphericalPoint](); vertices.reserveCapacity(longitudes.count)
        for index in longitudes.indices {
            let coordinate = index == 0 ? first : try makeCoordinate(
                longitude: longitudes[index],
                latitude: latitudes[index],
                variable: "vlon/vlat",
                index: index
            )
            latitudeMinimum = min(latitudeMinimum, coordinate.latitude)
            latitudeMaximum = max(latitudeMaximum, coordinate.latitude)
            longitudeMinimum = min(longitudeMinimum, coordinate.longitude)
            longitudeMaximum = max(longitudeMaximum, coordinate.longitude)
            vertices.append(SphericalPoint(latitude: coordinate.latitude, longitude: coordinate.longitude))
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
              latitude >= -.pi / 2 - 1e-8, latitude <= .pi / 2 + 1e-8 else {
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
        variable: String,
        allowsMissing: Bool
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
                if value < 0, allowsMissing {
                    result[cell * 3 + position] = IconNativeGrid.missingIndex
                    continue
                }
                guard value > 0, value <= upperBound else {
                    throw IconNativeGridSourceError.invalidValue(variable: variable, index: sourceIndex)
                }
                result[cell * 3 + position] = UInt32(value - 1)
            }
        }
        return result
    }

    private static func validateTopology(neighbourIndices: [UInt32], cellCount: Int) throws {
        for cell in 0..<cellCount {
            for position in 0..<3 {
                let neighbour = neighbourIndices[cell * 3 + position]
                if neighbour == IconNativeGrid.missingIndex { continue }
                guard neighbour < UInt32(cellCount), neighbour != UInt32(cell) else {
                    throw IconNativeGridSourceError.invalidTopology("invalid neighbour \(neighbour) for cell \(cell)")
                }
                let other = Int(neighbour) * 3
                guard neighbourIndices[other..<(other + 3)].contains(UInt32(cell)) else {
                    throw IconNativeGridSourceError.invalidTopology("asymmetric neighbour relation \(cell)-\(neighbour)")
                }
            }
        }
    }

}
