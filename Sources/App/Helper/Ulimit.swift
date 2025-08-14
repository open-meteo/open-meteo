import Foundation
import Logging

#if os(Linux)
    import Glibc
    fileprivate let OS_RLIMIT = __rlimit_resource_t(RLIMIT_NOFILE.rawValue)
#else
    import Darwin
    fileprivate let OS_RLIMIT = RLIMIT_NOFILE
#endif

extension Process {
    /// Set open files limit to 64k
    public static func increaseOpenFileLimit(logger: Logger) {
        for limit in [1024 * 1024, 524288, 65536] {
            var filelimit = rlimit(rlim_cur: rlim_t(limit), rlim_max: rlim_t(limit))
            guard setrlimit(OS_RLIMIT, &filelimit) != -1 else {
                logger.debug("Could not set number of open file limit to \(limit). \(String(cString: strerror(errno)))")
                continue
            }
            logger.debug("Set open file limit to \(limit).")
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
