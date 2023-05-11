import Foundation

/// Which kind of interpolation to use to interpolate 3h values to 1h values
enum Interpolation2StepType {
    // Simple linear interpolation
    case linear
    // Just copy the next value. Which means it is backwards filled. n+1 = n
    case nearest
    // Use solar radiation interpolation
    case solar_backwards_averaged
    // Use hemite interpolation
    case hermite(bounds: ClosedRange<Float>?)
    /// Hermite interpolation but for backward averaged data. Used for latent heat flux
    case hermite_backwards_averaged(bounds: ClosedRange<Float>?)
}

extension Array3DFastTime {
    mutating func interpolate2Steps(type: Interpolation2StepType, positions: [Int], grid: Gridable, locationRange: Range<Int>, run: Timestamp, dtSeconds: Int) {
        var d2 = Array2DFastTime(data: data, nLocations: nLocations*nLevel, nTime: nTime)
        d2.interpolate2Steps(type: type, positions: positions, grid: grid, locationRange: locationRange, run: run, dtSeconds: dtSeconds)
        data = d2.data
    }
    
    mutating func interpolate1Step(interpolation: ReaderInterpolation, interpolationHours: [Int], width: Int, time: TimerangeDt, grid: Gridable, locationRange: Range<Int>) {
        var d2 = Array2DFastTime(data: data, nLocations: nLocations*nLevel, nTime: nTime)
        d2.interpolate1Step(interpolation: interpolation, interpolationHours: interpolationHours, width: width, time: time, grid: grid, locationRange: locationRange)
        data = d2.data
    }
    
    mutating func deaccumulateOverTime(slidingWidth: Int, slidingOffset: Int) {
        var d2 = Array2DFastTime(data: data, nLocations: nLocations*nLevel, nTime: nTime)
        d2.deaccumulateOverTime(slidingWidth: slidingWidth, slidingOffset: slidingOffset)
        data = d2.data
    }
    
    mutating func deavergeOverTime(slidingWidth: Int, slidingOffset: Int) {
        var d2 = Array2DFastTime(data: data, nLocations: nLocations*nLevel, nTime: nTime)
        d2.deavergeOverTime(slidingWidth: slidingWidth, slidingOffset: slidingOffset)
        data = d2.data
    }
}


extension Array2DFastTime {
    /// Interpolate missing values for 1 hourly data that only has 3 hourly data at `positions`.
    mutating func interpolate2Steps(type: Interpolation2StepType, positions: [Int], grid: Gridable, locationRange: Range<Int>, run: Timestamp, dtSeconds: Int) {
        switch type {
        case .linear:
            interpolate2StepsLinear(positions: positions)
        case .nearest:
            interpolate2StepsNearest(positions: positions)
        case .solar_backwards_averaged:
            interpolate2StepsSolarBackwards(positions: positions, grid: grid, locationRange: locationRange, run: run, dtSeconds: dtSeconds)
        case .hermite(let bounds):
            interpolate2StepsHermite(positions: positions, bounds: bounds)
        case .hermite_backwards_averaged(let bounds):
            interpolate2StepsHermiteBackwardsAveraged(positions: positions, bounds: bounds)
        }
    }
    
    mutating func deavergeOverTime(slidingWidth: Int, slidingOffset: Int) {
        for l in 0..<nLocations {
            for start in stride(from: slidingOffset, to: nTime, by: slidingWidth) {
                var prev = self[l, start].isNaN ? 0 : self[l, start]
                var prevH = 1
                var skipped = 0
                for hour in start+1 ..< min(start+slidingWidth, nTime) {
                    let d = self[l, hour]
                    let h = hour-start+1
                    if d.isNaN {
                        skipped += 1
                        continue
                    }
                    self[l, hour] = (d * Float(h / (skipped+1)) - prev * Float(prevH / (skipped+1)))
                    prev = d
                    prevH = h
                    skipped = 0
                }
            }
        }
    }
    
