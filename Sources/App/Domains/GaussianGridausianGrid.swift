import Foundation

///Native grid for ECMWF IFS
///ftp://ftp.ecmwf.int/pub/landseamask/lsmoro_cy41r2_O1280.grib
struct GaussianGrid: Gridable {
    enum GridType {
        case o1280
        
        var count: Int {
            return 4 * 1280 * (1280 + 9) // 6599680
        }
    }
    
    let type: GridType
    
    var nx: Int { type.count }
    
    var ny: Int { 1 }
    
    func findPointInterpolated(lat: Float, lon: Float) -> GridPoint2DFraction? {
        fatalError("fractional grid position not possible with Gaussian Grid")
    }
    
    func getCoordinates(gridpoint: Int) -> (latitude: Float, longitude: Float) {
        // TODO
        return (0,0)
    }
    
    @inlinable func nxOf(y: Int) -> Int {
        return y < 1280 ? (20 + y * 4) : ((2*1280 - y - 1) * 4 + 20)
    }
    
    /// Integrate the number of grid points at this latitude line
    @inlinable func integral(y: Int) -> Int {
        return y < 1280 ? (2*y*y + 18 * y) : (6599680 - (2*(2*1280-y)*(2*1280-y) + 18 * (2*1280-y)))
    }
    
    func findPoint(lat: Float, lon: Float) -> Int? {
        let dy = Float(180)/(2*1280+0.5)
        let y = Int(round(Float(1280) - 1 - (lat / dy))) % (2*1280)
        
        let nx = nxOf(y: y)
        let dx = 360 / Float(nx)
        
        let x = (Int(round(lon / dx)) + nx) % nx
        return integral(y: y) + x
    }
}
