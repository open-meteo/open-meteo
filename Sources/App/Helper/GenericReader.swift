import Foundation
import SwiftPFor2D

/**
 Generic domain that is required for the reader
 */
protocol GenericDomain {
    /// The grid definition. Could later be replaced with a more generic implementation
    var grid: Gridable { get }
    
    /// Time resoltuion of the deomain. 3600 for hourly, 10800 for 3-hourly
    var dtSeconds: Int { get }
    
    /// An instance to read elevation and sea mask information
    var elevationFile: OmFileReader? { get }
    
    /// Where compressed time series files are stroed
    var omfileDirectory: String { get }
    
    /// If present, the directory to a long term archive
    var omfileArchive: String? { get }
    
    /// The time length of each compressed time series file
    var omFileLength: Int { get }
}

extension GenericDomain {
    var dtHours: Int { dtSeconds / 3600 }
}

/**
 Generic variable for the reader implementation
 */
protocol GenericVariable {
    /// The filename of the variable. Typically just `temperature_2m`
    var omFileName: String { get }
    
    /// The scalefactor to compress data
    var scalefactor: Float { get }
    
    /// Kind of interpolation for this variable. Used to interpolate from 1 to 3 hours
    var interpolation: ReaderInterpolation { get }
    
    /// SI unit of this variable
    var unit: SiUnit { get }
    
    /// If true, temperature will be corrected by 0.65°K per 100 m
    var isElevationCorrectable: Bool { get }
}

enum ReaderInterpolation {
    /// Simple linear interpolation
    case linear
    
    /// Hermite interpolation for more smooth interpolation for temperature
    case hermite
    
    case solar_backwards_averaged
    
    /// How many timesteps on the left and right side are used for interpolation
    var padding: Int {
        switch self {
        case .linear:
            return 1
        case .hermite:
            return 2
        case .solar_backwards_averaged:
            return 2
        }
    }
}


/**
 Generic reader implementation that resolves a grid point and interpolates data
 */
struct GenericReader<Domain: GenericDomain, Variable: GenericVariable> {
    /// Regerence to the domain object
    let domain: Domain
    
    /// Grid index in data files
    let position: Int
    
    /// The desired time and resolution to read
    let time: TimerangeDt
    
    /// Elevation of the grid point
    let modelElevation: Float
    
    /// The desired elevation. Used to correct temperature forecasts
    let targetElevation: Float
    
    /// Latitude of the grid point
    let modelLat: Float
    
    /// Longitude of the grid point
    let modelLon: Float
    
    /// If set, use new data files
    let omFileSplitter: OmFileSplitter
    
    /// Return nil, if the coordinates are outside the domain grid
    public init?(domain: Domain, lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode, time: TimerangeDt) throws {
        // check if coordinates are in domain, otherwise return nil
        guard let gridpoint = try domain.grid.findPoint(lat: lat, lon: lon, elevation: elevation, elevationFile: domain.elevationFile, mode: mode) else {
            return nil
        }
        self.domain = domain
        self.position = gridpoint.gridpoint
        self.time = time
        self.modelElevation = gridpoint.gridElevation
        self.targetElevation = elevation
        
        omFileSplitter = OmFileSplitter(basePath: domain.omfileDirectory, nLocations: domain.grid.count, nTimePerFile: domain.omFileLength, yearlyArchivePath: domain.omfileArchive)
        
        (modelLat, modelLon) = domain.grid.getCoordinates(gridpoint: gridpoint.gridpoint)
    }
    
    /// Prefetch data asynchronously. At the time `read` is called, it might already by in the kernel page cache.
    func prefetchData(variable: Variable) throws {
        try omFileSplitter.willNeed(variable: variable.omFileName, location: position, time: time)
    }
    
    /// Read and scale if required
    private func readAndScale(variable: Variable, time: TimerangeDt) throws -> DataAndUnit {
        var data = try omFileSplitter.read(variable: variable.omFileName, location: position, time: time)
        
        /// Scale pascal to hecto pasal. Case in era5
        if variable.unit == .pascal {
            return DataAndUnit(data.map({$0 / 100}), .hectoPascal)
        }
        
        if variable.isElevationCorrectable && variable.unit == .celsius && !modelElevation.isNaN && !targetElevation.isNaN {
            for i in data.indices {
                // correct temperature by 0.65° per 100 m elevation
                data[i] += (modelElevation - targetElevation) * 0.0065
            }
        }
        
        return DataAndUnit(data, variable.unit)
    }
    
