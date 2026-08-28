#if os(Linux)
    @preconcurrency import Glibc
#else
    import Darwin.C
#endif

import Synchronization

public final class ProcessExitStatus: Sendable {
    public static let shared = ProcessExitStatus()
    private let failed = Atomic(false)

    var hasFailed: Bool {
        failed.load(ordering: .relaxed)
    }

    func markFailure() {
        failed.store(true, ordering: .relaxed)
    }

    public func exitIfFailure() {
        if hasFailed {
            exit(EXIT_FAILURE)
        }
    }
}
