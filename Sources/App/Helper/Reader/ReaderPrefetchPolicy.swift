/// Keep normal paging separate from early remote block-cache warming.
/// Applied at the resolved file reader so derived variables and local fallbacks
/// follow the same policy as directly requested variables.
enum ReaderPrefetchPolicy: Sendable {
    case all
    case remoteOnly

    func includes(isRemote: Bool) -> Bool {
        switch self {
        case .all: return true
        case .remoteOnly: return isRemote
        }
    }

    static let concurrency = RemoteDataHttpClient.positiveLimit("REMOTE_DATA_PREFETCH_CONCURRENCY", default: 10)

    @TaskLocal static var current: ReaderPrefetchPolicy = .all
}
