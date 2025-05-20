import Foundation
@preconcurrency import SwiftEccodes
import CHelper

extension Curl {
    /// Download all grib files and return an array of grib messages
    func downloadGrib(url: String, bzip2Decode: Bool, range: String? = nil, minSize: Int? = nil, nConcurrent: Int = 1, deadLineHours: Double? = nil, headers: [(String, String)] = []) async throws -> [GribMessage] {
        let deadline = deadLineHours.map { Date().addingTimeInterval(TimeInterval($0 * 3600)) } ?? deadline
        let timeout = TimeoutTracker(logger: logger, deadline: deadline)

        // AWS does not allow multi http download ranges. Split download into multiple downloads
        let supportMultiRange = !url.contains("amazonaws.com")
        if !supportMultiRange, let parts = range?.split(separator: ","), parts.count > 1 {
            var messages = [GribMessage]()
            for part in parts {
                messages.append(contentsOf: try await downloadGrib(url: url, bzip2Decode: bzip2Decode, range: String(part), headers: headers))
            }
            return messages
        }

        while true {
            // Start the download and wait for the header
            let response = try await initiateDownload(url: url, range: range, minSize: minSize, deadline: deadline, nConcurrent: nConcurrent, waitAfterLastModifiedBeforeDownload: waitAfterLastModifiedBeforeDownload, headers: headers)

            // Retry failed file transfers after this point
            do {
                var messages = [GribMessage]()
                let contentLength = try response.contentLength()
                let tracker = TransferAmountTrackerActor(logger: logger, totalSize: contentLength)
                if bzip2Decode {
                    for try await m in response.body.tracker(tracker).decompressBzip2().decodeGrib() {
                        try Task.checkCancellation()
                        messages.append(m)
                        chelper_malloc_trim()
                    }
                } else {
                    for try await m in response.body.tracker(tracker).decodeGrib() {
                        try Task.checkCancellation()
                        messages.append(m)
                        chelper_malloc_trim()
                    }
                }
                let trackerTransfered = await tracker.transfered
                await totalBytesTransfered.add(trackerTransfered)
                if let minSize = minSize, trackerTransfered < minSize {
                    throw CurlError.sizeTooSmall
                }
                try await response.waitAfterLastModified(logger: logger, wait: waitAfterLastModified)
                return messages
            } catch {
                try await timeout.check(error: error, delay: nil)
            }
        }
    }

    /// Stream GRIB messages. The grib stream might be restarted on error.
    func withGribStream<T>(url: String, bzip2Decode: Bool, range: String? = nil, minSize: Int? = nil, nConcurrent: Int = 1, deadLineHours: Double? = nil, headers: [(String, String)] = [], body: (AnyAsyncSequence<GribMessage>) async throws -> (T)) async throws -> T {
        let deadline = deadLineHours.map { Date().addingTimeInterval(TimeInterval($0 * 3600)) } ?? deadline
        let timeout = TimeoutTracker(logger: logger, deadline: deadline)

        // TODO fix AWS code path
        // TODO use grib stream for GLOFAS downloader

        // AWS does not allow multi http download ranges. Split download into multiple downloads
        /*let supportMultiRange = !url.contains("amazonaws.com")
        if !supportMultiRange, let parts = range?.split(separator: ","), parts.count > 1 {
            var messages = [GribMessage]()
            for part in parts {
                messages.append(contentsOf: try await downloadGrib(url: url, bzip2Decode: bzip2Decode, range: String(part)))
            }
            return messages
        }*/

        while true {
            // Start the download and wait for the header
            let response = try await initiateDownload(url: url, range: range, minSize: minSize, deadline: deadline, nConcurrent: nConcurrent, waitAfterLastModifiedBeforeDownload: waitAfterLastModifiedBeforeDownload, headers: headers)

            // Retry failed file transfers after this point
            do {
                let contentLength = try response.contentLength()
                let tracker = TransferAmountTrackerActor(logger: logger, totalSize: contentLength)
                let result: T
                if bzip2Decode {
                    result = try await body(response.body.tracker(tracker).decompressBzip2().decodeGrib().eraseToAnyAsyncSequence())
                } else {
                    result = try await body(response.body.tracker(tracker).decodeGrib().eraseToAnyAsyncSequence())
                }
                let trackerTransfered = await tracker.transfered
                await totalBytesTransfered.add(trackerTransfered)
                if let minSize = minSize, trackerTransfered < minSize {
                    throw CurlError.sizeTooSmall
                }
                try await response.waitAfterLastModified(logger: logger, wait: waitAfterLastModified)
                return result
            } catch let error as GribAsyncStreamError {
                // do not retry missing Grib header error
                throw error
            } catch {
                try await timeout.check(error: error)
            }
        }
    }
}

