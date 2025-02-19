import Foundation


extension Array3DFastTime {
    /// Fill in missing data by interpolating using differnet interpolation types
    ///
    /// Important: Backwards sums like precipitation must be deaveraged before AND should already have a corrected sum. The interpolation code will simply copy the array value of the next element WITHOUT dividing by `dt`. Meaning a 6 hour preciptation value should be devided by 2 before, to preserve the rum correctly
    ///
    /// interpolate missing steps.. E.g. `DDDDDD-D-D-D-D-D`
    /// Automatically detects data spacing `--D--D--D` for deaverging or backfilling
    mutating func interpolateInplace(type: ReaderInterpolation, time: TimerangeDt, grid: Gridable, locationRange: any RandomAccessCollection<Int>) {
        precondition(nTime == time.count)
        data.interpolateInplace(type: type, time: time, grid: grid, locationRange: locationRange)
    }
}
extension Array2DFastTime {
    /// Fill in missing data by interpolating using differnet interpolation types
    ///
    /// Important: Backwards sums like precipitation must be deaveraged before AND should already have a corrected sum. The interpolation code will simply copy the array value of the next element WITHOUT dividing by `dt`. Meaning a 6 hour preciptation value should be devided by 2 before, to preserve the rum correctly
    ///
    /// interpolate missing steps.. E.g. `DDDDDD-D-D-D-D-D`
    /// Automatically detects data spacing `--D--D--D` for deaverging or backfilling
    mutating func interpolateInplace(type: ReaderInterpolation, time: TimerangeDt, grid: Gridable, locationRange: any RandomAccessCollection<Int>) {
        precondition(nTime == time.count)
        data.interpolateInplace(type: type, time: time, grid: grid, locationRange: locationRange)
    }
}


