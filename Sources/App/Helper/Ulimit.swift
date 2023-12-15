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
            print("[ WARNING ] Could not set number of open file limit to 65536. \(String(cString: strerror(errno)))")
            return
        }
        filelimit = rlimit(rlim_cur: 524288, rlim_max: 524288)
        if setrlimit(OS_RLIMIT, &filelimit) == -1 {
            print("[ WARNING ] Could not set number of open file limit to 524288. \(String(cString: strerror(errno)))")
            return
        }
    }
    
    /// Set alarm to terminate the process in case it gets stuck
    public static func alarm(seconds: Int) {
        #if os(Linux)
        Glibc.alarm(UInt32(seconds))
        #else
        Darwin.alarm(UInt32(seconds))
        #endif
    }
}


#if os(Linux)
/// Disable Idle sleep, Not supported for linux
func disableIdleSleep() {
    
}
#else
import IOKit.pwr_mgt

/// Disable Idle sleep, Not supported for linux
func disableIdleSleep() {
    let reason: String = "Disabling Screen Sleep"
    var assertionID: IOPMAssertionID = 0
    guard IOPMAssertionCreateWithName(kIOPMAssertPreventUserIdleSystemSleep as CFString, IOPMAssertionLevel(kIOPMAssertionLevelOn), reason as CFString, &assertionID) == kIOReturnSuccess else {
        fatalError("Idle sleep disable failed")
    }
}
#endif
