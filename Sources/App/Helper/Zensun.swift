import Foundation


/// Solar position calculations based on zensun
/// See https://gist.github.com/sangholee1990/eb3d997a9b28ace2dbcab6a45fd7c178#file-visualization_using_sun_position-pro-L306
struct Zensun {
    /// Watt per square meter
    static public let solarConstant = Float(1367.7)
    
    /// eqation of time
    static let eqt: [Float] = [ -3.23, -5.49, -7.60, -9.48, -11.09, -12.39, -13.34, -13.95, -14.23, -14.19, -13.85, -13.22, -12.35, -11.26, -10.01, -8.64, -7.18, -5.67, -4.16, -2.69, -1.29, -0.02, 1.10, 2.05, 2.80, 3.33, 3.63, 3.68, 3.49, 3.09, 2.48, 1.71, 0.79, -0.24, -1.33, -2.41, -3.45, -4.39, -5.20, -5.84, -6.28, -6.49, -6.44, -6.15, -5.60, -4.82, -3.81, -2.60, -1.19, 0.36, 2.03, 3.76, 5.54, 7.31, 9.04, 10.69, 12.20, 13.53, 14.65, 15.52, 16.12, 16.41, 16.36, 15.95, 15.19, 14.09, 12.67, 10.93, 8.93, 6.70, 4.32, 1.86, -0.62, -3.23]

    /// declination
    static let dec: [Float] = [-23.06, -22.57, -21.91, -21.06, -20.05, -18.88, -17.57, -16.13, -14.57, -12.91, -11.16, -9.34, -7.46, -5.54, -3.59, -1.62, 0.36, 2.33, 4.28, 6.19, 8.06, 9.88, 11.62, 13.29, 14.87, 16.34, 17.70, 18.94, 20.04, 21.00, 21.81, 22.47, 22.95, 23.28, 23.43, 23.40, 23.21, 22.85, 22.32, 21.63, 20.79, 19.80, 18.67, 17.42, 16.05, 14.57, 13.00, 11.33, 9.60, 7.80, 5.95, 4.06, 2.13, 0.19, -1.75, -3.69, -5.62, -7.51, -9.36, -11.16, -12.88, -14.53, -16.07, -17.50, -18.81, -19.98, -20.99, -21.85, -22.52, -23.02, -23.33, -23.44, -23.35, -23.06]
    
    /// Calculate sun rise and set times
    public static func calculateSunRiseSet(timeRange: Range<Timestamp>, lat: Float, lon: Float, utcOffsetSeconds: Int) -> (rise: [Timestamp], set: [Timestamp]) {
        var rise = [Timestamp]()
        var set = [Timestamp]()
        let nDays = (timeRange.upperBound.timeIntervalSince1970 - timeRange.lowerBound.timeIntervalSince1970) / 86400
        rise.reserveCapacity(nDays)
        set.reserveCapacity(nDays)
        for time in timeRange.stride(dtSeconds: 86400) {
            /// fractional day number with 12am 1jan = 1
            let tt = Float(((time.add(12*3600).timeIntervalSince1970 % 31_557_600) + 31_557_600) % 31_557_600) / 86400 + 1.0 + 0.5
            
            let fraction = (tt - 1).truncatingRemainder(dividingBy: 5) / 5
            let eqtime = eqt.interpolateLinear(Int(tt - 1)/5, fraction) / 60
            let decang = dec.interpolateLinear(Int(tt - 1)/5, fraction)
            let latsun = decang
            
            /// colatitude of sun
            let t1 = (90-latsun).degreesToRadians

            /// earth-sun distance in AU
            let rsun = 1-0.01673*cos(0.9856*(tt-2).degreesToRadians)
            
            /// solar disk half-angle
            let angsun = 6.96e10/(1.5e13*rsun) + Float(0.83333).degreesToRadians
            
            /// universal time of noon
            let noon = 12-lon/15

            /// colatitude of point
            let t0 = (90-lat).degreesToRadians

            let arg = -(sin(angsun)+cos(t0)*cos(t1))/(sin(t0)*sin(t1))

            guard arg <= 1 && arg >= -1 else {
                if arg > 1 {
                    // polar night
                    rise.append(Timestamp(0))
                    set.append(Timestamp(0))
                } else {
                    // polar day
                    rise.append(Timestamp(0))
                    set.append(Timestamp(0))
                }
                continue
            }

            let dtime = Foundation.acos(arg)/(Float(15).degreesToRadians)
            let sunrise = noon-dtime-eqtime
            let sunset = noon+dtime-eqtime
            
            rise.append(time.add(utcOffsetSeconds + Int(sunrise*3600)))
            set.append(time.add(utcOffsetSeconds + Int(sunset*3600)))
        }
        assert(rise.count == nDays)
        assert(set.count == nDays)
        return (rise, set)
    }

