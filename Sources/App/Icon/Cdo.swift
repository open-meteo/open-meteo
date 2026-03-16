import Foundation
import Vapor
@preconcurrency import SwiftEccodes
import CHelper
import SwiftNetCDF

protocol CdoIconGridNameConvertible: GenericDomain {
    var iconGridName: String? { get }
}

struct CdoHelper: Sendable {
    let cdo: CdoIconGlobal?
    let grid: any Gridable
    let curl: Curl

    var needsRemapping: Bool {
        return cdo != nil
    }

    init(domain: some CdoIconGridNameConvertible, logger: Logger, curl: Curl) async throws {
        self.curl = curl
        cdo = try await CdoIconGlobal(curl: curl, domain: domain)
        grid = domain.grid
    }

    /// Download a GRIB file, optionally bzip2-decode it, remap from the icosahedral
    /// ICON grid to the regular lat-lon target grid (when weights are available), and
    /// return an array of `(message, Array2D)` pairs.
    ///
    /// - Parameters:
    ///   - url: Remote URL of the GRIB2 file.
    ///   - bzip2Decode: Pass `true` for `.grib2.bz2` files (classic ICON open-data),
    ///     `false` for plain `.grib2` files (e.g. AICON).
    func downloadAndRemap(_ url: String, bzip2Decode: Bool = true) async throws -> [(message: GribMessage, data: Array2D)] {
        guard let cdo else {
            return try await curl.downloadGrib(url: url, bzip2Decode: bzip2Decode).map { message in
                return (message, Array2D(data: try message.getDouble().map(Float.init), nx: grid.nx, ny: grid.ny))
            }
        }
        
        /// Nearest neighbour interpolation using pre-computed CDO weights
        let messages = try await curl.downloadGrib(url: url, bzip2Decode: bzip2Decode)
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

extension IconDomains: CdoIconGridNameConvertible {
    var iconGridName: String? {
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

extension AiconDomain: CdoIconGridNameConvertible {
    /// AICON uses the same R3B7 icosahedral grid as ICON global.
    var iconGridName: String? {
        return "0026_R03B07_G"
    }
}

struct CdoIconGlobal {
    let mapping: [Int32]

    /// Download (if not yet cached) and parse the CDO nearest-neighbour weight file
    /// for the given domain's icosahedral grid.
    ///
    /// Returns `nil` when `domain.iconGridName` is `nil`, meaning the domain already
    /// provides data on a regular lat-lon grid.
    public init?(curl: Curl, domain: some CdoIconGridNameConvertible) async throws {
        guard domain.iconGridName != nil else {
            return nil
        }
        let fm = FileManager.default
        let weightsFile = "\(domain.domainRegistry.directory)static/cdo_weights.nc"

        if !fm.fileExists(atPath: weightsFile) {
            // FIXME: Hardcoded path in remote file
            let remoteFile = "https://openmeteo.s3.amazonaws.com/data/dwd_icon/static/cdo_weights.nc"
            try await curl.download(url: remoteFile, toFile: weightsFile, bzip2Decode: false)
        }
        guard let src_address = try NetCDF.open(path: weightsFile, allowUpdate: false)?.getVariable(name: "src_address")?.asType(Int32.self)?.read() else {
            fatalError("could not open weights file")
        }

        guard let dst_address = try NetCDF.open(path: weightsFile, allowUpdate: false)?.getVariable(name: "dst_address")?.asType(Int32.self)?.read() else {
            fatalError("could not open weights file")
        }

        let count = domain.grid.count
        var mapping = [Int32](repeating: -1, count: count)
        for (i, src) in src_address.enumerated() {
            mapping[Int(dst_address[i]) % count] = src - 1
        }
        self.mapping = mapping
    }
}