    /// Note: Enforces >0
    mutating func deaccumulateOverTime(slidingWidth: Int, slidingOffset: Int) {
        for l in 0..<nLocations {
            for start in stride(from: slidingOffset, to: nTime, by: slidingWidth) {
                for hour in stride(from: min(start + slidingWidth, nTime) - 1, through: start + 1, by: -1) {
                    let current = self[l, hour]
                    let previous = self[l, hour-1]
                    if previous.isNaN, hour-2 >= 0 {
                        // allow 1x missing value
                        // This is a bit hacky, but the case is only present for a single timestep at the end of ARPEGE WORLD
                        let previous = self[l, hour-2]
                        self[l, hour] = previous.isNaN ? current : max(current - previous, 0) / 2
                        continue
                    }
                    // due to floating point precision, it can become negative
                    self[l, hour] = previous.isNaN ? current : max(current - previous, 0)
                }
            }
        }
    }
    
    /// 2 poisitions are interpolated in one step. Steps should align to `hour % 3 == 1`
    mutating func interpolate2StepsLinear(positions: [Int]) {
        for l in 0..<nLocations {
            for hour in positions {
                let prev = self[l, hour-1]
                let next = self[l, hour+2]
                self[l, hour] = prev * 2/3 + next * 1/3
                self[l, hour+1] = prev * 1/3 + next * 2/3
            }
        }
    }
    
    /// 2 poisitions are interpolated in one step. Steps should align to `hour % 3 == 1`
    mutating func interpolate2StepsHermite(positions: [Int], bounds: ClosedRange<Float>?) {
        for l in 0..<nLocations {
            for hour in positions {
                let A = self[l, hour-4 < 0 ? hour-1 : hour-4]
                let B = self[l, hour-1]
                let C = self[l, hour+2]
                let D = self[l, hour+4 >= nTime ? hour+2 : hour+5]
                let a = -A/2.0 + (3.0*B)/2.0 - (3.0*C)/2.0 + D/2.0
                let b = A - (5.0*B)/2.0 + 2.0*C - D / 2.0
                let c = -A/2.0 + C/2.0
                let d = B
                let x0 = a*0.3*0.3*0.3 + b*0.3*0.3 + c*0.3 + d
                let x1 = a*0.6*0.6*0.6 + b*0.6*0.6 + c*0.6 + d
                if let bounds = bounds {
                    self[l, hour] = Swift.min(Swift.max(x0, bounds.lowerBound), bounds.upperBound)
                    self[l, hour+1] = Swift.min(Swift.max(x1, bounds.lowerBound), bounds.upperBound)
                } else {
                    self[l, hour] = x0
                    self[l, hour+1] = x1
                }
            }
        }
    }
    
    /// 2 poisitions are interpolated in one step. Steps should align to `hour % 3 == 1`
    mutating func interpolate2StepsHermiteBackwardsAveraged(positions: [Int], bounds: ClosedRange<Float>?) {
        /// basically shift the backwards averaged to the center and then do hermite
        for l in 0..<nLocations {
            for hour in positions {
                let A = self[l, hour-5 < 0 ? hour-2 : hour-5]
                let B = self[l, hour-2]
                let C = self[l, hour+2]
                let D = self[l, hour+4 >= nTime ? hour+2 : hour+5]
                let a = -A/2.0 + (3.0*B)/2.0 - (3.0*C)/2.0 + D/2.0
                let b = A - (5.0*B)/2.0 + 2.0*C - D / 2.0
                let c = -A/2.0 + C/2.0
                let d = B
                let xm1 = a*0.3*0.3*0.3 + b*0.3*0.3 + c*0.3 + d
                let x0 = a*0.6*0.6*0.6 + b*0.6*0.6 + c*0.6 + d
                let x1 = C
                if let bounds = bounds {
                    self[l, hour-1] = Swift.min(Swift.max(xm1, bounds.lowerBound), bounds.upperBound)
                    self[l, hour] = Swift.min(Swift.max(x0, bounds.lowerBound), bounds.upperBound)
                    self[l, hour+1] = Swift.min(Swift.max(x1, bounds.lowerBound), bounds.upperBound)
                } else {
                    self[l, hour-1] = xm1
                    self[l, hour] = x0
                    self[l, hour+1] = C
                }
            }
        }
    }
    
    /// 2 poisitions are interpolated in one step. Steps should align to `hour % 3 == 1`
    mutating func interpolate2StepsNearest(positions: [Int]) {
        // fill with next hour. For weather code, we fill with the next hour, because this represents precipitation
        for l in 0..<nLocations {
            for hour in positions {
                let next = self[l, hour+2]
                self[l, hour] = next
                self[l, hour+1] = next
            }
        }
    }
    
