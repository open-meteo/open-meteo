import Foundation


struct ZensunFastTime {
    let t1: [Float]
    let p1: [Float]
    let rsun_square: [Float]
    let steps: Int
    
    /// Caclulate backwards averaged solar factor
    /// if timerange is 1, instant values are returned
    public init(timerange: TimerangeDt, subsampleSteps: Int) {
        let subsampledTime = subsampleSteps == 1 ? timerange : TimerangeDt(start: timerange.range.lowerBound.add(-1 * timerange.dtSeconds), to: timerange.range.upperBound.add(-1 * timerange.dtSeconds), dtSeconds: timerange.dtSeconds/subsampleSteps)
        
        var array_t1 = [Float]()
        var array_p1 = [Float]()
        var array_rsun_square = [Float]()
        array_t1.reserveCapacity(subsampledTime.count)
        array_p1.reserveCapacity(subsampledTime.count)
        array_rsun_square.reserveCapacity(subsampledTime.count)
        
        for subTimestamp in subsampledTime {
            /// fractional day number with 12am 1jan = 1
            let tt = Float(((subTimestamp.timeIntervalSince1970 % 31_557_600) + 31_557_600) % 31_557_600) / 86400 + 1.0 + 0.5
            let rsun=1-0.01673*cos(0.9856*(tt-2).degreesToRadians)
            let rsun_square = rsun*rsun

            let fraction = (tt - 1).truncatingRemainder(dividingBy: 5) / 5
            let eqtime = Zensun.eqt.interpolateLinear(Int(tt - 1)/5, fraction) / 60
            let decang = Zensun.dec.interpolateLinear(Int(tt - 1)/5, fraction)

            let latsun=decang
            let ut = Float(((subTimestamp.timeIntervalSince1970 % 86400) + 86400) % 86400) / 3600
            let t1 = (90-latsun).degreesToRadians
            
            let lonsun = -15.0*(ut-12.0+eqtime)
            let p1 = lonsun.degreesToRadians
            array_t1.append(t1)
            array_p1.append(p1)
            array_rsun_square.append(rsun_square)
        }
        
        t1 = array_t1
        p1 = array_p1
        rsun_square = array_rsun_square
        steps = subsampleSteps
    }
    
    public func solfac(grid: RegularGrid, yrange: Range<Int>? = nil) -> Array2DFastTime {
        let yrange = yrange ?? 0..<grid.ny
        var out = [Float]()
        out.reserveCapacity(yrange.count * grid.nx * p1.count / steps)

        for indexY in yrange {
            let lat = grid.latMin + grid.dy * Float(indexY)
            for indexX in 0..<grid.nx {
                for t0 in stride(from: 0, to: t1.count, by: steps) {
                    var sum = Float(0)
                    for t in t0..<t0+steps {
                        let t1 = t1[t]
                        let p1 = p1[t]
                        let rsun_square = rsun_square[t]
                        
                        let lon = grid.lonMin + grid.dx * Float(indexX)
                        
                        let t0=(90-lat).degreesToRadians
                        let p0=lon.degreesToRadians
                        let zz=cos(t0)*cos(t1)+sin(t0)*sin(t1)*cos(p1-p0)
                        let solfac=zz/rsun_square
                        sum += max(solfac,0)
                    }
                    out.append(sum / Float(steps))
                }
                
            }
        }
        
        return Array2DFastTime(data: out, nLocations: yrange.count * grid.nx, nTime: p1.count / steps)
    }
}

/// Solar position calculations based on zensun
/// See https://gist.github.com/sangholee1990/eb3d997a9b28ace2dbcab6a45fd7c178#file-visualization_using_sun_position-pro-L306
struct Zensun {
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

    /// Calculate a 2d (space and time) solar factor field for interpolation to hourly data. Data is space oriented!
    /*public static func calculateRadiationBackwardsAveraged(grid: RegularGrid, timerange: TimerangeDt, yrange: Range<Int>? = nil) -> [Float] {
        var out = [Float]()
        let yrange = yrange ?? 0..<grid.ny
        out.reserveCapacity(yrange.count * grid.nx * timerange.count)
                
        for timestamp in timerange {
            /// fractional day number with 12am 1jan = 1
            let tt = Float(((timestamp.timeIntervalSince1970 % 31_557_600) + 31_557_600) % 31_557_600) / 86400 + 1.0 + 0.5

            let fraction = (tt - 1).truncatingRemainder(dividingBy: 5) / 5
            let eqtime = eqt.interpolateLinear(Int(tt - 1)/5, fraction) / 60
            let decang = dec.interpolateLinear(Int(tt - 1)/5, fraction)
            
            /// earth-sun distance in AU
            let rsun = 1-0.01673*cos(0.9856*(tt-2).degreesToRadians)
            
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
            
            for indexY in yrange {
                let lat = grid.latMin + grid.dy * Float(indexY)
                for indexX in 0..<grid.nx {
                    let lon = grid.lonMin + grid.dx * Float(indexX)
                    let t0=(90-lat).degreesToRadians                     // colatitude of point

                    /// longitude of point
                    var p0 = lon.degreesToRadians
                    if p0 < p1 - .pi {
                        p0 += 2 * .pi
                    }
                    if p0 > p1 + .pi {
                        p0 -= 2 * .pi
                    }

                    let arg = acos(-(cos(t0)*cos(t1)))/(sin(t0)*sin(t1))

                    let cos_p1_p0: Float
                    if arg.isFinite {
                        let p10_arg = min(p0 + arg, p10)
                        let p1_arg = max(p0 - arg, p1)
                        cos_p1_p0 = (sin(p10_arg-p0) - sin(p1_arg-p0)) / (p10_arg - p1_arg)
                    } else {
                        cos_p1_p0 = (sin(p10-p0) - sin(p1-p0)) / (p10-p1)
                    }

                    /// sun elevation
                    let zz = cos(t0)*cos(t1)+sin(t0)*sin(t1)*cos_p1_p0
                    if zz <= 0 {
                        out.append(0)
                    } else {
                        let solfac=zz/(rsun*rsun)
                        out.append(solfac)
                    }
                }
            }
        }
        return out
    }*/
    
