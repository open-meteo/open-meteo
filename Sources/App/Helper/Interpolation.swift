import Foundation


extension Array where Element == Float {
    /// bounds: Apply min and max after interpolation
    func interpolate(type: ReaderInterpolation, timeOld: TimerangeDt, timeNew: TimerangeDt, latitude: Float, longitude: Float, scalefactor: Float) -> [Float] {
        switch type {
        case .backwards:
            return interpolateNearest(timeOld: timeOld, timeNew: timeNew, scalefactor: scalefactor)
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
    
    func interpolateNearest(timeOld timeLow: TimerangeDt, timeNew time: TimerangeDt, scalefactor: Float) -> [Float] {
        return time.map { t in
            let index = t.timeIntervalSince1970 / timeLow.dtSeconds - timeLow.range.lowerBound.timeIntervalSince1970 / timeLow.dtSeconds
            let fraction = Float(t.timeIntervalSince1970 % timeLow.dtSeconds) / Float(timeLow.dtSeconds)
            let A = self[index]
            let B = index+1 >= self.count ? A : self[index+1]
            return fraction < 0.5 ? A : B
        }
    }
    
    func interpolateSolarBackwards(timeOld timeLow: TimerangeDt, timeNew time: TimerangeDt, latitude: Float, longitude: Float, scalefactor: Float) -> [Float] {
        /// Like regular hermite, but interpolated via clearsky index kt derived with solar factor
        let position = RegularGrid(nx: 1, ny: 1, latMin: latitude, lonMin: longitude, dx: 1, dy: 1)
        let solarLow = Zensun.calculateRadiationBackwardsAveraged(grid: position, locationRange: 0..<1, timerange: timeLow).data
        let solar = Zensun.calculateRadiationBackwardsAveraged(grid: position, locationRange: 0..<1, timerange: time).data
        
        let dt = time.dtSeconds
        let dtOld = timeLow.dtSeconds
        let tStart = timeLow.range.lowerBound.timeIntervalSince1970
        
        return time.enumerated().map { (i, t) in
            // time need to be shifted by dtOld/2 because those are averages over time
            let (index, fraction) = (t.timeIntervalSince1970 - tStart + dtOld - dt - dtOld/2 + dt/2).moduloFraction(dtOld)
            if index < 0 {
                return .nan
            }
            
            let indexB = Swift.max(index, 0)
            let indexA = Swift.max(index-1, 0)
            let indexC = Swift.min(index+1, self.count-1)
            let indexD = Swift.min(index+2, self.count-1)
            
            if self[indexB].isNaN {
                return .nan
            }
            if solar[i] == 0 {
                return 0 // Night
            }
            
            let A = self[indexA]
            let B = self[indexB]
            let C = self[indexC]
            let D = self[indexD]
            
            let solA = solarLow[indexA]
            let solB = solarLow[indexB]
            let solC = solarLow[indexC]
            let solD = solarLow[indexD]
            
            var ktA = solA <= 0.005 ? .nan : Swift.min(A / solA, 1100)
            var ktB = solB <= 0.005 ? .nan : Swift.min(B / solB, 1100)
            var ktC = solC <= 0.005 ? .nan : Swift.min(C / solC, 1100)
            var ktD = solD <= 0.005 ? .nan : Swift.min(D / solD, 1100)
            
            if ktA.isNaN {
                ktA = !ktB.isNaN ? ktB : !ktC.isNaN ? ktC : ktD
            }
            if ktB.isNaN {
                ktB = !ktA.isNaN ? ktA : !ktC.isNaN ? ktC : ktD
            }
            if ktC.isNaN {
                ktC = !ktB.isNaN ? ktB : !ktD.isNaN ? ktD : ktA
            }
            if ktD.isNaN {
                ktD = !ktC.isNaN ? ktC : !ktB.isNaN ? ktB : ktA
            }
            
            // no interpolation
            //return (fraction < 0.5 ? ktB : ktC) * solar[i]
            
            // linear interpolation
            //return (ktB * (1-fraction) + ktC * fraction) * solar[i]
            
            let a = -ktA/2.0 + (3.0*ktB)/2.0 - (3.0*ktC)/2.0 + ktD/2.0
            let b = ktA - (5.0*ktB)/2.0 + 2.0*ktC - ktD / 2.0
            let c = -ktA/2.0 + ktC/2.0
            let d = ktB
            let h = (a*fraction*fraction*fraction + b*fraction*fraction + c*fraction + d) * solar[i]
            /// adjust it to scalefactor, otherwise interpolated values show more level of detail
            return roundf(h * scalefactor) / scalefactor
        }
    }
    
    /// Take the next value and devide it by dt. Used for precipitation, snow, etc
    func backwardsSum(timeOld timeLow: TimerangeDt, timeNew time: TimerangeDt, scalefactor: Float) -> [Float] {
        let multiply = Float(time.dtSeconds) / Float(timeLow.dtSeconds)
        return time.map { t in
            /// Take the next array element, except it it is the same timestamp
            let index = Swift.min((t.timeIntervalSince1970 - time.dtSeconds) / timeLow.dtSeconds + 1 - timeLow.range.lowerBound.timeIntervalSince1970 / timeLow.dtSeconds, self.count-1)
            /// adjust it to scalefactor, otherwise interpolated values show more level of detail
            return roundf(self[index] * multiply * scalefactor) / scalefactor
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
