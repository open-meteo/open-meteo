import Foundation


extension Array3DFastTime {
    /// Take a running mean and deaverage over time
    mutating func deavergeOverTime(slidingWidth: Int, slidingOffset: Int) {
        data.deavergeOverTime(nTime: nTime, slidingWidth: slidingWidth, slidingOffset: slidingOffset)
    }
    
    /// Take running sum and deaccumulate it over time.
    /// Note: Enforces >0
    mutating func deaccumulateOverTime(slidingWidth: Int, slidingOffset: Int) {
        data.deaccumulateOverTime(nTime: nTime, slidingWidth: slidingWidth, slidingOffset: slidingOffset)
    }
}

extension Array2DFastTime {
    /// Take a running mean and deaverage over time
    mutating func deavergeOverTime(slidingWidth: Int, slidingOffset: Int) {
        data.deavergeOverTime(nTime: nTime, slidingWidth: slidingWidth, slidingOffset: slidingOffset)
    }
    
    /// Take running sum and deaccumulate it over time.
    /// Note: Enforces >0
    mutating func deaccumulateOverTime(slidingWidth: Int, slidingOffset: Int) {
        data.deaccumulateOverTime(nTime: nTime, slidingWidth: slidingWidth, slidingOffset: slidingOffset)
    }
}

extension Array where Element == Float {
    /// Take a running mean and deaverage over time
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
    
    /// Take running sum and deaccumulate it over time.
    /// Note: Enforces >0
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
