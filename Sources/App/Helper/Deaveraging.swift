import Foundation


extension Array3DFastTime {
    /// Deaverages a running mean over time.
    ///
    /// This function operates on an array of floating-point numbers that represents a time series, where each element in the array corresponds to a measurement at a specific time.
    /// The function modifies the input array in place, deaveraging a running mean over time for each location in the array.
    mutating func deavergeOverTime() {
        data.deavergeOverTime(nTime: nTime)
    }
    
    /// Deaccumulates a time series by subtracting the previous value from the current value.
    ///
    /// This function operates on an array of floating-point numbers that represents a time series, where each element in the array corresponds to a measurement at a specific time.
    /// The function modifies the input array in place, subtracting the previous value from the current value for each element in the sliding window within each location in the array.
    /// If the previous value is `NaN`, the function replaces it with the value of the element two time steps before or with 0 if it's negative.
    /// The deaccumulation process ensures that the time series is transformed from a cumulative sum to a series of differences.
    mutating func deaccumulateOverTime() {
        data.deaccumulateOverTime(nTime: nTime)
    }
}

extension Array2DFastTime {
    /// Deaverages a running mean over time.
    ///
    /// This function operates on an array of floating-point numbers that represents a time series, where each element in the array corresponds to a measurement at a specific time.
    /// The function modifies the input array in place, deaveraging a running mean over time for each location in the array.
    mutating func deavergeOverTime() {
        data.deavergeOverTime(nTime: nTime)
    }
    
    /// Deaccumulates a time series by subtracting the previous value from the current value.
    ///
    /// This function operates on an array of floating-point numbers that represents a time series, where each element in the array corresponds to a measurement at a specific time.
    /// The function modifies the input array in place, subtracting the previous value from the current value for each element in the sliding window within each location in the array.
    /// If the previous value is `NaN`, the function replaces it with the value of the element two time steps before or with 0 if it's negative.
    /// The deaccumulation process ensures that the time series is transformed from a cumulative sum to a series of differences.
    mutating func deaccumulateOverTime() {
        data.deaccumulateOverTime(nTime: nTime)
    }
}

extension Array where Element == Float {
    /// Deaverages a running mean over time.
    ///
    /// - Parameters:
    ///   - nTime: The number of time intervals in the time series.
    ///
    /// - Precondition: `nTime` must be less than or equal to the length of the input array.
    /// - Precondition: The length of the input array must be divisible by `nTime`.
    ///
    /// This function operates on an array of floating-point numbers that represents a time series, where each element in the array corresponds to a measurement at a specific time.
    /// The function modifies the input array in place, deaveraging a running mean over time for each location in the array.
    mutating func deavergeOverTime(nTime: Int) {
        precondition(nTime <= self.count)
        precondition(self.count % nTime == 0)
        let nLocations = self.count / nTime
        for l in 0..<nLocations {
            var startStep = 0
            var prev = Float.nan
            var prevH = 0
            for hour in 0 ..< nTime {
                let d = self[l * nTime + hour]
                if prev.isNaN {
                    // seek to first valid value
                    prev = d
                    startStep = hour
                    prevH = hour
                    continue
                }
                if d.isNaN {
                    // ignore missing values
                    continue
                }
                let deltaHours = Float(hour - startStep + 1)
                let deltaHoursPrevious = Float(prevH - startStep + 1)
                self[l * nTime + hour] = (d * deltaHours - prev * deltaHoursPrevious) / (deltaHours - deltaHoursPrevious)
                prev = d
                prevH = hour
            }
        }
    }
    
    /// Deaccumulates a time series by subtracting the previous value from the current value.
    ///
    /// - Parameters:
    ///   - nTime: The number of time intervals in the time series.
    ///
    /// - Precondition: `nTime` must be less than or equal to the length of the input array.
    /// - Precondition: The length of the input array must be divisible by `nTime`.
    ///
    /// This function operates on an array of floating-point numbers that represents a time series, where each element in the array corresponds to a measurement at a specific time.
    /// The function modifies the input array in place, subtracting the previous value from the current value for each element in the sliding window within each location in the array.
    /// If the previous value is `NaN`, the function replaces it with the value of the element two time steps before or with 0 if it's negative.
    /// The deaccumulation process ensures that the time series is transformed from a cumulative sum to a series of differences.
    mutating func deaccumulateOverTime(nTime: Int) {
        precondition(nTime <= self.count)
        precondition(self.count % nTime == 0)
        let nLocations = self.count / nTime
        for l in 0..<nLocations {
            var prev = Float.nan
            var skipped = 0
            for hour in 0 ..< nTime {
                let d = self[l * nTime + hour]
                if prev.isNaN {
                    prev = d
                    continue
                }
                if d.isNaN {
                    // ignore missing values
                    skipped += 1
                    continue
                }
                self[l * nTime + hour] = (d - prev) / Float(skipped + 1)
                prev = d
                skipped = 0
            }
        }
    }
}
