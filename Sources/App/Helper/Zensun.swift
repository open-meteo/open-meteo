import Foundation


/// Solar position calculations based on zensun
/// See https://gist.github.com/sangholee1990/eb3d997a9b28ace2dbcab6a45fd7c178#file-visualization_using_sun_position-pro-L306
public struct Zensun {
    /// Watt per square meter
    static public let solarConstant = Float(1367.7)
    
    /// Lookup table for sun declination and equation of time
    public static let sunPosition = SolarPositonFastLookup()
    
    /// Calculate sun rise and set times
    /// It is assumed the UTC offset has been applied already to `timeRange`. It will be removed in the next step
    public static func calculateSunRiseSet(timeRange: Range<Timestamp>, lat: Float, lon: Float, utcOffsetSeconds: Int) -> (rise: [Timestamp], set: [Timestamp]) {
        var rises = [Timestamp]()
        var sets = [Timestamp]()
        let nDays = (timeRange.upperBound.timeIntervalSince1970 - timeRange.lowerBound.timeIntervalSince1970) / 86400
        rises.reserveCapacity(nDays)
        sets.reserveCapacity(nDays)
        for time in timeRange.stride(dtSeconds: 86400) {
            let utc = time.add(utcOffsetSeconds)
            switch calculateSunTransit(utcMidnight: utc, lat: lat, lon: lon) {
            case .polarNight:
                rises.append(Timestamp(0))
                sets.append(Timestamp(0))
            case .polarDay:
                rises.append(Timestamp(0))
                sets.append(Timestamp(0))
            case .transit(rise: let rise, set: let set):
                rises.append(utc.add(rise))
                sets.append(utc.add(set))
            }
        }
        assert(rises.count == nDays)
        assert(sets.count == nDays)
        return (rises, sets)
    }
    
    /// Calculate daylight duration in seconds
    /// Time MUST be 0 UTC, it will add the time to match the noon time based on longitude
    /// The correct time is important to get the correct sun declination at local noon
    public static func calculateDaylightDuration(utcMidnight: Range<Timestamp>, lat: Float, lon: Float) -> [Float] {
        let noonTimeOffsetSeconds = Int((12-lon/15)*3600)
        return utcMidnight.stride(dtSeconds: 86400).map { date in
            let t1 = date.add(noonTimeOffsetSeconds).getSunDeclination().degreesToRadians
            let alpha = Float(0.83333).degreesToRadians
            let t0 = lat.degreesToRadians
            let arg = -(sin(alpha)+sin(t0)*sin(t1))/(cos(t0)*cos(t1))
            guard arg <= 1 && arg >= -1 else {
                // polar night or day
                return arg > 1 ? 0 : 24*3600
            }
            let dtime = acos(arg)/(Float(15).degreesToRadians)
            return dtime * 2 * 3600
        }
    }
    
    public enum SunTransit {
        case polarNight
        case polarDay
        /// Seconds after midnight in local time!
        case transit(rise: Int, set: Int)
    }
    
    /// Time MUST be 0 UTC, it will add the time to match the noon time based on longitude
    /// The correct time is important to get the correct sun declination at local noon
    @inlinable static func calculateSunTransit(utcMidnight: Timestamp, lat: Float, lon: Float) -> SunTransit {
        let localMidday = utcMidnight.add(Int((12-lon/15)*3600))
        let eqtime = localMidday.getSunEquationOfTime()
        let t1 = localMidday.getSunDeclination().degreesToRadians
        let alpha = Float(0.83333).degreesToRadians
        let noon = 12-lon/15
        let t0 = lat.degreesToRadians
        let arg = -(sin(alpha)+sin(t0)*sin(t1))/(cos(t0)*cos(t1))
        
        guard arg <= 1 && arg >= -1 else {
            return arg > 1 ? .polarNight : .polarDay
        }
        
        let dtime = acos(arg)/(Float(15).degreesToRadians)
        let sunrise = noon-dtime-eqtime
        let sunset = noon+dtime-eqtime
        return .transit(rise: Int(sunrise*3600), set: Int(sunset*3600))
    }
    
    /// Calculate if a given timestep has daylight (`1`) or not (`0`) using sun transit calculation
    public static func calculateIsDay(timeRange: TimerangeDt, lat: Float, lon: Float) -> [Float] {
        let universalUtcOffsetSeconds = Int(lon/15 * 3600)
        var lastCalculatedTransit: (date: Timestamp, transit: SunTransit)? = nil
        return timeRange.map({ time -> Float in
            // As we iteratate over an hourly range, caculate local-time midnight night for the given timestamp
            let localMidnight = time.add(universalUtcOffsetSeconds).floor(toNearest: 24*3600).add(-1 * universalUtcOffsetSeconds)
            
            // calculate new transit if required
            if lastCalculatedTransit?.date != localMidnight {
                lastCalculatedTransit = (localMidnight, calculateSunTransit(utcMidnight: localMidnight, lat: lat, lon: lon))
            }
            guard let lastCalculatedTransit else {
                fatalError("Not possible")
            }
            switch lastCalculatedTransit.transit {
            case .polarNight:
                return 0
            case .polarDay:
                return 1
            case .transit(rise: let rise, set: let set):
                // Compare in local time
                let secondsSinceMidnight = time.add(universalUtcOffsetSeconds).secondsSinceMidnight
                return secondsSinceMidnight > (rise+universalUtcOffsetSeconds) && secondsSinceMidnight < (set+universalUtcOffsetSeconds) ? 1 : 0
            }
        })
    }
    