    /// Read data and interpolate if required. If `raw` is set, no temperature correction is applied
    func get(variable: Variable) throws -> DataAndUnit {
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



extension Array where Element == Float {
    fileprivate func interpolate(type: ReaderInterpolation, timeOld: TimerangeDt, timeNew: TimerangeDt, latitude: Float, longitude: Float, scalefactor: Float) -> [Float] {
        switch type {
        case .linear:
            return interpolateLinear(timeOld: timeOld, timeNew: timeNew, scalefactor: scalefactor)
        case .hermite:
            return interpolateHermite(timeOld: timeOld, timeNew: timeNew, scalefactor: scalefactor)
        case .solar_backwards_averaged:
            return interpolateSolarBackwards(timeOld: timeOld, timeNew: timeNew, latitude: latitude, longitude: longitude, scalefactor: scalefactor)
        }
    }
    
    func interpolateSolarBackwards(timeOld timeLow: TimerangeDt, timeNew time: TimerangeDt, latitude: Float, longitude: Float, scalefactor: Float) -> [Float] {
        /// Like regular hermite, but interpolated via clearsky index kt derived with solar factor
        let position = RegularGrid(nx: 1, ny: 1, latMin: latitude, lonMin: longitude, dx: 1, dy: 1)
        let solarLow = Zensun.calculateRadiationBackwardsAveraged(grid: position, timerange: timeLow).data
        let solar = Zensun.calculateRadiationBackwardsAveraged(grid: position, timerange: time).data
        return time.enumerated().map { (i, t) in
            let index = t.timeIntervalSince1970 / timeLow.dtSeconds - timeLow.range.lowerBound.timeIntervalSince1970 / timeLow.dtSeconds
            let fraction = Float(t.timeIntervalSince1970 % timeLow.dtSeconds) / Float(timeLow.dtSeconds)
            
            let indexB = Swift.max(index, 0)
            let indexA = Swift.max(index-1, 0)
            let indexC = Swift.min(index+1, self.count-1)
            let indexD = Swift.min(index+2, self.count-1)
            
            if self[indexB].isNaN {
                return .nan
            }
            // At low radiaiton levels it is impossible to estimate KT indices
            if solarLow[indexB] < 0.005 {
                return 0
            }
            
            let B = self[indexB] / solarLow[indexB]
            let A = self[indexA].isNaN ? B : (solarLow[indexA] <= 0.005 ? B : self[indexA] / solarLow[indexA])
            let C = self[indexC].isNaN ? B : (solarLow[indexC] <= 0.005 ? B : self[indexC] / solarLow[indexC])
            let D = self[indexD].isNaN ? C : (solarLow[indexD] <= 0.005 ? C : self[indexD] / solarLow[indexD])
            
            // linear
            //let h = (B * (1-fraction) + C * fraction) * solar[i]
            
            let a = -A/2.0 + (3.0*B)/2.0 - (3.0*C)/2.0 + D/2.0
            let b = A - (5.0*B)/2.0 + 2.0*C - D / 2.0
            let c = -A/2.0 + C/2.0
            let d = B
            let h = (a*fraction*fraction*fraction + b*fraction*fraction + c*fraction + d) * solar[i]
            /// adjust it to scalefactor, otherwise interpolated values show more level of detail
            return roundf(h * scalefactor) / scalefactor
        }
    }
    
    func interpolateLinear(timeOld timeLow: TimerangeDt, timeNew time: TimerangeDt, scalefactor: Float) -> [Float] {
        return time.map { t in
            let index = t.timeIntervalSince1970 / timeLow.dtSeconds - timeLow.range.lowerBound.timeIntervalSince1970 / timeLow.dtSeconds
            let fraction = Float(t.timeIntervalSince1970 % timeLow.dtSeconds) / Float(timeLow.dtSeconds)
            let A = self[index]
            let B = index+1 >= self.count ? A : self[index+1]
            let h = A * (1-fraction) + B * fraction
            /// adjust it to scalefactor, otherwise interpolated values show more level of detail
            return roundf(h * scalefactor) / scalefactor
        }
    }
    
    func interpolateHermite(timeOld timeLow: TimerangeDt, timeNew time: TimerangeDt, scalefactor: Float) -> [Float] {
        return time.map { t in
            let index = t.timeIntervalSince1970 / timeLow.dtSeconds - timeLow.range.lowerBound.timeIntervalSince1970 / timeLow.dtSeconds
            let fraction = Float(t.timeIntervalSince1970 % timeLow.dtSeconds) / Float(timeLow.dtSeconds)
            
            let B = self[index]
            let A = index-1 < 0 ? B : self[index-1].isNaN ? B : self[index-1]
            let C = index+1 >= self.count ? B : self[index+1].isNaN ? B : self[index+1]
            let D = index+2 >= self.count ? C : self[index+2].isNaN ? B : self[index+2]
            let a = -A/2.0 + (3.0*B)/2.0 - (3.0*C)/2.0 + D/2.0
            let b = A - (5.0*B)/2.0 + 2.0*C - D / 2.0
            let c = -A/2.0 + C/2.0
            let d = B
            let h = a*fraction*fraction*fraction + b*fraction*fraction + c*fraction + d
            /// adjust it to scalefactor, otherwise interpolated values show more level of detail
            return roundf(h * scalefactor) / scalefactor
        }
    }
}
