import Foundation
import Vapor
import SwiftEccodes
import AsyncHTTPClient
import CHelper


enum CurlError: Error {
    case noGribMessagesMatch
    case didNotFindAllVariablesInGribIndex
    case gribIndexMatchedTwice
    case sizeTooSmall
    case didNotGetAllGribMessages(got: Int, expected: Int)
    case downloadFailed(code: HTTPStatus)
    case timeoutReached
    case futimes(error: String)
    case contentLengthHeaderTooLarge(got: Int)
}

/// Download http files to disk, or memory. decode GRIB messages and perform retries for failed downloads
final class Curl {
    let logger: Logger
    
    /// Give up downloading after the time, default 3 hours
    var deadline: Date
    
    /// start time of downloading
    let startTime = DispatchTime.now()
    
    /// Time to transfer a file. Default 5 minutes
    let readTimeout: Int
    
    /// Retry 4xx errors
    let retryError4xx: Bool
    
    /// Number of bytes of how much data was transfered
    var totalBytesTransfered: Int = 0
    
    /// If set, sleep for a specified amount of time on top of the `last-modified` response header. This way, we keep a constant delay to realtime updates -> reduce download errors
    let waitAfterLastModified: TimeInterval?
    
    let client: HTTPClient

    public init(logger: Logger, client: HTTPClient, deadLineHours: Double = 3, readTimeout: Int = 5*60, retryError4xx: Bool = true, waitAfterLastModified: TimeInterval? = nil) {
        self.logger = logger
        self.deadline = Date().addingTimeInterval(TimeInterval(deadLineHours * 3600))
        self.retryError4xx = retryError4xx
        self.readTimeout = readTimeout
        self.waitAfterLastModified = waitAfterLastModified
        self.client = client
    }
    
    deinit {
        // after downloads completed, memory might be a mess
        // trim it, before starting to convert data
        chelper_malloc_trim()
    }
    
    /// Set new deadline
    public func setDeadlineIn(minutes: Int) {
        self.deadline = Date().addingTimeInterval(TimeInterval(minutes * 60))
    }
    
    public func printStatistics() {
        logger.info("Finished downloading \(totalBytesTransfered.bytesHumanReadable) in \(startTime.timeElapsedPretty())")
    }
    
    /// Retry download start as many times until deadline is reached. As soon as the HTTP header is sucessfully returned, this function returns the HTTPClientResponse which can then be used to stream data
    func initiateDownload(url _url: String, range: String?, minSize: Int?) async throws -> HTTPClientResponse {
        // URL might contain password, strip them from logging
        let url: String
        let auth: String?
        if _url.contains("@") && _url.contains(":") {
            let usernamePassword = _url.split(separator: "/", maxSplits: 1)[1].dropFirst().split(separator: "@", maxSplits: 1)[0]
            auth = (usernamePassword).data(using: .utf8)!.base64EncodedString()
            url = _url.split(separator: "/")[0] + "//" + _url.split(separator: "@")[1]
        } else {
            url = _url
            auth = nil
        }
        logger.info("Downloading\(range != nil ? " [ranged]" : "") file \(url)")
        
        let request = {
            var request = HTTPClientRequest(url: url)
            if let range = range {
                request.headers.add(name: "range", value: "bytes=\(range)")
            }
            if let auth = auth {
                request.headers.add(name: "Authorization", value: "Basic \(auth)")
            }
            return request
        }()
        
        let timeout = TimeoutTracker(logger: logger, deadline: deadline)
        
        while true {
            do {
                let response = try await client.execute(request, timeout: .seconds(Int64(readTimeout)))
                if response.status != .ok && response.status != .partialContent {
                    throw CurlError.downloadFailed(code: response.status)
                }
                if let minSize = minSize, let contentLength = try response.contentLength(), contentLength < minSize {
                    throw CurlError.sizeTooSmall
                }
                return response
            } catch {
                if !self.retryError4xx, case CurlError.downloadFailed(code: let status) = error, (400..<500).contains(status.code) {
                    logger.error("Download failed with 4xx error, \(error)")
                    throw error
                }
                try await timeout.check(error: error)
            }
        }
    }
    
