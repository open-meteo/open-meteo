import Foundation

struct FullRunMetaJson: Encodable {
    let reference_time: Date
    let created_at: Date
    let variables: [String]
    let valid_times: [String]

    /// Data temporal resolution in seconds. E.g. 3600 for 1-hourly data
    let temporal_resolution_seconds: Int
    
    // valid_times? Params like precipitation do not have the first step. Some MeteoFrance variables are also missing steps...
    
    /// Use directory listing to get all variables. Model or pressure levels might be downloaded at a different time
    public init?(domain: GenericDomain, run: Timestamp, validTimes: [Timestamp]) throws {
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
        let path = "\(domain.dataRunDirectory!)\(run.format_directoriesYYYYMMddhhmm)/meta.json"
        try meta.writeTo(path: path)
    }
}
