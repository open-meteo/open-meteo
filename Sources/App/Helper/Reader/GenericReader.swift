import Foundation
import OmFileFormat
import Vapor

/// A contiguous interval whose data has been prefetched. An empty range means no data was prefetched.
/// Bounds are timestamps, independent of the reader's timestep; the upper bound is exclusive.
struct PrefetchResult: Equatable {
    private(set) var range: Range<Timestamp>

    init(_ range: Range<Timestamp> = Timestamp(0)..<Timestamp(0)) {
        self.range = range.isEmpty ? Timestamp(0)..<Timestamp(0) : range
    }

    func covers(_ requested: Range<Timestamp>) -> Bool {
        if requested.isEmpty { return true }
        guard !range.isEmpty else { return false }
        return range.lowerBound <= requested.lowerBound && range.upperBound >= requested.upperBound
    }

    /// Join overlapping or adjacent model/file coverage without claiming data across gaps.
    /// Keep the first interval when disjoint: this is conservative and requires no range array.
    mutating func include(_ other: PrefetchResult) {
        let other = other.range
        guard !other.isEmpty else { return }
        guard !range.isEmpty else { range = other; return }
        guard other.lowerBound <= range.upperBound && range.lowerBound <= other.upperBound else { return }
        self.range = min(range.lowerBound, other.lowerBound)..<max(range.upperBound, other.upperBound)
    }

    /// Derived data is available only where all required inputs are available.
    func intersecting(_ other: PrefetchResult) -> PrefetchResult {
        guard !range.isEmpty, !other.range.isEmpty else { return PrefetchResult() }
        return PrefetchResult(range.clamped(to: other.range))
    }

    /// Translate dependency coverage to the output timeline, accounting for read padding
    /// or a time shift. Partial padded reads are conservatively rounded to output steps.
    func mapped(from input: TimerangeDt, to output: TimerangeDt) -> PrefetchResult {
        if covers(input.range) { return PrefetchResult(output.range) }
        if input.range == output.range && input.dtSeconds == output.dtSeconds {
            return intersecting(PrefetchResult(output.range))
        }
        let range = intersecting(PrefetchResult(input.range)).range
        guard !range.isEmpty else { return PrefetchResult() }
        let missingStart = range.lowerBound.timeIntervalSince1970 - input.range.lowerBound.timeIntervalSince1970
        let missingEnd = input.range.upperBound.timeIntervalSince1970 - range.upperBound.timeIntervalSince1970
        let dt = output.dtSeconds
        let start = output.range.lowerBound.add(((missingStart + dt - 1) / dt) * dt)
        let end = output.range.upperBound.add(-((missingEnd + dt - 1) / dt) * dt)
        guard start < end else { return PrefetchResult() }
        return PrefetchResult(start..<end)
    }

    /// Restrict coverage to the interval shared with another required input.
    mutating func formIntersection(_ other: PrefetchResult) {
        self = intersecting(other)
    }

}

/// Accumulates file index ranges as timestamps without allocating a range array.
struct PrefetchCoverage {
    let requested: TimerangeDt
    private(set) var result = PrefetchResult()

    mutating func insert(_ range: Range<Int>) {
        let overlap = range.clamped(to: requested.toIndexTime())
        guard !overlap.isEmpty else { return }
        if requested.dtSeconds == .dtSecondsMonthly {
            let epoch = YearMonth(year: 1970, month: 1)
            result.include(PrefetchResult(epoch.advanced(by: overlap.lowerBound).timestamp..<epoch.advanced(by: overlap.upperBound).timestamp))
        } else {
            result.include(PrefetchResult(Timestamp(overlap.lowerBound * requested.dtSeconds)..<Timestamp(overlap.upperBound * requested.dtSeconds)))
        }
    }
}

protocol GenericReaderBaseProtocol {
    var modelLat: Float { get }
    var modelLon: Float { get }
    var modelElevation: ElevationOrSea { get }
    var targetElevation: Float { get }
    var modelDtSeconds: Int { get }
    func getStatic(type: ReaderStaticVariable) async throws -> Float?
}

extension GenericReaderBaseProtocol {
    var resolvedTargetElevation: Float {
        targetElevation.isFinite ? targetElevation : modelElevation.numeric
    }
}

/// Requirements to the reader in order to mix. Could be a GenericReaderDerived or just GenericReader
protocol GenericReaderProtocol: GenericReaderBaseProtocol {
    associatedtype MixingVar: GenericVariableMixable