    /// Use http-async http client to download and store to file. If the file already exists, it will be deleted before
    /// Data is first downloaded to a tempoary tilde file and then moved to its final location atomically
    func download(url: String, toFile: String, bzip2Decode: Bool, atomic: Bool = false) async throws {
        let timeout = TimeoutTracker(logger: logger, deadline: deadline)
        let fileTemp = "\(toFile)~"
        while true {
            // Start the download and wait for the header
            let response = try await initiateDownload(url: url, range: nil, minSize: nil)
            
            // Retry failed file transfers after this point
            do {
                let lastModified = response.headers.lastModified?.value
                try FileManager.default.removeItemIfExists(at: fileTemp)
                let contentLength = try response.contentLength()
                let tracker = TransferAmountTracker(logger: logger, totalSize: contentLength)
                if bzip2Decode {
                    try await response.body.tracker(tracker).decompressBzip2().saveTo(file: fileTemp, size: nil, modificationDate: lastModified, logger: logger)
                } else {
                    try await response.body.tracker(tracker).saveTo(file: fileTemp, size: contentLength, modificationDate: lastModified, logger: logger)
                }
                try FileManager.default.moveFileOverwrite(from: fileTemp, to: toFile)
                self.totalBytesTransfered += tracker.transfered
                try await response.waitAfterLastModified(logger: logger, wait: waitAfterLastModified)
                return
            } catch {
                try await timeout.check(error: error)
            }
        }
    }
    
    /// Use http-async http client to download
    /// `minSize` retry download if file is too small. Happens a lot with NOAA servers while files are uploaded while downloaded
    func downloadInMemoryAsync(url: String, range: String? = nil, minSize: Int?) async throws -> ByteBuffer {
        let timeout = TimeoutTracker(logger: logger, deadline: deadline)
        while true {
            // Start the download and wait for the header
            let response = try await initiateDownload(url: url, range: range, minSize: minSize)
            
            // Retry failed file transfers after this point
            do {
                var buffer = ByteBuffer()
                if let contentLength = try response.contentLength() {
                    buffer.reserveCapacity(contentLength)
                }
                for try await fragement in response.body {
                    try Task.checkCancellation()
                    self.totalBytesTransfered += fragement.readableBytes
                    buffer.writeImmutableBuffer(fragement)
                }
                if let minSize = minSize, buffer.readableBytes < minSize {
                    throw CurlError.sizeTooSmall
                }
                try await response.waitAfterLastModified(logger: logger, wait: waitAfterLastModified)
                return buffer
            } catch {
                try await timeout.check(error: error)
            }
        }
    }
    
    /// Download all grib files and return an array of grib messages
    func downloadGrib(url: String, bzip2Decode: Bool, range: String? = nil, minSize: Int? = nil) async throws -> [GribMessage] {
        let timeout = TimeoutTracker(logger: logger, deadline: deadline)
        while true {
            // Start the download and wait for the header
            let response = try await initiateDownload(url: url, range: range, minSize: minSize)
            
            // Retry failed file transfers after this point
            do {
                return try await withThrowingTaskGroup(of: Void.self) { group in
                    var messages = [GribMessage]()
                    let contentLength = try response.contentLength()
                    let tracker = TransferAmountTracker(logger: logger, totalSize: contentLength)
                    if bzip2Decode {
                        for try await m in response.body.tracker(tracker).decompressBzip2().decodeGrib() {
                            try Task.checkCancellation()
                            m.forEach({messages.append($0)})
                            chelper_malloc_trim()
                        }
                    } else {
                        for try await m in response.body.tracker(tracker).decodeGrib() {
                            try Task.checkCancellation()
                            m.forEach({messages.append($0)})
                            chelper_malloc_trim()
                        }
                    }
                    self.totalBytesTransfered += tracker.transfered
                    if let minSize = minSize, tracker.transfered < minSize {
                        throw CurlError.sizeTooSmall
                    }
                    try await response.waitAfterLastModified(logger: logger, wait: waitAfterLastModified)
                    return messages
                }
            } catch {
                try await timeout.check(error: error)
            }
        }
    }
}

extension GribMessage {
    func dumpCoordinates() throws {
        guard let nx = get(attribute: "Nx").map(Int.init) ?? nil else {
            fatalError("Could not get Nx")
        }
        guard let ny = get(attribute: "Ny").map(Int.init) ?? nil else {
            fatalError("Could not get Ny")
        }
        print("nx=\(nx) ny=\(ny)")
        for (i,(latitude, longitude,value)) in try iterateCoordinatesAndValues().enumerated() {
            if i % 10_000 == 0 || i == ny*nx-1 {
                print("grid \(i) lat \(latitude) lon \(longitude) value \(value)")
            }
        }
    }
}

struct GribArray2D {
    var bitmap: [Int]
    var double: [Double]
    var array: Array2D
    
