import Foundation
import OmFileFormat
import Vapor

/**
 Generic domain that is required for the reader
 */
protocol GenericDomain: DomainDefinition {
    /// Loaded geometry. Native domains retain an asynchronously initialized grid.
    var grid: any Gridable { get }

    /// Whether metadata exists for the requested run. Invalid metadata must throw.
    func isRunAvailable(run: Timestamp, client: HTTPClient?, logger: Logger) async throws -> Bool
}

/// Domains whose geometry is available synchronously from their typed registry.
protocol SyncGridDomain: GenericDomain {
    var syncGridRegistry: SyncGridRegistry { get }
}

extension SyncGridDomain {
    var grid: any Gridable { syncGridRegistry.grid }
    var gridRegistry: GridRegistry { .synchronous(syncGridRegistry) }
}

extension GenericDomain {
    /// Initialized domains need no additional loading.
    func loadDomain() -> any GenericDomain { self }

    func isRunAvailable(run: Timestamp, client: HTTPClient?, logger: Logger) async throws -> Bool {
        try await domainRegistry.getFullRunMeta(client: client, logger: logger, run: run) != nil
    }

    var generateFullRun: Bool {
        return countEnsembleMember == 1
    }
    
    var generateTimeSeries: Bool {
        return true
    }
    
    var dtHours: Int { dtSeconds / 3600 }

    /// Temporary directory to download data
    var dataRunDirectory: String? {
        guard let dataRunDirectory = OpenMeteo.dataRunDirectory else {
            return nil
        }
        return "\(dataRunDirectory)\(domainRegistry.rawValue)/"
    }

    /// The the file containing static information for elevation of soil types
    func getStaticFile(type: ReaderStaticVariable, httpClient: HTTPClient?, logger: Logger) async -> (any OmFileReaderArrayProtocol<Float>)? {
        guard let staticDomain = gridRegistry.staticDomain else {
            return nil
        }
        switch type {
        case .soilType:
            return try? await OmFileSystemManager.instance.get(
                file: OmFileType.staticFile(domain: staticDomain, variable: "soil_type", chunk: nil),
                client: httpClient,
                logger: logger
            )?.reader
        case .elevation:
            return try? await OmFileSystemManager.instance.get(
                file: OmFileType.staticFile(domain: staticDomain, variable: "HSURF", chunk: nil),
                client: httpClient,
                logger: logger
            )?.reader
        }
    }

    /// Meta JSON for time-series data
    func getMetaJson(client: HTTPClient?, logger: Logger) async throws -> ModelUpdateMetaJson? {
        return try await OmFileSystemManager.instance.get(
            file: ModelUpdateMetaFile(domain: self.domainRegistry),
            client: client,
            logger: logger
        )
    }
    
    func getLatestFullRun(client: HTTPClient?, logger: Logger) async throws -> Timestamp? {
        return try await OmFileSystemManager.instance.get(
            file: FullRunMetaFile.latest(self.domainRegistry),
            client: client,
            logger: logger
        )?.reference_time.toTimestamp()
    }

    /// Filename of the surface elevation file
    var surfaceElevationFileOm: OmFileType {
        .staticFile(domain: gridRegistry.staticDomain!, variable: "HSURF", chunk: nil)
    }

    var soilTypeFileOm: OmFileType {
        .staticFile(domain: gridRegistry.staticDomain!, variable: "soil_type", chunk: nil)
    }
}

/**
 Generic variable for the reader implementation
 */
protocol GenericVariable: GenericVariableMixable, Sendable, Hashable {
    /// The filename of the variable. Typically just `temperature_2m`. Level is used to store mutliple levels or ensemble members in one file
    /// NOTE: `level` has been replaced with `ensembleMemberLevel` in settings
    var omFileName: (file: String, level: Int) { get }

    /// The scalefactor to compress data
    var scalefactor: Float { get }

    /// Kind of interpolation for this variable. Used to interpolate from 1 to 3 hours
    var interpolation: ReaderInterpolation { get }

    /// SI unit of this variable
    var unit: SiUnit { get }

    /// If true, temperature will be corrected by 0.65°K per 100 m
    var isElevationCorrectable: Bool { get }

    /// If true, forecasts from the previous model runs will be preserved
    var storePreviousForecast: Bool { get }
}


enum ReaderInterpolation {
    /// Simple linear interpolation
    case linear

    /// Interpolate 0-360° values
    case linearDegrees

    /// Hermite interpolation for more smooth interpolation for temperature
    case hermite(bounds: ClosedRange<Float>?)

    /// Solar fluxes are properly backwards averaged during model run time. Always be the case with weather models
    case solar_backwards_averaged

    /// Solar flux is backwards averaged, but values after missing values are not averaged correctly.
    /// This happens with satellite data and missing time steps
    case solar_backwards_missing_not_averaged

    /// Take the next hour, and devide by `dt` to preserve sums like precipitation
    case backwards_sum

    /// Maximum over preceding intervals; replicate backwards when interpolating finer output.
    case backwards_max

    /// Replicate value backwards. E.g. min/max of previous hours
    case backwards

    /// How many timesteps on the left and right side are used for interpolation
    var padding: Int {
        switch self {
        case .linear, .linearDegrees:
            return 1
        case .hermite:
            return 2
        case .solar_backwards_averaged, .solar_backwards_missing_not_averaged:
            return 2
        case .backwards_sum, .backwards_max, .backwards:
            return 1
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
