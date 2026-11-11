import Synchronization

public enum OmFileSystemMetrics {
    public static let fileLocalOpen = Atomic(0)
    public static let fileLocalModifiedTotal = Atomic(0)
    public static let fileLocalDirectoriesOpen = Atomic(0)
    public static let fileLocalDirectoryUpdatedTotal = Atomic(0)
    public static let fileLocalDirectoryModifiedTotal = Atomic(0)
    
    public static let fileRemoteOpen = Atomic(0)
    public static let fileRemoteModifiedTotal = Atomic(0)
    public static let fileRemoteModifiedUnexpectedlyTotal = Atomic(0)
    public static let fileRemoteDirectoriesOpen = Atomic(0)
    public static let fileRemoteDirectoryUpdatedTotal = Atomic(0)
    public static let fileRemoteDirectoryUpdateWaiting = Atomic(0)
    public static let fileRemoteDirectoryModifiedTotal = Atomic(0)
    
    public static let fileRemotePayloadWaiting = Atomic(0)
    public static let fileRemotePayloadUpdateWaiting = Atomic(0)

    /// Occupied backend slots and waiting jobs across cache coordinators; both are gauges.
    public static let blockCacheFetchesRunning = Atomic(0)
    public static let blockCacheFetchesQueued = Atomic(0)
    /// Scheduling attempts rejected because a new job would exceed the pending queue limit.
    public static let blockCacheQueueFullTotal = Atomic(0)
    /// Bytes returned by successful provider fetches, counted once per shared/merged fetch.
    public static let blockCacheFetchedBytesTotal = Atomic(0)
    /// Requested preload bytes after EOF clipping, including cached and repeated ranges.
    public static let blockCachePreloadsBytesTotal = Atomic(0)
    /// Extra blocks batched into started provider fetches: sum of blockCount - 1, including failures.
    public static let blockCacheMergedBlocksTotal = Atomic(0)
}