    public init(nx: Int, ny: Int) {
        array = Array2D(data: [Float](repeating: .nan, count: nx*ny), nx: nx, ny: ny)
        bitmap = .init(repeating: 0, count: nx*ny)
        double = .init(repeating: .nan, count: nx*ny)
    }
    
    public mutating func load(message: GribMessage) throws {
        guard let gridType = message.get(attribute: "gridType") else {
            fatalError("Could not get gridType")
        }
        if gridType == "reduced_gg" {
            guard let numberOfCodedValues = message.get(attribute: "numberOfCodedValues").map(Int.init) ?? nil else {
                fatalError("Could not get numberOfCodedValues")
            }
            guard numberOfCodedValues == array.count else {
                fatalError("GRIB dimensions (count=\(numberOfCodedValues)) do not match domain grid dimensions (nx=\(array.nx), ny=\(array.ny))")
            }
        } else {
            guard let nx = message.get(attribute: "Nx").map(Int.init) ?? nil else {
                fatalError("Could not get Nx")
            }
            guard let ny = message.get(attribute: "Ny").map(Int.init) ?? nil else {
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
    }
}

extension AsyncSequence where Element == ByteBuffer {
    /// Store incoming data to file. Buffers up to 1024kb until flushed to disk.
    /// Optimised for ZFS recordsize of 1024kb
    /// NOTE: File IO is blocking e.g. synchronous
    /// If `size` is set, the required file size will be prealiocated
    /// If `modificationDate` is set, the files modification date will be set to it
    func saveTo(file: String, size: Int?, modificationDate: Date?, logger: Logger) async throws {
        let fn = try FileHandle.createNewFile(file: file, size: size)
        let recordSize = 1024 * 1024 // 1mb
        
        /// Buffer up to 1024kb and then write larger chunks
        var buffer = ByteBuffer()
        var timeActive: Double = 0
        var transfered: Int = 0
        buffer.reserveCapacity(recordSize)
        for try await fragment in self {
            try Task.checkCancellation()
            var fragment = fragment
            while fragment.readableBytes > 0 {
                fragment.readWithUnsafeReadableBytes({
                    let chunkBytes = Swift.min($0.count, recordSize)
                    return buffer.writeBytes(UnsafeRawBufferPointer(rebasing: $0[0..<chunkBytes]))
                })
                if buffer.readableBytes >= recordSize {
                    let time = Date()
                    try fn.write(contentsOf: buffer.readableBytesView[0..<recordSize])
                    timeActive += Date().timeIntervalSince(time)
                    transfered += buffer.readableBytes
                    buffer.moveReaderIndex(forwardBy: recordSize)
                    buffer.discardReadBytes()
                }
            }
        }
        // write remaining data
        let time = Date()
        try fn.write(contentsOf: buffer.readableBytesView)
        timeActive += Date().timeIntervalSince(time)
        transfered += buffer.readableBytes
        buffer.moveReaderIndex(forwardBy: buffer.readableBytes)
        
        if timeActive >= 0.01 {
            let rate = Int(Double(transfered) / timeActive)
            if rate < 80*1024*1024 {
                logger.warning("Slow disk write speed \(rate.bytesHumanReadable)/s")
            }
        }
        
        if let modificationDate {
            let times = [timespec](repeating: timespec(tv_sec: Int(modificationDate.timeIntervalSince1970), tv_nsec: 0), count: 2)
            guard futimens(fn.fileDescriptor, times) == 0 else {
                throw CurlError.futimes(error: String(cString: strerror(errno)))
            }
        }
        return
    }
}

extension HTTPClientResponse {
    /// Content length in bytes forom the http header
    func contentLength() throws -> Int? {
        guard let length = headers["Content-Length"].first.flatMap(Int.init), length >= 0 else {
            return nil
        }
        if length > 128*(1<<30) {
            throw CurlError.contentLengthHeaderTooLarge(got: length)
        }
        return length
    }
    
    /// Optionally wait to stay delayed a fixed time amount after last modified header
    fileprivate func waitAfterLastModified(logger: Logger, wait: TimeInterval?) async throws {
        guard let wait, let lastModified = headers.lastModified?.value else {
            return
            
        }
        let delta = wait - lastModified.distance(to: Date())
        if delta > 1 {
            if delta > 10 {
                logger.info("Last modified header is too jung. Target delay \(wait) seconds. Sleeping for \(delta.rounded()) seconds now.")
            }
            try await Task.sleep(nanoseconds:  UInt64(delta * 1_000_000_000))
        }
    }
}
