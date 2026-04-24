import Foundation
import OmFileFormat

/// Native grid for ECMWF IFS O1280
struct GaussianGrid: Gridable {
    var crsWkt2: String {
        // Gaussian grids do not have a OGC WTK2 string. Encode the Gaussian grid type as id "gaussian_grid"
        return """
            GEOGCRS["Reduced Gaussian Grid",
                DATUM["World Geodetic System 1984",
                    ELLIPSOID["WGS 84",6378137,298.257223563]],
                CS[ellipsoidal,2],
                    AXIS["latitude",north],
                    AXIS["longitude",east],
                    ANGLEUNIT["degree",0.0174532925199433],
                REMARK["Reduced Gaussian Grid \(type.proj4Title) (ECMWF)"],
                USAGE[
                    SCOPE["grid"],
                    BBOX[-90,-180.0,90,180]]]
            """
    }

    enum GridType {
        case o1280
        case o320
        case n320
        case n160
        
        var proj4Title: String {
            switch self {
            case .o1280:
                return "O1280"
            case .o320:
                return "O320"
            case .n320:
                return "N320"
            case .n160:
                return "N160"
            }
        }

        /// Note quite sure if there is an analytical solution for N type grid. https://confluence.ecmwf.int/display/FCST/Gaussian+grid+with+320+latitude+lines+between+pole+and+equator
        /// Therefore here is a lookup table
        static let n320CountPerLine = [18, 25, 36, 40, 45, 50, 60, 64, 72, 72, 75, 81, 90, 96, 100, 108, 120, 120, 125, 135, 144, 144, 150, 160, 180, 180, 180, 192, 192, 200, 216, 216, 216, 225, 240, 240, 240, 250, 256, 270, 270, 288, 288, 288, 300, 300, 320, 320, 320, 324, 360, 360, 360, 360, 360, 360, 375, 375, 384, 384, 400, 400, 405, 432, 432, 432, 432, 450, 450, 450, 480, 480, 480, 480, 480, 486, 500, 500, 500, 512, 512, 540, 540, 540, 540, 540, 576, 576, 576, 576, 576, 576, 600, 600, 600, 600, 640, 640, 640, 640, 640, 640, 640, 648, 648, 675, 675, 675, 675, 720, 720, 720, 720, 720, 720, 720, 720, 720, 729, 750, 750, 750, 750, 768, 768, 768, 768, 800, 800, 800, 800, 800, 800, 810, 810, 864, 864, 864, 864, 864, 864, 864, 864, 864, 864, 864, 900, 900, 900, 900, 900, 900, 900, 900, 960, 960, 960, 960, 960, 960, 960, 960, 960, 960, 960, 960, 960, 960, 972, 972, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1024, 1024, 1024, 1024, 1024, 1024, 1080, 1080, 1080, 1080, 1080, 1080, 1080, 1080, 1080, 1080, 1080, 1080, 1080, 1080, 1125, 1125, 1125, 1125, 1125, 1125, 1125, 1125, 1125, 1125, 1125, 1125, 1125, 1125, 1152, 1152, 1152, 1152, 1152, 1152, 1152, 1152, 1152, 1200, 1200, 1200, 1200, 1200, 1200, 1200, 1200, 1200, 1200, 1200, 1200, 1200, 1200, 1200, 1200, 1200, 1200, 1215, 1215, 1215, 1215, 1215, 1215, 1215, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280]
        
        /// https://confluence.ecmwf.int/display/UDOC/N160
        static let n160CountPerLine = [18,25,36,40,45,50,60,64,72,72,80,90,90,96,108,120,120,125,128,135,144,150,160,160,180,180,180,192,192,200,216,216,225,225,240,240,243,250,256,270,270,288,288,288,300,300,320,320,320,320,324,360,360,360,360,360,360,375,375,375,384,384,400,400,400,405,432,432,432,432,432,450,450,450,450,480,480,480,480,480,480,480,500,500,500,500,500,512,512,540,540,540,540,540,540,540,540,576,576,576,576,576,576,576,576,576,576,600,600,600,600,600,600,600,600,600,640,640,640,640,640,640,640,640,640,640,640,640,640,640,640,640,640,640,640,640,640,640,640,640,640,640,640,640,640,640,640,640,640,640,640,640,640,640,640,640,640,640,640,640]