    /// Calculate a 2d (space and time) solar factor field for interpolation to hourly data. Data is time oriented!
    /// This function is performance critical for updates. This explains redundant code.
    public static func calculateRadiationBackwardsAveraged(grid: Gridable, locationRange: Range<Int>, timerange: TimerangeDt) -> Array2DFastTime {
        var out = Array2DFastTime(nLocations: locationRange.count, nTime: timerange.count)
                
        for (t, timestamp) in timerange.enumerated() {
            let decang = timestamp.getSunDeclination()
            let eqtime = timestamp.getSunEquationOfTime()
            
            /// earth-sun distance in AU
            let rsun = timestamp.getSunRadius()
            
            /// solar disk half-angle
            let alpha = Float(0.83333).degreesToRadians
            
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
            
            for (i, gridpoint) in locationRange.enumerated() {
                let (lat,lon) = grid.getCoordinates(gridpoint: gridpoint)
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
                /// sun elevation (`zz = sin(alpha)`)
                let zz = (left-right) / (p1_l - p10_l)
                
                out[i, t] = zz <= 0 ? 0 : zz / (rsun*rsun)
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
            let decang = timestamp.getSunDeclination()
            let eqtime = timestamp.getSunEquationOfTime()
            let alpha = Float(0.83333).degreesToRadians
            
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
                    /// sun elevation (`zz = sin(alpha)`)
                    let zz = (left-right) / (p1_l - p10_l)
                    
                    out[l, t] = zz
                    l += 1
                }
            }
        }
        return out
    }
    
    /*public static func calculateZenithInstant(lat: Float, lon: Float, time: Timestamp) -> Float {
        let decang = time.getSunDeclination()
        let eqtime = time.getSunEquationOfTime()

        let latsun=decang
        let ut = time.hourWithFraction
        let t1 = (90-latsun).degreesToRadians
        
        let lonsun = -15.0*(ut-12.0+eqtime)
        let p1 = lonsun.degreesToRadians
        

        let t0 = (90-lat).degreesToRadians
        let p0 = lon.degreesToRadians
        /// sun elevation (`zz = sin(alpha)`)
        let zz = cos(t0)*cos(t1)+sin(t0)*sin(t1)*cos(p1-p0)
        return acos(zz).radiansToDegrees
    }*/
    
    
    /// Calculate a 2d (space and time) solar factor field for interpolation to hourly data. Data is space oriented!
    public static func calculateRadiationInstant(grid: Gridable, timerange: TimerangeDt, yrange: Range<Int>? = nil) -> [Float] {
        var out = [Float]()
        let yrange = yrange ?? 0..<grid.ny
        out.reserveCapacity(yrange.count * grid.nx * timerange.count)
                
        for timestamp in timerange {
            let rsun = timestamp.getSunRadius()
            let rsun_square = rsun*rsun

            let decang = timestamp.getSunDeclination()
            let eqtime = timestamp.getSunEquationOfTime()

            let latsun=decang
            let ut = timestamp.hourWithFraction
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
    public static func calculateBackwardsDNI(directRadiation: [Float], latitude: Float, longitude: Float, timerange: TimerangeDt) -> [Float] {
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
            return dni
        }
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
    
    /// Watt per square meter
    public static func extraTerrestrialRadiationBackwards(latitude: Float, longitude: Float, timerange: TimerangeDt) -> [Float] {
        // compute hourly mean radiation flux
        return Zensun.calculateRadiationBackwardsAveraged(grid: RegularGrid(nx: 1, ny: 1, latMin: latitude, lonMin: longitude, dx: 1, dy: 1), locationRange: 0..<1, timerange: timerange).data.map {
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
            let decang = timestamp.getSunDeclination()
            let eqtime = timestamp.getSunEquationOfTime()
            
            let alpha = Float(0.83333).degreesToRadians
            
            let latsun=decang
            /// universal time
            let ut = timestamp.hourWithFraction
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

extension Timestamp {
    /// Second of year, assuming average of 365.25 days
    /// Range `0 ..< 364.25 * 86400`
    public var secondInAverageYear: Int {
        ((timeIntervalSince1970 %  Self.secondsPerAverageYear) + Self.secondsPerAverageYear) % Self.secondsPerAverageYear
    }
    
    /// Number of seconds since midnight
    public var secondsSinceMidnight: Int {
        return timeIntervalSince1970 % (24*3600)
    }
    
    /// Seconds per year if a year has 365.25 days
    public static var secondsPerAverageYear: Int {
        31_557_600
    }
    
    /// E.g. 2.5 for 2:30
    public var hourWithFraction: Float {
        Float(((timeIntervalSince1970 % 86400) + 86400) % 86400) / 3600
    }
    
    @inlinable public func getSunDeclination() -> Float {
        return Zensun.sunPosition.getDeclination(self)
    }
    
    /// In  hours
    @inlinable public func getSunEquationOfTime() -> Float {
        return Zensun.sunPosition.getEquationOfTime(self) / 60
    }
     
    /// Eaarth-Sun distance in AU. 0.983 in january. 1.0167135 in july
    /// https://physics.stackexchange.com/questions/177949/earth-sun-distance-on-a-given-day-of-the-year
    @inlinable public func getSunRadius() -> Float {
        let day = Float(secondInAverageYear) / 86400 - 4 + 1
        return 1-0.01672*cos(((360/365.256363)*day).degreesToRadians)
    }
}
