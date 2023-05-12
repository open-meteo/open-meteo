import Foundation


extension Array3DFastTime {
    /// Deaverages a running mean over time.
    ///
    /// - Parameters:
    ///   - slidingWidth: The width of the sliding window used to calculate the running mean.
    ///   - slidingOffset: The offset of the sliding window used to calculate the running mean.
    ///
    /// This function operates on an array of floating-point numbers that represents a time series, where each element in the array corresponds to a measurement at a specific time.
    /// The function modifies the input array in place, deaveraging a running mean over time for each sliding window within each location in the array.
    mutating func deavergeOverTime(slidingWidth: Int, slidingOffset: Int) {
        data.deavergeOverTime(nTime: nTime, slidingWidth: slidingWidth, slidingOffset: slidingOffset)
    }
    
    /// Deaccumulates a time series by subtracting the previous value from the current value.
    ///
    /// - Parameters:
    ///   - slidingWidth: The width of the sliding window used to deaccumulate the time series.
    ///   - slidingOffset: The offset of the sliding window used to deaccumulate the time series.
    ///
    /// This function operates on an array of floating-point numbers that represents a time series, where each element in the array corresponds to a measurement at a specific time.
    /// The function modifies the input array in place, subtracting the previous value from the current value for each element in the sliding window within each location in the array.
    /// If the previous value is `NaN`, the function replaces it with the value of the element two time steps before or with 0 if it's negative.
    /// The deaccumulation process ensures that the time series is transformed from a cumulative sum to a series of differences.
    mutating func deaccumulateOverTime(slidingWidth: Int, slidingOffset: Int) {
        data.deaccumulateOverTime(nTime: nTime, slidingWidth: slidingWidth, slidingOffset: slidingOffset)
    }
}

extension Array2DFastTime {
    /// Deaverages a running mean over time.
    ///
    /// - Parameters:
    ///   - slidingWidth: The width of the sliding window used to calculate the running mean.
    ///   - slidingOffset: The offset of the sliding window used to calculate the running mean.
    ///
    /// This function operates on an array of floating-point numbers that represents a time series, where each element in the array corresponds to a measurement at a specific time.
    /// The function modifies the input array in place, deaveraging a running mean over time for each sliding window within each location in the array.
    mutating func deavergeOverTime(slidingWidth: Int, slidingOffset: Int) {
        data.deavergeOverTime(nTime: nTime, slidingWidth: slidingWidth, slidingOffset: slidingOffset)
    }
    
    /// Deaccumulates a time series by subtracting the previous value from the current value.
    ///
    /// - Parameters:
    ///   - slidingWidth: The width of the sliding window used to deaccumulate the time series.
    ///   - slidingOffset: The offset of the sliding window used to deaccumulate the time series.
    ///
    /// This function operates on an array of floating-point numbers that represents a time series, where each element in the array corresponds to a measurement at a specific time.
    /// The function modifies the input array in place, subtracting the previous value from the current value for each element in the sliding window within each location in the array.
    /// If the previous value is `NaN`, the function replaces it with the value of the element two time steps before or with 0 if it's negative.
    /// The deaccumulation process ensures that the time series is transformed from a cumulative sum to a series of differences.
    mutating func deaccumulateOverTime(slidingWidth: Int, slidingOffset: Int) {
        data.deaccumulateOverTime(nTime: nTime, slidingWidth: slidingWidth, slidingOffset: slidingOffset)
    }
}

extension Array where Element == Float {
    /// Deaverages a running mean over time.
    ///
    /// - Parameters:
    ///   - nTime: The number of time intervals in the time series.
    ///   - slidingWidth: The width of the sliding window used to calculate the running mean.
    ///   - slidingOffset: The offset of the sliding window used to calculate the running mean.
    ///
    /// - Precondition: `nTime` must be less than or equal to the length of the input array.
    /// - Precondition: The length of the input array must be divisible by `nTime`.
    ///
    /// This function operates on an array of floating-point numbers that represents a time series, where each element in the array corresponds to a measurement at a specific time.
    /// The function modifies the input array in place, deaveraging a running mean over time for each sliding window within each location in the array.
    mutating func deavergeOverTime(nTime: Int, slidingWidth: Int, slidingOffset: Int) {
        precondition(nTime <= self.count)
        precondition(self.count % nTime == 0)
        let nLocations = self.count / nTime
        for l in 0..<nLocations {
            for start in stride(from: slidingOffset, to: nTime, by: slidingWidth) {
                var prev = self[l * nTime + start].isNaN ? 0 : self[l * nTime + start]
                var prevH = 1
                var skipped = 0
                for hour in start+1 ..< Swift.min(start+slidingWidth, nTime) {
                    let d = self[l * nTime + hour]
                    let h = hour-start+1
                    if d.isNaN {
                        skipped += 1
                        continue
                    }
                    self[l * nTime + hour] = (d * Float(h / (skipped+1)) - prev * Float(prevH / (skipped+1)))
                    prev = d
                    prevH = h
                    skipped = 0
                }
            }
        }
    }
    
    /// Deaccumulates a time series by subtracting the previous value from the current value.
    ///
    /// - Parameters:
    ///   - nTime: The number of time intervals in the time series.
    ///   - slidingWidth: The width of the sliding window used to deaccumulate the time series.
    ///   - slidingOffset: The offset of the sliding window used to deaccumulate the time series.
    ///
    /// - Precondition: `nTime` must be less than or equal to the length of the input array.
    /// - Precondition: The length of the input array must be divisible by `nTime`.
    ///
    /// This function operates on an array of floating-point numbers that represents a time series, where each element in the array corresponds to a measurement at a specific time.
    /// The function modifies the input array in place, subtracting the previous value from the current value for each element in the sliding window within each location in the array.
    /// If the previous value is `NaN`, the function replaces it with the value of the element two time steps before or with 0 if it's negative.
    /// The deaccumulation process ensures that the time series is transformed from a cumulative sum to a series of differences.
    mutating func deaccumulateOverTime(nTime: Int, slidingWidth: Int, slidingOffset: Int) {
        precondition(nTime <= self.count)
        precondition(self.count % nTime == 0)
        let nLocations = self.count / nTime
        for l in 0..<nLocations {
            for start in stride(from: slidingOffset, to: nTime, by: slidingWidth) {
                for hour in stride(from: Swift.min(start + slidingWidth, nTime) - 1, through: start + 1, by: -1) {
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
}