        var count: Int {
            switch self {
            case .o1280, .o320:
                // o1280 = 6599680
                // o320 = 421120
                return 4 * latitudeLines * (latitudeLines + 9)
            case .n320:
                return 542080
            case .n160:
                return 138346
            }
        }

        var latitudeLines: Int {
            switch self {
            case .o1280:
                return 1280
            case .o320:
                return 320
            case .n320:
                return 320
            case .n160:
                return 160
            }
        }
        
        private var countPerLine: [Int] {
            switch self {
            case .o1280, .o320:
                return []
            case .n320:
                return Self.n320CountPerLine
            case .n160:
                return Self.n160CountPerLine
            }
        }

        @inlinable func nxOf(y: Int) -> Int {
            switch self {
            case .o1280, .o320:
                return y < latitudeLines ? (20 + y * 4) : ((2 * latitudeLines - y - 1) * 4 + 20)
            case .n320, .n160:
                return y < latitudeLines ? countPerLine[y] : countPerLine[2 * countPerLine.count - y - 1]
            }
        }

        /// Integrate the number of grid points at this latitude line
        @inlinable func integral(y: Int) -> Int {
            switch self {
            case .o1280, .o320:
                return y < latitudeLines ? (2 * y * y + 18 * y) : (count - (2 * (2 * latitudeLines - y) * (2 * latitudeLines - y) + 18 * (2 * latitudeLines - y)))
            case .n320, .n160:
                if y < latitudeLines {
                    return countPerLine[0..<y].reduce(0, +)
                }
                // return count / 2 + Self.n320CountPerLine.reversed()[0..<y-Self.n320CountPerLine.count].reduce(0, +)
                return count / 2 + countPerLine[2 * countPerLine.count - y ..< countPerLine.count].reduce(0, +)
            }
        }

        /// Find latitude line for given grid-point
        @inlinable func getPos(gridpoint: Int) -> (y: Int, x: Int, nxPerLine: Int) {
            switch self {
            case .o1280, .o320:
                let y = gridpoint < count / 2 ? Int((sqrt(2 * Float(gridpoint) + 81) - 9) / 2) : (2 * latitudeLines - 1 - Int((sqrt(2 * Float(count - gridpoint - 1) + 81) - 9) / 2))
                let x = gridpoint - integral(y: y)
                let nx = nxOf(y: y)
                return (y, x, nx)
            case .n320, .n160:
                var sum = 0
                for (y, n) in countPerLine.enumerated() {
                    sum += n
                    if gridpoint < sum {
                        return (y, gridpoint - (sum - n), n)
                    }
                }
                for (y, n) in countPerLine.reversed().enumerated() {
                    sum += n
                    if gridpoint < sum {
                        return (y + countPerLine.count, gridpoint - (sum - n), n)
                    }
                }
                fatalError("Index out of range")
            }
        }
    }

    let type: GridType

    var nx: Int { return type.count }

    var ny: Int { 1 }

    var searchRadius: Int {
        return 1
    }

    func findPointInterpolated(lat: Float, lon: Float) -> GridPoint2DFraction? {
        fatalError("fractional grid position not possible with Gaussian Grid")
    }

    func getCoordinates(gridpoint: Int) -> (latitude: Float, longitude: Float) {
        let latitudeLines = type.latitudeLines
        let (y, x, nx) = type.getPos(gridpoint: gridpoint)
        let dx = 360 / Float(nx)
        let dy = Float(180) / (2 * Float(latitudeLines) + 0.5)
        let lon = Float(x) * dx
        return (Float(latitudeLines - y - 1) * dy + dy / 2, lon >= 180 ? lon - 360 : lon)
    }

    @inlinable func nxOf(y: Int) -> Int {
        return type.nxOf(y: y)
    }

    /// Integrate the number of grid points at this latitude line
    @inlinable func integral(y: Int) -> Int {
        return type.integral(y: y)
    }