    func get(variable: MixingVar, time: TimerangeDtAndSettings) async throws -> DataAndUnit
    func prefetchData(variable: MixingVar, time: TimerangeDtAndSettings) async throws -> PrefetchResult
}

protocol GenericReaderOptionalProtocol<VariableOpt>: GenericReaderBaseProtocol {
    associatedtype VariableOpt: GenericVariableMixable

    func get(variable: VariableOpt, time: TimerangeDtAndSettings) async throws -> DataAndUnit?
    func prefetchData(variable: VariableOpt, time: TimerangeDtAndSettings) async throws -> PrefetchResult
}

extension GenericReaderProtocol {
    /// Try to initialise a given variable from a string
    static func variableFromString(_ string: String) -> MixingVar? {
        guard let variable = MixingVar(rawValue: string) else {
            return nil
        }
        return variable
    }
}

/**
 Each call to `get` or `prefetch` is accompanied by time, ensemble member and previous day information
 */
struct TimerangeDtAndSettings: Hashable  {
    let time: TimerangeDt
    /// Member stored in separate files
    let ensembleMember: Int
    /// Member stored as an additional dimension int the same file
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
    func toSettings(ensembleMember: Int? = nil, previousDay: Int? = nil, ensembleMemberLevel: Int? = nil) -> TimerangeDtAndSettings {
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

    /// Latitude of the output cell, or the grid point when not remapped.
    let modelLat: Float

    /// Longitude of the output cell, or the grid point when not remapped.
    let modelLon: Float

    /// If set, use new data files
    let omFileSplitter: OmFileSplitter
    
    /// Selected and validated at initialization; shared by every read from this reader.
    let run: IsoDateTime?

    var modelDtSeconds: Int {
        return domain.dtSeconds
    }

    /// Initialise reader to read a single grid-point
    // TODO: Use decoded cached elevations for icon native domains in both initializers 
    // and getStatic(.elevation) to avoid redundant filesystem-cache access and OM reads.
    public init(domain: Domain, position: Int, modelCoordinates: (latitude: Float, longitude: Float)? = nil, elevation: Float = .nan, options: GenericReaderOptions) async throws {
        try await options.validateRun(domain: domain)
        self.domain = domain
        self.position = position
        if let elevationFile = await domain.getStaticFile(type: .elevation) {
            self.modelElevation = try await domain.grid.readElevation(gridpoint: position, elevationFile: elevationFile)
        } else {
            self.modelElevation = .noData
        }
        // Mixed sources share a target elevation; standalone grid-point reads use model terrain.
        self.targetElevation = elevation.isNaN ? self.modelElevation.numeric : elevation
        let coords = modelCoordinates ?? domain.grid.getCoordinates(gridpoint: position)
        self.modelLat = coords.latitude
        self.modelLon = coords.longitude
        self.omFileSplitter = OmFileSplitter(domain)
        self.run = options.run
    }

    /// Return nil outside the grid. A missing requested run throws during initialization.
    public init?(domain: Domain, lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode, options: GenericReaderOptions) async throws {
        try await options.validateRun(domain: domain)
        // check if coordinates are in domain, otherwise return nil
        let elevationFile = await domain.getStaticFile(type: .elevation)
        guard let gridpoint = try await domain.grid.findPoint(lat: lat, lon: lon, elevation: elevation, elevationFile: elevationFile, mode: mode) else {
            return nil
        }
        self.domain = domain
        self.position = gridpoint.gridpoint
        self.modelElevation = gridpoint.gridElevation
        self.targetElevation = elevation.isNaN ? gridpoint.gridElevation.numeric : elevation
        self.run = options.run

        omFileSplitter = OmFileSplitter(domain)

        (modelLat, modelLon) = domain.grid.getCoordinates(gridpoint: gridpoint.gridpoint)
    }

    /// Prefetch data asynchronously. At the time `read` is called, it might already by in the kernel page cache.
    func prefetchData(variable: Variable, time: TimerangeDtAndSettings) async throws -> PrefetchResult {
        if time.dtSeconds == domain.dtSeconds {
            return try await omFileSplitter.willNeed(variable: variable.omFileName.file, location: position..<position + 1, level: time.ensembleMemberLevel, time: time, run: run)
        }

        let interpolationType = variable.interpolation
        let timeRead = time.dtSeconds > domain.dtSeconds ?
            time.time.forAggregationTo(modelDt: domain.dtSeconds, interpolation: interpolationType) :
            time.time.forInterpolationTo(modelDt: domain.dtSeconds, interpolation: interpolationType)

        let prefetched = try await omFileSplitter.willNeed(variable: variable.omFileName.file, location: position..<position + 1, level: time.ensembleMemberLevel, time: time.with(time: timeRead), run: run)
        return prefetched.mapped(from: timeRead, to: time.time)
    }

    /// Read
    private func readRaw(variable: Variable, time: TimerangeDtAndSettings) async throws -> [Float] {
        return try await omFileSplitter.read(variable: variable, location: position..<position + 1, level: time.ensembleMemberLevel, time: time, run: run)
    }
    
    /// Scale and apply elevation correction. Must be done after temporal interpolation to preserve scaling
    private func scale(data: consuming [Float], isElevationCorrectable: Bool, unit: SiUnit) -> DataAndUnit {
        if unit == .pascal {
            return DataAndUnit(data.map({ $0 / 100 }), .hectopascal)
        }

        if isElevationCorrectable && unit == .celsius && !modelElevation.numeric.isNaN && !targetElevation.isNaN && targetElevation != modelElevation.numeric {
            for i in data.indices {
                // correct temperature by 0.65° per 100 m elevation
                data[i] += (modelElevation.numeric - targetElevation) * 0.0065
            }
        }
        return DataAndUnit(data, unit)
    }

    /// Read data and interpolate if required
    func readAndInterpolate(variable: Variable, time: TimerangeDtAndSettings) async throws -> DataAndUnit {
        if time.dtSeconds == domain.dtSeconds {
            let data = try await readRaw(variable: variable, time: time)
            return scale(data: data, isElevationCorrectable: variable.isElevationCorrectable, unit: variable.unit)
        }
        let interpolationType = variable.interpolation

        if time.dtSeconds > domain.dtSeconds {
            // Aggregate data
            let timeRead = time.time.forAggregationTo(modelDt: domain.dtSeconds, interpolation: interpolationType)
            let data = try await readRaw(variable: variable, time: time.with(time: timeRead))
            let aggregated = data.aggregate(type: interpolationType, timeOld: timeRead, timeNew: time.time)
            return scale(data: aggregated, isElevationCorrectable: variable.isElevationCorrectable, unit: variable.unit)
        }

        // Interpolate data
        let timeLow = time.time.forInterpolationTo(modelDt: domain.dtSeconds, interpolation: interpolationType)
        let data = try await readRaw(variable: variable, time: time.with(time: timeLow))
        let interpolated = data.interpolate(type: interpolationType, timeOld: timeLow, timeNew: time.time, latitude: modelLat, longitude: modelLon, scalefactor: variable.scalefactor)
        return scale(data: interpolated, isElevationCorrectable: variable.isElevationCorrectable, unit: variable.unit)
    }

    func get(variable: Variable, time: TimerangeDtAndSettings) async throws -> DataAndUnit {
        return try await readAndInterpolate(variable: variable, time: time)
    }

    func getStatic(type: ReaderStaticVariable) async throws -> Float? {
        guard let file = await domain.getStaticFile(type: type) else {
            return nil
        }
        return try await domain.grid.readFromStaticFile(gridpoint: position, file: file)
    }
}

extension TimerangeDt {
    /// Expand the time range for interpolation
    func forAggregationTo(modelDt: Int, interpolation: ReaderInterpolation) -> TimerangeDt {
        switch interpolation {
        case .linear, .linearDegrees, .hermite:
            return self.with(dtSeconds: modelDt)
        case .solar_backwards_averaged, .solar_backwards_missing_not_averaged, .backwards_sum, .backwards_max, .backwards:
            // Need to read previous timesteps to sum/average the correct value
            let steps = dtSeconds / modelDt
            let backSeconds = -1 * modelDt * (steps - 1)
            return self.with(dtSeconds: modelDt).with(start: range.lowerBound.add(backSeconds))
        }
    }

    /// Adjust time for interpolation. E.g. Reads a bit more data for hermite interpolation
    func forInterpolationTo(modelDt: Int, interpolation: ReaderInterpolation) -> TimerangeDt {
        let start = range.lowerBound.floor(toNearest: modelDt).add(-1 * modelDt * (interpolation.padding - 1))
        let end = range.upperBound.ceil(toNearest: modelDt).add(modelDt * (interpolation.padding))
        return TimerangeDt(start: start, to: end, dtSeconds: modelDt)
    }
}
