import Foundation

/// A geographic subset of a Gaussian grid backed by a flat 1D array.
///
/// TODO:
/// - Optimised terrain and sea grid cell resolution
///
/// Local array indices `(0..<nx)` enumerate points north-to-south, then west-to-east within each
/// latitude line — the same order as the subset extracted from the full grid.
struct GaussianGridArea: Gridable {
    typealias SliceType = GaussianGridAreaSlice

    let type: GaussianGrid.GridType
    let bounds: BoundingBoxWGS84

    /// First latitude line index in global Gaussian grid coordinates (0 = north pole side)
    let yStart: Int
    /// One past the last latitude line index
    let yEnd: Int

    /// Prefix sums: `prefixSum[i]` = total points in lines 0..<i; length is `lineCount + 1`
    let prefixSum: [Int]

    /// Total number of grid points in the area
    var nx: Int { prefixSum[prefixSum.count - 1] }
    var ny: Int { 1 }
    var searchRadius: Int { 1 }

    var crsWkt2: String {
        return """
            GEOGCRS["Reduced Gaussian Grid",
                DATUM["World Geodetic System 1984",
                    ELLIPSOID["WGS 84",6378137,298.257223563]],
                CS[ellipsoidal,2],
                    AXIS["latitude",north],
                    AXIS["longitude",east],
                    ANGLEUNIT["degree",0.0174532925199433],
                REMARK["Reduced Gaussian Grid \(type.proj4Title) Area (ECMWF)"],
                USAGE[
                    SCOPE["grid"],
                    BBOX[\(bounds.latitude.lowerBound),\(bounds.longitude.lowerBound),\(bounds.latitude.upperBound),\(bounds.longitude.upperBound)]]]
            """
    }

    init(type: GaussianGrid.GridType, bounds: BoundingBoxWGS84) {
        self.type = type
        self.bounds = bounds

        let latitudeLines = type.latitudeLines
        let dy = Float(180) / (2 * Float(latitudeLines) + 0.5)

        // y=0 is near the north pole; convert latitude bounds to y-indices.
        // Clamp to valid range [0, 2*latitudeLines-1].
        let y1 = max(0, min(2 * latitudeLines - 1,
            Int(round(Float(latitudeLines) - 1 - ((bounds.latitude.upperBound - dy / 2) / dy)))))
        let y2 = max(0, min(2 * latitudeLines - 1,
            Int(round(Float(latitudeLines) - 1 - ((bounds.latitude.lowerBound - dy / 2) / dy)))))

        self.yStart = y1
        self.yEnd   = y2 + 1

        let lineCount = yEnd - yStart
        var prefix   = [Int](repeating: 0, count: lineCount + 1)

        for i in 0..<lineCount {
            let y     = y1 + i
            let nxLine = type.nxOf(y: y)
            let dx    = 360 / Float(nxLine)
            let x1    = (Int(bounds.longitude.lowerBound / dx) + nxLine) % nxLine
            let x2    = (Int(bounds.longitude.upperBound / dx) + nxLine) % nxLine
            // When x2 < x1 the range wraps across 0°/360°
            let n     = x2 >= x1 ? (x2 - x1 + 1) : (nxLine - x1 + x2 + 1)
            prefix[i + 1]    = prefix[i] + n
        }
        self.prefixSum     = prefix
    }

    func findPointInterpolated(lat: Float, lon: Float) -> GridPoint2DFraction? {
        fatalError("fractional grid position not possible with GaussianGridArea")
    }

    /// Convert a local 1D array index to WGS84 coordinates.
    func getCoordinates(gridpoint: Int) -> (latitude: Float, longitude: Float) {
        let latitudeLines = type.latitudeLines
        let dy = Float(180) / (2 * Float(latitudeLines) + 0.5)

        // Binary search: find the largest lineIdx such that prefixSum[lineIdx] <= gridpoint.
        var lo = 0
        var hi = prefixSum.count - 2   // lineIdx lives in 0..<lineCount
        while lo < hi {
            let mid = (lo + hi + 1) / 2
            if prefixSum[mid] <= gridpoint { lo = mid } else { hi = mid - 1 }
        }
        let lineIdx = lo
        let y      = yStart + lineIdx
        let nxLine = type.nxOf(y: y)
        let dx     = 360 / Float(nxLine)
        let xOffset = gridpoint - prefixSum[lineIdx]
        let x1    = (Int(bounds.longitude.lowerBound / dx) + nxLine) % nxLine
        let x      = (x1 + xOffset) % nxLine
        let lon    = Float(x) * dx
        let lat    = Float(latitudeLines - y - 1) * dy + dy / 2
        return (lat, lon >= 180 ? lon - 360 : lon)
    }

