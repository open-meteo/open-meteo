import Foundation
import Vapor


enum CurlError: Error {
    case noGribMessagesMatch
}

struct Curl {
    let logger: Logger

    let connectTimeout = 30

    /// Total time it will retry and then give up. Default 2 hourss
    let maxTimeSeconds = 2*3600

    let retryDelaySeconds = 5

    func download(url: String, to: String, range: String? = nil) throws {
        // URL might contain password, strip them from logging
        if url.contains("@") && url.contains(":") {
            let urlSafe = url.split(separator: "/")[0] + "//" + url.split(separator: "@")[1]
            logger.info("Downloading file \(urlSafe)")
        } else {
            logger.info("Downloading file \(url)")
        }
        
        let startTime = Date()
        let args = range.map{["-r",$0]} ?? [] + [
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
        while true {
            do {
                try Process.spawnOrDie(cmd: "curl", args: args)
                return
            } catch {
                if Int(Date().timeIntervalSince(startTime)) > maxTimeSeconds {
                    throw error
                }
                sleep(UInt32(retryDelaySeconds))
            }
        }
    }
    
    /// Download an indexed grib file, but select only required grib messages
    func downloadIndexedGrib(url: String, to: String, include: (String) -> Bool) throws {
        try download(url: "\(url).idx", to: "\(to).idx")
        
        let idx = try FileHandle.openFileReading(file: "\(to).idx")
        guard let range = idx.forEachLine().indexToRange(include: include) else {
            throw CurlError.noGribMessagesMatch
        }
        try download(url: url, to: to, range: range)
    }
}


extension Sequence where Element == String {
    /// Parse a GRID index to curl read ranges
    func indexToRange(include: (String) -> Bool) -> String? {
        var range = ""
        var start: Int? = nil
        for line in self {
            let parts = line.split(separator: ":")
            guard parts.count > 2, let messageStart = Int(parts[1]) else {
                continue
            }
            guard include(line) else {
                if let startUnwrapped = start {
                    range += "\(range.isEmpty ? "" : ",")\(startUnwrapped)-\(messageStart-1)"
                    start = nil
                }
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

extension FileHandle {
    func forEachLine() -> AnyIterator<String> {
        var lineByteArrayPointer: UnsafeMutablePointer<CChar>? = nil
        var lineCap: Int = 0
        let fd = fdopen(fileDescriptor, "r")
        
        defer {
            lineByteArrayPointer?.deallocate()
            fclose(fd)
        }
        
        var bytesRead = 0
        
        return AnyIterator<String>({
            bytesRead = getline(&lineByteArrayPointer, &lineCap, fd)
            guard bytesRead > 0, let lineByteArrayPointer = lineByteArrayPointer else {
                return nil
            }
            return String(cString: lineByteArrayPointer)
        })
    }
}