    func findPoint(lat: Float, lon: Float) -> Int? {
        let (x, y) = findPointXY(lat: lat, lon: lon)
        return integral(y: y) + x
    }
    
    /// Find closest grid points for a given coordinate.
    /// Need to evaluate two latitude lines to find the nearest grid-cell, because Gaussian grids are a triangle strip
    func findPointXY(lat: Float, lon: Float) -> (x: Int, y: Int) {
        let latitudeLines = type.latitudeLines

        let dy = Float(180) / (2 * Float(latitudeLines) + 0.5)
        // Note: Limited by `-2` because later we add +1, otherwise it would be `-1`
        let y = max(0, min(2*latitudeLines-2, Int(Float(latitudeLines) - 1 - ((lat - dy / 2) / dy))))
        let yUpper = y + 1

        let nx = nxOf(y: y)
        let nxUpper = nxOf(y: yUpper)
        
        let dx = 360 / Float(nx)
        let dxUpper = 360 / Float(nxUpper)

        let x = Int(round(lon / dx))
        let xUpper = Int(round(lon / dxUpper))
        
        let pointLat = Float(latitudeLines - y - 1) * dy + dy / 2
        let pointLon = Float(x) * dx
        let pointLatUpper = Float(latitudeLines - yUpper - 1) * dy + dy / 2
        let pointLonUpper = Float(xUpper) * dxUpper
        
        let distance = pow(pointLat - lat, 2) + pow(pointLon - lon, 2)
        let distanceUpper = pow(pointLatUpper - lat, 2) + pow(pointLonUpper - lon, 2)
        
        return distance < distanceUpper ? ((x + nx) % nx, y) : ((xUpper + nxUpper) % nxUpper, yUpper)
    }

    func findBox(boundingBox bb: BoundingBoxWGS84) -> Slice? {
        return Slice(type: type, bb: bb)
    }
    
    /// Get a list of grid points surrounding a coordinate. Used to find sea grid points of optimize for land grid cells
    func getSurroundingGridpoints(centerY: Int, lat: Float, lon: Float, elevationFile: any OmFileReaderArrayProtocol<Float>) async throws -> (gridpoints: [Int], elevations: [Float], distances: [Float]) {
        
        let latitudeLines = type.latitudeLines
        let dy = Float(180) / (2 * Float(latitudeLines) + 0.5)
        
        let yrange = (centerY - searchRadius..<centerY + searchRadius + 1).clamped(to: 0..<2*latitudeLines)
        let width = 2*searchRadius + 1
        
        /// List of 3x3 gridpoints we want to read in linear 1D array index
        /// `x` wraps at 0° longitude
        var gridpoints: [Int] = []
        var distances: [Float] = []
        gridpoints.reserveCapacity(yrange.count * width)
        distances.reserveCapacity(yrange.count * width)
        for y in yrange {
            let nx = nxOf(y: y)
            let dx = 360 / Float(nx)
            let xCenter = Int(round(lon / dx))
            let pointLat = Float(latitudeLines - y - 1) * dy + dy / 2

            /// If x wraps over 0° longitude, start at an offset to get a strictly increasing grid-point list
            let start = max(0, searchRadius - xCenter)
            for i in 0..<width {
                let i = (i + start) % width
                let x = xCenter + i - searchRadius
                gridpoints.append(integral(y: y) + (x + 2*nx) % nx)
                let pointLon = Float(x) * dx
                distances.append(pow(pointLat - lat, 2) + pow(pointLon - lon, 2))
            }
        }
        
        var start = 0
        /// Read grid elevation from list of gridpoints that might be consecutive
        /// -999 marks sea points, therefore  elevation matching will naturally avoid those
        var elevation = [Float](repeating: .nan, count: gridpoints.count)
        for i in gridpoints.indices {
            // if next one is not increasing by one, read it
            let lastIteration = i == gridpoints.count - 1
            if lastIteration || gridpoints[i] != gridpoints[i + 1] - 1 {
                // read data from start to end
                try await elevationFile.read(
                    into: &elevation,
                    range: [0..<1, UInt64(gridpoints[start])..<UInt64(gridpoints[i]+1)],
                    intoCubeOffset: [0, UInt64(start)],
                    intoCubeDimension: [1, UInt64(gridpoints.count)]
                )
                start = i+1
            }
        }
        
        return (gridpoints, elevation, distances)
    }
    
