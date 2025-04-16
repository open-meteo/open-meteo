import Foundation

/// Native grid for ECMWF IFS O1280
struct GaussianGrid: Gridable {
    enum GridType {
        case o1280
        case n320

        /// Note quite sure if there is an analysical soltiuion for N type grid. https://confluence.ecmwf.int/display/FCST/Gaussian+grid+with+320+latitude+lines+between+pole+and+equator
        /// Therefore here is a lookup table
        static var n320CountPerLine = [18, 25, 36, 40, 45, 50, 60, 64, 72, 72, 75, 81, 90, 96, 100, 108, 120, 120, 125, 135, 144, 144, 150, 160, 180, 180, 180, 192, 192, 200, 216, 216, 216, 225, 240, 240, 240, 250, 256, 270, 270, 288, 288, 288, 300, 300, 320, 320, 320, 324, 360, 360, 360, 360, 360, 360, 375, 375, 384, 384, 400, 400, 405, 432, 432, 432, 432, 450, 450, 450, 480, 480, 480, 480, 480, 486, 500, 500, 500, 512, 512, 540, 540, 540, 540, 540, 576, 576, 576, 576, 576, 576, 600, 600, 600, 600, 640, 640, 640, 640, 640, 640, 640, 648, 648, 675, 675, 675, 675, 720, 720, 720, 720, 720, 720, 720, 720, 720, 729, 750, 750, 750, 750, 768, 768, 768, 768, 800, 800, 800, 800, 800, 800, 810, 810, 864, 864, 864, 864, 864, 864, 864, 864, 864, 864, 864, 900, 900, 900, 900, 900, 900, 900, 900, 960, 960, 960, 960, 960, 960, 960, 960, 960, 960, 960, 960, 960, 960, 972, 972, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1024, 1024, 1024, 1024, 1024, 1024, 1080, 1080, 1080, 1080, 1080, 1080, 1080, 1080, 1080, 1080, 1080, 1080, 1080, 1080, 1125, 1125, 1125, 1125, 1125, 1125, 1125, 1125, 1125, 1125, 1125, 1125, 1125, 1125, 1152, 1152, 1152, 1152, 1152, 1152, 1152, 1152, 1152, 1200, 1200, 1200, 1200, 1200, 1200, 1200, 1200, 1200, 1200, 1200, 1200, 1200, 1200, 1200, 1200, 1200, 1200, 1215, 1215, 1215, 1215, 1215, 1215, 1215, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280, 1280]

        var count: Int {
            switch self {
            case .o1280:
                return 4 * 1280 * (1280 + 9) // 6599680
            case .n320:
                return 542080
            }
        }

        var latitudeLines: Int {
            switch self {
            case .o1280:
                return 1280
            case .n320:
                return 320
            }
        }

        @inlinable func nxOf(y: Int) -> Int {
            switch self {
            case .o1280:
                return y < latitudeLines ? (20 + y * 4) : ((2 * latitudeLines - y - 1) * 4 + 20)
            case .n320:
                return y < latitudeLines ? Self.n320CountPerLine[y] : Self.n320CountPerLine[2 * Self.n320CountPerLine.count - y - 1]
            }
        }

        /// Integrate the number of grid points at this latitude line
        @inlinable func integral(y: Int) -> Int {
            switch self {
            case .o1280:
                return y < latitudeLines ? (2 * y * y + 18 * y) : (count - (2 * (2 * latitudeLines - y) * (2 * latitudeLines - y) + 18 * (2 * latitudeLines - y)))
            case .n320:
                if y < latitudeLines {
                    return Self.n320CountPerLine[0..<y].reduce(0, +)
                }
                // return count / 2 + Self.n320CountPerLine.reversed()[0..<y-Self.n320CountPerLine.count].reduce(0, +)
                return count / 2 + Self.n320CountPerLine[2 * Self.n320CountPerLine.count - y ..< Self.n320CountPerLine.count].reduce(0, +)
            }
        }

        /// Find latiture line for given gridpoint
        @inlinable func getPos(gridpoint: Int) -> (y: Int, x: Int, nxPerLine: Int) {
            switch self {
            case .o1280:
                let y = gridpoint < count / 2 ? Int((sqrt(2 * Float(gridpoint) + 81) - 9) / 2) : (2 * latitudeLines - 1 - Int((sqrt(2 * Float(count - gridpoint - 1) + 81) - 9) / 2))
                let x = gridpoint - integral(y: y)
                let nx = nxOf(y: y)
                return (y, x, nx)
            case .n320:
                var sum = 0
                for (y, n) in Self.n320CountPerLine.enumerated() {
                    sum += n
                    if gridpoint < sum {
                        return (y, gridpoint - (sum - n), n)
                    }
                }
                for (y, n) in Self.n320CountPerLine.reversed().enumerated() {
                    sum += n
                    if gridpoint < sum {
                        return (y + Self.n320CountPerLine.count, gridpoint - (sum - n), n)
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
        let latitudeLines = type.latitudeLines

        let dy = Float(180) / (2 * Float(latitudeLines) + 0.5)
        let y = (Int(round(Float(latitudeLines) - 1 - ((lat - dy / 2) / dy))) + 2 * latitudeLines) % (2 * latitudeLines)

        let nx = nxOf(y: y)
        let dx = 360 / Float(nx)

        let x = (Int(round(lon / dx)) + nx) % nx
        return integral(y: y) + x
    }

    func findBox(boundingBox bb: BoundingBoxWGS84) -> (any Sequence<Int>)? {
        return Slice(type: type, bb: bb)
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
        let y1 = (Int(round(Float(latitudeLines) - 1 - ((bb.latitude.upperBound - dy / 2) / dy))) + 2 * latitudeLines) % (2 * latitudeLines)
        let y2 = (Int(round(Float(latitudeLines) - 1 - ((bb.latitude.lowerBound - dy / 2) / dy))) + 2 * latitudeLines) % (2 * latitudeLines)

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
