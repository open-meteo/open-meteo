import Foundation
import Vapor
import SwiftEccodes


enum CurlError: Error {
    case noGribMessagesMatch
    case didNotFindAllVariablesInGribIndex
    case gribIndexMatchedTwice
    case sizeTooSmall
    case didNotGetAllGribMessages(got: Int, expected: Int)
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
    }
    
    /// Wait for a download to finish
    func downloadInMemory(url: String, range: String? = nil, minSize: Int? = nil) throws -> Data {
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
                let data = try Process.spawnWithOutputData(cmd: "curl", args: args)
                if let minSize = minSize, data.count < minSize {
                    throw CurlError.sizeTooSmall
                }
                return data
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
    func downloadIndexedGrib<Variable: CurlIndexedVariable>(url: String, variables: [Variable], extension: String = ".idx") throws -> AnyIterator<(variable: Variable, message: GribMessage)> {
        let count = variables.reduce(0, { return $0 + ($1.gribIndexName == nil ? 0 : 1) })
        if count == 0 {
            return AnyIterator { return nil }
        }
        
        guard let index = String(data: try downloadInMemory(url: "\(url)\(`extension`)"), encoding: .utf8) else {
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
            logger.debug("Matched \(match) with \(idx)")
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
        
        /// Retry download 3 times to get the correct number of grib messages
        for i in 1...3 {
            let data = try downloadInMemory(url: url, range: range.range, minSize: range.minSize)
            logger.debug("Converting GRIB, size \(data.count) bytes (expected minSize \(range.minSize))")
            //try data.write(to: URL(fileURLWithPath: "/Users/patrick/Downloads/multipart2.grib"))
            do {
                return try data.withUnsafeBytes { ptr in
                    let grib = try GribMemory(ptr: ptr)
                    if grib.messages.count != matches.count {
                        logger.error("Grib reader did not get all matched variables. Matches count \(matches.count). Grib count \(grib.messages.count)")
                        throw CurlError.didNotGetAllGribMessages(got: grib.messages.count, expected: matches.count)
                    }
                    var itr = zip(matches, grib.messages).makeIterator()
                    return AnyIterator {
                        guard let (variable, message) = itr.next() else {
                            return nil
                        }
                        return (variable, message)
                    }
                }
            } catch {
                if i == 3 {
                    throw error
                }
            }
        }
        fatalError("not reachable")
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

protocol CurlIndexedVariable {
    /// Return true, if this index string is matching. Index string looks like `13:520719:d=2022080900:ULWRF:top of atmosphere:anl:`
    /// If nil, this record is ignored
    var gribIndexName: String? { get }
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
