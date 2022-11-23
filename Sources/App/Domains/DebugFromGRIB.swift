import Foundation
import SwiftEccodes


extension GribMessage {
    fileprivate struct Coords {
        let i: Int, x: Int, y: Int, latitude: Float, longitude: Float
    }
    
    /// Print debug grid information
    func debugGrid(grid: Gridable) throws {
        guard let nx = get(attribute: "Nx").map(Int.init) ?? nil else {
            fatalError("Could not get Nx")
        }
        guard let ny = get(attribute: "Ny").map(Int.init) ?? nil else {
            fatalError("Could not get Ny")
        }
        guard nx == grid.nx, ny == grid.ny else {
            fatalError("GRIB dimensions (nx=\(grid.nx), ny=\(grid.ny)) do not match domain grid dimensions (nx=\(nx), ny=\(ny))")
        }
        
        for atr in self.iterate(namespace: .geography) {
            print(atr)
        }
        print(get(attribute: "projString")!)
        
        var coords = [Coords]()
        
        for (i,(latitude, longitude,_)) in try iterateCoordinatesAndValues().enumerated() {
            let lon = Float(longitude + 180).truncatingRemainder(dividingBy: 360) - 180
            let c = Coords(i: i, x: i % nx, y: i / nx, latitude: Float(latitude), longitude: lon)
            if c.x == 0, c.y == 0 {
                coords.append(c)
            }
            if c.x == nx-1, c.y == 0 {
                coords.append(c)
            }
            if c.x == 0, c.y == ny-1 {
                coords.append(c)
            }
            if c.x == nx-1, c.y == ny-1 {
                coords.append(c)
            }
            
            if i % (nx*ny/100) == 0 {
                coords.append(c)
            }
        }
        
        for c in coords {
            print(c)
        }
        
        print("Validating grid settings now")
        for c in coords {
            print(c)
            guard let gridpoint = grid.findPoint(lat: c.latitude, lon: c.longitude) else {
                print("FAILED NULL")
                continue
            }
            if gridpoint != c.i {
                print("FAILED gridpoint=\(gridpoint), x=\(gridpoint % nx), y=\(gridpoint / nx)")
                continue
            }
            let coords = grid.getCoordinates(gridpoint: gridpoint)
            if abs(coords.latitude - c.latitude) > 0.002 || abs(coords.longitude - c.longitude) > 0.002 {
                print("FAILED lat=\(coords.latitude), lon=\(coords.longitude)")
                continue
            }
            print("OK")
        }

    }
}
