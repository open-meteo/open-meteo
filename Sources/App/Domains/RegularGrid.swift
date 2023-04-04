import Foundation


struct RegularGrid: Gridable {
    let nx: Int
    let ny: Int
    let latMin: Float
    let lonMin: Float
    let dx: Float
    let dy: Float
    
    func findPoint(lat: Float, lon: Float) -> Int? {
        let x = Int(roundf((lon-lonMin) / dx))
        let y = Int(roundf((lat-latMin) / dy))
        if y == ny && x == nx {
            // Allow points on the border. Technically for global grids, this grid point now wrappes to the eastern side
            return (ny - 1) * nx + (nx - 1)
        }
        if y >= 0 && y < ny && x == nx {
            return y * nx + (nx - 1)
        }
        if x >= 0 && x < nx && y == ny {
            return (ny - 1) * nx + x
        }
        if y < 0 || x < 0 || y >= ny || x >= nx {
            return nil
        }
        return y * nx + x
    }
    
    func getCoordinates(gridpoint: Int) -> (latitude: Float, longitude: Float) {
        let y = gridpoint / nx
        let x = gridpoint-y * nx
        let lat = latMin + Float(y) * dy
        let lon = lonMin + Float(x) * dx
        return (lat, lon)
    }
    
    func findPointInterpolated(lat: Float, lon: Float) -> GridPoint2DFraction? {
        let x = (lon-lonMin) / dx
        let y = (lat-latMin) / dy
        
        if y < 0 || x < 0 || y >= Float(ny) || x >= Float(nx) {
            return nil
        }
        
        let xFraction = (lon-lonMin).truncatingRemainder(dividingBy: dx)
        let yFraction = (lat-latMin).truncatingRemainder(dividingBy: dy)
        return GridPoint2DFraction(gridpoint: Int(y) * nx + Int(x), xFraction: xFraction, yFraction: yFraction)
    }
}
