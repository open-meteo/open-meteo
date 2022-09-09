import Foundation
import SwiftPFor2D


public protocol Gridable {
    var nx: Int { get }
    var ny: Int { get }
    
    func findPoint(lat: Float, lon: Float) -> Int?
    func getCoordinates(gridpoint: Int) -> (latitude: Float, longitude: Float)
}

extension Gridable {
    /// number of grid cells
    var count: Int {
        return nx * ny
    }
    
    func findPoint(lat: Float, lon: Float, elevation: Float, elevationFile: OmFileReader?, mode: GridSelectionMode) throws -> (gridpoint: Int, gridElevation: Float)? {
        guard let elevationFile = elevationFile else {
            guard let point = findPoint(lat: lat, lon: lon) else {
                return nil
            }
            return (point, .nan)
        }

        
        switch mode {
        case .terrainOptimised:
            return try findPointTerrainOptimised(lat: lat, lon: lon, elevation: elevation, elevationFile: elevationFile)
        case .sea:
            return try findPointInSea(lat: lat, lon: lon, elevationFile: elevationFile)
        case .nearest:
            return try findPointNearest(lat: lat, lon: lon, elevationFile: elevationFile)
        }
    }
    
    /// Get nearest grid point
    func findPointNearest(lat: Float, lon: Float, elevationFile: OmFileReader) throws -> (gridpoint: Int, gridElevation: Float)? {
        guard let center = findPoint(lat: lat, lon: lon) else {
            return nil
        }
        let x = center % nx
        let y = center / nx
        var elevation = Float.nan
        try elevationFile.read(into: &elevation, arrayRange: 0..<1, dim0Slow: y..<y+1, dim1: x..<x+1)
        if elevation.isNaN {
            return nil
        }
        if elevation <= -999 {
            // sea gtid point
            return (center, 0)
        }
        return (center, elevation)
    }
    
    /// Find point, perferably in sea
    func findPointInSea(lat: Float, lon: Float, elevationFile: OmFileReader) throws -> (gridpoint: Int, gridElevation: Float)? {
        guard let center = findPoint(lat: lat, lon: lon) else {
            return nil
        }
        let x = center % nx
        let y = center / nx
        
        let xrange = (x-1..<x+2).clamped(to: 0..<nx)
        let yrange = (y-1..<y+2).clamped(to: 0..<ny)
        
        // TODO find a solution to reuse buffers inside read... maybe allocate buffers in a pool per eventloop?
        /// -999 marks sea points, therefore  elevation matching will naturally avoid those
        let elevationSurrounding = try elevationFile.read(dim0Slow: yrange, dim1: xrange)
        
        if elevationSurrounding[elevationSurrounding.count / 2] <= -999 {
            return (center, 0)
        }
        
        for i in elevationSurrounding.indices {
            if elevationSurrounding[i].isNaN {
                continue
            }
            if elevationSurrounding[i] <= -999 {
                let dx = i % xrange.count - (x - xrange.lowerBound)
                let dy = i / xrange.count - (y - yrange.lowerBound)
                let gridpoint = (y + dy) * nx + (x + dx)
                return (gridpoint, 0)
            }
        }
        
        // all land, take center
        if elevationSurrounding[elevationSurrounding.count / 2].isNaN {
            return nil
        }
        return (center, elevationSurrounding[elevationSurrounding.count / 2])
    }
    
    /// Analyse 3x3 locations around the desired coordinate and return the best elevation match
    func findPointTerrainOptimised(lat: Float, lon: Float, elevation: Float, elevationFile: OmFileReader) throws -> (gridpoint: Int, gridElevation: Float)? {
        guard let center = findPoint(lat: lat, lon: lon) else {
            return nil
        }
        let x = center % nx
        let y = center / nx
        
        let xrange = (x-1..<x+2).clamped(to: 0..<nx)
        let yrange = (y-1..<y+2).clamped(to: 0..<ny)
        
        // TODO find a solution to reuse buffers inside read... maybe allocate buffers in a pool per eventloop?
        /// -999 marks sea points, therefore  elevation matching will naturally avoid those
        let elevationSurrounding = try elevationFile.read(dim0Slow: yrange, dim1: xrange)
        
        if abs(elevationSurrounding[elevationSurrounding.count / 2] - elevation ) <= 100 {
            return (center, elevationSurrounding[elevationSurrounding.count / 2])
        }
        
        var minDelta = Float(10_000)
        var minPos = elevationSurrounding.count / 2
        for i in elevationSurrounding.indices {
            if elevationSurrounding[i].isNaN {
                continue
            }
            if abs(elevationSurrounding[i] - elevation) < minDelta {
                minDelta = abs(elevationSurrounding[i] - elevation)
                minPos = i
            }
        }
        
        /// only sea points or elevation ish hugly off -> just use center
        if minDelta > 900 {
            minPos = elevationSurrounding.count / 2
        }
        
        let dx = minPos % xrange.count - (x - xrange.lowerBound)
        let dy = minPos / xrange.count - (y - yrange.lowerBound)
        let gridpoint = (y + dy) * nx + (x + dx)
        if elevationSurrounding[minPos].isNaN {
            return nil
        }
        if elevationSurrounding[minPos] <= -999 {
            return (gridpoint, 0)
        }
        return (gridpoint, elevationSurrounding[minPos])
    }
}

enum GridSelectionMode {
    case terrainOptimised
    case sea
    case nearest
}
