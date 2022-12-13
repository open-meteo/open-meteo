import Foundation


extension DispatchTime {
    /// Nicely format elapsed time
    func timeElapsedPretty() -> String {
        let seconds = Double((DispatchTime.now().uptimeNanoseconds - uptimeNanoseconds)) / 1_000_000_1000
        return seconds.asSecondsPrettyPrint
    }
}

extension Double {
    var asSecondsPrettyPrint: String {
        let milliseconds = self * 1000
        let seconds = self
        let minutes = self / 60
        let hours = self / 3600
        if milliseconds < 5 {
            return "\(milliseconds.round(digits: 2))ms"
        }
        if milliseconds < 20 {
            return "\(milliseconds.round(digits: 1))ms"
        }
        if milliseconds < 800 {
            return "\(milliseconds.round(digits: 0))ms"
        }
        if milliseconds < 5_000 {
            return "\(seconds.round(digits: 2))s"
        }
        if milliseconds < 20_000 {
            return "\(seconds.round(digits: 1))s"
        }
        if milliseconds < 180_000 {
            return "\(seconds.round(digits: 0))s"
        }
        if milliseconds < 1000 * 60 * 90 {
            return "\(minutes.round(digits: 0))m"
        }
        return "\(hours.round(digits: 0))h \(minutes.round(digits: 0))m"
    }
}
