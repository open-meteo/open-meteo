import Foundation
import Vapor
import SwiftEccodes
import AsyncHTTPClient
import SwiftPFor2D
import CHelper

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

enum CurlError: Error {
    case noGribMessagesMatch
    case didNotFindAllVariablesInGribIndex
    case gribIndexMatchedTwice
    case sizeTooSmall
    case didNotGetAllGribMessages(got: Int, expected: Int)
    case downloadFailed(code: HTTPStatus)
    case timeoutReached
    case futimes(error: String)
}

/// Isolate buffer for concurrent access.. Although it is not really concurrent
final actor ConcurrentByteBuffer {
    private var buffer: ByteBuffer
    
    public init() {
        buffer = ByteBuffer()
        // Reserve 1MB buffer
        buffer.reserveCapacity(1024*1024)
    }
    
    public func reset() {
        if !self.buffer.uniquelyOwned() {
            fatalError("Download buffer is not uniquely owned!")
        }
        self.buffer.moveReaderIndex(to: 0)
        self.buffer.moveWriterIndex(to: 0)
    }
    
    public func writeImmutableBuffer(_ input: ByteBuffer) {
        if !self.buffer.uniquelyOwned() {
            fatalError("Download buffer is not uniquely owned!")
        }
        self.buffer.writeImmutableBuffer(input)
    }
    
    public func reserveCapacity(_ count: Int) {
        if !self.buffer.uniquelyOwned() {
            fatalError("Download buffer is not uniquely owned!")
        }
        buffer.reserveCapacity(count)
    }
    
    public func getBuffer() -> ByteBuffer {
        if !self.buffer.uniquelyOwned() {
            fatalError("Download buffer is not uniquely owned!")
        }
        return buffer
    }
}

final class Curl {
    let logger: Logger
    
    /// Give up downloading after the time, default 3 hours
    var deadline: Date

    /// Time to connect. Default 1 minute
    let connectTimeout = 60
    
    /// Time to transfer a file. Default 5 minutes
    let readTimeout = 5*60

    /// Wait time after each download
    let retryDelaySeconds = 5
    
    /// Retry 4xx errors
    let retryError4xx: Bool
    
    /// Download buffer which is reused during downloads
    var buffer: ConcurrentByteBuffer

    public init(logger: Logger, deadLineHours: Int = 3, retryError4xx: Bool = true) {
        self.logger = logger
        self.deadline = Date().addingTimeInterval(TimeInterval(deadLineHours * 3600))
        self.retryError4xx = retryError4xx

        buffer = ConcurrentByteBuffer()
        
        /// Access this mutable static variable, to workaround a concurrency issue
        _ = HTTPClientError.deadlineExceeded
        //logger.info("Curl initialised. Accessed mutable static var \(error)")
    }
    
    /// Set new deadline
    public func setDeadlineIn(minutes: Int) {
        self.deadline = Date().addingTimeInterval(TimeInterval(minutes * 60))
    }
    
    /*func download(url: String, to: String, range: String? = nil) throws {
        // URL might contain password, strip them from logging
        if url.contains("@") && url.contains(":") {
            let urlSafe = url.split(separator: "/")[0] + "//" + url.split(separator: "@")[1]
            logger.info("Downloading file \(urlSafe)")
        } else {
            logger.info("Downloading file \(url)")
        }
        
        let startTime = Date()
        let args = (range.map{["-r",$0]} ?? []) + [
            "-s",
            "--show-error",
            "--fail", // also retry 404
            "--insecure", // ignore expired or invalid SSL certs
            "--retry-connrefused",
            "--limit-rate", "10M", // Limit to 10 MB/s -> 80 Mbps
            "--connect-timeout", "\(connectTimeout)",
            "--max-time", "\(maxTimeSeconds)",
            "-o", to,
            url
        ]
        var lastPrint = Date().addingTimeInterval(TimeInterval(-60))
        while true {
            do {
                try Process.spawn(cmd: "curl", args: args)
                return
            } catch {
                let timeElapsed = Date().timeIntervalSince(startTime)
                if Date().timeIntervalSince(lastPrint) > 60 {
                    logger.info("Download failed, retry every \(retryDelaySeconds) seconds, (\(Int(timeElapsed/60)) minutes elapsed, curl error '\(error)'")
                    lastPrint = Date()
                }
                if Date() > deadline {
                    logger.error("Deadline reached")
                    throw error
                }
                sleep(UInt32(retryDelaySeconds))
            }
        }
    }*/
    
