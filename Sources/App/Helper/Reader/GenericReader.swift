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
    
    func get(variable: MixingVar, time: TimerangeDtAndSettings) throws -> DataAndUnit
    func getStatic(type: ReaderStaticVariable) throws -> Float?
    func prefetchData(variable: MixingVar, time: TimerangeDtAndSettings) throws
}

/**
 Each call to `get` or `prefetch` is acompanied by time, ensemble member and previous day information
 */
struct TimerangeDtAndSettings: Hashable {
    let time: TimerangeDt
    /// Member stored in separate files
    let ensembleMember: Int
    /// Member stored as an addiitonal dimention int the same file
    let ensembleMemberLevel: Int
    
    let previousDay: Int
    
    var dtSeconds: Int {
        time.dtSeconds
    }
    
    var range: Range<Timestamp> {
        time.range
    }
    
    func with(start: Timestamp) -> TimerangeDtAndSettings {
        return TimerangeDtAndSettings(time: time.with(start: start), ensembleMember: ensembleMember, ensembleMemberLevel: ensembleMemberLevel, previousDay: previousDay)
    }
    
    func with(time: TimerangeDt? = nil, ensembleMember: Int? = nil) -> TimerangeDtAndSettings {
        return TimerangeDtAndSettings(time: time ?? self.time, ensembleMember: ensembleMember ?? self.ensembleMember, ensembleMemberLevel: ensembleMemberLevel, previousDay: previousDay)
    }
    
    func with(dtSeconds: Int) -> TimerangeDtAndSettings {
        return TimerangeDtAndSettings(time: time.with(dtSeconds: dtSeconds), ensembleMember: ensembleMember, ensembleMemberLevel: ensembleMemberLevel, previousDay: previousDay)
    }
}

extension TimerangeDt {
    func toSettings(ensembleMember: Int? = nil, previousDay: Int? = nil, ensembleMemberLevel: Int? = nil) -> TimerangeDtAndSettings{
        return TimerangeDtAndSettings(time: self, ensembleMember: ensembleMember ?? 0, ensembleMemberLevel: ensembleMemberLevel ?? 0, previousDay: previousDay ?? 0)
    }
}

enum ReaderStaticVariable {
    case soilType
    case elevation
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
        if let elevationFile = domain.getStaticFile(type: .elevation) {
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
        guard let gridpoint = try domain.grid.findPoint(lat: lat, lon: lon, elevation: elevation, elevationFile: domain.getStaticFile(type: .elevation), mode: mode) else {
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
    func prefetchData(variable: Variable, time: TimerangeDtAndSettings) throws {
        if time.dtSeconds == domain.dtSeconds {
            try omFileSplitter.willNeed(variable: variable.omFileName.file, location: position..<position+1, level: time.ensembleMemberLevel, time: time)
            return
        }
        
        let interpolationType = variable.interpolation
        let timeRead = time.dtSeconds > domain.dtSeconds ?
            time.time.forAggregationTo(modelDt: domain.dtSeconds, interpolation: interpolationType) :
            time.time.forInterpolationTo(modelDt: domain.dtSeconds, interpolation: interpolationType)
        
        try omFileSplitter.willNeed(variable: variable.omFileName.file, location: position..<position+1, level: time.ensembleMemberLevel, time: time.with(time: timeRead))
    }
    
    /// Read and scale if required
    private func readAndScale(variable: Variable, time: TimerangeDtAndSettings) throws -> DataAndUnit {
        var data = try omFileSplitter.read(variable: variable.omFileName.file, location: position..<position+1, level: time.ensembleMemberLevel, time: time)
        
        /// Scale pascal to hecto pasal. Case in era5
        if variable.unit == .pascal {
            return DataAndUnit(data.map({$0 / 100}), .hectopascal)
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
    func readAndInterpolate(variable: Variable, time: TimerangeDtAndSettings) throws -> DataAndUnit {
        if time.dtSeconds == domain.dtSeconds {
            return try readAndScale(variable: variable, time: time)
        }
        let interpolationType = variable.interpolation
        
        if time.dtSeconds > domain.dtSeconds {
            // Aggregate data
            let timeRead = time.time.forAggregationTo(modelDt: domain.dtSeconds, interpolation: interpolationType)
            let read = try readAndScale(variable: variable, time: time.with(time: timeRead))
            let aggregated = read.data.aggregate(type: interpolationType, timeOld: timeRead, timeNew: time.time)
            return DataAndUnit(aggregated, read.unit)
        }
        
        // Interpolate data
        let timeLow = time.time.forInterpolationTo(modelDt: domain.dtSeconds, interpolation: interpolationType)
        let read = try readAndScale(variable: variable, time: time.with(time: timeLow))
        let interpolated = read.data.interpolate(type: interpolationType, timeOld: timeLow, timeNew: time.time, latitude: modelLat, longitude: modelLon, scalefactor: variable.scalefactor)
        return DataAndUnit(interpolated, read.unit)
    }
    
    func get(variable: Variable, time: TimerangeDtAndSettings) throws -> DataAndUnit {
        return try readAndInterpolate(variable: variable, time: time)
    }
    
    func getStatic(type: ReaderStaticVariable) throws -> Float? {
        guard let file = domain.getStaticFile(type: type) else {
            return nil
        }
        return try domain.grid.readFromStaticFile(gridpoint: position, file: file)
    }
}

extension TimerangeDt {
    /// Expand the time range for interpolation
    func forAggregationTo(modelDt: Int, interpolation: ReaderInterpolation) -> TimerangeDt {
        switch interpolation {
        case .linear, .linearDegrees, .hermite(_), .backwards:
            return self.with(dtSeconds: modelDt)
        case .solar_backwards_averaged, .backwards_sum:
            // Need to read previous timesteps to sum/average the correct value
            let steps = dtSeconds / modelDt
            let backSeconds = -1 * modelDt * (steps - 1)
            return self.with(dtSeconds: modelDt).with(start: range.lowerBound.add(backSeconds))
        }
    }
    
    /// Adjust time for interpolation. E.g. Reads a bit more data for hermite interpolation
    func forInterpolationTo(modelDt: Int, interpolation: ReaderInterpolation) -> TimerangeDt {
        let expand = modelDt*(interpolation.padding-1)
        let start = range.lowerBound.floor(toNearest: modelDt).add(-1*expand)
        let end = range.upperBound.ceil(toNearest: modelDt).add(expand)
        return TimerangeDt(start: start, to: end, dtSeconds: modelDt)
    }
}
