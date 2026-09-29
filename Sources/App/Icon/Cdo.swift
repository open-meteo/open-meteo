import Foundation
import SwiftNetCDF

struct IconRemapper: Sendable {
    let mapping: [Int32]

    func remap(_ source: [Float]) -> [Float] {
        mapping.map { index in
            guard index >= 0 else {
                return .nan
            }
            return source[Int(index)]
        }
    }

    /// Reuse historical weights where native input was already processed; otherwise build from the native index.
    /// For DWD ICON D2 this yields a mapping equivalent to the data produced by DWD themselves.
    /// For ICON EU data is not equivalent. Regular lat-lon output on ICON EU uses RBF or BCT interpolation
    /// during regridding. Here everything is currently nearest neighbour regridding, same as what CDO does.
    init(curl: Curl, domain: IconDomains) async throws {
        guard [.icon, .iconEu, .iconD2, .iconEps, .iconEuEps, .iconD2Eps].contains(domain),
              let target = domain.grid as? RegularGrid else {
            throw IconDownloadError(description: "No regular remapping grid for \(domain)")
        }
        if [.icon, .iconEps, .iconEuEps, .iconD2Eps].contains(domain) {
            // Preserve the original CDO tie-breaking and missing-value mask for unchanged source grids.
            let directory = "\(domain.domainRegistry.directory)static/"
            let weightsFile = "\(directory)cdo_weights.nc"
            if !FileManager.default.fileExists(atPath: weightsFile) {
                try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
                try await curl.download(
                    url: "https://openmeteo.s3.amazonaws.com/data/\(domain.domainRegistry.rawValue)/static/cdo_weights.nc",
                    toFile: weightsFile, bzip2Decode: false
                )
            }
            guard let weights = try NetCDF.open(path: weightsFile, allowUpdate: false),
                  let src = try weights.getVariable(name: "src_address")?.asType(Int32.self)?.read(),
                  let dst = try weights.getVariable(name: "dst_address")?.asType(Int32.self)?.read(),
                  src.count == dst.count, !src.isEmpty,
                  src.allSatisfy({ $0 > 0 && $0 <= domain.sourceGridIdentity.cellCount }),
                  dst.allSatisfy({ $0 > 0 && $0 <= target.count }) else {
                throw IconDownloadError(description: "Invalid remapping weights: \(weightsFile)")
            }
            var mapping = [Int32](repeating: -1, count: target.count)
            for i in src.indices { mapping[Int(dst[i]) - 1] = src[i] - 1 }
            self.mapping = mapping
            return
        }
        let artifact = domain.nativeDomain.nativeGridFile
        guard let source = try await artifact.prepare(curl: curl, loadSource: true).source else {
            preconditionFailure("Remapping requires the native source mesh")
        }
        let grid = try await artifact.load()
        var mapping = Self.makeMapping(grid: grid, target: target, latitudes: source.coordinates.latitudes, longitudes: source.coordinates.longitudes)
        if domain == .iconD2 {
            try Self.adjustD2Boundary(mapping: &mapping, mesh: source.mesh)
        }
        self.mapping = mapping
    }

    static func makeMapping(grid: IconNativeGrid, target: RegularGrid, latitudes: [Double], longitudes: [Double]) -> [Int32] {
        // Recover the decimal grid definitions before arithmetic, rather than widening
        // Float coordinates (43.18 and 0.02 otherwise retain their Float rounding error).
        let latMin = Double(String(target.latMin))!, lonMin = Double(String(target.lonMin))!
        let dx = Double(String(target.dx))!, dy = Double(String(target.dy))!
        // Float queries can move slightly across the radius boundary. Gather with
        // a small margin, then enforce the original radius using Double distances.
        let limit = Double(grid.maximumChordDistanceSquared)
        let searchLimit = Float(min(4, pow(sqrt(limit) + 0x1p-19, 2)))
        var mapping = [Int32](repeating: -1, count: target.count)
        for i in mapping.indices {
            let latitude = latMin + Double(i / target.nx) * dy
            let longitude = lonMin + Double(i % target.nx) * dx
            guard let lookup = grid.storage.nearestLookup(
                latitude: Float(latitude), 
                longitude: Float(longitude),
                maximumChordDistanceSquared: searchLimit
            ) else { continue }
            let candidates = grid.storage.nearestCandidates(from: lookup, maximumChordDistanceSquared: searchLimit)
            let lat = latitude * .pi / 180, lon = longitude * .pi / 180
            var best = Double.infinity
            for j in 0..<candidates.count {
                let cell = candidates.pointIDs[j]
                let distance = pow(sin((latitudes[cell] - lat) / 2), 2)
                    + cos(lat) * cos(latitudes[cell]) * pow(sin((longitudes[cell] - lon) / 2), 2)
                if distance < best || (distance == best && cell < mapping[i]) {
                    best = distance
                    mapping[i] = Int32(cell)
                }
            }
            if best * 4 > limit { mapping[i] = -1 }
        }
        return mapping
    }

    static func adjustD2Boundary(mapping: inout [Int32], mesh: Group) throws {
        guard let layers = try mesh.getVariable(name: "refin_c_ctrl")?.asType(Int32.self)?.read(),
              let neighbors = try mesh.getVariable(name: "neighbor_cell_index")?.asType(Int32.self)?.read(),
              layers.count == IconNativeGridIdentity.d2.cellCount, neighbors.count == layers.count * 3,
              neighbors.allSatisfy({ $0 >= -1 && $0 <= layers.count }) else {
            throw IconDownloadError(description: "Invalid D2 boundary topology")
        }
        func adjacent(_ cell: Int32) -> [Int32] {
            (0..<3).map { neighbors[$0 * layers.count + Int(cell)] - 1 }.filter { $0 >= 0 }
        }
        // DWD fills layer 4 from the first layer-5 cell within two mesh edges,
        // breadth-first in stored neighbour order. Searching farther changes its mask.
        for i in mapping.indices where mapping[i] >= 0 && layers[Int(mapping[i])] == 4 {
            let direct = adjacent(mapping[i])
            let candidates = direct + direct.flatMap(adjacent)
            if let replacement = candidates.first(where: { layers[Int($0)] == 5 }) {
                mapping[i] = replacement
            }
        }
    }
}