    /// Find point, preferably in sea
    /// O1280 implementation: For every latitude line, the x-ranges are calculated to read elevation data. Effectively reads 3x3 elevation information, but considers the Gaussian grid point staggering. Overlapping ranges that wrap on 0° longitude are merged to reduce IO.
    func findPointInSea(lat: Float, lon: Float, elevationFile: any OmFileReaderArrayProtocol<Float>) async throws -> (gridpoint: Int, gridElevation: ElevationOrSea)? {
        
        let (centerX, centerY) = findPointXY(lat: lat, lon: lon)
        let centerPoint = integral(y: centerY) + centerX
        let centerElevation = try await readFromStaticFile(gridpoint: centerPoint, file: elevationFile)
        if centerElevation <= -999 {
            return (centerPoint, .sea)
        }
        let (points, elevations, distances) = try await getSurroundingGridpoints(centerY: centerY, lat: lat, lon: lon, elevationFile: elevationFile)
        var minDistance = Float(9999)
        var minPosition = -1
        for i in elevations.indices {
            if elevations[i].isNaN {
                continue
            }
            let distance = distances[i]
            if elevations[i] <= -999 && distance < minDistance {
                minDistance = distance
                minPosition = points[i]
            }
        }
        guard minPosition >= 0 else {
            if centerElevation.isNaN {
                return (centerPoint, .noData)
            }
            return (centerPoint, .elevation(centerElevation))
        }
        return (minPosition, .sea)
    }
    
    func findPointTerrainOptimised(lat: Float, lon: Float, elevation: Float, elevationFile: any OmFileReaderArrayProtocol<Float>) async throws -> (gridpoint: Int, gridElevation: ElevationOrSea)? {
        
        let (centerX, centerY) = findPointXY(lat: lat, lon: lon)
        let centerPoint = integral(y: centerY) + centerX
        let centerElevation = try await readFromStaticFile(gridpoint: centerPoint, file: elevationFile)
        let deltaCenter = abs(centerElevation - elevation )
        if deltaCenter <= 100 {
            return (centerPoint, .elevation(elevation))
        }
        let (points, elevations, distances) = try await getSurroundingGridpoints(centerY: centerY, lat: lat, lon: lon, elevationFile: elevationFile)
        var minDelta = Float(9999)
        var minPosition = -1
        var minElevation = Float.nan
        for i in elevations.indices {
            if elevations[i].isNaN || elevations[i] <= -999 {
                continue
            }
            let distanceKm = sqrt(distances[i])*111
            /// For every 1km in distance, the elevation must be 30 m better
            let distancePenalty = distanceKm * 30
            let delta = abs(elevations[i] - elevation) + distancePenalty
            //print("point \(points[i]) elevation \(elevations[i]) delta \(delta) distance ~\(distanceKm) km, penalty \(distancePenalty) m")
            if delta < minDelta && distanceKm < 50 {
                minDelta = delta
                minPosition = points[i]
                minElevation = elevations[i]
            }
        }
        /// only sea points or elevation is hugely off -> just use center
        if minElevation.isNaN || minDelta > 1500 {
            minElevation = centerElevation
            minPosition = centerPoint
        }
        if minElevation <= -999 {
            return (minPosition, .sea)
        }
        return (minPosition, .elevation(minElevation))
    }
}

extension GaussianGrid {
    /// Represent a subsection of a gaussian grid
    /// Important: The iterated coordinates are in global coordinates (-> gridpoint index). Array slices would use local indices.
    struct Slice {
        let type: GridType
        let bb: BoundingBoxWGS84
    }
}

