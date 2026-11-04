import OmFileIO

/// Separate early remote discovery from the normal paging pass over all readers.
enum ReaderPrefetchPolicy: Sendable {
    case all
    case remoteOnly

    func includes(isRemote: Bool) -> Bool {
        switch self {
        case .all: return true
        case .remoteOnly: return isRemote
        }
    }

    /// Per-request traversal bound and speculative payload HTTP ceiling.
    static let concurrency = RemoteDataHttpClientLifecycle.positiveLimit("REMOTE_DATA_PREFETCH_CONCURRENCY", default: 10)

    /// Global and rotation limits apply only to speculative payload HTTP attempts.
    static let executor = RemotePreloadExecutor(
        concurrency: RemoteDataHttpClientLifecycle.positiveLimit("REMOTE_DATA_PREFETCH_GLOBAL_CONCURRENCY", default: 32),
        warmingConcurrency: RemoteDataHttpClientLifecycle.positiveLimit("REMOTE_DATA_BACKGROUND_DOWNLOADS", default: 4)
    )

    @TaskLocal static var current: ReaderPrefetchPolicy = .all
}

/// The response owns the download session after discovery completes.
/// Dropping an unconsumed response also stops its pending preload work.
final class ReaderPreload: Sendable {
    let session = ReaderPrefetchPolicy.executor.makeSession(concurrency: ReaderPrefetchPolicy.concurrency)

    func stop() { session.stop() }
    deinit { session.stop() }
}