    /// Retry downloading as many times until deadline is reached. Exceptions in `callback` will also result in a retry. This is usefull to retry corrupted GRIB file download
    func withRetriedDownload<T>(url _url: String, range: String?, client: HTTPClient, callback: (HTTPClientResponse) async throws -> (T)) async throws -> T {
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
        
        let startTime = Date()
        var lastPrint = Date().addingTimeInterval(TimeInterval(-60))
        
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
        
        let connectTimeout = self.connectTimeout
        let readTimeout = self.readTimeout
        let retryError4xx = self.retryError4xx
        
        while true {
            do {
                // All those timers are a workaround for https://github.com/swift-server/async-http-client/issues/642
                let task = Task {
                    return try await client.execute(request, timeout: .seconds(Int64(connectTimeout + readTimeout + 5)))
                }
                let connectTimeout = Timer(timeInterval: TimeInterval(connectTimeout), repeats: false, block: { _ in task.cancel() })
                let response = try await task.value
                defer {
                    connectTimeout.invalidate()
                }
                connectTimeout.invalidate()
                
                if response.status != .ok && response.status != .partialContent {
                    throw CurlError.downloadFailed(code: response.status)
                }
                return try await callback(response)
            } catch {
                if !retryError4xx, case CurlError.downloadFailed(code: let status) = error, (400..<500).contains(status.code) {
                    logger.error("Download failed with 4xx error, \(error)")
                    throw error
                }
                let timeElapsed = Date().timeIntervalSince(startTime)
                if Date().timeIntervalSince(lastPrint) > 60 {
                    logger.info("Download failed, retry every \(retryDelaySeconds) seconds, (\(Int(timeElapsed/60)) minutes elapsed, curl error '\(error)'")
                    lastPrint = Date()
                }
                if Date() > deadline {
                    logger.error("Deadline reached")
                    throw error
                }
                try await Task.sleep(nanoseconds: UInt64(retryDelaySeconds * 1_000_000_000))
            }
        }
    }
    
    /// Use http-async http client to download, decompress BZIP2 and store to file. If the file already exists, it will be deleted before
    func downloadBz2Decompress(url: String, toFile: String, client: HTTPClient) async throws {
        return try await withRetriedDownload(url: url, range: nil, client: client) { response in
            let task = Task {
                try FileManager.default.removeItemIfExists(at: toFile)
                let lastModified = response.headers.lastModified?.value
                try await response.body.decompressBzip2().saveTo(file: toFile, size: nil, modificationDate: lastModified)
            }
            let readTimeout = Timer(timeInterval: TimeInterval(readTimeout), repeats: false, block: { _ in task.cancel() })
            defer {
                readTimeout.invalidate()
            }
            return try await task.value
        }
    }
    
    /// Use http-async http client to download and store to file. If the file already exists, it will be deleted before
    /// 
    func download(url: String, toFile: String, client: HTTPClient) async throws {
        return try await withRetriedDownload(url: url, range: nil, client: client) { response in
            let task = Task {
                let contentLength = response.headers["Content-Length"].first.flatMap(Int.init)
                let lastModified = response.headers.lastModified?.value
                try FileManager.default.removeItemIfExists(at: toFile)
                try await response.body.saveTo(file: toFile, size: contentLength, modificationDate: lastModified)
            }
            let readTimeout = Timer(timeInterval: TimeInterval(readTimeout), repeats: false, block: { _ in task.cancel() })
            defer {
                readTimeout.invalidate()
            }
            return try await task.value
        }
    }
    
    /// Use http-async http client to download and decompress as bzip2
    func downloadBz2Decompress(url: String, client: HTTPClient) async throws -> ConcurrentByteBuffer {
        return try await withRetriedDownload(url: url, range: nil, client: client) { [unowned self] response in
            let task = Task {
                await self.buffer.reset()
                for try await fragement in response.body.decompressBzip2() {
                    await self.buffer.writeImmutableBuffer(fragement)
                }
                return self.buffer
            }
            let readTimeout = Timer(timeInterval: TimeInterval(readTimeout), repeats: false, block: { _ in task.cancel() })
            defer {
                readTimeout.invalidate()
            }
            return try await task.value
        }
    }
    
