import Foundation

struct DataSpatialJson: Codable {
    let reference_time: Date
    let last_modified_time: Date
    let completed: Bool
    let valid_times: [String]
    let variables: [String]

    /// Data temporal resolution in seconds. E.g. 3600 for 1-hourly data
    //let temporal_resolution_seconds: Int

    // variables_step0?
    // grid attributes?
    // units? step types?

    /*struct VariableSpatialJson: Encodable {
        /// E.g. `temperature_2m`
        let name: String
        let unit: String
        let skip_hour0: Bool
        let step_type: StepType
    }

    enum StepType: Encodable {
        case instantaneous
        case mean
        case sum
        case maximum
        case minimum
    }*/
    
    func sameRunOrOlderThan5Minutes(run: Timestamp) -> Bool {
        /*guard let lastModified = try? Date(last_modified_time, strategy: .iso8601),
              let lastRun = try? Date(reference_time, strategy: .iso8601) else {
            return true
        }*/
        let sameRun = Int(reference_time.timeIntervalSince1970) == run.timeIntervalSince1970
        let olderThan5Minutes = last_modified_time.addingTimeInterval(300) < Date()
        return sameRun || olderThan5Minutes
    }
}
