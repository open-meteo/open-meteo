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

    public init(logger: Logger, client: HTTPClient, deadLineHours: Int = 3, readTimeout: Int = 5*60, retryError4xx: Bool = true, waitAfterLastModified: TimeInterval? = nil) {
        self.logger = logger
        self.deadline = Date().addingTimeInterval(TimeInterval(deadLineHours * 3600))
        self.retryError4xx = retryError4xx
        self.readTimeout = readTimeout
        self.waitAfterLastModified = waitAfterLastModified
        self.client = client
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
    ///
    func download(url: String, toFile: String, bzip2Decode: Bool) async throws {
        let timeout = TimeoutTracker(logger: logger, deadline: deadline)
        while true {
            // Start the download and wait for the header
            let response = try await initiateDownload(url: url, range: nil, minSize: nil)
            
            // Retry failed file transfers after this point
            do {
                let lastModified = response.headers.lastModified?.value
                try FileManager.default.removeItemIfExists(at: toFile)
                let contentLength = try response.contentLength()
                let tracker = TransferAmountTracker(logger: logger, totalSize: contentLength)
                if bzip2Decode {
                    try await response.body.tracker(tracker).decompressBzip2().saveTo(file: toFile, size: nil, modificationDate: lastModified)
                } else {
                    try await response.body.tracker(tracker).saveTo(file: toFile, size: contentLength, modificationDate: lastModified)
                }
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
    
    /// Download index file and match against curl variable
    func downloadIndexAndDecode<Variable: CurlIndexedVariable>(url: String, variables: [Variable]) async throws -> (matches: [Variable], range: String, minSize: Int)? {
        let count = variables.reduce(0, { return $0 + ($1.gribIndexName == nil ? 0 : 1) })
        if count == 0 {
            return nil
        }
        
        guard let index = try await downloadInMemoryAsync(url: url, minSize: nil).readStringImmutable() else {
            fatalError("Could not decode index to string")
        }

        var matches = [Variable]()
        matches.reserveCapacity(count)
        guard let range = index.split(separator: "\n").indexToRange(include: { idx in
            guard let match = variables.first(where: {
                guard let gribIndexName = $0.gribIndexName else {
                    return false
                }
                return idx.contains(gribIndexName)
            }) else {
                return false
            }
            guard !matches.contains(where: {$0.gribIndexName == match.gribIndexName}) else {
                logger.info("Grib variable \(match) matched twice for \(idx)")
                return false
            }
            //logger.debug("Matched \(match) with \(idx)")
            matches.append(match)
            return true
        }) else {
            throw CurlError.noGribMessagesMatch
        }
        
        var missing = false
        for variable in variables {
            guard let gribIndexName = variable.gribIndexName else {
                continue
            }
            if !matches.contains(where: {$0.gribIndexName == gribIndexName}) {
                logger.error("Variable \(variable) '\(gribIndexName)' missing")
                missing = true
            }
        }
        if missing {
            throw CurlError.didNotFindAllVariablesInGribIndex
        }
        
        return (matches, range.range, range.minSize)
    }
    
    
    /// Download an indexed grib file, but selects only required grib messages
    /// Data is downloaded directly into memory and GRIB decoded while iterating
    func downloadIndexedGrib<Variable: CurlIndexedVariable>(url: String, variables: [Variable], extension: String = ".idx") async throws -> [(variable: Variable, message: GribMessage)] {
        
        guard let inventory = try await downloadIndexAndDecode(url: "\(url)\(`extension`)", variables: variables) else {
            return []
        }
        
        // Retry download 20 times with increasing retry delay to get the correct number of grib messages
        var retries = 0
        while true {
            do {
                let messages = try await downloadGrib(url: url, bzip2Decode: false, range: inventory.range, minSize: inventory.minSize)
                if messages.count != inventory.matches.count {
                    logger.error("Grib reader did not get all matched variables. Matches count \(inventory.matches.count). Grib count \(messages.count)")
                    throw CurlError.didNotGetAllGribMessages(got: messages.count, expected: inventory.matches.count)
                }
                return zip(inventory.matches, messages).map({($0,$1)})
            } catch {
                retries += 1
                if retries >= 20 {
                    throw error
                }
                logger.warning("Grib decoding failed, retry download")
                try await Task.sleep(nanoseconds: UInt64(5 * 1_000_000_000 * min(10, retries)))
            }
        }
    }
    
    /// download using index ranges, BUT only single ranges and not multiple ranges.... AWS S3 does not support multi ranges
    func downloadIndexedGribSequential<Variable: CurlIndexedVariable>(url: String, variables: [Variable], extension: String = ".idx") async throws -> [(variable: Variable, message: GribMessage)] {
        
        guard let inventory = try await downloadIndexAndDecode(url: "\(url)\(`extension`)", variables: variables) else {
            return []
        }
        
        let ranges = inventory.range.split(separator: ",")
        var messages = [GribMessage]()
        messages.reserveCapacity(inventory.matches.count)
        for range in ranges {
            let m = try await downloadGrib(url: url, bzip2Decode: false, range: String(range))
            m.forEach({messages.append($0)})
        }
        if messages.count != inventory.matches.count {
            logger.error("Grib reader did not get all matched variables. Matches count \(inventory.matches.count). Grib count \(messages.count)")
            throw CurlError.didNotGetAllGribMessages(got: messages.count, expected: inventory.matches.count)
        }
        
        return zip(inventory.matches, messages).map({($0,$1)})
    }
}

extension ByteBuffer {
    public func readStringImmutable() -> String? {
        var b = self
        return b.readString(length: b.readableBytes)
    }
    
    public mutating func uniquelyOwned() -> Bool {
        self.modifyIfUniquelyOwned { _ in } != nil
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
        guard let nx = message.get(attribute: "Nx").map(Int.init) ?? nil else {
            fatalError("Could not get Nx")
        }
        guard let ny = message.get(attribute: "Ny").map(Int.init) ?? nil else {
            fatalError("Could not get Ny")
        }
        guard nx == array.nx, ny == array.ny else {
            fatalError("GRIB dimensions (nx=\(nx), ny=\(ny)) do not match domain grid dimensions (nx=\(array.nx), ny=\(array.ny))")
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

protocol CurlIndexedVariable {
    /// Return true, if this index string is matching. Index string looks like `13:520719:d=2022080900:ULWRF:top of atmosphere:anl:`
    /// If nil, this record is ignored
    var gribIndexName: String? { get }
}

extension AsyncSequence where Element == ByteBuffer {
    /// Store incoming data to file. Buffers up to 150kb until flushed to disk.
    /// NOTE: File IO is blocking e.g. synchronous
    /// Returns total amount of bytes transfered
    func saveTo(file: String, size: Int?, modificationDate: Date?) async throws {
        let fn = try FileHandle.createNewFile(file: file, size: size)
        
        /// Buffer up to 64kb and then write larger chunks
        var buffer = ByteBuffer()
        buffer.reserveCapacity(80*1024)
        for try await fragment in self {
            try Task.checkCancellation()
            buffer.writeImmutableBuffer(fragment)
            if buffer.readableBytes > 64*1024 {
                try fn.write(contentsOf: buffer.readableBytesView)
                buffer.moveReaderIndex(to: 0)
                buffer.moveWriterIndex(to: 0)
            }
        }
        // write remaining data
        try fn.write(contentsOf: buffer.readableBytesView)
        buffer.moveReaderIndex(forwardBy: buffer.readableBytes)
        
        if let modificationDate {
            let times = [timespec](repeating: timespec(tv_sec: Int(modificationDate.timeIntervalSince1970), tv_nsec: 0), count: 2)
            guard futimens(fn.fileDescriptor, times) == 0 else {
                throw CurlError.futimes(error: String(cString: strerror(errno)))
            }
        }
        return
    }
}

extension Int {
    /// Format number of bytes to a human readable format like `5.5 MB`
    var bytesHumanReadable: String {
        if self > 5 * 1024*1024*1024 {
            return "\((Double(self)/1024/1024/1024).round(digits: 1)) GB"
        }
        if self > 1 * 1024*1024*1024 {
            return "\((Double(self)/1024/1024/1024).round(digits: 2)) GB"
        }
        if self > 5 * 1024*1024 {
            return "\((Double(self)/1024/1024).round(digits: 1)) MB"
        }
        if self > 1 * 1024*1024 {
            return "\((Double(self)/1024/1024).round(digits: 2)) MB"
        }
        if self > 5 * 1024 {
            return "\((Double(self)/1024).round(digits: 1)) KB"
        }
        if self > 1 * 1024 {
            return "\((Double(self)/1024).round(digits: 2)) KB"
        }
        return "\(self) bytes"
    }
}

extension Sequence where Element == Substring {
    /// Parse a GRID index to curl read ranges
    func indexToRange(include: (Substring) throws -> Bool) rethrows -> (range: String, minSize: Int)? {
        var range = ""
        var start: Int? = nil
        var minSize = 0
        var previousMatched: Int? = nil
        for line in self {
            let parts = line.split(separator: ":")
            guard parts.count > 2, let messageStart = Int(parts[1]) else {
                continue
            }
            if let previousMatched = previousMatched {
                minSize += messageStart - previousMatched
            }
            previousMatched = nil
            guard try include(line) else {
                if let start = start {
                    range += "\(range.isEmpty ? "" : ",")\(start)-\(messageStart-1)"
                }
                start = nil
                continue
            }
            if start == nil {
                start = messageStart
            }
            previousMatched = messageStart
        }
        if let start = start {
            range += "\(range.isEmpty ? "" : ",")\(start)-"
        }
        if range.isEmpty {
            return nil
        }
        return (range, minSize)
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
