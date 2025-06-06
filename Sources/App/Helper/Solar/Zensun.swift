import Foundation

/// Solar position calculations based on zensun
/// See https://gist.github.com/sangholee1990/eb3d997a9b28ace2dbcab6a45fd7c178#file-visualization_using_sun_position-pro-L306
/// Revised using NREL Solar Posiition Altorithm SPA
public enum Zensun {
    /// Watt per square meter
    public static let solarConstant = Float(1367.7)

    /// Lookup table for sun declination and equation of time
    public static let sunPosition = SolarPositonFastLookup()

    /// Calculate a 2d (space and time) solar factor field for interpolation to hourly data. Data is time oriented!
    /// This function is performance critical for updates. This explains redundant code.
    public static func calculateRadiationBackwardsAveraged(grid: Gridable, locationRange: some RandomAccessCollection<Int>, timerange: TimerangeDt) -> Array2DFastTime {
        var out = Array2DFastTime(nLocations: locationRange.count, nTime: timerange.count)

        for (t, timestamp) in timerange.enumerated() {
            let decang = timestamp.getSunDeclination()
            let eqtime = timestamp.getSunEquationOfTime()

            /// earth-sun distance in AU
            let rsun = timestamp.getSunRadius()

            /// solar disk half-angle
            let alpha = Float(0.83333).degreesToRadians

            let latsun = decang
            /// universal time
            let ut = timestamp.hourWithFraction
            let t1 = (90 - latsun).degreesToRadians

            let lonsun = -15.0 * (ut - 12.0 + eqtime)

            /// longitude of sun
            let p1 = lonsun.degreesToRadians

            let ut0 = ut - (Float(timerange.dtSeconds) / 3600)
            let lonsun0 = -15.0 * (ut0 - 12.0 + eqtime)

            let p10 = lonsun0.degreesToRadians

            for (i, gridpoint) in locationRange.enumerated() {
                let (lat, lon) = grid.getCoordinates(gridpoint: gridpoint)
                let t0 = (90 - lat).degreesToRadians                     // colatitude of point

                /// longitude of point
                var p0 = lon.degreesToRadians
                if p0 < p1 - .pi {
                    p0 += 2 * .pi
                }
                if p0 > p1 + .pi {
                    p0 -= 2 * .pi
                }

                // limit p1 and p10 to sunrise/set
                let arg = -(sin(alpha) + cos(t0) * cos(t1)) / (sin(t0) * sin(t1))
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
                let zz = (left - right) / (p1_l - p10_l)

                out[i, t] = zz <= 0 ? 0 : zz / (rsun * rsun)
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

            let latsun = decang
            /// universal time
            let ut = timestamp.hourWithFraction
            let t1 = (90 - latsun).degreesToRadians

            let lonsun = -15.0 * (ut - 12.0 + eqtime)

            /// longitude of sun
            let p1 = lonsun.degreesToRadians

            let ut0 = ut - (Float(timerange.dtSeconds) / 3600)
            let lonsun0 = -15.0 * (ut0 - 12.0 + eqtime)

            let p10 = lonsun0.degreesToRadians

            var l = 0
            for indexY in yrange {
                for indexX in 0..<grid.nx {
                    let (lat, lon) = grid.getCoordinates(gridpoint: indexY * grid.nx + indexX)
                    let t0 = (90 - lat).degreesToRadians                     // colatitude of point

                    /// longitude of point
                    var p0 = lon.degreesToRadians
                    if p0 < p1 - .pi {
                        p0 += 2 * .pi
                    }
                    if p0 > p1 + .pi {
                        p0 -= 2 * .pi
                    }

                    // limit p1 and p10 to sunrise/set
                    let arg = -(sin(alpha) + cos(t0) * cos(t1)) / (sin(t0) * sin(t1))
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
                    let zz = (left - right) / (p1_l - p10_l)

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
            let rsun_square = rsun * rsun

            let decang = timestamp.getSunDeclination()
            let eqtime = timestamp.getSunEquationOfTime()

            let latsun = decang
            let ut = timestamp.hourWithFraction
            let t1 = (90 - latsun).degreesToRadians

            let lonsun = -15.0 * (ut - 12.0 + eqtime)
            let p1 = lonsun.degreesToRadians

            for indexY in yrange {
                for indexX in 0..<grid.nx {
                    let (lat, lon) = grid.getCoordinates(gridpoint: indexY * grid.nx + indexX)

                    let t0 = (90 - lat).degreesToRadians
                    let p0 = lon.degreesToRadians
                    /// sun elevation (`zz = sin(alpha)`)
                    let zz = cos(t0) * cos(t1) + sin(t0) * sin(t1) * cos(p1 - p0)
                    let solfac = zz / rsun_square
                    out.append(solfac)
                }
            }
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

    /// 2d field. Calculate scaling factor from backwards to instant radiation factor
    public static func backwardsAveragedToInstantFactor(grid: Gridable, locationRange: Range<Int>, timerange: TimerangeDt) -> Array2DFastTime {
        var out = Array2DFastTime(nLocations: locationRange.count, nTime: timerange.count)

        for (t, timestamp) in timerange.enumerated() {
            /// fractional day number with 12am 1jan = 1
            let decang = timestamp.getSunDeclination()
            let eqtime = timestamp.getSunEquationOfTime()

            let alpha = Float(0.83333).degreesToRadians

            let latsun = decang
            /// universal time
            let ut = timestamp.hourWithFraction
            let t1 = (90 - latsun).degreesToRadians

            let lonsun = -15.0 * (ut - 12.0 + eqtime)

            for (i, gridpoint) in locationRange.enumerated() {
                let (latitude, longitude) = grid.getCoordinates(gridpoint: gridpoint)
                /// longitude of sun
                let p1 = lonsun.degreesToRadians

                let ut0 = ut - (Float(timerange.dtSeconds) / 3600)
                let lonsun0 = -15.0 * (ut0 - 12.0 + eqtime)

                let p10 = lonsun0.degreesToRadians

                let t0 = (90 - latitude).degreesToRadians                     // colatitude of point

                /// longitude of point
                var p0 = longitude.degreesToRadians
                if p0 < p1 - .pi {
                    p0 += 2 * .pi
                }
                if p0 > p1 + .pi {
                    p0 -= 2 * .pi
                }

                // limit p1 and p10 to sunrise/set
                let arg = -(sin(alpha) + cos(t0) * cos(t1)) / (sin(t0) * sin(t1))
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
                let zzBackwards = (left - right) / (p1_l - p10_l)

                /// Instant sun elevation
                let zzInstant = cos(t0) * cos(t1) + sin(t0) * sin(t1) * cos(p1 - p0)
                if zzBackwards <= 0 || zzInstant <= 0 {
                    out[i, t] = 0
                    continue
                }
                out[i, t] = zzInstant / zzBackwards
            }
        }
        return out
    }

    /// Assumes data is an instantaneous satellite solar radiation which is converted to backwards averaged solar radiation.
    /// Corrects for scan time difference for each location. With EUMETSAT this is around 10 to 15 minutes in Europe.
    /// Corrects for missing averages radiation values at sunset assuming the cloudiness index `kt` from the previous step. This only works for `t>0` timesteps
    ///
    /// Used for SARAH-3 shortwave and direct radiation and processes 24 hours at once.
    /// The scan time differences are particular annoying. Probably most users of satellite radiation completely ignore them....
    /// SARAH-3 appears to have a 1° solar declination cut off. `sunDeclinationCutOffDegrees` is set to 1.
    public static func instantaneousSolarRadiationToBackwardsAverages(timeOrientedData data: inout [Float], grid: Gridable, locationRange: Range<Int>, timerange: TimerangeDt, scanTimeDifferenceHours: [Double], sunDeclinationCutOffDegrees: Float) {
        let decang = timerange.map { $0.getSunDeclination() }
        let eqtime = timerange.map { $0.getSunEquationOfTime() }

        /// At low solar inclination angles (less than 5 watts), reuse clearness factors from other timesteps
        let radMinium = 5 / Zensun.solarConstant

        for (i, gridpoint) in locationRange.enumerated() {
            var ktPrevious = Float.nan

            for (t, timestamp) in timerange.enumerated() {
                let pos = i * timerange.count + t
                let scanTimeDifferenceHours = scanTimeDifferenceHours[i]
                if scanTimeDifferenceHours.isNaN {
                    continue
                }
                let decang = decang[t]
                let eqtime = eqtime[t]

                let alpha = Float(0.83333).degreesToRadians - sunDeclinationCutOffDegrees.degreesToRadians

                let latsun = decang
                /// universal time
                let ut = timestamp.hourWithFraction
                let t1 = (90 - latsun).degreesToRadians

                let scantime = timestamp.add(Int(scanTimeDifferenceHours * 3600))
                let utScan = scantime.hourWithFraction

                let lonsun = -15.0 * (ut - 12.0 + eqtime)
                let lonsunScan = -15.0 * (utScan - 12.0 + eqtime)

                let (latitude, longitude) = grid.getCoordinates(gridpoint: gridpoint)
                /// longitude of sun
                let p1 = lonsun.degreesToRadians
                let p1Scan = lonsunScan.degreesToRadians

                let ut0 = ut - (Float(timerange.dtSeconds) / 3600)
                let lonsun0 = -15.0 * (ut0 - 12.0 + eqtime)

                let p10 = lonsun0.degreesToRadians

                let t0 = (90 - latitude).degreesToRadians                     // colatitude of point

                /// longitude of point
                var p0 = longitude.degreesToRadians
                if p0 < p1 - .pi {
                    p0 += 2 * .pi
                }
                if p0 > p1 + .pi {
                    p0 -= 2 * .pi
                }

                // limit p1 and p10 to sunrise/set
                let arg = -(sin(alpha) + cos(t0) * cos(t1)) / (sin(t0) * sin(t1))
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
                let zzBackwards = (left - right) / (p1_l - p10_l)

                /// Instant sun elevation
                let zzInstant = cos(t0) * cos(t1) + sin(t0) * sin(t1) * cos(p1Scan - p0)
                // SARAH-3 already shows 0 watts close to sunset even at zzInstant > 0
                // Additionally very old files have missing some timesteps. Use kt to backfill data
                if (data[pos] == 0 || data[pos].isNaN) && zzBackwards > radMinium && ktPrevious.isFinite {
                    // condition at sunset, use previous kt index to estimate solar radiation
                    data[pos] = ktPrevious * zzBackwards
                    ktPrevious = .nan
                    continue
                }
                if data[pos].isNaN {
                    continue
                }
                if zzBackwards <= radMinium || zzInstant <= radMinium {
                    data[pos] = 0
                    ktPrevious = .nan
                    continue
                }
                let factor = zzInstant / zzBackwards
                if factor < 0.05 {
                    data[pos] = 0
                    ktPrevious = .nan
                    continue
                }
                let instant = data[pos]
                let backwards = instant / factor
                data[pos] = backwards
                ktPrevious = (instant / zzInstant)
            }
        }
    }

    /// Calculate scaling factor from backwards to instant radiation factor
    public static func backwardsAveragedToInstantFactor(time: TimerangeDt, latitude: Float, longitude: Float) -> [Float] {
        return time.map { timestamp in
            /// fractional day number with 12am 1jan = 1
            let decang = timestamp.getSunDeclination()
            let eqtime = timestamp.getSunEquationOfTime()

            let alpha = Float(0.83333).degreesToRadians

            let latsun = decang
            /// universal time
            let ut = timestamp.hourWithFraction
            let t1 = (90 - latsun).degreesToRadians

            let lonsun = -15.0 * (ut - 12.0 + eqtime)

            /// longitude of sun
            let p1 = lonsun.degreesToRadians

            let ut0 = ut - (Float(time.dtSeconds) / 3600)
            let lonsun0 = -15.0 * (ut0 - 12.0 + eqtime)

            let p10 = lonsun0.degreesToRadians

            let t0 = (90 - latitude).degreesToRadians                     // colatitude of point

            /// longitude of point
            var p0 = longitude.degreesToRadians
            if p0 < p1 - .pi {
                p0 += 2 * .pi
            }
            if p0 > p1 + .pi {
                p0 -= 2 * .pi
            }

            // limit p1 and p10 to sunrise/set
            let arg = -(sin(alpha) + cos(t0) * cos(t1)) / (sin(t0) * sin(t1))
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
            let zzBackwards = (left - right) / (p1_l - p10_l)

            /// Instant sun elevation
            let zzInstant = cos(t0) * cos(t1) + sin(t0) * sin(t1) * cos(p1 - p0)
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
            if sinAlpha <= 5 / Zensun.solarConstant {
                // At low solar angles and at night, assume GHI is diffuse
                return ghi
            }
            let exrad = min(sinAlpha * Self.solarConstant, 0.95 * Self.solarConstant)

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

            let kd = c1 * kt + c2 * aoi + c3 * powf(kt, 2) + c4 * kt * aoi + c5 * powf(aoi, 2) + c6 * powf(kt, 3) + c7 * powf(kt, 2) * aoi + c8 * kt * powf(aoi, 2) + c9 * powf(aoi, 3) + c10

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

            return min(kd * ghi, ghi)
        }
    }
}

extension Timestamp {
    /// Second of year, assuming average of 365.25 days
    /// Range `0 ..< 364.25 * 86400`
    public var secondInAverageYear: Int {
        ((timeIntervalSince1970 % Self.secondsPerAverageYear) + Self.secondsPerAverageYear) % Self.secondsPerAverageYear
    }

    /// Number of seconds since midnight
    public var secondsSinceMidnight: Int {
        return timeIntervalSince1970 % (24 * 3600)
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
        return 1 - 0.01672 * cos(((360 / 365.256363) * day).degreesToRadians)
    }
}