    /// 2 poisitions are interpolated in one step. Steps should align to `hour % 3 == 1`
    mutating func interpolate2StepsSolarBackwards(positions: [Int], grid: Gridable, locationRange: Range<Int>, run: Timestamp, dtSeconds: Int) {
        // Solar backwards averages data. Data needs to be deaveraged before
        // First the clear sky index KT is calaculated (KT based on extraterrestrial radiation)
        // clearsky index is hermite interpolated and then back to actual radiation
        
        /// Which range of hours solar radiation data is required
        let solarHours = positions.minAndMax().map { $0.min - 4 ..< $0.max + 7 } ?? 0..<0
        let solarTime = TimerangeDt(start: run.add(solarHours.lowerBound * dtSeconds), nTime: solarHours.count, dtSeconds: dtSeconds)
        
        /// solar factor, backwards averaged over dt
        let solar2d = Zensun.calculateRadiationBackwardsAveraged(grid: grid, locationRange: locationRange, timerange: solarTime)
        
        /// Instead of caiculating solar radiation for the entire grid, itterate through a smaller grid portion
        for l in 0..<nLocations {
            for hour in positions {
                let sHour = hour - solarHours.lowerBound
                let sPos = l / (nLocations / locationRange.count)
                // point C and D are still 3 h averages
                let solC1 = solar2d[sPos, sHour + 0]
                let solC2 = solar2d[sPos, sHour + 1]
                let solC3 = solar2d[sPos, sHour + 2]
                let solC = (solC1 + solC2 + solC3) / 3
                // At low radiaiton levels it is impossible to estimate KT indices
                let C = solC <= 0.005 ? 0 : min(self[l, hour+2] / solC, 1100)
                
                let solB = solar2d[sPos, sHour - 1]
                let B = solB <= 0.005 ? 0 : min(self[l, hour-1] / solB, 1100)
                
                let solA = solar2d[sPos, sHour - 4]
                let A = solA <= 0.005 ? 0 : hour-4 < 0 ? B : min((self[l, hour-4] / solA), 1100)
                
                let solD1 = solar2d[sPos, sHour + 3]
                let solD2 = solar2d[sPos, sHour + 4]
                let solD3 = solar2d[sPos, sHour + 5]
                let solD = (solD1 + solD2 + solD3) / 3
                let D = solD <= 0.005 ? 0 : hour+4 >= nTime ? C : min((self[l, hour+5] / solD), 1100)
                
                let a = -A/2.0 + (3.0*B)/2.0 - (3.0*C)/2.0 + D/2.0
                let b = A - (5.0*B)/2.0 + 2.0*C - D / 2.0
                let c = -A/2.0 + C/2.0
                let d = B
                
                self[l, hour] = max(a*0.3*0.3*0.3 + b*0.3*0.3 + c*0.3 + d, 0) * solC1
                self[l, hour+1] = max(a*0.6*0.6*0.6 + b*0.6*0.6 + c*0.6 + d, 0) * solC2
                self[l, hour+2] = max(C, 0) * solC3
            }
        }
    }
}


extension Array where Element == Float {
    /// Interpolate missing values, but taking the next valid value
    /// `skipFirst` set skip first to prevent filling the frist hour of precipitation
    mutating func interpolateInplaceBackwards(nTime: Int, skipFirst: Int) {
        precondition(nTime <= self.count)
        precondition(skipFirst <= nTime)
        precondition(self.count % nTime == 0)
        let nLocations = self.count / nTime
        for l in 0..<nLocations {
            for t in skipFirst..<nTime {
                guard self[l * nTime + t].isNaN else {
                    continue
                }
                // Seek next valid value
                for t2 in t..<nTime {
                    let value = self[l * nTime + t2]
                    guard !value.isNaN else {
                        continue
                    }
                    // Fill up all values until the first valid value
                    for t in t..<t2 {
                        self[l * nTime + t] = value
                    }
                    break
                }
            }
        }
    }
    
