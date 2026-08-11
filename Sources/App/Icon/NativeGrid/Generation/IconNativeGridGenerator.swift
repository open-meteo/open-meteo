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
        static func generate(
            sourceFile: String,
            identity: IconNativeGridIdentity,
            artifactFile: String
        )
            throws -> IconNativeGrid
        {
            let points = try readSource(file: sourceFile, identity: identity)
            let maximumFileSize = identity.isGlobal ? 128 * 1_024 * 1_024 : 32 * 1_024 * 1_024
            let maximumAngle = Double(identity.maximumDistanceMeters) / 6_371_229
            let maximumChord = 2 * sin(maximumAngle * 0.5)
            let metadata = SphericalCubeArtifact.Metadata(
                identity: .init(number: identity.gridNumber, uuid: identity.gridUUID),
                coversWholeSphere: identity.isGlobal,
                maximumChordDistanceSquared: Float(maximumChord * maximumChord)
            )
            try SphericalCubeArtifact.Writer.write(
                to: URL(fileURLWithPath: artifactFile),
                metadata: metadata,
                points: points,
                level: identity.isGlobal ? 9 : 11,
                maximumFileSize: maximumFileSize
            )
            return try IconNativeGrid.load(file: URL(fileURLWithPath: artifactFile))
        }

        /// Cell arrays remain in NetCDF/GRIB order; this makes a cell index directly usable as the
        /// location offset in native forecast files.
        static func readSource(file: String, identity: IconNativeGridIdentity) throws -> [SphericalPoint] {
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
            -> [SphericalPoint]
        {
            guard let group = try NetCDF.open(path: file, allowUpdate: false) else {
                throw IconNativeGridSourceError.couldNotOpen(file)
            }
            try validateAttributes(group: group, identity: identity)

            let cellCount = identity.cellCount
            let clon = try readDouble(group: group, name: "clon")
            let clat = try readDouble(group: group, name: "clat")
            guard clon.count == cellCount, clat.count == cellCount else {
                throw IconNativeGridSourceError.invalidTopology("coordinate array length mismatch")
            }

            return try makePoints(longitudes: clon, latitudes: clat)
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
            name: String
        ) throws
            -> [Double]
        {
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

        private static func makePoints(
            longitudes: [Double],
            latitudes: [Double]
        ) throws -> [SphericalPoint] {
            var points = [SphericalPoint]()
            points.reserveCapacity(longitudes.count)
            for index in longitudes.indices {
                let longitude = longitudes[index]
                let latitude = latitudes[index]
                guard longitude.isFinite, latitude.isFinite,
                    longitude >= -.pi - 1e-8, longitude <= .pi + 1e-8,
                    latitude >= -.pi / 2 - 1e-8, latitude <= .pi / 2 + 1e-8
                else {
                    throw IconNativeGridSourceError.invalidValue(variable: "clon/clat", index: index)
                }
                points.append(SphericalPoint(latitudeRadians: latitude, longitudeRadians: longitude))
            }
            return points
        }

    }
}
