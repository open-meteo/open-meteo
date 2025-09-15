import Foundation

struct FullRunMetaJson: Codable {
    let reference_time: Date
    let created_at: Date
    let variables: [String]
    let valid_times: [String]

    /// Data temporal resolution in seconds. E.g. 3600 for 1-hourly data
    let temporal_resolution_seconds: Int
    
    // valid_times? Params like precipitation do not have the first step. Some MeteoFrance variables are also missing steps...
    
    /// Use directory listing to get all variables. Model or pressure levels might be downloaded at a different time
    private init?(domain: GenericDomain, run: Timestamp, validTimes: [Timestamp]) throws {
        let path = "\(domain.dataRunDirectory!)\(run.format_directoriesYYYYMMddhhmm)/"
        guard FileManager.default.fileExists(atPath: path) else {
            print("Directory does not exist to generate FullRunMetaJson: \(path)")
            return nil
        }
        let items = try FileManager.default.contentsOfDirectory(atPath: path)
        self.variables = items.filter({$0.hasSuffix(".om")}).map({String($0.dropLast(3))})
        self.reference_time = run.toDate()
        self.created_at = Date()
        self.temporal_resolution_seconds = domain.dtSeconds
        self.valid_times = validTimes.map(\.iso8601_YYYY_MM_dd_HH_mmZ)
    }
    
    static func write(domain: GenericDomain, run: Timestamp, validTimes: [Timestamp]) throws {
        guard let meta = try FullRunMetaJson(domain: domain, run: run, validTimes: validTimes) else {
            return
        }
        let path = FullRunMetaFile.run(domain.domainRegistry, run)
        try meta.writeTo(path: path.getFilePath())
        let pathLatest = FullRunMetaFile.latest(domain.domainRegistry)
        try meta.writeTo(path: pathLatest.getFilePath())
    }
}

enum FullRunMetaFile: RemoteFileManageableJson {
    typealias Value = FullRunMetaJson
    
    case latest(DomainRegistry)
    case run(DomainRegistry, Timestamp)
    
    func revalidateEverySeconds(modificationTime: Timestamp?, now: Timestamp) -> Int {
        switch self {
        case .latest(_):
            return 30
        case .run(_, _):
            return modificationTime == nil ? 30 : 24*3600
        }
    }
    
    func getFilePath() -> String {
        let directory = OpenMeteo.dataRunDirectory ?? OpenMeteo.dataDirectory
        switch self {
        case .latest(let domainRegistry):
            return "\(directory)\(domainRegistry.rawValue)/latest.json"
        case .run(let domainRegistry, let run):
            return "\(directory)\(domainRegistry.rawValue)/\(run.format_directoriesYYYYMMddhhmm)/meta.json"
        }
    }
    
    func getRemoteUrl() -> String? {
        switch self {
        case .latest(let domain):
            guard let directory = domain.remoteDataRunDirectory else {
                return nil
            }
            return "\(directory)latest.json"
        case .run(let domain, let run):
            guard let directory = domain.remoteDataRunDirectory else {
                return nil
            }
            return "\(directory)\(run.format_directoriesYYYYMMddhhmm)/meta.json"
        }
    }
}
