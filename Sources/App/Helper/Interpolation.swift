import Foundation


extension Array where Element == Float {
    /// bounds: Apply min and max after interpolation
    func interpolate(type: ReaderInterpolation, timeOld: TimerangeDt, timeNew: TimerangeDt, latitude: Float, longitude: Float, scalefactor: Float) -> [Float] {
        switch type {
        case .linear:
            return interpolateLinear(timeOld: timeOld, timeNew: timeNew, scalefactor: scalefactor)
        case .hermite(let bounds):
            return interpolateHermite(timeOld: timeOld, timeNew: timeNew, scalefactor: scalefactor, bounds: bounds)
        case .solar_backwards_averaged:
            return interpolateSolarBackwards(timeOld: timeOld, timeNew: timeNew, latitude: latitude, longitude: longitude, scalefactor: scalefactor)
        case .backwards_sum:
            return backwardsSum(timeOld: timeOld, timeNew: timeNew, scalefactor: scalefactor)
        }
    }
    
    func interpolateSolarBackwards(timeOld timeLow: TimerangeDt, timeNew time: TimerangeDt, latitude: Float, longitude: Float, scalefactor: Float) -> [Float] {
        /// Like regular hermite, but interpolated via clearsky index kt derived with solar factor
        let position = RegularGrid(nx: 1, ny: 1, latMin: latitude, lonMin: longitude, dx: 1, dy: 1)
        let solarLow = Zensun.calculateRadiationBackwardsAveraged(grid: position, locationRange: 0..<1, timerange: timeLow).data
        let solar = Zensun.calculateRadiationBackwardsAveraged(grid: position, locationRange: 0..<1, timerange: time).data
        return time.enumerated().map { (i, t) in
            let index = t.timeIntervalSince1970 / timeLow.dtSeconds - timeLow.range.lowerBound.timeIntervalSince1970 / timeLow.dtSeconds
            let fraction = Float(t.timeIntervalSince1970 % timeLow.dtSeconds) / Float(timeLow.dtSeconds)
            
            let indexB = Swift.max(index, 0)
            let indexA = Swift.max(index-1, 0)
            let indexC = Swift.min(index+1, self.count-1)
            let indexD = Swift.min(index+2, self.count-1)
            
            if self[indexB].isNaN {
                return .nan
            }
            // At low radiaiton levels it is impossible to estimate KT indices
            if solarLow[indexB] < 0.005 {
                return 0
            }
            
            let B = self[indexB] / solarLow[indexB]
            let A = self[indexA].isNaN ? B : (solarLow[indexA] <= 0.005 ? B : self[indexA] / solarLow[indexA])
            let C = self[indexC].isNaN ? B : (solarLow[indexC] <= 0.005 ? B : self[indexC] / solarLow[indexC])
            let D = self[indexD].isNaN ? C : (solarLow[indexD] <= 0.005 ? C : self[indexD] / solarLow[indexD])
            
            // linear
            //let h = (B * (1-fraction) + C * fraction) * solar[i]
            
            let a = -A/2.0 + (3.0*B)/2.0 - (3.0*C)/2.0 + D/2.0
            let b = A - (5.0*B)/2.0 + 2.0*C - D / 2.0
            let c = -A/2.0 + C/2.0
            let d = B
            let h = (a*fraction*fraction*fraction + b*fraction*fraction + c*fraction + d) * solar[i]
            /// adjust it to scalefactor, otherwise interpolated values show more level of detail
            return roundf(h * scalefactor) / scalefactor
        }
    }
    
    func backwardsSum(timeOld timeLow: TimerangeDt, timeNew time: TimerangeDt, scalefactor: Float) -> [Float] {
        let multiply = Float(time.dtSeconds) / Float(timeLow.dtSeconds)
        return time.map { t in
            let index = t.timeIntervalSince1970 / timeLow.dtSeconds - timeLow.range.lowerBound.timeIntervalSince1970 / timeLow.dtSeconds
            let fraction = Float(t.timeIntervalSince1970 % timeLow.dtSeconds) / Float(timeLow.dtSeconds)
            let A = self[index]
            let B = index+1 >= self.count ? A : self[index+1]
            let h = A * (1-fraction) + B * fraction
            /// adjust it to scalefactor, otherwise interpolated values show more level of detail
            return roundf(h * multiply * scalefactor) / scalefactor
        }
    }
    
    func interpolateLinear(timeOld timeLow: TimerangeDt, timeNew time: TimerangeDt, scalefactor: Float) -> [Float] {
        return time.map { t in
            let index = t.timeIntervalSince1970 / timeLow.dtSeconds - timeLow.range.lowerBound.timeIntervalSince1970 / timeLow.dtSeconds
            let fraction = Float(t.timeIntervalSince1970 % timeLow.dtSeconds) / Float(timeLow.dtSeconds)
            let A = self[index]
            let B = index+1 >= self.count ? A : self[index+1]
            let h = A * (1-fraction) + B * fraction
            /// adjust it to scalefactor, otherwise interpolated values show more level of detail
            return roundf(h * scalefactor) / scalefactor
        }
    }
    
    func interpolateHermite(timeOld timeLow: TimerangeDt, timeNew time: TimerangeDt, scalefactor: Float, bounds: ClosedRange<Float>?) -> [Float] {
        return time.map { t in
            let index = t.timeIntervalSince1970 / timeLow.dtSeconds - timeLow.range.lowerBound.timeIntervalSince1970 / timeLow.dtSeconds
            let fraction = Float(t.timeIntervalSince1970 % timeLow.dtSeconds) / Float(timeLow.dtSeconds)
            
            let B = self[index]
            let A = index-1 < 0 ? B : self[index-1].isNaN ? B : self[index-1]
            let C = index+1 >= self.count ? B : self[index+1].isNaN ? B : self[index+1]
            let D = index+2 >= self.count ? C : self[index+2].isNaN ? B : self[index+2]
            let a = -A/2.0 + (3.0*B)/2.0 - (3.0*C)/2.0 + D/2.0
            let b = A - (5.0*B)/2.0 + 2.0*C - D / 2.0
            let c = -A/2.0 + C/2.0
            let d = B
            let h = a*fraction*fraction*fraction + b*fraction*fraction + c*fraction + d
            /// adjust it to scalefactor, otherwise interpolated values show more level of detail
            let hScaled = roundf(h * scalefactor) / scalefactor
            if let bounds = bounds {
                return Swift.min(Swift.max(hScaled, bounds.lowerBound), bounds.upperBound)
            }
            return hScaled
        }
    }
}
