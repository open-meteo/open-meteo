import Foundation
import Vapor
import SwiftEccodes


protocol CurlIndexedVariable {
    /// Return true, if this index string is matching. Index string looks like `13:520719:d=2022080900:ULWRF:top of atmosphere:anl:`
    /// If nil, this record is ignored
    var gribIndexName: String? { get }
    
    /// If true, the exact string needs to match at the end
    var exactMatch: Bool { get }
}

extension Curl {
    
    /// {"domain": "g", "date": "20230501", "time": "0000", "expver": "0001", "class": "od", "type": "fc", "stream": "oper", "step": "102", "levelist": "300", "levtype": "pl", "param": "t", "_offset": 6699726, "_length": 609046}
    /// {"domain": "g", "date": "20230501", "time": "0000", "expver": "0001", "class": "od", "type": "pf", "stream": "enfo", "step": "102", "levelist": "925", "levtype": "pl", "number": "4", "param": "u", "_offset": 291741552, "_length": 609069}
    struct EcmwfIndexEntry: Decodable {
        enum LevelType: String, Decodable {
            case sfc
            case pl
            case sol
        }
        /// pressure or surface level
        let levtype: LevelType
        /// For pressure level, strings like "925"
        let levelist: String?
        /// ensemle member number
        let number: String?
        /// Short grib name like `u` or `t2`
        let param: String
        let _offset: Int
        let _length: Int
        
        var level: Int? {
            return levelist.flatMap(Int.init)
        }
    }
    
    /// Download a ECMWF grib file from the opendata server, but selectively get messages and download only partial file
    func downloadEcmwfIndexed(url: String, concurrent: Int, isIncluded: (EcmwfIndexEntry) -> Bool) async throws -> AnyAsyncSequence<GribMessage> {
        let urlIndex = url.replacingOccurrences(of: ".grib2", with: ".index")
        let index = try await downloadInMemoryAsync(url: urlIndex, minSize: nil).readEcmwfIndexEntries().filter(isIncluded)
        guard !index.isEmpty else {
            fatalError("Empty grib selection")
        }
        let ranges = index.indexToRange()
        return ranges.mapStream(nConcurrent: 1, body: {
            range in try await self.downloadGrib(url: url, bzip2Decode: false, range: range.range, minSize: range.minSize, nConcurrent: concurrent)
        }).flatMap({$0.mapStream(nConcurrent: 1, body: {$0})}).eraseToAnyAsyncSequence()
    }
    
    /// Download index file and match against curl variable
    func downloadIndexAndDecode<Variable: CurlIndexedVariable>(url: [String], variables: [Variable], errorOnMissing: Bool) async throws -> [(matches: [Variable], range: String, minSize: Int)] {
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
                    if $0.exactMatch {
                        return idx.hasSuffix(gribIndexName)
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
        if missing && errorOnMissing {
            throw CurlError.didNotFindAllVariablesInGribIndex
        }
        
        return result
    }
    
    
    /// Download an indexed grib file, but selects only required grib messages
    /// Data is downloaded directly into memory and GRIB decoded while iterating
    func downloadIndexedGrib<Variable: CurlIndexedVariable>(url: [String], variables: [Variable], extension: String = ".idx", errorOnMissing: Bool = true) async throws -> [(variable: Variable, message: GribMessage)] {
        
        let urlIndex = url.map({"\($0)\(`extension`)"})
        let inventories = try await downloadIndexAndDecode(url: urlIndex, variables: variables, errorOnMissing: errorOnMissing)
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
}

extension ByteBuffer {
    public func readStringImmutable() -> String? {
        var b = self
        return b.readString(length: b.readableBytes)
    }
    /// Decode ECMWF JSON index file
    func readEcmwfIndexEntries() throws -> [Curl.EcmwfIndexEntry] {
        var b = self
        var results = [Curl.EcmwfIndexEntry]()
        while let pos = b.readableBytesView.firstIndex(of: 10) {
            let length = pos - b.readerIndex
            guard let entry = try b.readJSONDecodable(Curl.EcmwfIndexEntry.self, length: length) else {
                fatalError("Could not decode index")
            }
            b.moveReaderIndex(forwardBy: 1)
            results.append(entry)
        }
        if b.readableBytes > 50 {
            guard let entry = try b.readJSONDecodable(Curl.EcmwfIndexEntry.self, length: b.readableBytes) else {
                fatalError("Could not decode index end")
            }
            results.append(entry)
        }
        return results
    }
}

extension Array where Element == Curl.EcmwfIndexEntry {
    /// Convert grib entries to http range download command
    /// Split large range downloads to multiple individual downloads to prevent `request header too large` error
    func indexToRange() -> [(range: String, minSize: Int)] {
        var results = [(range: String, minSize: Int)]()
        var range = ""
        var i = 0
        var size = 0
        var end = 0
        while i < count {
            let entry = self[i]
            range += "\(entry._offset)-"
            size += entry._length
            end = entry._offset + entry._length
            i += 1
            while i < count {
                let entry = self[i]
                if entry._offset != end {
                    range += "\(end)"
                    if range.count > 4000 || size > 64*1024*1024 {
                        results.append((range,size))
                        range = ""
                        size = 0
                        break
                    }
                    range += ","
                    break
                }
                size += entry._length
                end = entry._offset + entry._length
                i += 1
            }
        }
        range += "\(end)"
        results.append((range,size))
        return results
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
