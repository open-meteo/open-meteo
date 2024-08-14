import Foundation

/**
 TODO:
 - CAMS, IconWave, GloFas, seasonal forecast, CMIP, satellite
 - run end lenght might be too short for side-runs
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
    
    /// First date of available data
    let data_start_time: Int
    
    /// Last available timestamp
    let data_end_time: Int
    
    /// Write a new meta data JSON
    static func update(domain: GenericDomain, run: Timestamp, end: Timestamp) throws {
        let now = Timestamp.now()
        let meta = ModelUpdateMetaJson(
            last_run_initialisation_time: run.timeIntervalSince1970,
            last_run_modification_time: now.timeIntervalSince1970,
            last_run_availability_time: now.timeIntervalSince1970,
            temporal_resolution_seconds: domain.dtSeconds,
            data_start_time: 0,
            data_end_time: end.timeIntervalSince1970
        )
        let encoder = JSONEncoder()
        let path = OmFileManagerReadable.meta(domain: domain.domainRegistry).getFilePath()
        let fn = try FileHandle.createNewFile(file: "\(path)~")
        try fn.write(contentsOf: try encoder.encode(meta))
        try fn.close()
        try FileManager.default.moveFileOverwrite(from: "\(path)~", to: path)
    }
    
    /// Write new model meta data, but only of it contains temperature_2m or precipitation. Ignores e.g. upper level runs
    static func update(domain: GenericDomain, run: Timestamp, handles: [GenericVariableHandle]) throws {
        if handles.contains(where: {["temperature_2m", "precipitation"].contains($0.variable.omFileName.file)}) {
            try update(domain: domain, run: run, end: handles.max(by: {$0.time > $1.time})?.time ?? Timestamp(0))
        }
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
