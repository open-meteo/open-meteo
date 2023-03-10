import Foundation

/// Native grid for ECMWF IFS O1280
struct GaussianGrid: Gridable {
    enum GridType {
        case o1280
        
        var count: Int {
            return 4 * 1280 * (1280 + 9) // 6599680
        }
    }
    
    let type: GridType
    
    var nx: Int { type.count }
    
    var ny: Int { return 4 * 1280 * (1280 + 9) }
    
    func findPointInterpolated(lat: Float, lon: Float) -> GridPoint2DFraction? {
        fatalError("fractional grid position not possible with Gaussian Grid")
    }
    
    func getCoordinates(gridpoint: Int) -> (latitude: Float, longitude: Float) {
        let y = gridpoint < count / 2 ? Int((sqrt(2 * Float(gridpoint) + 81) - 9) / 2) : (2*1280 - 1 - Int((sqrt(2 * Float(count - gridpoint - 1) + 81) - 9) / 2))
        let x = gridpoint - integral(y: y)
        let nx = nxOf(y: y)
        let dx = 360 / Float(nx)
        let dy = Float(180)/(2*1280 + 0.5)
        let lon = Float(x) * dx
        // grid points are shifted by dy/2
        //print("y=\(y) x=\(x)")
        return (Float(1280 - y - 1) * dy + dy/2, lon >= 180 ? lon - 360 : lon)
    }
    
    @inlinable func nxOf(y: Int) -> Int {
        return y < 1280 ? (20 + y * 4) : ((2*1280 - y - 1) * 4 + 20)
    }
    
    /// Integrate the number of grid points at this latitude line
    @inlinable func integral(y: Int) -> Int {
        return y < 1280 ? (2*y*y + 18 * y) : (count - (2*(2*1280-y)*(2*1280-y) + 18 * (2*1280-y)))
    }
    
    func findPoint(lat: Float, lon: Float) -> Int? {
        let dy = Float(180)/(2*1280+0.5)
        let y = (Int(round(Float(1280) - 1 - ((lat - dy/2) / dy))) + 2*1280) % (2*1280)
        
        let nx = nxOf(y: y)
        let dx = 360 / Float(nx)
        
        let x = (Int(round(lon / dx)) + nx) % nx
        //print("y=\(y) x=\(x)")
        return integral(y: y) + x
    }
}