    /// Calculate a 2d (space and time) solar factor field for interpolation to hourly data. Data is time oriented!
    /// This function is performance critical for updates. This explains redundant code.
    public static func calculateRadiationBackwardsAveraged(grid: Gridable, timerange: TimerangeDt, yrange: Range<Int>? = nil) -> Array2DFastTime {
        let yrange = yrange ?? 0..<grid.ny
        var out = Array2DFastTime(nLocations: yrange.count * grid.nx, nTime: timerange.count)
                
        for (t, timestamp) in timerange.enumerated() {
            /// fractional day number with 12am 1jan = 1
            let tt = Float(((timestamp.timeIntervalSince1970 % 31_557_600) + 31_557_600) % 31_557_600) / 86400 + 1.0 + 0.5

            let fraction = (tt - 1).truncatingRemainder(dividingBy: 5) / 5
            let eqtime = eqt.interpolateLinear(Int(tt - 1)/5, fraction) / 60
            let decang = dec.interpolateLinear(Int(tt - 1)/5, fraction)
            
            /// earth-sun distance in AU
            let rsun = 1-0.01673*cos(0.9856*(tt-2).degreesToRadians)
            
            /// solar disk half-angle
            let angsun = 6.96e10/(1.5e13*rsun) + Float(0.83333).degreesToRadians
            
            let latsun=decang
            /// universal time
            let ut = Float(((timestamp.timeIntervalSince1970 % 86400) + 86400) % 86400) / 3600
            let t1 = (90-latsun).degreesToRadians
            
            let lonsun = -15.0*(ut-12.0+eqtime)
            
            /// longitude of sun
            let p1 = lonsun.degreesToRadians
            
            let ut0 = ut - (Float(timerange.dtSeconds)/3600)
            let lonsun0 = -15.0*(ut0-12.0+eqtime)
            
            let p10 = lonsun0.degreesToRadians
            
            var l = 0
            for indexY in yrange {
                for indexX in 0..<grid.nx {
                    let (lat,lon) = grid.getCoordinates(gridpoint: indexY * grid.nx + indexX)
                    let t0=(90-lat).degreesToRadians                     // colatitude of point

                    /// longitude of point
                    var p0 = lon.degreesToRadians
                    if p0 < p1 - .pi {
                        p0 += 2 * .pi
                    }
                    if p0 > p1 + .pi {
                        p0 -= 2 * .pi
                    }
                    
                    // limit p1 and p10 to sunrise/set
                    let arg = -(sin(angsun)+cos(t0)*cos(t1))/(sin(t0)*sin(t1))
                    let carg = arg > 1 || arg < -1 ? .pi : acos(arg)
                    let sunrise = p0 + carg
                    let sunset = p0 - carg
                    let p1_l = min(sunrise, p10)
                    let p10_l = max(sunset, p1)
                    
                    // solve integral to get sun elevation dt
                    // integral(cos(t0) cos(t1) + sin(t0) sin(t1) cos(p - p0)) dp = sin(t0) sin(t1) sin(p - p0) + p cos(t0) cos(t1) + constant
                    let left = sin(t0) * sin(t1) * sin(p1_l - p0) + p1_l * cos(t0) * cos(t1)
                    let right = sin(t0) * sin(t1) * sin(p10_l - p0) + p10_l * cos(t0) * cos(t1)
                    /// sun elevation (`zz = sin(alpha)`)
                    let zz = (left-right) / (p1_l - p10_l)
                    
                    out[l, t] = zz <= 0 ? 0 : zz / (rsun*rsun)
                    l += 1
                }
            }
        }
        return out
    }
    
    
    /// Calculate a 2d (space and time) solar factor field for interpolation to hourly data. Data is time oriented!
    /// To get zenith angle, use `acos`
    public static func calculateSunElevationBackwards(grid: Gridable, timerange: TimerangeDt, yrange: Range<Int>? = nil) -> Array2DFastTime {
        let yrange = yrange ?? 0..<grid.ny
        var out = Array2DFastTime(nLocations: yrange.count * grid.nx, nTime: timerange.count)
                
        for (t, timestamp) in timerange.enumerated() {
            /// fractional day number with 12am 1jan = 1
            let tt = Float(((timestamp.timeIntervalSince1970 % 31_557_600) + 31_557_600) % 31_557_600) / 86400 + 1.0 + 0.5

            let fraction = (tt - 1).truncatingRemainder(dividingBy: 5) / 5
            let eqtime = eqt.interpolateLinear(Int(tt - 1)/5, fraction) / 60
            let decang = dec.interpolateLinear(Int(tt - 1)/5, fraction)
            
            /// earth-sun distance in AU
            let rsun = 1-0.01673*cos(0.9856*(tt-2).degreesToRadians)
            
            /// solar disk half-angle
            let angsun = 6.96e10/(1.5e13*rsun) + Float(0.83333).degreesToRadians
            
            let latsun=decang
            /// universal time
            let ut = Float(((timestamp.timeIntervalSince1970 % 86400) + 86400) % 86400) / 3600
            let t1 = (90-latsun).degreesToRadians
            
            let lonsun = -15.0*(ut-12.0+eqtime)
            
            /// longitude of sun
            let p1 = lonsun.degreesToRadians
            
            let ut0 = ut - (Float(timerange.dtSeconds)/3600)
            let lonsun0 = -15.0*(ut0-12.0+eqtime)
            
            let p10 = lonsun0.degreesToRadians
            
            var l = 0
            for indexY in yrange {
                for indexX in 0..<grid.nx {
                    let (lat,lon) = grid.getCoordinates(gridpoint: indexY * grid.nx + indexX)
                    let t0=(90-lat).degreesToRadians                     // colatitude of point

                    /// longitude of point
                    var p0 = lon.degreesToRadians
                    if p0 < p1 - .pi {
                        p0 += 2 * .pi
                    }
                    if p0 > p1 + .pi {
                        p0 -= 2 * .pi
                    }
                    
                    // limit p1 and p10 to sunrise/set
                    let arg = -(sin(angsun)+cos(t0)*cos(t1))/(sin(t0)*sin(t1))
                    let carg = arg > 1 || arg < -1 ? .pi : acos(arg)
                    let sunrise = p0 + carg
                    let sunset = p0 - carg
                    let p1_l = min(sunrise, p10)
                    let p10_l = max(sunset, p1)
                    
                    // solve integral to get sun elevation dt
                    // integral(cos(t0) cos(t1) + sin(t0) sin(t1) cos(p - p0)) dp = sin(t0) sin(t1) sin(p - p0) + p cos(t0) cos(t1) + constant
                    let left = sin(t0) * sin(t1) * sin(p1_l - p0) + p1_l * cos(t0) * cos(t1)
                    let right = sin(t0) * sin(t1) * sin(p10_l - p0) + p10_l * cos(t0) * cos(t1)
                    /// sun elevation (`zz = sin(alpha)`)
                    let zz = (left-right) / (p1_l - p10_l)
                    
                    out[l, t] = zz
                    l += 1
                }
            }
        }
        return out
    }
    
    
    /// Calculate a 2d (space and time) solar factor field for interpolation to hourly data. Data is space oriented!
    public static func calculateRadiationInstant(grid: Gridable, timerange: TimerangeDt, yrange: Range<Int>? = nil) -> [Float] {
        var out = [Float]()
        let yrange = yrange ?? 0..<grid.ny
        out.reserveCapacity(yrange.count * grid.nx * timerange.count)
                
        for timestamp in timerange {
            /// fractional day number with 12am 1jan = 1
            let tt = Float(((timestamp.timeIntervalSince1970 % 31_557_600) + 31_557_600) % 31_557_600) / 86400 + 1.0 + 0.5
            let rsun=1-0.01673*cos(0.9856*(tt-2).degreesToRadians)
            let rsun_square = rsun*rsun

            let fraction = (tt - 1).truncatingRemainder(dividingBy: 5) / 5
            let eqtime = eqt.interpolateLinear(Int(tt - 1)/5, fraction) / 60
            let decang = dec.interpolateLinear(Int(tt - 1)/5, fraction)

            let latsun=decang
            let ut = Float(((timestamp.timeIntervalSince1970 % 86400) + 86400) % 86400) / 3600
            let t1 = (90-latsun).degreesToRadians
            
            let lonsun = -15.0*(ut-12.0+eqtime)
            let p1 = lonsun.degreesToRadians
            
            for indexY in yrange {
                for indexX in 0..<grid.nx {
                    let (lat,lon) = grid.getCoordinates(gridpoint: indexY * grid.nx + indexX)
                    
                    let t0 = (90-lat).degreesToRadians
                    let p0 = lon.degreesToRadians
                    /// sun elevation (`zz = sin(alpha)`)
                    let zz = cos(t0)*cos(t1)+sin(t0)*sin(t1)*cos(p1-p0)
                    let solfac = zz/rsun_square
                    out.append(solfac)
                }
            }
        }
        return out
    }
    
