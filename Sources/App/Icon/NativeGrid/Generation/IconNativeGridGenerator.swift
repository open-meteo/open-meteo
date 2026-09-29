import Foundation
import OmFileFormat
import ReducedLatLon
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

/// Offline converter from DWD's official ICON grid NetCDF to a provider-neutral reduced latitude–longitude
/// artifact. It preserves NetCDF cell order as canonical point IDs and supplies ICON-specific
/// identity, coverage, resolution, distance, and size policies. Spatial-index construction belongs
/// here, never in API coordinate lookup.
extension IconNativeGrid {
    enum Generator {
        typealias Coordinates = (latitudes: [Double], longitudes: [Double])

        /// Builds from an official NetCDF mesh, validates the unpublished artifact and identity,
        /// writes missing coordinates from the same source, then atomically publishes the artifact.
        /// Generation and validation failures leave an existing artifact untouched.
        static func generateAndPublish(
            sourceFile: String,
            identity: IconNativeGridIdentity,
            artifactFile: String,
            coordinatesFile: String
        )
            throws -> (grid: IconNativeGrid, coordinatesGenerated: Bool)
        {
            let coordinates = try readCoordinates(file: sourceFile, identity: identity)
            return try generateAndPublish(
                coordinates: coordinates, identity: identity,
                artifactFile: artifactFile, coordinatesFile: coordinatesFile
            )
        }

        /// Reuses coordinates already validated by readCoordinates, without reopening the mesh.
        static func generateAndPublish(
            coordinates: Coordinates,
            identity: IconNativeGridIdentity,
            artifactFile: String,
            coordinatesFile: String
        ) throws -> (grid: IconNativeGrid, coordinatesGenerated: Bool) {
            let points = zip(coordinates.latitudes, coordinates.longitudes).map {
                ReducedLatLonPoint(latitudeRadians: $0, longitudeRadians: $1)
            }
            let maximumFileSize = identity.isGlobal ? 128 * 1_024 * 1_024 : 32 * 1_024 * 1_024
            let metadata = ReducedLatLonArtifact.Metadata(
                number: identity.gridNumber, uuid: identity.gridUUID.bytes,
                coversWholeSphere: identity.isGlobal
            )
            let artifactHandle = try FileHandle.createNewFile(
                file: artifactFile,
                overwrite: true,
                temporary: true
            )
            try ReducedLatLonArtifact.Writer.write(
                to: artifactHandle,
                metadata: metadata,
                points: points,
                latitudeBandCount: identity.latitudeBandCount,
                maximumFileSize: maximumFileSize
            )
            let storage = try identity.loadStorage(mapped: MmapFile(fn: artifactHandle), path: artifactFile)
            let grid = IconNativeGrid(storage: storage,
                resolutionMeters: identity.resolutionMeters,
                maximumChordDistanceSquared: identity.maximumChordDistanceSquared,
                nearbyMaximumChordDistanceSquared: identity.nearbyMaximumChordDistanceSquared)
            let coordinatesGenerated = try writeCoordinatesOmFileIfMissing(
                file: coordinatesFile, latitudes: coordinates.latitudes, longitudes: coordinates.longitudes
            )
            try artifactHandle.linkTemporary(file: artifactFile)
            return (grid, coordinatesGenerated)
        }

        /// Cell arrays remain in NetCDF/GRIB order; this makes a cell index directly usable as the
        /// location offset in native forecast files.
        static func readCoordinates(file: String, identity: IconNativeGridIdentity) throws -> Coordinates {
            do {
                guard let group = try NetCDF.open(path: file, allowUpdate: false) else {
                    throw IconNativeGridSourceError.couldNotOpen(file)
                }
                return try readCoordinates(group: group, identity: identity)
            } catch let error as IconNativeGridSourceError {
                throw error
            } catch {
                throw IconNativeGridSourceError.io(path: file, reason: String(describing: error))
            }
        }

        static func readCoordinates(group: Group, identity: IconNativeGridIdentity) throws -> Coordinates {
            try validateAttributes(group: group, identity: identity)
            let latitudes = try readDouble(group: group, name: "clat")
            let longitudes = try readDouble(group: group, name: "clon")
            guard latitudes.count == identity.cellCount, longitudes.count == identity.cellCount else {
                throw IconNativeGridSourceError.invalidTopology("coordinate array length mismatch")
            }
            for index in latitudes.indices {
                let latitude = latitudes[index], longitude = longitudes[index]
                guard latitude.isFinite, longitude.isFinite,
                      abs(latitude) <= .pi / 2 + 1e-8, abs(longitude) <= .pi + 1e-8 else {
                    throw IconNativeGridSourceError.invalidValue(variable: "clon/clat", index: index)
                }
            }
            return (latitudes, longitudes)
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
            guard normalisedUUID == identity.gridUUID.hexString else {
                throw IconNativeGridSourceError.invalidAttribute(name: "uuidOfHGrid", actual: uuid)
            }
            // DWD's published grid files do not consistently carry ICON's optional `global_grid`
            // attribute. Grid number, UUID, and the validated cell count uniquely identify the mesh.
        }

        private static func readDouble(group: Group, name: String) throws -> [Double] {
            guard let variable = group.getVariable(name: name), let typed = variable.asType(Double.self)
            else {
                throw IconNativeGridSourceError.missingVariable(name)
            }
            let actual = variable.dimensions.map(\.name)
            guard actual == ["cell"] else {
                throw IconNativeGridSourceError.invalidDimensions(variable: name, actual: actual)
            }
            return try typed.read()
        }

        /// Uses the validated source coordinates directly, before Cartesian Float32 rounding.
        private static func writeCoordinatesOmFileIfMissing(file: String, latitudes: [Double], longitudes: [Double]) throws -> Bool {
            guard !FileManager.default.fileExists(atPath: file) else {
                return false
            }
            let handle = try FileHandle.createNewFile(file: file, overwrite: true, temporary: true)
            let writer = OmFileWriter(fn: handle, initialCapacity: 4 * 1_024)
            func writeCoordinate(_ values: [Double], name: String, unit: String) throws -> OmOffsetSize {
                let array = try writer.writeArray(
                    data: values.map { Float($0 * 180 / .pi) },
                    dimensions: [1, UInt64(values.count)],
                    chunkDimensions: [1, UInt64(min(400, values.count))],
                    compression: .fpx_xor2d,
                    scale_factor: 1,
                    add_offset: 0
                )
                let unit = try writer.write(value: unit, name: "unit", children: [])
                return try writer.write(array: array, name: name, children: [unit])
            }
            let latitude = try writeCoordinate(latitudes, name: "lat", unit: "degrees_north")
            let longitude = try writeCoordinate(longitudes, name: "lon", unit: "degrees_east")
            let createdAt = try writer.write(value: Timestamp.now().timeIntervalSince1970, name: "created_at", children: [])
            let root = try writer.writeNone(name: "", children: [latitude, longitude, createdAt])
            try writer.writeTrailer(rootVariable: root)
            try handle.linkTemporary(file: file)
            return true
        }
    }
}
