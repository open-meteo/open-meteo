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

/// Offline converter from DWD's official ICON grid NetCDF to the compact, mmap-oriented runtime
/// artifact. Spatial-index work belongs here, never in API coordinate lookup.
extension IconNativeGrid {
    enum Generator {
        struct SourceData {
            /// Cell arrays remain in NetCDF/GRIB order; this makes a cell index directly usable as the
            /// location offset in native forecast files.
            let centers: [IconNativeCenter]
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
                maximumDistanceMeters: identity.maximumDistanceMeters
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
            let clon = try readDouble(group: group, name: "clon", dimensions: ["cell"])
            let clat = try readDouble(group: group, name: "clat", dimensions: ["cell"])
            guard clon.count == cellCount, clat.count == cellCount else {
                throw IconNativeGridSourceError.invalidTopology("coordinate array length mismatch")
            }

            return SourceData(centers: try makeCenters(longitudes: clon, latitudes: clat))
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
                metadata.maximumDistanceMeters.isFinite, metadata.maximumDistanceMeters > 0
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

            let layout = Artifact.SectionLayout(
                cellCount: centers.count,
                bucketCount: bucketCount
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
            data.writeCubeFloat(metadata.maximumDistanceMeters, at: 28)
            data.replaceSubrange(32..<48, with: metadata.gridUUID)

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

    fileprivate mutating func writeCubeFloat(_ value: Float, at offset: Int) {
        writeCubeInteger(value.bitPattern, at: offset)
    }
}