extension GaussianGrid.Slice: Sequence {
    func makeIterator() -> SliceIterator {
        let latitudeLines = type.latitudeLines
        let dy = Float(180) / (2 * Float(latitudeLines) + 0.5)
        let y1 = Swift.max(0, Swift.min(2*latitudeLines-1, Int(round(Float(latitudeLines) - 1 - ((bb.latitude.upperBound - dy / 2) / dy)))))
        let y2 = Swift.max(0, Swift.min(2*latitudeLines-1, Int(round(Float(latitudeLines) - 1 - ((bb.latitude.lowerBound - dy / 2) / dy)))))
                  
        let nx = type.nxOf(y: y1)
        let dx = 360 / Float(nx)
        let x1 = (Int(round(bb.longitude.lowerBound / dx)) + nx) % nx
        let x2 = (Int(round(bb.longitude.upperBound / dx)) + nx) % nx

        return SliceIterator(
            position: type.integral(y: y1) + x1,
            y: y1,
            x: x1,
            nx: nx,
            xEnd: x2,
            yEnd: y2,
            type: type,
            longitude: bb.longitude
        )
    }

    /// Iterate over a subset of a grib following x and y ranges. The element returns the global grid coordinate (grid point index as integer)
    struct SliceIterator: IteratorProtocol {
        var position: Int

        var y: Int

        var x: Int

        /// number of longitudes in this latitude line
        var nx: Int

        var xEnd: Int

        let yEnd: Int

        let type: GaussianGrid.GridType

        let longitude: Range<Float>

        mutating func next() -> Int? {
            // check if x exceeds x-range
            if x >= xEnd {
                // move y forward if possible
                guard y + 1 < yEnd else {
                    return nil
                }
                y = y + 1
                position = position - x + nx // move position to new line
                nx = type.nxOf(y: y)
                let dx = 360 / Float(nx)
                x = (Int(round(longitude.lowerBound / dx)) + nx) % nx
                position += x // move position in line to x
                xEnd = (Int(round(longitude.upperBound / dx)) + nx) % nx
            }
            position += 1
            x += 1
            return position - 1
        }
    }
}

/// A geographic subset of a Gaussian grid backed by a flat 1D array.
/// Local array indices (0..<nx) enumerate points north-to-south, then west-to-east within each
/// latitude line — the same order as the subset extracted from the full grid.
struct GaussianGridArea: Gridable {
    typealias SliceType = GaussianGridAreaSlice

    let type: GaussianGrid.GridType
    let bounds: BoundingBoxWGS84

    /// First latitude line index in global Gaussian grid coordinates (0 = north pole side)
    let yStart: Int
    /// One past the last latitude line index
    let yEnd: Int
    /// Starting global-x index for each latitude line within the area (0-based per line in area)
    let lineXStart: [Int]
    /// Number of grid points retained within the longitude bounds for each latitude line
    let linePointCount: [Int]
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
        var xStarts  = [Int](repeating: 0, count: lineCount)
        var counts   = [Int](repeating: 0, count: lineCount)
        var prefix   = [Int](repeating: 0, count: lineCount + 1)

        for i in 0..<lineCount {
            let y     = y1 + i
            let nxLine = type.nxOf(y: y)
            let dx    = 360 / Float(nxLine)
            let x1    = (Int(round(bounds.longitude.lowerBound / dx)) + nxLine) % nxLine
            let x2    = (Int(round(bounds.longitude.upperBound / dx)) + nxLine) % nxLine
            // When x2 < x1 the range wraps across 0°/360°
            let n     = x2 >= x1 ? (x2 - x1 + 1) : (nxLine - x1 + x2 + 1)
            xStarts[i]       = x1
            counts[i]        = n
            prefix[i + 1]    = prefix[i] + n
        }

        self.lineXStart    = xStarts
        self.linePointCount = counts
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
        let x      = (lineXStart[lineIdx] + xOffset) % nxLine
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
            let xRel    = (xGlobal - lineXStart[lineIdx] + nxLine) % nxLine
            guard xRel < linePointCount[lineIdx] else { continue }
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
        let areaX1    = area.lineXStart[lineIdx]
        let areaCount = area.linePointCount[lineIdx]
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
