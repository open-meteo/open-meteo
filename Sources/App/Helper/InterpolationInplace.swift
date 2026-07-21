import Foundation

extension Array3DFastTime {
    /// Fill in missing data by interpolating using different interpolation types
    ///
    /// Important: Backwards sums like precipitation must be deaveraged before AND should already have a corrected sum. The interpolation code will simply copy the array value of the next element WITHOUT dividing by `dt`. Meaning a 6 hour precipitation value should be divided by 2 before, to preserve the sum correctly
    ///
    /// interpolate missing steps.. E.g. `DDDDDD-D-D-D-D-D`
    /// Automatically detects data spacing `--D--D--D` for deaveraging or backfilling
    mutating func interpolateInplace(type: ReaderInterpolation, time: TimerangeDt, grid: any Gridable, locationRange: any RandomAccessCollection<Int>) {
        precondition(nTime == time.count)
        data.interpolateInplace(type: type, time: time, grid: grid, locationRange: locationRange)
    }
}
extension Array2DFastTime {
    /// Fill in missing data by interpolating using different interpolation types
    ///
    /// Important: Backwards sums like precipitation must be deaveraged before AND should already have a corrected sum. The interpolation code will simply copy the array value of the next element WITHOUT dividing by `dt`. Meaning a 6 hour precipitation value should be divided by 2 before, to preserve the sum correctly
    ///
    /// interpolate missing steps.. E.g. `DDDDDD-D-D-D-D-D`
    /// Automatically detects data spacing `--D--D--D` for deaveraging or backfilling
    mutating func interpolateInplace(type: ReaderInterpolation, time: TimerangeDt, grid: any Gridable, locationRange: any RandomAccessCollection<Int>) {
        precondition(nTime == time.count)
        data.interpolateInplace(type: type, time: time, grid: grid, locationRange: locationRange)
    }
}

extension Array where Element == Float {
    /// Fill in missing data by interpolating using different interpolation types
    ///
    /// Important: Backwards sums like precipitation must be deaveraged before AND should already have a corrected sum. The interpolation code will simply copy the array value of the next element WITHOUT dividing by `dt`. Meaning a 6 hour precipitation value should be divided by 2 before, to preserve the sum correctly
    ///
    /// interpolate missing steps.. E.g. `DDDDDD-D-D-D-D-D`
    /// Automatically detects data spacing `--D--D--D` for deaveraging or backfilling
    mutating func interpolateInplace(type: ReaderInterpolation, time: TimerangeDt, grid: any Gridable, locationRange: any RandomAccessCollection<Int>) {
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
                        let A2 = (abs(previousValue - value) > 180 && value < previousValue) ? value + 360 : value
                        let B2 = (abs(previousValue - value) > 180 && value > previousValue) ? previousValue + 360 : previousValue
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
                    guard !value.isNaN else {
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
                let a = -A / 2.0 + (3.0 * B) / 2.0 - (3.0 * C) / 2.0 + D / 2.0
                let b = A - (5.0 * B) / 2.0 + 2.0 * C - D / 2.0
                let c = -A / 2.0 + C / 2.0
                let d = B

                // Fill up all missing values until point C
                for t in t..<posC {
                    // fractional position of the missing value in relation to points B and C
                    let f = Float(t - posB) / Float(posC - posB)
                    let interpolated = a * f * f * f + b * f * f + c * f + d
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
    /// If multiple perturbed runs are supplied, dimensions must be [location, member, time]
    ///
    /// The interpolation can handle mixed missing values e.g. switching from 1 to 3 and then to 6 hourly values
    ///
    /// Automatically detects data spacing. e.g. `--D--D--D` and correctly backfills
    ///
    /// If `missingValuesAreBackwardsAveraged` is set, it is assumed that values after missing data is properly averaged over the missing time-steps.
    /// `true` for weather model data. `false` for satellite data and other measurements
    mutating func interpolateInplaceSolarBackwards(time: TimerangeDt, grid: any Gridable, locationRange: any RandomAccessCollection<Int>, missingValuesAreBackwardsAveraged: Bool) {
        let nTime = time.count
        precondition(nTime <= self.count)
        precondition(self.count % nTime == 0)

        /// May contain multiple members
        let nTimeSeries = self.count / nTime
        let nLocations = locationRange.count
        let nMembers = nTimeSeries / nLocations
        precondition(nLocations <= nTimeSeries)
        precondition(nTimeSeries % nLocations == 0)
        
        // If no values are missing, return and do not calculate solar coefficients
        guard self.containsNaN() else {
            return
        }
        
        // Find first and last missing values, but start from the first valid value
        // Checks all time series
        var firstMissing = nTime
        var lastMissing = 0
        for l in 0..<nTimeSeries {
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
            for i in firstValid..<nTime {
                guard self[l * nTime + i].isNaN else {
                    continue
                }
                if i < firstMissing {
                    firstMissing = i
                }
                if i > lastMissing {
                    lastMissing = i
                }
            }
        }
        // Only first timestep is missing -> nothing to do here.
        guard firstMissing <= lastMissing else {
            return
        }
        
        let maximumMissingHours = 12
        let missingSteps = maximumMissingHours * 3600 / time.dtSeconds
        
        /// Which range of hours solar radiation data is required
        let solarHours = firstMissing - missingSteps*2 ..< lastMissing + missingSteps*2
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
        let solar2d_raw = Zensun.calculateRadiationBackwardsAveraged(grid: grid, locationRange: locationRange, timerange: solarTime)
        /// Atmospheric attenuation constant besed on Haurwitz. Standard would be -0.059. -0.09 is assuming more haze, but it matches better with reference data
        let atmosphericAttenuationConstant: Float = -0.09
        /// Estimate clear sky radiation
        let solar2d = Array2DFastTime(data: solar2d_raw.data.map {
            $0 * exp(atmosphericAttenuationConstant / $0)
        }, nLocations: solar2d_raw.nLocations, nTime: solar2d_raw.nTime)
        /// Lower bound of solar hours
        let sLow = solarHours.lowerBound

        for l in 0..<nTimeSeries {
            let sPos = l / nMembers
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
                // var D = Float.nan
                let posB = t - 1
                var posC = 0
                // Find the first valid value for point C within the next 12 hours
                for t2 in (t + 1)..<Swift.min(t + 1 + 1 + maximumMissingHours * 3600 / time.dtSeconds, nTime) {
                    let value = self[l * nTime + t2]
                    guard !value.isNaN else {
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
                let solC = solar2d[sPos, posC - sLow]

                /// solAvgC is an average of the solar factor from posB until posC
                let solAvgC = missingValuesAreBackwardsAveraged ? solar2d[sPos, posB + 1 - sLow ..< posC + 1 - sLow].mean() : solC

                /// clearness index at point C. At low radiation levels it is impossible to estimate KT indices, set to NaN
                let ktC = solAvgC <= radMinium || C <= 0 ? .nan : Swift.min(C / solAvgC, radLimit)
                
                for t in t..<posC {
                    self[l * nTime + t] = Swift.max(0, ktC) * solar2d[sPos, t - sLow]
                }
                if missingValuesAreBackwardsAveraged {
                    self[l * nTime + posC] = Swift.max(0, ktC) * solC
                }
            }
        }
    }
}
