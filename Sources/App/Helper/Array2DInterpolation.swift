import Foundation

/// Which kind of interpolation to use to interpolate 3h values to 1h values
enum Interpolation2StepType {
    // Simple linear interpolation
    case linear
    // Just copy the next value
    case nearest
    // Use solar radiation interpolation
    case solar_backwards_averaged
    // Use hemite interpolation
    case hermite(bounds: ClosedRange<Float>?)
    /// Hermite interpolation but for backward averaged data. Used for latent heat flux
    case hermite_backwards_averaged(bounds: ClosedRange<Float>?)
}

extension Array2DFastTime {
    /// Interpolate missing values for 1 hourly data that only has 3 hourly data at `positions`.
    mutating func interpolate2Steps(type: Interpolation2StepType, positions: [Int], grid: Gridable, run: Timestamp, dtSeconds: Int) {
        switch type {
        case .linear:
            interpolate2StepsLinear(positions: positions)
        case .nearest:
            interpolate2StepsNearest(positions: positions)
        case .solar_backwards_averaged:
            interpolate2StepsSolarBackwards(positions: positions, grid: grid, run: run, dtSeconds: dtSeconds)
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
                for hour in start+1 ..< start+slidingWidth {
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
                for hour in stride(from: start + slidingWidth - 1, through: start + 1, by: -1) {
                    let current = self[l, hour]
                    let previous = self[l, hour-1]
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
    mutating func interpolate2StepsSolarBackwards(positions: [Int], grid: Gridable, run: Timestamp, dtSeconds: Int) {
        // Solar backwards averages data. Data needs to be deaveraged before
        // First the clear sky index KT is calaculated (KT based on extraterrestrial radiation)
        // clearsky index is hermite interpolated and then back to actual radiation
        
        /// Which range of hours solar radiation data is required
        let solarHours = positions.minAndMax().map { $0.min - 4 ..< $0.max + 7 } ?? 0..<0
        let solarTime = TimerangeDt(start: run.add(solarHours.lowerBound * dtSeconds), nTime: solarHours.count, dtSeconds: dtSeconds)
        
        /// Instead of caiculating solar radiation for the entire grid, itterate through a smaller grid portion
        let nx = grid.nx
        let byY = 1
        for cy in 0..<grid.ny/byY+1 {
            let yrange = cy*byY ..< min((cy+1)*byY, grid.ny)
            let locationRange = yrange.lowerBound * nx ..< yrange.upperBound * nx
            /// solar factor, backwards averaged over dt
            let solar2d = Zensun.calculateRadiationBackwardsAveraged(grid: grid, timerange: solarTime, yrange: yrange)
            
            for l in locationRange {
                for hour in positions {
                    let sHour = hour - solarHours.lowerBound
                    let sLocation = l - locationRange.lowerBound
                    // point C and D are still 3 h averages
                    let solC1 = solar2d[sLocation, sHour + 0]
                    let solC2 = solar2d[sLocation, sHour + 1]
                    let solC3 = solar2d[sLocation, sHour + 2]
                    let solC = (solC1 + solC2 + solC3) / 3
                    // At low radiaiton levels it is impossible to estimate KT indices
                    let C = solC <= 0.005 ? 0 : min(self[l, hour+2] / solC, 1100)
                    
                    let solB = solar2d[sLocation, sHour - 1]
                    let B = solB <= 0.005 ? 0 : min(self[l, hour-1] / solB, 1100)
                    
                    let solA = solar2d[sLocation, sHour - 4]
                    let A = solA <= 0.005 ? 0 : hour-4 < 0 ? B : min((self[l, hour-4] / solA), 1100)
                    
                    let solD1 = solar2d[sLocation, sHour + 3]
                    let solD2 = solar2d[sLocation, sHour + 4]
                    let solD3 = solar2d[sLocation, sHour + 5]
                    let solD = (solD1 + solD2 + solD3) / 3
                    let D = solD <= 0.005 ? 0 : hour+4 >= nTime ? C : min((self[l, hour+5] / solD), 1100)
                    
                    let a = -A/2.0 + (3.0*B)/2.0 - (3.0*C)/2.0 + D/2.0
                    let b = A - (5.0*B)/2.0 + 2.0*C - D / 2.0
                    let c = -A/2.0 + C/2.0
                    let d = B
                    
                    self[l, hour] = (a*0.3*0.3*0.3 + b*0.3*0.3 + c*0.3 + d) * solC1
                    self[l, hour+1] = (a*0.6*0.6*0.6 + b*0.6*0.6 + c*0.6 + d) * solC2
                    self[l, hour+2] = C * solC3
                }
            }
        }
    }
}