    /// Use http-async http client to download
    func downloadInMemoryAsync(url: String, range: String? = nil, client: HTTPClient) async throws -> ConcurrentByteBuffer {
        return try await withRetriedDownload(url: url, range: range, client: client) { [unowned self] response in
            let task = Task {
                await self.buffer.reset()
                if let contentLength = response.headers["Content-Length"].first.flatMap(Int.init) {
                    await self.buffer.reserveCapacity(contentLength)
                }
                for try await fragement in response.body {
                    await self.buffer.writeImmutableBuffer(fragement)
                }
                return self.buffer
            }
            let readTimeout = Timer(timeInterval: TimeInterval(readTimeout), repeats: false, block: { _ in task.cancel() })
            defer {
                readTimeout.invalidate()
            }
            return try await task.value
        }
    }
    
    /// Download an entire grib file
    /// Data is downloaded directly into memory and GRIB decoded while iterating
    func downloadGrib(url: String, client: HTTPClient) async throws -> GribByteBuffer {
        // Retry download 20 times with increasing retry delay to get the correct number of grib messages
        var retries = 0
        while true {
            let data = try await downloadInMemoryAsync(url: url, client: client).getBuffer()
            logger.debug("Converting GRIB, size \(data.readableBytes) bytes")
            do {
                return try GribByteBuffer(bytebuffer: data)
            } catch {
                retries += 1
                if retries >= 20 {
                    throw error
                }
                logger.warning("Grib decoding failed, retry download")
                try await Task.sleep(nanoseconds: UInt64(retryDelaySeconds * 1_000_000_000 * min(10, retries)))
            }
        }
    }
    