extension GribMessage {
    func dumpCoordinates() throws {
        guard let nx = get(attribute: "Nx")?.toInt() else {
            fatalError("Could not get Nx")
        }
        guard let ny = get(attribute: "Ny")?.toInt() else {
            fatalError("Could not get Ny")
        }
        print("nx=\(nx) ny=\(ny)")
        for (i, (latitude, longitude, value)) in try iterateCoordinatesAndValues().enumerated() {
            if i % 10_000 == 0 || i == ny * nx - 1 {
                print("grid \(i) lat \(latitude) lon \(longitude) value \(value)")
            }
        }
    }

    /// Read data as 2D grid assuming given `nx` and `ny`. Error is dimensions to not agree
    /// if `shift180LongitudeAndFlipLatitudeIfRequired` is set, automatically check the first and last grid points to see if the grid needs to be shifted to alwys start at -90/-180.
    func to2D(nx: Int, ny: Int, shift180LongitudeAndFlipLatitudeIfRequired: Bool) throws -> GribArray2D {
        var array2D = GribArray2D(nx: nx, ny: ny)
        try array2D.load(message: self, shift180LongitudeAndFlipLatitudeIfRequired: shift180LongitudeAndFlipLatitudeIfRequired)
        return array2D
    }
}

struct GribArray2D {
    var bitmap: [Int]
    var double: [Double]
    var array: Array2D

    public init(nx: Int, ny: Int) {
        array = Array2D(data: [Float](repeating: .nan, count: nx * ny), nx: nx, ny: ny)
        bitmap = .init(repeating: 0, count: nx * ny)
        double = .init(repeating: .nan, count: nx * ny)
    }

    /// Read data as 2D grid assuming given `nx` and `ny`. Error is dimensions to not agree
    /// if `shift180LongitudeAndFlipLatitudeIfRequired` is set, automatically check the first and last grid points to see if the grid needs to be shifted to alwys start at -90/-180.
    public mutating func load(message: GribMessage, shift180LongitudeAndFlipLatitudeIfRequired: Bool = false) throws {
        guard let gridType = message.get(attribute: "gridType") else {
            fatalError("Could not get gridType")
        }
        if gridType == "reduced_gg" {
            guard let numberOfCodedValues = message.get(attribute: "numberOfCodedValues")?.toInt() else {
                fatalError("Could not get numberOfCodedValues")
            }
            guard numberOfCodedValues == array.count else {
                fatalError("GRIB dimensions (count=\(numberOfCodedValues)) do not match domain grid dimensions (nx=\(array.nx), ny=\(array.ny))")
            }
        } else {
            guard let nx = message.get(attribute: "Nx")?.toInt() else {
                fatalError("Could not get Nx")
            }
            guard let ny = message.get(attribute: "Ny")?.toInt() else {
                fatalError("Could not get Ny")
            }
            guard nx == array.nx, ny == array.ny else {
                fatalError("GRIB dimensions (nx=\(nx), ny=\(ny)) do not match domain grid dimensions (nx=\(array.nx), ny=\(array.ny))")
            }
        }
        try message.loadDoubleNotNaNChecked(into: &double)
        for i in double.indices {
            array.data[i] = Float(double[i])
        }
        if try message.loadBitmap(into: &bitmap) {
            for i in bitmap.indices {
                if bitmap[i] == 0 {
                    array.data[i] = .nan
                }
            }
        }

        /// Some global grids start at latitude 90 and longitude 0. As a convention we always use -90 and -180.
        if shift180LongitudeAndFlipLatitudeIfRequired, gridType == "regular_ll" {
            guard let latitudeFirst = message.get(attribute: "latitudeOfFirstGridPointInDegrees").flatMap(Float.init),
                  let longitudeFirst = message.get(attribute: "longitudeOfFirstGridPointInDegrees").flatMap(Float.init) else {
                fatalError("Could not read first grid point coordinates")
            }
            guard let latitudeLast = message.get(attribute: "latitudeOfLastGridPointInDegrees").flatMap(Float.init),
                  let longitudeLast = message.get(attribute: "longitudeOfLastGridPointInDegrees").flatMap(Float.init) else {
                fatalError("Could not read last grid point coordinates")
            }
            let flipLatitude = latitudeFirst > latitudeLast
            let shiftLongitude = (-2...2).contains(longitudeFirst) && (358...362).contains(longitudeLast)
            if shiftLongitude {
                array.shift180Longitudee()
            }
            if flipLatitude {
                array.flipLatitude()
            }
        }
    }
}
