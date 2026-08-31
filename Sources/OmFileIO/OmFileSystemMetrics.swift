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
}
