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
    public init?(domain: Domain, lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode) throws {
        // check if coordinates are in domain, otherwise return nil
        guard let gridpoint = try domain.grid.findPoint(lat: lat, lon: lon, elevation: elevation, elevationFile: domain.elevationFile, mode: mode) else {
            return nil
        }
        self.domain = domain
        self.position = gridpoint.gridpoint
        self.modelElevation = gridpoint.gridElevation
        self.targetElevation = elevation
        
        omFileSplitter = OmFileSplitter(basePath: domain.omfileDirectory, nLocations: domain.grid.count, nTimePerFile: domain.omFileLength, yearlyArchivePath: domain.omfileArchive)
        
        (modelLat, modelLon) = domain.grid.getCoordinates(gridpoint: gridpoint.gridpoint)
    }
    
    /// Prefetch data asynchronously. At the time `read` is called, it might already by in the kernel page cache.
    func prefetchData(variable: Variable, time: TimerangeDt) throws {
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
        /*if let domain = domain as? IconDomains, let variable = variable as? IconVariable {
            if domain == .iconD2 {
                // do pressure level interpolation
            }
        }*/
        
        if let domain = domain as? GfsDomain, let variable = variable as? GfsVariable {
            /// HRRR domain has no cloud cover for pressure levels, calculate from RH
            if domain == .hrrr_conus || domain == .nam_conus, case let .pressure(pressure) = variable, pressure.variable == .cloudcover {
                let rh = try get(variable: GfsVariable.pressure(GfsPressureVariable(variable: .relativehumidity, level: pressure.level)) as! Variable, time: time)
                let clc = rh.data.map(Meteorology.relativeHumidityToCloudCover)
                return DataAndUnit(clc, .percent)
            }
            
            /// GFS has no diffuse radiation
            if domain == .gfs025, case let .surface(variable) = variable, variable == .diffuse_radiation {
                let ghi = try get(variable: GfsVariable.surface(.shortwave_radiation) as! Variable, time: time)
                let dhi = Zensun.calculateDiffuseRadiationBackwards(shortwaveRadiation: ghi.data, latitude: modelLat, longitude: modelLon, timerange: time)
                return DataAndUnit(dhi, ghi.unit)
            }
        }
        
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

