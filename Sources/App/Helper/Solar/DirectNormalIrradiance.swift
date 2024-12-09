import Foundation

extension Zensun {
    /// Calculate DNI based on zenith angle
    public static func calculateInstantDNI(directRadiation: [Float], latitude: Float, longitude: Float, timerange: TimerangeDt) -> [Float] {
        var out = [Float]()
        out.reserveCapacity(directRadiation.count)
        
        for (dhi, timestamp) in zip(directRadiation, timerange) {
            // direct horizontal irradiation
            if dhi.isNaN {
                out.append(.nan)
                continue
            }
            if dhi <= 0 {
                out.append(0)
                continue
            }

            let decang = timestamp.getSunDeclination()
            let eqtime = timestamp.getSunEquationOfTime()
            
            let latsun=decang
            /// universal time
            let ut = timestamp.hourWithFraction
            let t1 = (90-latsun).degreesToRadians
            
            let lonsun = -15.0*(ut-12.0+eqtime)
            
            /// longitude of sun
            let p1 = lonsun.degreesToRadians
            let t0=(90-latitude).degreesToRadians

            /// longitude of point
            let p0 = longitude.degreesToRadians
            let zz = cos(t0)*cos(t1)+sin(t0)*sin(t1)*cos(p1-p0)
            if zz <= 0 {
                out.append(0)
                continue
            }
            let b = max(zz, cos(Float(85).degreesToRadians))
            let dni = dhi / b
            out.append(dni)
        }
        return out
    }
    
    /// Calculate DNI using super sampling
    public static func calculateBackwardsDNISupersampled(directRadiation: [Float], latitude: Float, longitude: Float, timerange: TimerangeDt, samples: Int = 60) -> [Float] {
        // Shift timerange by dt and increase time resolution
        let dtNew = timerange.dtSeconds / samples
        let timeSuperSampled = timerange.range.add(-timerange.dtSeconds + dtNew).range(dtSeconds: dtNew)
        let dhiBackwardsSuperSamled = directRadiation.interpolateSolarBackwards(timeOld: timerange, timeNew: timeSuperSampled, latitude: latitude, longitude: longitude, scalefactor: 1000)
        
        let averagedToInstant = backwardsAveragedToInstantFactor(time: timeSuperSampled, latitude: latitude, longitude: longitude)
        let dhiSuperSamled = zip(dhiBackwardsSuperSamled, averagedToInstant).map(*)
        
        let dniSuperSampled = calculateInstantDNI(directRadiation: dhiSuperSamled, latitude: latitude, longitude: longitude, timerange: timeSuperSampled)
        
        /// return instant values
        //return (0..<timerange.count).map { dhiBackwardsSuperSamled[Swift.min($0 * samples + samples, dhiBackwardsSuperSamled.count-1)] }
        
        let dni = dniSuperSampled.mean(by: samples)
        
        return dni
    }
    
    /// Calculate DNI based on zenith angle
    public static func calculateBackwardsDNI(directRadiation: [Float], latitude: Float, longitude: Float, timerange: TimerangeDt, convertToInstant: Bool = false) -> [Float] {
        //return calculateBackwardsDNISupersampled(directRadiation: directRadiation, latitude: latitude, longitude: longitude, timerange: timerange)
        
        return zip(directRadiation, timerange).map { (dhi, timestamp) in
            if dhi.isNaN {
                return .nan
            }
            if dhi <= 0 {
                return 0
            }
            
            /// DNI is typically limted to 85° zenith. We apply 5° to the parallax in addition to atmospheric refraction
            /// The parallax is then use to limit integral coefficients to sun rise/set
            let alpha = Float(0.83333 - 5).degreesToRadians

            let decang = timestamp.getSunDeclination()
            let eqtime = timestamp.getSunEquationOfTime()
            
            let latsun=decang
            /// universal time
            let ut = timestamp.hourWithFraction
            let t1 = (90-latsun).degreesToRadians
            
            let lonsun = -15.0*(ut-12.0+eqtime)
            
            /// longitude of sun
            let p1 = lonsun.degreesToRadians
            
            
            let ut0 = ut - (Float(timerange.dtSeconds)/3600)
            let lonsun0 = -15.0*(ut0-12.0+eqtime)
            
            let p10 = lonsun0.degreesToRadians
            
            let t0=(90-latitude).degreesToRadians

            /// longitude of point
            var p0 = longitude.degreesToRadians
            if p0 < p1 - .pi {
                p0 += 2 * .pi
            }
            if p0 > p1 + .pi {
                p0 -= 2 * .pi
            }

            // limit p1 and p10 to sunrise/set
            let arg = -(sin(alpha)+cos(t0)*cos(t1))/(sin(t0)*sin(t1))
            let carg = arg > 1 || arg < -1 ? .pi : acos(arg)
            let sunrise = p0 + carg
            let sunset = p0 - carg
            let p1_l = min(sunrise, p10)
            let p10_l = max(sunset, p1)
            
            // solve integral to get sun elevation dt
            // integral(cos(t0) cos(t1) + sin(t0) sin(t1) cos(p - p0)) dp = sin(t0) sin(t1) sin(p - p0) + p cos(t0) cos(t1) + constant
            let left = sin(t0) * sin(t1) * sin(p1_l - p0) + p1_l * cos(t0) * cos(t1)
            let right = sin(t0) * sin(t1) * sin(p10_l - p0) + p10_l * cos(t0) * cos(t1)
            let zzBackwards = (left-right) / (p1_l - p10_l)
            let dni = dhi / zzBackwards
            
            // Prevent possible division by zero
            // See https://github.com/open-meteo/open-meteo/discussions/395
            if zzBackwards <= 0.0001 {
                return dhi
            }
            
            /// Instant sun elevation
            let zzInstant = cos(t0)*cos(t1)+sin(t0)*sin(t1)*cos(p1-p0)
            return convertToInstant ? dni * max(zzInstant, 0) / zzBackwards : dni
        }
    }
}
