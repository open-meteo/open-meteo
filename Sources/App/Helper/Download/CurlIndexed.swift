import Foundation
import Vapor
import SwiftEccodes


protocol CurlIndexedVariable {
    /// Return true, if this index string is matching. Index string looks like `13:520719:d=2022080900:ULWRF:top of atmosphere:anl:`
    /// If nil, this record is ignored
    var gribIndexName: String? { get }
}

extension Curl {
    
    /// Download index file and match against curl variable
    func downloadIndexAndDecode<Variable: CurlIndexedVariable>(url: [String], variables: [Variable]) async throws -> [(matches: [Variable], range: String, minSize: Int)] {
        let count = variables.reduce(0, { return $0 + ($1.gribIndexName == nil ? 0 : 1) })
        if count == 0 {
            return []
        }
        
        var indices = [String]()
        indices.reserveCapacity(url.count)
        for url in url {
            guard let index = try await downloadInMemoryAsync(url: url, minSize: nil).readStringImmutable() else {
                fatalError("Could not decode index to string")
            }
            indices.append(index)
        }

        var result = [(matches: [Variable], range: String, minSize: Int)]()
        result.reserveCapacity(url.count)
        
        for index in indices {
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
                result.append((matches, "", 0))
                continue
            }
            result.append((matches, range.range, range.minSize))
        }
        
        var missing = false
        for variable in variables {
            guard let gribIndexName = variable.gribIndexName else {
                continue
            }
            if !result.contains(where: { $0.matches.contains(where: {$0.gribIndexName == gribIndexName}) }) {
                logger.error("Variable \(variable) '\(gribIndexName)' missing")
                missing = true
            }
        }
        if missing {
            throw CurlError.didNotFindAllVariablesInGribIndex
        }
        
        return result
    }
    
    
    /// Download an indexed grib file, but selects only required grib messages
    /// Data is downloaded directly into memory and GRIB decoded while iterating
    func downloadIndexedGrib<Variable: CurlIndexedVariable>(url: [String], variables: [Variable], extension: String = ".idx") async throws -> [(variable: Variable, message: GribMessage)] {
        
        let urlIndex = url.map({"\($0)\(`extension`)"})
        let inventories = try await downloadIndexAndDecode(url: urlIndex, variables: variables)
        guard !inventories.isEmpty else {
            return []
        }
        
        // Retry download 20 times with increasing retry delay to get the correct number of grib messages
        var retries = 0
        while true {
            do {
                var result = [(variable: Variable, message: GribMessage)]()
                result.reserveCapacity(variables.count)
                for (url,inventory) in zip(url,inventories) {
                    if inventory.matches.isEmpty {
                        continue
                    }
                    let messages = try await downloadGrib(url: url, bzip2Decode: false, range: inventory.range, minSize: inventory.minSize)
                    
                    if messages.count != inventory.matches.count {
                        logger.error("Grib reader did not get all matched variables. Matches count \(inventory.matches.count). Grib count \(messages.count)")
                        throw CurlError.didNotGetAllGribMessages(got: messages.count, expected: inventory.matches.count)
                    }
                    zip(inventory.matches, messages).forEach({ result.append(($0,$1))})
                }
                return result
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
        
        guard let inventory = try await downloadIndexAndDecode(url: ["\(url)\(`extension`)"], variables: variables).first else {
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
