//
//  File.swift
//  
//
//  Created by Patrick Zippenfenig on 17.01.2024.
//

import Foundation

extension Zensun {
    /// Calculate GTI for an array based on tilt and azimuth
    /// Azimuth 0°  south, -90° = east, +90° = west
    /// Tilt should be from 0° horizontal to 90° vertical
    /// Direct and diffuse radiation must be backwards averaged over `time.dtSeconds`
    /// For convenience, if `convertBackwardsToInstant` is set, output is converted to instantanous values
    public static func calculateTiltedIrradiance(directRadiation: [Float], diffuseRadiation: [Float], tilt: Float, azimuth arrayAzimuth: Float, latitude: Float, longitude: Float, timerange: TimerangeDt, convertBackwardsToInstant: Bool) -> [Float] {
        //return calculateBackwardsDNISupersampled(directRadiation: directRadiation, latitude: latitude, longitude: longitude, timerange: timerange)
        
        return zip(zip(directRadiation, diffuseRadiation), timerange).map { (arg0, timestamp) in
            let (direct, diffuse) = arg0
            if direct.isNaN || diffuse.isNaN {
                return .nan
            }
            if direct + diffuse <= 0 {
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
            
            //let xx = sin(t1) * sin(p1-p0)
            let xxBackwards = (sin(t1) * (-cos(p1_l-p0)) - sin(t1) * (-cos(p10_l-p0))) / (p1_l - p10_l)
            
            //let yy = sin(t0) * cos(t1) - cos(t0) * sin(t1) * cos(p1-p0)
            let yyLeft = p1_l * sin(t0) * cos(t1) - cos(t0) * sin(t1) * sin(p1_l - p0)
            let yyRight = p10_l * sin(t0) * cos(t1) - cos(t0) * sin(t1) * sin(p10_l - p0)
            let yyBackwards = (yyLeft-yyRight) / (p1_l - p10_l)
            
            // Solar zenith and azimuth averaged over the dt (mostly 1h)
            let zenith = acos(zzBackwards) // radians
            let azimuth = atan2(xxBackwards, yyBackwards)
            
            // If azimuth is NaN, use solar azimuth => panel tracking left/right axis
            let arrayAzimuthRadians = arrayAzimuth.isNaN ? (azimuth + .pi) : arrayAzimuth.degreesToRadians
            // If tilt is NaN, use zenith -> Panel tracking top/down axis
            let tiltRadians = tilt.isNaN ? (zenith) : tilt.degreesToRadians
            
            let skyViewFactor = (1+cos(tiltRadians)) / 2
            // Simple isotropic sky model, may be upgraded later to sandia or hay and davis model
            let moduleDiffuse = skyViewFactor * diffuse
            
            let albedo: Float = 0.2
            let moduleAlbedo = (direct + diffuse) * albedo * (1-skyViewFactor)
            
            // Prevent possible division by zero
            // See https://github.com/open-meteo/open-meteo/discussions/395
            let dni = zzBackwards <= 0.0001 ? direct : direct / zzBackwards
            
            let angleOfIncidenceCosine = max(cos(zenith)*cos(tiltRadians) + sin(zenith)*sin(tiltRadians)*cos(azimuth - .pi - arrayAzimuthRadians), 0)
            
            let moduleDirect = dni * angleOfIncidenceCosine
            
            let gti = moduleDirect + moduleDiffuse + moduleAlbedo
            
            if convertBackwardsToInstant {
                let zzInstant = cos(t0)*cos(t1)+sin(t0)*sin(t1)*cos(p1-p0)
                if zzBackwards <= 0 || zzInstant <= 0 {
                    return 0
                }
                return gti * (zzInstant / zzBackwards)
            }
            return gti
        }
    }
}
