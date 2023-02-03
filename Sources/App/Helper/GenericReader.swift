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
    var elevationFile: OmFileReader<MmapFile>? { get }
    
    /// Where compressed time series files are stroed
    var omfileDirectory: String { get }
    
    /// If present, the directory to a long term archive
    var omfileArchive: String? { get }
    
    /// The time length of each compressed time series file
    var omFileLength: Int { get }
    
    /// Single master file for a large time series
    var omFileMaster: (path: String, time: TimerangeDt)? { get }
    
    /// Domain name used in data directories
    var rawValue: String { get }
}

extension GenericDomain {
    var dtHours: Int { dtSeconds / 3600 }
}

/**
 Generic variable for the reader implementation
 */
protocol GenericVariable: GenericVariableMixable {
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
    case hermite(bounds: ClosedRange<Float>?)
    
    case solar_backwards_averaged
    
    case backwards_sum
    
    /// How many timesteps on the left and right side are used for interpolation
    var padding: Int {
        switch self {
        case .linear:
            return 1
        case .hermite:
            return 2
        case .solar_backwards_averaged:
            return 2
        case .backwards_sum:
            return 1
        }
    }
    
    var isSolarInterpolation: Bool {
        switch self {
        case .solar_backwards_averaged:
            return true
        default:
            return false
        }
    }
    
    var bounds: ClosedRange<Float>? {
        switch self {
        case .hermite(let bounds):
            return bounds
        default:
            return nil
        }
    }
}


/**
 Generic reader implementation that resolves a grid point and interpolates data.
 Corrects elevation
 */
struct GenericReader<Domain: GenericDomain, Variable: GenericVariable>: GenericReaderMixable {
    /// Regerence to the domain object
    let domain: Domain
    
    /// Grid index in data files
    let position: Range<Int>
    
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
    
    var modelDtSeconds: Int {
        return domain.dtSeconds
    }
    
    /// Initialise reader to read a range of locations
    public init(domain: Domain, position: Range<Int>) {
        self.domain = domain
        self.position = position
        self.modelElevation = .nan
        self.targetElevation = .nan
        self.modelLat = .nan
        self.modelLon = .nan
        self.omFileSplitter = OmFileSplitter(domain)
    }
    
    /// Return nil, if the coordinates are outside the domain grid
    public init?(domain: Domain, lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode) throws {
        // check if coordinates are in domain, otherwise return nil
        guard let gridpoint = try domain.grid.findPoint(lat: lat, lon: lon, elevation: elevation, elevationFile: domain.elevationFile, mode: mode) else {
            return nil
        }
        self.domain = domain
        self.position = gridpoint.gridpoint ..< gridpoint.gridpoint + 1
        self.modelElevation = gridpoint.gridElevation
        self.targetElevation = elevation.isNaN ? gridpoint.gridElevation : elevation
        
        omFileSplitter = OmFileSplitter(domain)
        
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
        
        if variable.isElevationCorrectable && variable.unit == .celsius && !modelElevation.isNaN && !targetElevation.isNaN && targetElevation != modelElevation {
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
        
        if position.count > 1 {
            throw ForecastapiError.generic(message: "Multi point support for temporal interpolation unavailable")
        }
        
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