    /// Calculate DNI using super sampling
    public static func calculateBackwardsDNISupersampled(directRadiation: [Float], latitude: Float, longitude: Float, timerange: TimerangeDt, samples: Int = 60) -> [Float] {
        // Shit timerange by dt and increase time resolution
        let timeSuperSampled = timerange.range.add(-timerange.dtSeconds).range(dtSeconds: timerange.dtSeconds / samples)
        let dhiBackwardsSuperSamled = directRadiation.interpolateSolarBackwards(timeOld: timerange, timeNew: timeSuperSampled, latitude: latitude, longitude: longitude, scalefactor: 1)
        
        let averagedToInstant = backwardsAveragedToInstantFactor(time: timeSuperSampled, latitude: latitude, longitude: longitude)
        let dhiSuperSamled = zip(dhiBackwardsSuperSamled, averagedToInstant).map(*)
        
        let dniSuperSampled = calculateInstantDNI(directRadiation: dhiSuperSamled, latitude: latitude, longitude: longitude, timerange: timeSuperSampled)
        
        /// return instant values
        //return (0..<timerange.count).map { dhiBackwardsSuperSamled[Swift.min($0 * samples + samples, dhiBackwardsSuperSamled.count-1)] }
        
        return dniSuperSampled.mean(by: samples)
    }
    
