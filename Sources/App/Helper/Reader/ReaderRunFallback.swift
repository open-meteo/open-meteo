/// Skips unavailable single runs while preserving the mixer's normal reader priority.
struct ReaderRunFallback {
    let time: TimerangeDtAndSettings
    private var unavailableRun: ForecastApiError?
    private var succeeded = false

    init(time: TimerangeDtAndSettings) {
        self.time = time
    }

    mutating func read<Value>(_ operation: () async throws -> Value?) async throws -> Value? {
        do {
            let value = try await operation()
            succeeded = succeeded || value != nil
            return value
        } catch let error as ForecastApiError {
            guard time.run != nil, case .modelRunUnavailable = error else { throw error }
            unavailableRun = unavailableRun ?? error
            return nil
        }
    }

    func finish() throws {
        if !succeeded, let unavailableRun {
            throw unavailableRun
        }
    }
}
