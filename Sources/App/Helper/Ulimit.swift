import Foundation

#if os(Linux)
    import Glibc
    fileprivate let OS_RLIMIT = __rlimit_resource_t(RLIMIT_NOFILE.rawValue)
#else
    import Darwin
    fileprivate let OS_RLIMIT = RLIMIT_NOFILE
#endif


extension Process {
    /// Set open files limit to 64k
    public static func setOpenFileLimitto64k() {
        var filelimit = rlimit(rlim_cur: 65536, rlim_max: 65536)
        if setrlimit(OS_RLIMIT, &filelimit) == -1 {
            print("[WARNING] Could not set number of open file limit to 65536). \(String(cString: strerror(errno)))")
        }
    }
}