    /// Map WGS84 coordinates to the local 1D array index, or `nil` if the point falls outside the area.
    func findPoint(lat: Float, lon: Float) -> Int? {
        let latitudeLines = type.latitudeLines
        let dy = Float(180) / (2 * Float(latitudeLines) + 0.5)

        // Check both y and y+1, like GaussianGrid, to handle the staggered latitude rows.
        let yApprox = max(0, min(2 * latitudeLines - 2,
            Int(Float(latitudeLines) - 1 - ((lat - dy / 2) / dy))))

        var bestLocal: Int? = nil
        var bestDist = Float.infinity

        for yGlobal in [yApprox, yApprox + 1] {
            guard yGlobal >= yStart && yGlobal < yEnd else { continue }
            let lineIdx = yGlobal - yStart
            let nxLine  = type.nxOf(y: yGlobal)
            let dx      = 360 / Float(nxLine)
            let xGlobal = (Int(round(lon / dx)) + nxLine) % nxLine
            let x1    = (Int(bounds.longitude.lowerBound / dx) + nxLine) % nxLine
            let x2    = (Int(bounds.longitude.upperBound / dx) + nxLine) % nxLine
            let xRel    = (xGlobal - x1 + nxLine) % nxLine
            let n     = x2 >= x1 ? (x2 - x1 + 1) : (nxLine - x1 + x2 + 1)
            guard xRel < n else { continue }
            let localIndex  = prefixSum[lineIdx] + xRel
            let pointLat    = Float(latitudeLines - yGlobal - 1) * dy + dy / 2
            let pointLon    = Float(xGlobal) * dx
            let pointLonNorm = pointLon >= 180 ? pointLon - 360 : pointLon
            let dist = (pointLat - lat) * (pointLat - lat) + (pointLonNorm - lon) * (pointLonNorm - lon)
            if dist < bestDist {
                bestDist  = dist
                bestLocal = localIndex
            }
        }
        return bestLocal
    }

    func findBox(boundingBox bb: BoundingBoxWGS84) -> GaussianGridAreaSlice? {
        return GaussianGridAreaSlice(area: self, bb: bb)
    }
}

/// A sub-region of a `GaussianGridArea`, yielding local 1D indices.
struct GaussianGridAreaSlice: Sequence {
    let area: GaussianGridArea
    let bb: BoundingBoxWGS84

    func makeIterator() -> GaussianGridAreaSliceIterator {
        let latitudeLines = area.type.latitudeLines
        let dy = Float(180) / (2 * Float(latitudeLines) + 0.5)

        let y1: Int = Int(round(Float(latitudeLines) - 1 - ((bb.latitude.upperBound - dy / 2) / dy)))
        let y2: Int = Int(round(Float(latitudeLines) - 1 - ((bb.latitude.lowerBound - dy / 2) / dy)))
        
        // Clamp y bounds to the area's row range
        let y1Clamped = Swift.max(area.yStart, Swift.min(area.yEnd - 1, y1))
        let y2Clamped = Swift.max(area.yStart, Swift.min(area.yEnd - 1, y2))

        let startLineIdx = y1Clamped - area.yStart
        let endLineIdx   = y2Clamped - area.yStart

        var iter = GaussianGridAreaSliceIterator(
            area: area,
            lineIdx: startLineIdx,
            lineIdxEnd: endLineIdx,
            xOffset: 0,
            xOffsetEnd: 0,
            bb: bb
        )
        if startLineIdx <= endLineIdx {
            iter.setupLine()
        }
        return iter
    }
}

struct GaussianGridAreaSliceIterator: IteratorProtocol {
    let area: GaussianGridArea
    var lineIdx: Int
    let lineIdxEnd: Int
    var xOffset: Int
    var xOffsetEnd: Int
    let bb: BoundingBoxWGS84

    /// Compute the x-offset range [xOffset, xOffsetEnd) for the current latitude line.
    mutating func setupLine() {
        let y      = area.yStart + lineIdx
        let nxLine = area.type.nxOf(y: y)
        let dx     = 360 / Float(nxLine)
        let x1Sub  = (Int(round(bb.longitude.lowerBound / dx)) + nxLine) % nxLine
        let x2Sub  = (Int(round(bb.longitude.upperBound / dx)) + nxLine) % nxLine
        let x1    = (Int(area.bounds.longitude.lowerBound / dx) + nxLine) % nxLine
        let x2    = (Int(area.bounds.longitude.upperBound / dx) + nxLine) % nxLine
        let n     = x2 >= x1 ? (x2 - x1 + 1) : (nxLine - x1 + x2 + 1)
        let areaX1    = x1
        let areaCount = n
        // Express sub-bbox x bounds as offsets from the area's western edge, clamped to [0, areaCount)
        let rel1   = (x1Sub - areaX1 + nxLine) % nxLine
        let rel2   = (x2Sub - areaX1 + nxLine) % nxLine
        xOffset    = min(rel1, areaCount)
        xOffsetEnd = min(rel2 + 1, areaCount)
    }

    mutating func next() -> Int? {
        // Advance through lines until we find a non-empty x range
        while xOffset >= xOffsetEnd {
            lineIdx += 1
            guard lineIdx <= lineIdxEnd else { return nil }
            setupLine()
        }
        let result = area.prefixSum[lineIdx] + xOffset
        xOffset += 1
        return result
    }
}
