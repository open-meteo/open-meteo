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
    /// - Parameters:
    ///   - slidingOffset: The offset of the sliding window used to deaccumulate the time series.
    ///
    /// This function operates on an array of floating-point numbers that represents a time series, where each element in the array corresponds to a measurement at a specific time.
    /// The function modifies the input array in place, subtracting the previous value from the current value for each element in the sliding window within each location in the array.
    /// If the previous value is `NaN`, the function replaces it with the value of the element two time steps before or with 0 if it's negative.
    /// The deaccumulation process ensures that the time series is transformed from a cumulative sum to a series of differences.
    mutating func deaccumulateOverTime(slidingOffset: Int) {
        data.deaccumulateOverTime(nTime: nTime, slidingOffset: slidingOffset)
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
    /// - Parameters:
    ///   - slidingOffset: The offset of the sliding window used to deaccumulate the time series.
    ///
    /// This function operates on an array of floating-point numbers that represents a time series, where each element in the array corresponds to a measurement at a specific time.
    /// The function modifies the input array in place, subtracting the previous value from the current value for each element in the sliding window within each location in the array.
    /// If the previous value is `NaN`, the function replaces it with the value of the element two time steps before or with 0 if it's negative.
    /// The deaccumulation process ensures that the time series is transformed from a cumulative sum to a series of differences.
    mutating func deaccumulateOverTime(slidingOffset: Int) {
        data.deaccumulateOverTime(nTime: nTime, slidingOffset: slidingOffset)
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
    ///   - slidingOffset: The offset of the sliding window used to deaccumulate the time series.
    ///
    /// - Precondition: `nTime` must be less than or equal to the length of the input array.
    /// - Precondition: The length of the input array must be divisible by `nTime`.
    ///
    /// This function operates on an array of floating-point numbers that represents a time series, where each element in the array corresponds to a measurement at a specific time.
    /// The function modifies the input array in place, subtracting the previous value from the current value for each element in the sliding window within each location in the array.
    /// If the previous value is `NaN`, the function replaces it with the value of the element two time steps before or with 0 if it's negative.
    /// The deaccumulation process ensures that the time series is transformed from a cumulative sum to a series of differences.
    mutating func deaccumulateOverTime(nTime: Int, slidingOffset: Int) {
        precondition(nTime <= self.count)
        precondition(self.count % nTime == 0)
        let nLocations = self.count / nTime
        for l in 0..<nLocations {
            for hour in stride(from: Swift.min(slidingOffset + nTime, nTime) - 1, through: slidingOffset + 1, by: -1) {
                let current = self[l * nTime + hour]
                let previous = self[l * nTime + hour-1]
                if previous.isNaN, hour-2 >= 0 {
                    // allow 1x missing value
                    // This is a bit hacky, but the case is only present for a single timestep at the end of ARPEGE WORLD
                    let previous = self[l * nTime + hour-2]
                    self[l * nTime + hour] = previous.isNaN ? current : Swift.max(current - previous, 0) / 2
                    continue
                }
                // due to floating point precision, it can become negative
                self[l * nTime + hour] = previous.isNaN ? current : Swift.max(current - previous, 0)
            }
        }
    }
}