    /// Calculate a 2d (space and time) solar factor field for interpolation to hourly data. Data is space oriented!
    /*public static func calculateRadiationBackwardsSubsampled(grid: RegularGrid, timerange: TimerangeDt, yrange: Range<Int>? = nil, steps: Int = 60) -> Array2DFastTime {
        let yrange = yrange ?? 0..<grid.ny
        var out = Array2DFastTime(nLocations: yrange.count * grid.nx, nTime: timerange.count)
        var temp = Array2DFastTime(nLocations: yrange.count * grid.nx, nTime: steps)
        
        for (t1, timestamp) in timerange.enumerated() {
            for (t, timestamp) in TimerangeDt(start: timestamp.add(-1 * timerange.dtSeconds), to: timestamp, dtSeconds: timerange.dtSeconds/steps).enumerated() {
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
                
                var l = 0
                for indexY in yrange {
                    let lat = grid.latMin + grid.dy * Float(indexY)
                    for indexX in 0..<grid.nx {
                        let lon = grid.lonMin + grid.dx * Float(indexX)
                        
                        let t0=(90-lat).degreesToRadians
                        let p0=lon.degreesToRadians
                        let zz=cos(t0)*cos(t1)+sin(t0)*sin(t1)*cos(p1-p0)
                        let solfac=zz/rsun_square
                        temp[l, t] = max(solfac,0)
                        l += 1
                    }
                }
            }
            for l in 0..<temp.nLocations {
                out[l, t1] = temp[l, 0..<steps].reduce(Float(0), +) / Float(steps)
            }
        }
        return out
    }*/
    
    /// Calculate a 2d (space and time) solar factor field for interpolation to hourly data. Data is space oriented!
    /*public static func calculateRadiationInstant(grid: RegularGrid, timerange: TimerangeDt, yrange: Range<Int>? = nil) -> [Float] {
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
                let lat = grid.latMin + grid.dy * Float(indexY)
                for indexX in 0..<grid.nx {
                    let lon = grid.lonMin + grid.dx * Float(indexX)
                    
                    let t0=(90-lat).degreesToRadians
                    let p0=lon.degreesToRadians
                    let zz=cos(t0)*cos(t1)+sin(t0)*sin(t1)*cos(p1-p0)
                    let solfac=zz/rsun_square
                    out.append(solfac)
                }
            }
        }
        return out
    }*/
    
    /// Calculate DNI based on zenith angle
    public static func caluclateBackwardsDNI(directRadiation: [Float], latitude: Float, longitude: Float, startTime: Timestamp, dtSeconds: Int) -> [Float] {
        
        var out = [Float]()
        out.reserveCapacity(directRadiation.count)
        
        let max_sun_zenith = Float(85).degreesToRadians
        
        for i in 0..<directRadiation.count {
            // direct horizontal irradiation
            let dhi = directRadiation[i]
            if dhi.isNaN {
                out.append(.nan)
                continue
            }
            if dhi <= 0 {
                out.append(0)
                continue
            }
            
            let timestamp = startTime.timeIntervalSince1970 + dtSeconds * i
            let tt = Float(((timestamp % 31_557_600) + 31_557_600) % 31_557_600) / 86400 + 1.0 + 0.5

            let fraction = (tt - 1).truncatingRemainder(dividingBy: 5) / 5
            let eqtime = eqt.interpolateLinear(Int(tt - 1)/5, fraction) / 60
            let decang = dec.interpolateLinear(Int(tt - 1)/5, fraction)

            let latsun=decang
            let ut = Float(((timestamp % 86400) + 86400) % 86400) / 3600

            let lonsun = -15.0*(ut-12.0+eqtime)
            let t0 = (90-latitude).degreesToRadians
            let t1 = (90-latsun).degreesToRadians
            var p0 = longitude.degreesToRadians
            let p1 = lonsun.degreesToRadians

            if p0 < p1 - .pi {
                p0 += 2 * .pi
            }
            if p0 > p1 + .pi {
                p0 -= 2 * .pi
            }

            let ut0 = ut - (Float(dtSeconds)/3600)
            let lonsun0 = -15.0*(ut0-12.0+eqtime)
            let p10 = lonsun0.degreesToRadians

            let arg = acos(-(cos(t0)*cos(t1))/(sin(t0)*sin(t1)))

            let cos_p1_p0: Float
            if arg.isFinite {
                let p10_arg = min(p0 + arg, p10)
                let p1_arg = max(p0 - arg, p1)
                cos_p1_p0 = (sin(p10_arg-p0) - sin(p1_arg-p0)) / (p10_arg - p1_arg)
            } else {
                cos_p1_p0 = (sin(p10-p0) - sin(p1-p0)) / (p10-p1)
            }

            let zz = cos(t0)*cos(t1)+sin(t0)*sin(t1)*cos_p1_p0
            if zz <= 0 {
                out.append(0)
                continue
                
            }
            let zenithRadians=acos(zz)
            let b = max(cos(zenithRadians), cos(max_sun_zenith))
            let dni = dhi / b
            out.append(dni)
        }
        return out
    }
}