extension Array where Element == Float {
    /// Fill in missing data by interpolating using differnet interpolation types
    ///
    /// Important: Backwards sums like precipitation must be deaveraged before AND should already have a corrected sum. The interpolation code will simply copy the array value of the next element WITHOUT dividing by `dt`. Meaning a 6 hour preciptation value should be devided by 2 before, to preserve the rum correctly
    ///
    /// interpolate missing steps.. E.g. `DDDDDD-D-D-D-D-D`
    /// Automatically detects data spacing `--D--D--D` for deaverging or backfilling
    mutating func interpolateInplace(type: ReaderInterpolation, time: TimerangeDt, grid: Gridable, locationRange: any RandomAccessCollection<Int>) {
        switch type {
        case .linear:
            interpolateInplaceLinear(nTime: time.count)
        case .linearDegrees:
            interpolateInplaceLinearDegrees(nTime: time.count)
        case .hermite(let bounds):
            interpolateInplaceHermite(nTime: time.count, bounds: bounds)
        case .solar_backwards_averaged:
            interpolateInplaceSolarBackwards(time: time, grid: grid, locationRange: locationRange, missingValuesAreBackwardsAveraged: true)
        case .solar_backwards_missing_not_averaged:
            interpolateInplaceSolarBackwards(time: time, grid: grid, locationRange: locationRange, missingValuesAreBackwardsAveraged: false)
        case .backwards_sum:
            interpolateInplaceBackwards(nTime: time.count, isSummation: true)
        case .backwards:
            interpolateInplaceBackwards(nTime: time.count, isSummation: false)
        }
    }
    
    
    /// Interpolate missing values, but taking the next valid value
    /// Automatically detects data spacing. e.g. `--D--D--D` and correctly backfills
    mutating func interpolateInplaceBackwards(nTime: Int, isSummation: Bool) {
        precondition(nTime <= self.count)
        precondition(self.count % nTime == 0)
        let nLocations = self.count / nTime
        for l in 0..<nLocations {
            /// Find the first valid value. This might be adjusted due to data spacing
            var firstValid = nTime
            for t in 0..<nTime {
                guard !self[l * nTime + t].isNaN else {
                    continue
                }
                if firstValid == nTime {
                    firstValid = t
                    continue
                }
                // 1 = no spacing
                // 2 = -D-D-D
                // 3 = --D--D--D
                firstValid = Swift.max(firstValid - (t - firstValid - 1), 0)
                break
            }

            var previousIndex = firstValid - 1
            for t in firstValid..<nTime {
                guard self[l * nTime + t].isNaN else {
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
                    for t in t...t2 {
                        self[l * nTime + t] = isSummation ? value / Float(t2 - previousIndex) : value
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
    
    /// Interpolate missing values by seeking for the next valid value and perform a linear interpolation
    mutating func interpolateInplaceLinearDegrees(nTime: Int) {
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
                        let A2 = (abs(previousValue-value) > 180 && value < previousValue) ? value + 360 : value
                        let B2 = (abs(previousValue-value) > 180 && value > previousValue) ? previousValue + 360 : previousValue
                        let h = A2 * fraction + B2 * (1 - fraction)
                        self[l * nTime + t] = h.truncatingRemainder(dividingBy: 360)
                    }
                    break
                }
            }
        }
    }
    
    /// Interpolate missing values by seeking for the next valid value and perform a hermite interpolation
    mutating func interpolateInplaceHermite(nTime: Int, bounds: ClosedRange<Float>?) {
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
                let B = self[l * nTime + posB]
                let A = self[l * nTime + posA]
                let a = -A/2.0 + (3.0*B)/2.0 - (3.0*C)/2.0 + D/2.0
                let b = A - (5.0*B)/2.0 + 2.0*C - D / 2.0
                let c = -A/2.0 + C/2.0
                let d = B
                
                // Fill up all missing values until point C
                for t in t..<posC {
                    // fractional position of the missing value in relation to points B and C
                    let f = Float(t - posB) / Float(posC - posB)
                    let interpolated = a*f*f*f + b*f*f + c*f + d
                    self[l * nTime + t] = bounds.map({
                        Swift.min( Swift.max(interpolated, $0.lowerBound), $0.upperBound)
                    }) ?? interpolated
                }
            }
        }
    }
    
    /// Interpolate missing values by seeking for the next valid value and perform a solar backwards interpolation
    /// Calculates the solar position backwards averages over `dt` and estimates the clearness index `kt` which is then hermite interpolated
    ///
    /// Assumes that the first value after a series of missing values is the average solar radiation for all missing steps (including self)
    /// Values after missing values will afterwards deaveraged as well
    ///
    /// The interpolation can handle mixed missing values e.g. switching from 1 to 3 and then to 6 hourly values
    ///
    /// Automatically detects data spacing. e.g. `--D--D--D` and correctly backfills
    ///
    /// If `missingValuesAreBackwardsAveraged` is set, it is assumed that values after missing data is properly averaged over the missing time-steps.
    /// `true` for weather model data. `false` for satellite data and other measurements
    mutating func interpolateInplaceSolarBackwards(time: TimerangeDt, grid: Gridable, locationRange: any RandomAccessCollection<Int>, missingValuesAreBackwardsAveraged: Bool) {
        let nTime = time.count
        precondition(nTime <= self.count)
        precondition(self.count % nTime == 0)
        
        let nLocations = self.count / nTime
        precondition(locationRange.count <= nLocations)
        precondition(nLocations % locationRange.count == 0)
        
        // If no values are missing, return and do not calculate solar coefficients
        guard let firstMissing = self[0..<nTime].firstIndex(where: {$0.isNaN}),
              let lastMissing = self[0..<nTime].lastIndex(where: {$0.isNaN}) else {
            return
        }
        /// Which range of hours solar radiation data is required
        let solarHours = firstMissing - 6 ..< lastMissing + 3
        /// Only calculate solar coefficients for this time-range
        let solarTime = TimerangeDt(
            start: time.range.lowerBound.add(solarHours.lowerBound * time.dtSeconds),
            nTime: solarHours.count,
            dtSeconds: time.dtSeconds
        )
        
        /// Make sure solar radiation does not exceed 95% extraterrestrial radiation.
        let radLimit = Zensun.solarConstant * 0.95
        
        /// At low solar inclination angles (less than 5 watts), reuse clearness factors from other timesteps
        let radMinium = 5 / Zensun.solarConstant
        
        /// solar factor, backwards averaged over dt
        let solar2d = Zensun.calculateRadiationBackwardsAveraged(grid: grid, locationRange: locationRange, timerange: solarTime)
        /// Lower bound of solar hours
        let sLow = solarHours.lowerBound

        for l in 0..<nLocations {
            let sPos = l / (nLocations / locationRange.count)
            
            /// Find the first valid value. This might be adjusted due to data spacing
            var firstValid = nTime
            for t in 0..<nTime {
                guard !self[l * nTime + t].isNaN else {
                    continue
                }
                if firstValid == nTime {
                    firstValid = t
                    continue
                }
                // 1 = no spacing
                // 2 = -D-D-D
                // 3 = --D--D--D
                firstValid = Swift.max(firstValid - (t - firstValid - 1), 0)
                break
            }
            
            for t in firstValid..<nTime {
                guard self[l * nTime + t].isNaN else {
                    continue
                }
                
                var C = Float.nan
                //var D = Float.nan
                let posB = t - 1
                var posC = 0
                // Find the first valid value for point C within the next 7 hours
                for t2 in t..<Swift.min(t + 7*3600/time.dtSeconds, nTime) {
                    let value = self[l * nTime + t2]
                    guard !value.isNaN else  {
                        continue
                    }
                    C = value
                    posC = t2
                    break
                }
                if C.isNaN {
                    // not possible to do any interpolation
                    break
                }
                let width = posC - posB
                let posA = posB - width
                let posD = posC + width
                let posAValid = posA >= 0 && posA - sLow >= 0 && !self[l * nTime + posA].isNaN
                let posDValid = posD < nTime && posD - sLow < solarTime.count && !self[l * nTime + posD].isNaN
                
                let B = self[l * nTime + posB]
                let solB = solar2d[sPos, posB - sLow]
                let solC = solar2d[sPos, posC - sLow]
                
                /// solAvgC is an average of the solar factor from posB until posC
                let solAvgC = missingValuesAreBackwardsAveraged ? solar2d[sPos, posB + 1 - sLow ..< posC + 1 - sLow].mean() : solC

                /// clearness index at point C. At low radiation levels it is impossible to estimate KT indices, set to NaN
                var ktC = solAvgC <= radMinium ? .nan : Swift.min(C / solAvgC, radLimit)
                
                /// Clearness index at point B, or use `ktC` for low radiation levels. B could be NaN if data is immediately missing in the beginning of a time-series
                var ktB = solB <= radMinium || B.isNaN ? ktC : Swift.min(B / solB, radLimit)
                
                
                var ktA, ktD: Float
                if posDValid && posAValid {
                    // 4 point Hermite kt interpolation
                    let A = self[l * nTime + posA]
                    let D = self[l * nTime + posD]
                    
                    let solA = solar2d[sPos, posA - sLow]
                    ktA = solA <= radMinium ? ktB : Swift.min(A / solA, radLimit)
                    
                    /// solD is an average of the solar factor from posC until posD
                    let solAvgD = missingValuesAreBackwardsAveraged ? solar2d[sPos, posC + 1 - sLow ..< posD + 1 - sLow].mean() : solar2d[sPos, posD - sLow]
                    ktD = solAvgD <= radMinium ? ktC : Swift.min(D / solAvgD, radLimit)
                } else {
                    // 2 point linear kt interpolation
                    ktA = ktB
                    ktD = ktC
                }
                

                if ktC.isNaN && ktB > 0 {
                    ktC = ktB
                }

                if ktC.isNaN && ktA > 0 {
                    ktB = ktA
                    ktC = ktA
                }
                
                // Especially for 6h values, aggressively try to find any KT index that works
                // As a future improvement, the clear-sky radiation could be approximated by cloud cover total as an additional input
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
                    // kt can still be NaN at night
                    self[l * nTime + t] = Swift.max(0, kt) * solar2d[sPos, t - sLow]
                }
                
                if missingValuesAreBackwardsAveraged {
                    // Deaverage point C, ktC could be NaN at night, therefore `max(0, ktC)` instead of `max(ktC, 0)`
                    self[l * nTime + posC] = Swift.max(0, ktC) * solC
                }
            }
        }
    }
}
