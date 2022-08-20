import Foundation
import Vapor
import SwiftEccodes


enum CurlError: Error {
    case noGribMessagesMatch
    case didNotFindAllVariablesInGribIndex
    case gribIndexMatchedTwice
}

struct Curl {
    let logger: Logger

    /// Curl connect timeout parameter
    let connectTimeout = 30
    
    /// Give up downloading after the time, default 3 hours
    let deadline: Date

    /// Curl max-time paramter to download a single file. Default 5 minutes
    let maxTimeSeconds = 5*60

    /// Wait time after each download
    let retryDelaySeconds = 5
    
    public init(logger: Logger, deadLineHours: Int = 3) {
        self.logger = logger
        self.deadline = Date().addingTimeInterval(TimeInterval(deadLineHours * 3600))
    }

    func download(url: String, to: String, range: String? = nil) throws {
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
                try Process.spawnOrDie(cmd: "curl", args: args)
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
    }
    
    func downloadInMemory(url: String, range: String? = nil) throws -> Data {
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
            url
        ]
        //logger.debug("Curl command: \(args.joined(separator: " "))")
        
        var lastPrint = Date().addingTimeInterval(TimeInterval(-60))
        while true {
            do {
                return try Process.spawnWithOutputData(cmd: "curl", args: args)
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
    }
    
    /// Download an indexed grib file, but selects only required grib messages
    /// Data is downloaded directly into memory and GRIB decoded while iterating
    func downloadIndexedGrib<Variable: CurlIndexedVariable>(url: String, variables: [Variable]) throws -> AnyIterator<(variable: Variable, message: GribMessage)> {
        
        if variables.isEmpty {
            return AnyIterator { return nil }
        }
        
        guard let index = String(data: try downloadInMemory(url: "\(url).idx"), encoding: .utf8) else {
            fatalError("Could not decode index to string")
        }
        
        var matches = [Variable]()
        matches.reserveCapacity(variables.count)
        guard let range = index.split(separator: "\n").indexToRange(include: { idx in
            guard let match = variables.first(where: { idx.contains($0.gribIndexName) }) else {
                return false
            }
            guard !matches.contains(match) else {
                logger.info("Grib variable \(match) matched twice for \(idx)")
                return false
            }
            logger.debug("Matched \(match) with \(idx)")
            matches.append(match)
            return true
        }) else {
            throw CurlError.noGribMessagesMatch
        }
        logger.debug("Ranged download \(range)")
        
        
        var missing = false
        for variable in variables {
            if !matches.contains(variable) {
                logger.error("Variable \(variable) '\(variable)' missing")
                missing = true
            }
        }
        if missing {
            throw CurlError.didNotFindAllVariablesInGribIndex
        }
        
        let data = try downloadInMemory(url: url, range: range)
        logger.debug("Converting GRIB, size \(data.count) bytes")
        //try data.write(to: URL(fileURLWithPath: "/Users/patrick/Downloads/multipart2.grib"))
        return try data.withUnsafeBytes { data in
            let grib = try GribMemory(ptr: data)
            if grib.messages.count != matches.count {
                fatalError("Grib reader did not get all matched variables. Matches count \(matches.count). Grib count \(grib.messages.count)")
            }
            var itr = zip(matches, grib.messages).makeIterator()
            return AnyIterator {
                guard let (variable, message) = itr.next() else {
                    return nil
                }
                return (variable, message)
            }
        }
    }
}

extension GribMessage {
    func toArray2d() -> Array2D {
        guard let data = try? getDouble().map(Float.init) else {
            fatalError("Could not read GRIB data")
        }
        guard let nx = get(attribute: "Nx").map(Int.init) ?? nil else {
            fatalError("Could not get Nx")
        }
        guard let ny = get(attribute: "Ny").map(Int.init) ?? nil else {
            fatalError("Could not get Ny")
        }
        return Array2D(data: data, nx: nx, ny: ny)
    }
}

protocol CurlIndexedVariable: Equatable {
    /// Return true, if this index string is matching. Index string looks like `13:520719:d=2022080900:ULWRF:top of atmosphere:anl:`
    var gribIndexName: String { get }
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
