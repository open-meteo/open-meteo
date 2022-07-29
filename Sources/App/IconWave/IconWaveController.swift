import Foundation
import Vapor


struct IconWaveController {
    func query(_ req: Request) -> EventLoopFuture<Response> {
        fatalError()
    }
}

struct IconWaveMixer {
    
}

struct IconWaveReader {
    let domain: IconWaveDomain
    
    /// Grid index in data files
    let position: Int
    let time: TimerangeDt
    
    let modelLat: Float
    let modelLon: Float
    
    /// If set, use new data files
    let omFileSplitter: OmFileSplitter
    
    public init?(domain: IconWaveDomain, lat: Float, lon: Float, time: TimerangeDt) throws {
        guard let gridpoint = domain.grid.findPoint(lat: lat, lon: lon) else {
            return nil
        }
        self.domain = domain
        self.position = gridpoint
        self.time = time
        
        omFileSplitter = OmFileSplitter(basePath: domain.omfileDirectory, nLocations: domain.grid.count, nTimePerFile: domain.omFileLength, yearlyArchivePath: nil)
        
        (modelLat, modelLon) = domain.grid.getCoordinates(gridpoint: gridpoint)
    }
    
    func prefetchData(variable: IconVariable) throws {
        try omFileSplitter.willNeed(variable: variable.rawValue, location: position, time: time)
    }
    
    func get(variable: IconVariable, targetAsl: Float) throws -> [Float] {
        return try omFileSplitter.read(variable: variable.rawValue, location: position, time: time)
    }
}