    /// Calculate DNI based on zenith angle
    public static func calculateBackwardsDNI(directRadiation: [Float], latitude: Float, longitude: Float, timerange: TimerangeDt) -> [Float] {
        return calculateBackwardsDNISupersampled(directRadiation: directRadiation, latitude: latitude, longitude: longitude, timerange: timerange)
        
        // For some reason, the code below deaverages data!
        // Same issue with taylor series expansion
        
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
            
            /// fractional day number with 12am 1jan = 1
            let tt = Float(((timestamp.timeIntervalSince1970 % 31_557_600) + 31_557_600) % 31_557_600) / 86400 + 1.0 + 0.5

            let fraction = (tt - 1).truncatingRemainder(dividingBy: 5) / 5
            let eqtime = eqt.interpolateLinear(Int(tt - 1)/5, fraction) / 60
            let decang = dec.interpolateLinear(Int(tt - 1)/5, fraction)
            
            /// earth-sun distance in AU
            let rsun = 1-0.01673*cos(0.9856*(tt-2).degreesToRadians)
            
            /// solar disk half-angle
            let angsun = 6.96e10/(1.5e13*rsun) + Float(0.83333).degreesToRadians
            
            let latsun=decang
            /// universal time
            let ut = Float(((timestamp.timeIntervalSince1970 % 86400) + 86400) % 86400) / 3600
            let t1 = (90-latsun).degreesToRadians
            
            let lonsun = -15.0*(ut-12.0+eqtime)
            
            /// longitude of sun
            let p1 = lonsun.degreesToRadians
            
            let ut0 = ut - (Float(timerange.dtSeconds)/3600)
            let lonsun0 = -15.0*(ut0-12.0+eqtime)
            
            let p10 = lonsun0.degreesToRadians
            
            let t0=(90-latitude).degreesToRadians                     // colatitude of point

            /// longitude of point
            var p0 = longitude.degreesToRadians
            if p0 < p1 - .pi {
                p0 += 2 * .pi
            }
            if p0 > p1 + .pi {
                p0 -= 2 * .pi
            }

            // limit p1 and p10 to sunrise/set
            let arg = -(sin(angsun)+cos(t0)*cos(t1))/(sin(t0)*sin(t1))
            let carg = arg > 1 || arg < -1 ? .pi : acos(arg)
            let sunrise = p0 + carg
            let sunset = p0 - carg
            let p1_l = min(sunrise, p10)
            let p10_l = max(sunset, p1)
            
            // solve integral to get sun elevation dt
            // integral(cos(t0) cos(t1) + sin(t0) sin(t1) cos(p - p0)) dp = sin(t0) sin(t1) sin(p - p0) + p cos(t0) cos(t1) + constant
            let left = sin(t0) * sin(t1) * sin(p1_l - p0) + p1_l * cos(t0) * cos(t1)
            let right = sin(t0) * sin(t1) * sin(p10_l - p0) + p10_l * cos(t0) * cos(t1)
            /// sun elevation (`zz = sin(alpha) = cos(zenith)`)
            let zzBackwards = (left-right) / (p1_l - p10_l)
            
            // The 85° limit should be applied before the integral is calculated, but there seems not to be an easy mathematical solution
            //let b = max(zz), cos(Float(85).degreesToRadians))
            //let zenith = 90 - asin(zzBackwards).radiansToDegrees
            let dni = dhi / zzBackwards
            out.append(dni)
        }
        return out
    }
    
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
            
            /// fractional day number with 12am 1jan = 1
            let tt = Float(((timestamp.timeIntervalSince1970 % 31_557_600) + 31_557_600) % 31_557_600) / 86400 + 1.0 + 0.5

            let fraction = (tt - 1).truncatingRemainder(dividingBy: 5) / 5
            let eqtime = eqt.interpolateLinear(Int(tt - 1)/5, fraction) / 60
            let decang = dec.interpolateLinear(Int(tt - 1)/5, fraction)
            
            let latsun=decang
            /// universal time
            let ut = Float(((timestamp.timeIntervalSince1970 % 86400) + 86400) % 86400) / 3600
            let t1 = (90-latsun).degreesToRadians
            
            let lonsun = -15.0*(ut-12.0+eqtime)
            
            /// longitude of sun
            let p1 = lonsun.degreesToRadians
            
            let t0=(90-latitude).degreesToRadians                     // colatitude of point

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
    
    /// Watt per square meter
    public static func extraTerrestrialRadiationBackwards(latitude: Float, longitude: Float, timerange: TimerangeDt) -> [Float] {
        // compute hourly mean radiation flux
        return Zensun.calculateRadiationBackwardsAveraged(grid: RegularGrid(nx: 1, ny: 1, latMin: latitude, lonMin: longitude, dx: 1, dy: 1), timerange: timerange).data.map {
            $0 * solarConstant
        }
    }
    
    public static func extraTerrestrialRadiationInstant(latitude: Float, longitude: Float, timerange: TimerangeDt) -> [Float] {
        // compute hourly mean radiation flux
        return Zensun.calculateRadiationInstant(grid: RegularGrid(nx: 1, ny: 1, latMin: latitude, lonMin: longitude, dx: 1, dy: 1), timerange: timerange).map {
            max($0 * solarConstant, 0)
        }
    }
    
    /// Calculate scaling factor from backwards to instant radiation factor
    public static func backwardsAveragedToInstantFactor(time: TimerangeDt, latitude: Float, longitude: Float) -> [Float] {
        return time.map { timestamp in
            /// fractional day number with 12am 1jan = 1
            let tt = Float(((timestamp.timeIntervalSince1970 % 31_557_600) + 31_557_600) % 31_557_600) / 86400 + 1.0 + 0.5

            let fraction = (tt - 1).truncatingRemainder(dividingBy: 5) / 5
            let eqtime = eqt.interpolateLinear(Int(tt - 1)/5, fraction) / 60
            let decang = dec.interpolateLinear(Int(tt - 1)/5, fraction)
            
            /// earth-sun distance in AU
            let rsun = 1-0.01673*cos(0.9856*(tt-2).degreesToRadians)
            
            /// solar disk half-angle
            let angsun = 6.96e10/(1.5e13*rsun) + Float(0.83333).degreesToRadians
            
            let latsun=decang
            /// universal time
            let ut = Float(((timestamp.timeIntervalSince1970 % 86400) + 86400) % 86400) / 3600
            let t1 = (90-latsun).degreesToRadians
            
            let lonsun = -15.0*(ut-12.0+eqtime)
            
            /// longitude of sun
            let p1 = lonsun.degreesToRadians
            
            let ut0 = ut - (Float(time.dtSeconds)/3600)
            let lonsun0 = -15.0*(ut0-12.0+eqtime)
            
            let p10 = lonsun0.degreesToRadians
            
            let t0=(90-latitude).degreesToRadians                     // colatitude of point

            /// longitude of point
            var p0 = longitude.degreesToRadians
            if p0 < p1 - .pi {
                p0 += 2 * .pi
            }
            if p0 > p1 + .pi {
                p0 -= 2 * .pi
            }

            // limit p1 and p10 to sunrise/set
            let arg = -(sin(angsun)+cos(t0)*cos(t1))/(sin(t0)*sin(t1))
            let carg = arg > 1 || arg < -1 ? .pi : acos(arg)
            let sunrise = p0 + carg
            let sunset = p0 - carg
            let p1_l = min(sunrise, p10)
            let p10_l = max(sunset, p1)
            
            // solve integral to get sun elevation dt
            // integral(cos(t0) cos(t1) + sin(t0) sin(t1) cos(p - p0)) dp = sin(t0) sin(t1) sin(p - p0) + p cos(t0) cos(t1) + constant
            let left = sin(t0) * sin(t1) * sin(p1_l - p0) + p1_l * cos(t0) * cos(t1)
            let right = sin(t0) * sin(t1) * sin(p10_l - p0) + p10_l * cos(t0) * cos(t1)
            /// sun elevation (`zz = sin(alpha)`)
            let zzBackwards = (left-right) / (p1_l - p10_l)
            
            /// Instant sun elevation
            let zzInstant = cos(t0)*cos(t1)+sin(t0)*sin(t1)*cos(p1-p0)
            if zzBackwards <= 0 || zzInstant <= 0 {
                return 0
            }
            return zzInstant / zzBackwards
        }
    }
    
    /// Approximate diffuse radiation based on  Razo, Müller Witwer: Ein Modellansatz zur Bestimmung von Direkt-und Diffusanteil der Einstrahlung auf die PV-Modulebene
    /// https://www.researchgate.net/publication/333293000_Ein_Modellansatz_zur_Bestimmung_von_Direkt-und_Diffusanteil_der_Einstrahlung_auf_die_PV-Modulebene
    /// https://www.ise.fraunhofer.de/content/dam/ise/de/documents/publications/conference-paper/36-eupvsec-2019/Guzman_5CV31.pdf
    /// Engerer model could also be interesting: https://github.com/JamieMBright/Engerer2-separation-model/blob/master/Engerer2Separation.py
    public static func calculateDiffuseRadiationBackwards(shortwaveRadiation: [Float], latitude: Float, longitude: Float, timerange: TimerangeDt) -> [Float] {
        let grid = RegularGrid(nx: 1, ny: 1, latMin: latitude, lonMin: longitude, dx: 1, dy: 1)
        let sunElevation = calculateSunElevationBackwards(grid: grid, timerange: timerange).data
        return zip(shortwaveRadiation, sunElevation).map { ghi, sinAlpha in
            let exrad = sinAlpha * Self.solarConstant
            
            /// clearness index [0;1], must be relative to extraterrestrial radiation NOT cleasky
            let kt = ghi / exrad
            
            let aoi = acos(sinAlpha)
            
            let c1: Float = 1.58
            let c2: Float = 0.991
            let c3: Float = -5.084
            let c4: Float = -2.11
            let c5: Float = -1.16
            let c6: Float = 2.918
            let c7: Float = 1.307
            let c8: Float = 0.762
            let c9: Float = 0.432
            let c10: Float = 0.718
            
            let kd = c1*kt + c2*aoi + c3*powf(kt,2) + c4*kt*aoi + c5*powf(aoi,2) + c6*powf(kt,3) + c7*powf(kt,2)*aoi + c8*kt*powf(aoi,2) + c9*powf(aoi,3) + c10
            
            /// diffuse fraction [0;1]
            /*var kd: Float
            // Reindl-2 model
            switch kt {
            case ...0.3:
                kd = min(1.02 - 0.254 * kt + 0.0123 * sinAlpha, 1)
            case 0.3 ..< 0.78:
                kd = max(min(1.4 - 1.749 * kt + 0.177 * sinAlpha, 0.97), 0.1)
            default: // >= 0.78
                kd = max(0.486 * kt - 0.182 * sinAlpha, 0.1)
            }*/
            
            return kd * ghi
        }
    }
}

