import Foundation
import SwiftPFor2D

/// Requirements to the reader in order to mix. Could be a GenericReaderDerived or just GenericReader
protocol GenericReaderProtocol {
    associatedtype MixingVar: GenericVariableMixable

    var modelLat: Float { get }
    var modelLon: Float { get }
    var modelElevation: ElevationOrSea { get }
    var targetElevation: Float { get }
    var modelDtSeconds: Int { get }
    
    func get(variable: MixingVar, time: TimerangeDt) throws -> DataAndUnit
    func prefetchData(variable: MixingVar, time: TimerangeDt) throws
}

/**
 Generic reader implementation that resolves a grid point and interpolates data.
 Corrects elevation
 */
struct GenericReader<Domain: GenericDomain, Variable: GenericVariable>: GenericReaderProtocol {
    /// Reference to the domain object
    let domain: Domain
    
    /// Grid index in data files
    let position: Int
    
    /// Elevation of the grid point
    let modelElevation: ElevationOrSea
    
    /// The desired elevation. Used to correct temperature forecasts
    let targetElevation: Float
    
    /// Latitude of the grid point
    let modelLat: Float
    
    /// Longitude of the grid point
    let modelLon: Float
    
    /// If set, use new data files
    let omFileSplitter: OmFileSplitter
    
    var modelDtSeconds: Int {
        return domain.dtSeconds
    }
    
    /// Initialise reader to read a single grid-point
    public init(domain: Domain, position: Int) throws {
        self.domain = domain
        self.position = position
        if let elevationFile = domain.elevationFile {
            self.modelElevation = try domain.grid.readElevation(gridpoint: position, elevationFile: elevationFile)
        } else {
            self.modelElevation = .noData
        }
        self.targetElevation = .nan
        let coords = domain.grid.getCoordinates(gridpoint: position)
        self.modelLat = coords.latitude
        self.modelLon = coords.longitude
        self.omFileSplitter = OmFileSplitter(domain)
    }
    
    /// Return nil, if the coordinates are outside the domain grid
    public init?(domain: Domain, lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode) throws {
        // check if coordinates are in domain, otherwise return nil
        guard let gridpoint = try domain.grid.findPoint(lat: lat, lon: lon, elevation: elevation, elevationFile: domain.elevationFile, mode: mode) else {
            return nil
        }
        self.domain = domain
        self.position = gridpoint.gridpoint
        self.modelElevation = gridpoint.gridElevation
        self.targetElevation = elevation.isNaN ? gridpoint.gridElevation.numeric : elevation
        
        omFileSplitter = OmFileSplitter(domain)
        
        (modelLat, modelLon) = domain.grid.getCoordinates(gridpoint: gridpoint.gridpoint)
    }
    
    /// Prefetch data asynchronously. At the time `read` is called, it might already by in the kernel page cache.
    func prefetchData(variable: Variable, time: TimerangeDt) throws {
        try omFileSplitter.willNeed(variable: variable.omFileName, location: position..<position+1, time: time)
    }
    
    /// Read and scale if required
    private func readAndScale(variable: Variable, time: TimerangeDt) throws -> DataAndUnit {
        var data = try omFileSplitter.read(variable: variable.omFileName, location: position..<position+1, time: time)
        
        /// Scale pascal to hecto pasal. Case in era5
        if variable.unit == .pascal {
            return DataAndUnit(data.map({$0 / 100}), .hectoPascal)
        }
        
        if variable.isElevationCorrectable && variable.unit == .celsius && !modelElevation.numeric.isNaN && !targetElevation.isNaN && targetElevation != modelElevation.numeric {
            for i in data.indices {
                // correct temperature by 0.65° per 100 m elevation
                data[i] += (modelElevation.numeric - targetElevation) * 0.0065
            }
        }
        return DataAndUnit(data, variable.unit)
    }
    
    /// Read data and interpolate if required
    func readAndInterpolate(variable: Variable, time: TimerangeDt) throws -> DataAndUnit {
        if time.dtSeconds == domain.dtSeconds {
            return try readAndScale(variable: variable, time: time)
        }
        if time.dtSeconds > domain.dtSeconds {
            fatalError()
        }
        
        let interpolationType = variable.interpolation
        
        let timeLow = time.forInterpolationTo(modelDt: domain.dtSeconds).expandLeftRight(by: domain.dtSeconds*(interpolationType.padding-1))
        let read = try readAndScale(variable: variable, time: timeLow)
        let dataLow = read.data
        
        let data = dataLow.interpolate(type: interpolationType, timeOld: timeLow, timeNew: time, latitude: modelLat, longitude: modelLon, scalefactor: variable.scalefactor)
        return DataAndUnit(data, read.unit)
    }
    
    func get(variable: Variable, time: TimerangeDt) throws -> DataAndUnit {
        return try readAndInterpolate(variable: variable, time: time)
    }
}

extension TimerangeDt {
    func forInterpolationTo(modelDt: Int) -> TimerangeDt {
        let start = range.lowerBound.floor(toNearest: modelDt)
        let end = range.upperBound.ceil(toNearest: modelDt)
        return TimerangeDt(start: start, to: end, dtSeconds: modelDt)
    }
    func expandLeftRight(by: Int) -> TimerangeDt {
        return TimerangeDt(start: range.lowerBound.add(-1*by), to: range.upperBound.add(by), dtSeconds: dtSeconds)
    }
}