    /// Interpolate missing values by seeking for the next valid value and perform a linear interpolation
    mutating func interpolateInplaceLinear(nTime: Int) {
        precondition(nTime <= self.count)
        precondition(self.count % nTime == 0)
        let nLocations = self.count / nTime
        for l in 0..<nLocations {
            /// Previous value that was not NaN
            var previousValue = Float.nan
            var previousIndex = 0
            for t in 0..<nTime {
                guard self[l * nTime + t].isNaN else {
                    previousValue = self[l * nTime + t]
                    previousIndex = t
                    continue
                }
                // Seek next valid value
                for t2 in t..<nTime {
                    let value = self[l * nTime + t2]
                    guard !value.isNaN else {
                        continue
                    }
                    // Fill up all values until the first valid value
                    for t in t..<t2 {
                        /// Calculate fraction from 0-1 for linear interpolation
                        let fraction = Float(t - previousIndex) / Float(t2 - previousIndex)
                        self[l * nTime + t] = value * fraction + previousValue * (1 - fraction)
                    }
                    break
                }
            }
        }
    }
    
    /// Interpolate missing values by seeking for the next valid value and perform a hermite interpolation
    mutating func interpolateInplaceHermite(nTime: Int) {
        precondition(nTime <= self.count)
        precondition(self.count % nTime == 0)
        let nLocations = self.count / nTime
        for l in 0..<nLocations {
            /// At  the boundary, it wont be possible to detect a valid spacing for 4 points
            /// Reuse the previously good known spacing
            var width = 0
            for t in 0..<nTime {
                guard self[l * nTime + t].isNaN else {
                    continue
                }
                var C = Float.nan
                var D = Float.nan
                var posC = 0
                var posD = 0
                // Seek next 2 valid values, point C and D
                for t2 in t..<nTime {
                    let value = self[l * nTime + t2]
                    guard !value.isNaN else  {
                        continue
                    }
                    if C.isNaN {
                        C = value
                        posC = t2
                        continue
                    }
                    D = value
                    posD = t2
                    break
                }
                if C.isNaN {
                    // not possible to to any interpolation
                    break
                }
                if D.isNaN {
                    // At the boundary, replicate point C
                    D = C
                    posD = posC
                } else {
                    width = posD - posC
                }
                let posB = Swift.max(posC - width, 0)
                // Replicate point B if A would be outside
                let posA = (posB - width) >= 0 ? posB - width : posB
                let B = self[posB]
                let A = self[posA]
                let a = -A/2.0 + (3.0*B)/2.0 - (3.0*C)/2.0 + D/2.0
                let b = A - (5.0*B)/2.0 + 2.0*C - D / 2.0
                let c = -A/2.0 + C/2.0
                let d = B
                
                // Fill up all missing values until point C
                for t in t..<posC {
                    // fractional position of the missing value in relation to points B and C
                    let f = Float(t - posB) / Float(posC - posB)
                    self[l * nTime + t] = a*f*f*f + b*f*f + c*f + d
                }
            }
        }
    }
    
