import Foundation
import SwiftPFor2D

enum ModelTimeVariable: String, GenericVariable {
    case initialisation_time
    case modification_time
    
    var omFileName: (file: String, level: Int) {
        return (rawValue, 0)
    }
    
    var scalefactor: Float {
        return 1
    }
    
    var interpolation: ReaderInterpolation {
        return .backwards
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
    
    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
}


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
struct ModelUpdateMetaJson: Codable {
    /// Model initilsiation time as unix timestamp. E.g. 0z
    let last_run_initialisation_time: Int
    
    /// Last modification time. The time the conversion finished on the download and processing server
    let last_run_modification_time: Int
    
    /// Time at which that model run has been available on the current server
    let last_run_availability_time: Int
    
    /// Data temporal resolution in seconds. E.g. 3600 for 1-hourly data
    let temporal_resolution_seconds: Int
    
    /// First date of available data -> Also different per server / variable etc
    //let data_start_time: Int
    
    /// End of updated timerange. The last timestep is not included! -> Probably not reliable at all.... Short runs, upper model runs, etc....
    let data_end_time: Int
    
    /// E.g. `3600` for updates every 1 hour
    let update_interval_seconds: Int
    
    /// Write a new meta data JSON
    static func update(domain: GenericDomain, run: Timestamp, end: Timestamp, now: Timestamp = .now()) throws {
        let meta = ModelUpdateMetaJson(
            last_run_initialisation_time: run.timeIntervalSince1970,
            last_run_modification_time: now.timeIntervalSince1970,
            last_run_availability_time: now.timeIntervalSince1970,
            temporal_resolution_seconds: domain.dtSeconds,
            //data_start_time: 0,
            data_end_time: end.timeIntervalSince1970,
            update_interval_seconds: domain.updateIntervalSeconds
        )
        let path = OmFileManagerReadable.meta(domain: domain.domainRegistry)
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
            update_interval_seconds: update_interval_seconds
        )
    }
}

extension Encodable {
    /// Write to as an atomic operation
    func writeTo(path: String) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let fn = try FileHandle.createNewFile(file: "\(path)~")
        try fn.write(contentsOf: try encoder.encode(self))
        try fn.close()
        try FileManager.default.moveFileOverwrite(from: "\(path)~", to: path)
    }
}

/// Intermediate structure to keep meta files open
struct ModelUpdateMetaJsonAndFileHandle: GenericFileManagable {
    let fn: FileHandle
    let meta: ModelUpdateMetaJson
    
    func wasDeleted() -> Bool {
        fn.wasDeleted()
    }
    
    static func open(from: OmFileManagerReadable) throws -> ModelUpdateMetaJsonAndFileHandle? {
        guard let fn = try? FileHandle.openFileReading(file: from.getFilePath()) else {
            return nil
        }
        guard let data = try fn.readToEnd() else {
            return nil
        }
        guard let json = try? JSONDecoder().decode(ModelUpdateMetaJson.self, from: data) else {
            return nil
        }
        return .init(fn: fn, meta: json)
    }
}

/// Cache access to metadata JSONs
struct MetaFileManager {
    public static var instance = GenericFileManager<ModelUpdateMetaJsonAndFileHandle>()
    
    private init() {}
    
    /// Get cached file or return nil, if the files does not exist
    public static func get(_ file: OmFileManagerReadable) throws -> ModelUpdateMetaJson? {
        try instance.get(file)?.meta
    }
}
