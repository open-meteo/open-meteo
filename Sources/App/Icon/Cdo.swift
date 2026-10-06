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

    /// Reuse historical CDO weights and masks for deterministic global ICON.
    init(curl: Curl, domain: IconDomains) async throws {
        guard domain == .icon,
              let target = domain.grid as? RegularGrid else {
            throw IconDownloadError(description: "No regular remapping grid for \(domain)")
        }
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
    }
}