    /// Interpolate missing values by seeking for the next valid value and perform a solar backwards interpolation
    /// Calculates the solar position backwards averages over `dt` and estimates the clearness index `kt` which is then hermite interpolated
    ///
    /// Assumes that the first value after a series of missing values is the average solar radiation for all missing steps (including self)
    /// Values after missing values will afterwards deaveraged as well
    mutating func interpolateInplaceSolarBackwards(nTime: Int, time: TimerangeDt, grid: Gridable, locationRange: Range<Int>) {
        let solar2d = Zensun.calculateRadiationBackwardsAveraged(grid: grid, locationRange: locationRange, timerange: time)
        
        precondition(nTime <= self.count)
        precondition(self.count % nTime == 0)
        let nLocations = self.count / nTime
        for l in 0..<nLocations {
            let sPos = l / (nLocations / locationRange.count)
            
            /// At  the boundary, it wont be possible to detect a valid spacing for 4 points
            /// Reuse the previously good known spacing
            var width = 0
            for t in 0..<nTime {
                guard self[l * nTime + t].isNaN else {
                    continue
                }
                var C = Float.nan
                var D = Float.nan
                var posC = 0
                var posD = 0
                // Seek next 2 valid values, point C and D
                for t2 in t..<nTime {
                    let value = self[l * nTime + t2]
                    guard !value.isNaN else  {
                        continue
                    }
                    if C.isNaN {
                        C = value
                        posC = t2
                        continue
                    }
                    D = value
                    posD = t2
                    break
                }
                if C.isNaN {
                    // not possible to to any interpolation
                    break
                }
                if !D.isNaN {
                    width = posD - posC
                }
                let posB = Swift.max(posC - width, 0)
                let B = self[l * nTime + posB]
                let solB = solar2d[sPos, posB]
                
                /// solC is an average of the solar factor from posB until posC
                let solC = solar2d[sPos, posB+1..<posC+1].mean()

                /// clearness index at point C. At low radiation levels it is impossible to estimate KT indices, set to NaN
                var ktC = solC <= 0.005 ? .nan : Swift.min(C / solC, 1100)
                /// Clearness index at point B, or use `ktC` for low radiation levels
                var ktB = solB <= 0.005 ? ktC : Swift.min(B / solB, 1100)
                if ktC.isNaN && ktB > 0 {
                    ktC = ktB
                }
                
                var ktA: Float
                if posB - width < 0 {
                    // Replicate point B if A would be outside
                    ktA = ktB
                } else {
                    let posA = posB - width
                    /// Solar factor for point A is already deaveraged unlike point C and D
                    let solA = solar2d[sPos, posA]
                    ktA = solA <= 0.005 ? ktB : Swift.min(self[l * nTime + posA] / solA, 1100)
                }

                if ktC.isNaN && ktA > 0 {
                    ktB = ktA
                    ktC = ktA
                }
                
                let ktD: Float
                if D.isNaN {
                    // Replicate point C if D is outside boundary
                    ktD = ktC
                } else {
                    /// solC is an average of the solar factor from posC until posD
                    let solD = solar2d[sPos, posC+1..<posD+1].mean()
                    ktD = solD <= 0.005 ? ktC : Swift.min(D / solD, 1100)
                }
                
                // Espcially for 6h values, aggressively try to find any KT index that works
                // As a future improvement, the clearsky radiation could be approximated by cloud cover total as an additional input
                // This could improve morning/evening kt approximations
                if ktC.isNaN && ktD > 0 {
                    ktA = ktD
                    ktB = ktD
                    ktC = ktD
                }
                
                let a = -ktA/2.0 + (3.0*ktB)/2.0 - (3.0*ktC)/2.0 + ktD/2.0
                let b = ktA - (5.0*ktB)/2.0 + 2.0*ktC - ktD / 2.0
                let c = -ktA/2.0 + ktC/2.0
                let d = ktB
                
                // Fill up all missing values until point C
                for t in t..<posC {
                    // fractional position of the missing value in relation to points B and C
                    let f = Float(t - posB) / Float(posC - posB)
                    // Interpolated clearness index at missing value position
                    let kt = a*f*f*f + b*f*f + c*f + d
                    self[l * nTime + t] = Swift.max(kt, 0) * solar2d[sPos, t]
                }
                
                // Deaverage point C
                self[l * nTime + posC] = Swift.max(ktC, 0) * solar2d[sPos, posC]
            }
        }
    }
}


