import Foundation
import Vapor
@preconcurrency import SwiftEccodes
import CHelper
import SwiftNetCDF

struct CdoHelper: Sendable {
    let cdo: CdoIconGlobal?
    let grid: Gridable
    let domain: IconDomains
    let curl: Curl

    var needsRemapping: Bool {
        return cdo != nil
    }

    init(domain: IconDomains, logger: Logger, curl: Curl) async throws {
        // icon global needs resampling to plate carree
        self.curl = curl
        cdo = try await CdoIconGlobal(curl: curl, domain: domain)
        grid = domain.grid
        self.domain = domain
    }

    // Uncompress bz2, reproject to regular grid and read into memory
    func downloadAndRemap(_ url: String) async throws -> [(message: GribMessage, data: Array2D)] {
        guard let cdo else {
            return try await curl.downloadGrib(url: url, bzip2Decode: true).map { message in
                return (message, Array2D(data: try message.getDouble().map(Float.init), nx: grid.nx, ny: grid.ny))
            }
        }
        /// Nearest neighbour interpolation
        let messages = try await curl.downloadGrib(url: url, bzip2Decode: true)
        return try messages.map { message in
            let source = try message.getDouble()
            let destination = cdo.mapping.map { src in
                guard src >= 0 else {
                    return Float.nan
                }
                return Float(source[Int(src)])
            }
            let grid2d = Array2D(data: destination, nx: grid.nx, ny: grid.ny)
            return (message, grid2d)
        }
    }
}

extension IconDomains {
    fileprivate var iconGridName: String? {
        switch self {
        case .icon:
            return "0026_R03B07_G"
        case .iconEu:
            return nil
        case .iconD2:
            return nil
        case .iconD2_15min:
            return nil
        case .iconEps:
            return "0036_R03B06_G"
        case .iconEuEps:
            return "0037_R03B07_N02"
        case .iconD2Eps:
            return "0047_R19B07_L"
        }
    }
}

struct CdoIconGlobal {
    let mapping: [Int32]

    /// Download and prepare weights for icon global remapping
    public init?(curl: Curl, domain: IconDomains) async throws {
        guard domain.iconGridName != nil else {
            return nil
        }
        let fm = FileManager.default
        let weightsFile = "\(domain.domainRegistry.directory)static/cdo_weights.nc"
        
        if !fm.fileExists(atPath: weightsFile) {
            let remoteFile = "https://openmeteo.s3.amazonaws.com/data/\(domain.domainRegistry.rawValue)/static/cdo_weights.nc"
            try await curl.download(url: remoteFile, toFile: weightsFile, bzip2Decode: false)
        }
        guard let src_address = try NetCDF.open(path: weightsFile, allowUpdate: false)?.getVariable(name: "src_address")?.asType(Int32.self)?.read() else {
            fatalError("could not open weights file")
        }
        guard let dst_address = try NetCDF.open(path: weightsFile, allowUpdate: false)?.getVariable(name: "dst_address")?.asType(Int32.self)?.read() else {
            fatalError("could not open weights file")
        }
        var mapping = [Int32](repeating: -1, count: domain.grid.count)
        for (i, src) in src_address.enumerated() {
            mapping[Int(dst_address[i])] = src - 1
        }
        self.mapping = mapping
    }
}
