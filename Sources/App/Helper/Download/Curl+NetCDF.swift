import Foundation
import SwiftNetCDF


fileprivate enum CurlNetCdfError: Error {
    case netcdfOpenFailed
    case netcdfVarGetFailed
}

extension Curl {
    /// Download all grib files and return an array of grib messages
    func downloadNetCdf(url: String, file: String, ncVariable: String, bzip2Decode: Bool, minSize: Int? = nil, nConcurrent: Int = 1, deadLineHours: Double? = nil) async throws -> Group {
        
        let deadline = deadLineHours.map { Date().addingTimeInterval(TimeInterval($0 * 3600)) } ?? deadline
        let timeout = TimeoutTracker(logger: logger, deadline: deadline)
        
        while true {
            // Start the download and wait for the header
            try await download(url: url, toFile: file, bzip2Decode: bzip2Decode, minSize: minSize, nConcurrent: nConcurrent, deadLineHours: deadLineHours)
            
            // If NetCDF open fails, retry
            // Can happen for truncated files while downloading
            do {
                guard let nc = try NetCDF.open(path: file, allowUpdate: false) else {
                    throw CurlNetCdfError.netcdfOpenFailed
                }
                // Try to read meta data from variable
                guard (nc.getVariable(name: ncVariable)?.dimensions) != nil else {
                    throw CurlNetCdfError.netcdfVarGetFailed
                }
                return nc
            } catch {
                // wait 3 minutes
                try await timeout.check(error: error, delay: 60*3)
            }
        }
    }
}