    /// download a bz2 compressed grib
    func downloadBz2Grib(url: String, client: HTTPClient) async throws -> GribByteBuffer {
        // Retry download 20 times with increasing retry delay to get the correct number of grib messages
        var retries = 0
        while true {
            let data = try await downloadBz2Decompress(url: url, client: client).getBuffer()
            //logger.debug("Converting GRIB, size \(data.readableBytes) bytes")
            do {
                return try GribByteBuffer(bytebuffer: data)
            } catch {
                retries += 1
                if retries >= 20 {
                    throw error
                }
                logger.warning("Grib decoding failed, retry download")
                try await Task.sleep(nanoseconds: UInt64(retryDelaySeconds * 1_000_000_000 * min(10, retries)))
            }
        }
    }
    
    
    /// Download an indexed grib file, but selects only required grib messages
    /// Data is downloaded directly into memory and GRIB decoded while iterating
    func downloadIndexedGrib<Variable: CurlIndexedVariable>(url: String, variables: [Variable], extension: String = ".idx", client: HTTPClient, callback: ([Variable], [GribMessage]) throws -> ()) async throws {
        let count = variables.reduce(0, { return $0 + ($1.gribIndexName == nil ? 0 : 1) })
        if count == 0 {
            return
        }
        
        guard let index = try await downloadInMemoryAsync(url: "\(url)\(`extension`)", client: client).getBuffer().readStringImmutable() else {
        //guard let index = String(data: try await withRetriedDownloadUrlSession(url: "\(url)\(`extension`)", range: nil), encoding: .utf8) else {
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
        
        // Retry download 20 times with increasing retry delay to get the correct number of grib messages
        var retries = 0
        while true {
            let data = try await downloadInMemoryAsync(url: url, range: range, client: client).getBuffer()
            //let data = try await withRetriedDownloadUrlSession(url: url, range: range)
            logger.debug("Converting GRIB, size \(data.readableBytes) bytes")
            //try data.write(to: URL(fileURLWithPath: "/Users/patrick/Downloads/multipart2.grib"))
            do {
                try data.withUnsafeReadableBytes {
                    let messages = try GribMemory(ptr: $0).messages
                    
                    // memory allocations in libeccodes can case severe memory fragementation
                    // This leads to 20GB+ usage while decoding gfs025 with upper level variables
                    // malloc_trim() reduces this effect significantly
                    chelper_malloc_trim()
                    
                    if messages.count != matches.count {
                        logger.error("Grib reader did not get all matched variables. Matches count \(matches.count). Grib count \(messages.count). Grib size \(data.readableBytes)")
                        throw CurlError.didNotGetAllGribMessages(got: messages.count, expected: matches.count)
                    }
                    try callback(matches, messages)
                    chelper_malloc_trim()
                }
                //display_mallinfo2()
                return
            } catch {
                retries += 1
                if retries >= 20 {
                    throw error
                }
                logger.warning("Grib decoding failed, retry download")
                try await Task.sleep(nanoseconds: UInt64(retryDelaySeconds * 1_000_000_000 * min(10, retries)))
            }
        }
    }
    
    /// download using index ranges, BUT only single ranges and not multiple ranges.... AWS S3 does not support multi ranges
    func downloadIndexedGribSequential<Variable: CurlIndexedVariable>(url: String, variables: [Variable], extension: String = ".idx", client: HTTPClient, callback: (Variable, GribMessage) throws -> ()) async throws {
        let count = variables.reduce(0, { return $0 + ($1.gribIndexName == nil ? 0 : 1) })
        if count == 0 {
            return
        }
        
        guard let index = try await downloadInMemoryAsync(url: "\(url)\(`extension`)", client: client).getBuffer().readStringImmutable() else {
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
        logger.debug("Ranged download \(range)")
        
        
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
        
        let ranges = range.split(separator: ",")
        var matchesPos = 0
        for range in ranges {
            let data = try await downloadInMemoryAsync(url: url, range: String(range), client: client).getBuffer()
            try data.withUnsafeReadableBytes { ptr in
                let grib = try GribMemory(ptr: ptr)
                chelper_malloc_trim()
                for message in grib.messages {
                    //try! $0.dumpCoordinates()
                    //fatalError("OK")
                    let variable = matches[matchesPos]
                    matchesPos += 1
                    try callback(variable, message)
                }
                chelper_malloc_trim()
            }
        }
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


/// Small wrapper for GribMemory to keep a reference to bytebuffer
struct GribByteBuffer {
    let bytebuffer: ByteBuffer
    let messages: [GribMessage]
    
    init(bytebuffer: ByteBuffer) throws {
        self.bytebuffer = bytebuffer
        self.messages = try bytebuffer.withUnsafeReadableBytes {
            try GribMemory(ptr: $0).messages
        }
        chelper_malloc_trim()
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

/// Synchronise access to file handles
fileprivate actor ConcurrentFileHandle {
    private var fn: FileHandle
    
    public init(_ fn: FileHandle) {
        self.fn = fn
    }
    
    public func write(_ buffer: ByteBuffer) throws {
        try fn.write(contentsOf: buffer.readableBytesView)
    }
    
    public func setModificationDate(_ date: Date) throws {
        let times = [timespec](repeating: timespec(tv_sec: Int(date.timeIntervalSince1970), tv_nsec: 0), count: 2)
        guard futimens(fn.fileDescriptor, times) == 0 else {
            throw CurlError.futimes(error: String(cString: strerror(errno)))
        }
    }
}

extension AsyncSequence where Element == ByteBuffer {
    /// Store incoming data to file
    /// NOTE: File IO is blocking e.g. synchronous
    func saveTo(file: String, size: Int?, modificationDate: Date?) async throws {
        let fn = try ConcurrentFileHandle(FileHandle.createNewFile(file: file, size: size))
        for try await fragment in self {
            try await fn.write(fragment)
        }
        if let modificationDate {
            try await fn.setModificationDate(modificationDate)
        }
    }
}

extension Sequence where Element == Substring {
    /// Parse a GRID index to curl read ranges
    func indexToRange(include: (Substring) throws -> Bool) rethrows -> String? {
        var range = ""
        var start: Int? = nil
        for line in self {
            let parts = line.split(separator: ":")
            guard parts.count > 2, let messageStart = Int(parts[1]) else {
                continue
            }
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
        }
        if let start = start {
            range += "\(range.isEmpty ? "" : ",")\(start)-"
        }
        if range.isEmpty {
            return nil
        }
        return range
    }
}
