import Foundation
import OmFileFormat
import OrderedCollections

/*enum ModelTimeVariable: String, GenericVariable {
    case initialisation_time
    case modification_time

    var omFileName: (file: String, level: Int) {
        return (rawValue, 0)
    }

    var scalefactor: Float {
        return 1
    }

    var interpolation: ReaderInterpolation {
        return .linear
    }

    var unit: SiUnit {
        return .seconds
    }

    var isElevationCorrectable: Bool {
        return false
    }

    var storePreviousForecast: Bool {
        return true
    }
}*/

/**
 TODO:
 - CAMS, IconWave, GloFas, seasonal forecast, CMIP, satellite
 - run end lenght might be too short for side-runs
 - license
 - name of provider
 - spatial resolution
 - area / region
 - grid system / proj string?
 - list of variables? pressure levels, model levels?
 - forecast length (per run?)
 - model forecast steps with 1,3,6 hour switching?
 */
struct ModelUpdateMetaJson: Codable, Sendable {
    /// Model initialisation time as unix timestamp. E.g. 0z
    let last_run_initialisation_time: Int

    /// Last modification time. The time the conversion finished on the download and processing server
    let last_run_modification_time: Int

    /// Time at which that model run has been available on the current server
    let last_run_availability_time: Int

    /// Data temporal resolution in seconds. E.g. 3600 for 1-hourly data
    let temporal_resolution_seconds: Int

    /// End of updated timerange. The last timestep is not included! -> Probably not reliable at all.... Short runs, upper model runs, etc....
    let data_end_time: Int

    /// E.g. `3600` for updates every 1 hour
    let update_interval_seconds: Int
    
    /// Number of time-steps per chunk file. E.g. `192` for DWD ICON-EU
    let chunk_time_length: Int?


    enum DimensionName: String, Codable, Hashable {
        case nx
        case ny
        case nt
    }

    /// Chunk files dimensions
    let chunk_file_dimensions: [DimensionName: Int]?
    let grid_bounds: GridBounds?
    let proj_string: String?


    /// Time at which that model run has been available on the current server
    var lastRunAvailabilityTime: Timestamp {
        Timestamp(last_run_availability_time)
    }

    /// Write a new meta data JSON
    static func update(domain: GenericDomain, run: Timestamp, end: Timestamp, now: Timestamp = .now()) throws {
        let meta = ModelUpdateMetaJson(
            last_run_initialisation_time: run.timeIntervalSince1970,
            last_run_modification_time: now.timeIntervalSince1970,
            last_run_availability_time: now.timeIntervalSince1970,
            temporal_resolution_seconds: domain.dtSeconds,
            // data_start_time: 0,
            data_end_time: end.timeIntervalSince1970,
            update_interval_seconds: domain.updateIntervalSeconds,
            chunk_time_length: domain.omFileLength,
            chunk_file_dimensions: [
                .nx: domain.grid.nx,
                .ny: domain.grid.ny,
                .nt: domain.omFileLength
            ],
            grid_bounds: domain.grid.gridBounds,
            proj_string: domain.grid.proj4
        )
        let path = ModelUpdateMetaFile(domain: domain.domainRegistry)
        try path.createDirectory()
        let pathString = path.getFilePath()
        try meta.writeTo(path: pathString)
    }

    /// Update the availability time and return a new object
    func with(last_run_availability_time: Timestamp) -> ModelUpdateMetaJson {
        return ModelUpdateMetaJson(
            last_run_initialisation_time: last_run_initialisation_time,
            last_run_modification_time: last_run_modification_time,
            last_run_availability_time: last_run_availability_time.timeIntervalSince1970,
            temporal_resolution_seconds: temporal_resolution_seconds,
            data_end_time: data_end_time,
            update_interval_seconds: update_interval_seconds,
            chunk_time_length: chunk_time_length,
            chunk_file_dimensions: chunk_file_dimensions,
            grid_bounds: grid_bounds,
            proj_string: proj_string
        )
    }
}

struct ModelUpdateMetaFile: RemoteFileManageableJson {
    typealias Value = ModelUpdateMetaJson
    let domain: DomainRegistry
    
    func revalidateEverySeconds(modificationTime: Timestamp?, now: Timestamp) -> Int {
        return 30
    }
    
    func getFilePath() -> String {
        return "\(OpenMeteo.dataDirectory)\(domain.rawValue)/static/meta.json"
    }
    
    func getRemoteUrl() -> String? {
        guard let directory = domain.remoteDataDirectory else {
            return nil
        }
        return "\(directory)static/meta.json"
    }
}
