import Foundation
import Vapor
import SwiftEccodes


enum CurlError: Error {
    case noGribMessagesMatch
    case didNotFindAllVariablesInGribIndex
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
        
        while true {
            do {
                return try Process.spawnWithOutputData(cmd: "curl", args: args)
            } catch {
                if Int(Date().timeIntervalSince(startTime)) > maxTimeSeconds {
                    throw error
                }
                sleep(UInt32(retryDelaySeconds))
            }
        }
    }
    
    /// Download an indexed grib file, but selects only required grib messages
    /// Data is downloaded directly into memory and GRIB decoded while iterating
    func downloadIndexedGrib<Variable: CurlIndexedVariable>(url: String, variables: [Variable]) throws -> AnyIterator<(variable: Variable, data: [Float])> {
        
        guard let index = String(data: try downloadInMemory(url: "\(url).idx"), encoding: .utf8) else {
            fatalError("Could not decode index to string")
        }
        
        var matches = [Variable]()
        matches.reserveCapacity(variables.count)
        guard let range = index.split(separator: "\n").indexToRange(include: { idx in
            guard let match = variables.first(where: { idx.contains($0.gribIndexName) }) else {
                return false
            }
            matches.append(match)
            return true
        }) else {
            throw CurlError.noGribMessagesMatch
        }
        logger.debug("Ranged download \(range)")
        
        if variables.allSatisfy({ matches.contains($0) }) {
            throw CurlError.didNotFindAllVariablesInGribIndex
        }
        
        let data = try downloadInMemory(url: url, range: range)
        return data.withUnsafeBytes { data in
            let grib = GribMemory(ptr: data)
            var itr = zip(matches, grib.messages).makeIterator()
            return AnyIterator {
                guard let (variable, message) = itr.next() else {
                    return nil
                }
                guard let data = try? message.getDouble().map(Float.init) else {
                    fatalError("Could not read GRIB data for variable \(variable)")
                }
                return (variable, data)
            }
        }
    }
}

protocol CurlIndexedVariable: Equatable {
    /// Return true, if this index string is matching. Index string looks like `13:520719:d=2022080900:ULWRF:top of atmosphere:anl:`
    var gribIndexName: String { get }
}


extension Sequence where Element == Substring {
    /// Parse a GRID index to curl read ranges
    func indexToRange(include: (Substring) -> Bool) -> String? {
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