extension Array2DFastTime {
    /// Used in ECMWF and MeteoFrance
    ///
    /// Important: Backwards sums like precipitation must be deaveraged before AND should already have a corrected sum. The interpolation code will simply copy the array value of the next element WITHOUT dividing by `dt`. Meaning a 6 hour preciptation value should be devided by 2 before, to preserve the rum correctly
    ///
    /// interpolate 1 missing step.. E.g. `DDDDDD-D-D-D-D-D`
    /// `dt` can be used to set element spacing E.g. `DxDxDxDxDxDx-xDx-xDx-xDx-xDx-xD` whith dt=1 all `x` positions will be ignored
    mutating func interpolate1Step(interpolation: ReaderInterpolation, interpolationHours: [Int], width: Int, time: TimerangeDt, grid: Gridable, locationRange: Range<Int>) {
        
        precondition(nLocations % locationRange.count == 0)
        
        switch interpolation {
        case .backwards:
            fallthrough
        case .backwards_sum:
            // take the next hour
            for l in 0..<nLocations {
                for hour in interpolationHours {
                    self[l, hour] = self[l, hour+1*width]
                }
            }
        case .linear:
            for l in 0..<nLocations {
                for hour in interpolationHours {
                    let prev = self[l, hour-1*width]
                    let next = self[l, hour+1*width]
                    self[l, hour] = prev * 1/2 + next * 1/2
                }
            }
        case .hermite:
            for l in 0..<nLocations {
                for hour in interpolationHours {
                    let A = self[l, hour-3*width < 0 ? hour-1*width : hour-3*width]
                    let B = self[l, hour-1*width]
                    let C = self[l, hour+1*width]
                    let D = self[l, hour+2*width >= nTime ? hour+1*width : hour+3*width]
                    let a = -A/2.0 + (3.0*B)/2.0 - (3.0*C)/2.0 + D/2.0
                    let b = A - (5.0*B)/2.0 + 2.0*C - D / 2.0
                    let c = -A/2.0 + C/2.0
                    let d = B
                    self[l, hour] = a*0.5*0.5*0.5 + b*0.5*0.5 + c*0.5 + d
                }
            }
        case .solar_backwards_averaged:
            // Solar backwards averages data. Data needs to be deaveraged before
            // First the clear sky index KT is calaculated (KT based on extraterrestrial radiation)
            // clearsky index is hermite interpolated and then back to actual radiation
            
            if interpolationHours.isEmpty {
                return
            }
            
            /// Which range of hours solar radiation data is required
            let solarHours = interpolationHours.minAndMax().map { $0.min - 3 * width ..< $0.max + 5 * width } ?? 0..<0
            let solarTime = TimerangeDt(
                start: time.range.lowerBound.add(solarHours.lowerBound * time.dtSeconds),
                nTime: solarHours.count / width,
                dtSeconds: time.dtSeconds * width
            )
            
            /// solar factor, backwards averaged over dt
            let solar2d = Zensun.calculateRadiationBackwardsAveraged(grid: grid, locationRange: locationRange, timerange: solarTime)
            
            /// Instead of caiculating solar radiation for the entire grid, itterate through a smaller grid portion
            for l in 0..<nLocations {
                for hour in interpolationHours {
                    let sHour = (hour - solarHours.lowerBound) / width
                    let sPos = l / (nLocations / locationRange.count)
                    // point C and D are still 2 step averages
                    let solC1 = solar2d[sPos, sHour + 0]
                    let solC2 = solar2d[sPos, sHour + 1]
                    let solC = (solC1 + solC2) / 2
                    // At low radiation levels it is impossible to estimate KT indices
                    var C = solC <= 0.005 ? 0 : min(self[l, hour+1*width] / solC, 1100)
                    
                    let solB = solar2d[sPos, sHour - 1]
                    var B = solB <= 0.005 ? C : min(self[l, hour-1*width] / solB, 1100)
                    
                    if C == 0 && B > 0 {
                        C = B
                    }
                    
                    let solA = solar2d[sPos, sHour - 3]
                    var A = solA <= 0.005 ? B : hour-3 < 0 ? B : min((self[l, hour-3*width] / solA), 1100)
                    
                    if C == 0 && A > 0 {
                        B = A
                        C = A
                    }
                    
                    let solD1 = solar2d[sPos, sHour + 2]
                    let solD2 = solar2d[sPos, sHour + 3]
                    let solD = (solD1 + solD2) / 2
                    let D = solD <= 0.005 ? C : hour+3 > nTime ? C : min((self[l, hour+3*width] / solD), 1100)
                    
                    // Espcially for 6h values, aggressively try to find any KT index that works
                    // As a future improvement, the clearsky radiation could be approximated by cloud cover total as an additional input
                    // This could improve morning/evening kt approximations
                    if C == 0 && D > 0 {
                        A = D
                        B = D
                        C = D
                    }
                    
                    let a = -A/2.0 + (3.0*B)/2.0 - (3.0*C)/2.0 + D/2.0
                    let b = A - (5.0*B)/2.0 + 2.0*C - D / 2.0
                    let c = -A/2.0 + C/2.0
                    let d = B
                    
                    self[l, hour] = max(a*0.5*0.5*0.5 + b*0.5*0.5 + c*0.5 + d, 0) * solC1
                    self[l, hour+1*width] = max(C, 0) * solC2
                }
            }
        }
    }
}
