import Foundation

/// Lunar position, rise/set and phase calculations.
///
/// The geocentric ecliptic position uses the compact "MiniMoon" lunar series from
/// Montenbruck & Pfleger, "Astronomy on the Personal Computer". It is accurate to a few
/// arc-minutes which translates to roughly one minute in rise/set times — more than enough
/// for a weather API and far cheaper than the hundreds of periodic terms required by full
/// lunar theory (ELP-2000) or the NREL MPA used for the sun in ``SolarPositionAlgorithm``.
///
/// Unlike the sun (``Zensun``), the moon moves ~13°/day, so a precomputed declination lookup
/// table is not viable. Rise/set are instead found by evaluating the altitude on an hourly grid
/// and refining the horizon crossings with quadratic interpolation. This is only ever evaluated
/// for a single location per API request, so direct computation is fast enough (~25 position
/// evaluations per day).
public enum Moon {
    /// Geocentric ecliptic longitude and latitude of the moon in radians, referred to the mean
    /// equinox of date. Delta-T is neglected (sub-arcsecond effect on rise/set).
    static func eclipticPosition(_ time: Timestamp) -> (longitude: Double, latitude: Double) {
        /// Julian centuries since J2000.0
        let t = (time.julianDate - 2451545.0) / 36525.0
        let pi2 = 2 * Double.pi
        /// Arc-seconds per radian
        let arc = 206264.8062

        func frac(_ x: Double) -> Double { x - x.rounded(.down) }

        let l0 = frac(0.606433 + 1336.855225 * t)       // mean longitude (revolutions)
        let l = pi2 * frac(0.374897 + 1325.552410 * t)  // moon's mean anomaly
        let ls = pi2 * frac(0.993133 + 99.997361 * t)   // sun's mean anomaly
        let d = pi2 * frac(0.827361 + 1236.853086 * t)  // mean elongation moon - sun
        let f = pi2 * frac(0.259086 + 1342.227825 * t)  // mean argument of latitude

        /// Perturbations in ecliptic longitude (arc-seconds)
        let dl = 22640 * sin(l)
            - 4586 * sin(l - 2 * d)
            + 2370 * sin(2 * d)
            + 769 * sin(2 * l)
            - 668 * sin(ls)
            - 412 * sin(2 * f)
            - 212 * sin(2 * l - 2 * d)
            - 206 * sin(l + ls - 2 * d)
            + 192 * sin(l + 2 * d)
            - 165 * sin(ls - 2 * d)
            - 125 * sin(d)
            - 110 * sin(l + ls)
            + 148 * sin(l - ls)
            - 55 * sin(2 * f - 2 * d)

        let s = f + (dl + 412 * sin(2 * f) + 541 * sin(ls)) / arc
        let h = f - 2 * d
        /// Perturbations in ecliptic latitude (arc-seconds)
        let n = -526 * sin(h)
            + 44 * sin(l + h)
            - 31 * sin(-l + h)
            - 23 * sin(ls + h)
            + 11 * sin(-ls + h)
            - 25 * sin(-2 * l + f)
            + 21 * sin(-l + f)

        let longitude = pi2 * frac(l0 + dl / 1296000)
        let latitude = (18520.0 * sin(s) + n) / arc
        return (longitude, latitude)
    }

    /// Geocentric equatorial coordinates (right ascension and declination, radians) of the moon.
    static func equatorialPosition(_ time: Timestamp) -> (rightAscension: Double, declination: Double) {
        /// cos / sin of the mean obliquity of the ecliptic (~23.43929°)
        let coseps = 0.91748
        let sineps = 0.39778
        let (lon, lat) = eclipticPosition(time)
        let cb = cos(lat)
        let x = cb * cos(lon)
        let v = cb * sin(lon)
        let w = sin(lat)
        let y = coseps * v - sineps * w
        let z = sineps * v + coseps * w
        let rho = (1 - z * z).squareRoot()
        return (atan2(y, x), atan2(z, rho))
    }

    /// Greenwich mean sidereal time in radians for a given instant.
    static func greenwichMeanSiderealTime(_ time: Timestamp) -> Double {
        let d = time.julianDate - 2451545.0
        let t = d / 36525.0
        var gmst = 280.46061837 + 360.98564736629 * d + t * t * (0.000387933 - t / 38710000.0)
        gmst = gmst.truncatingRemainder(dividingBy: 360)
        if gmst < 0 {
            gmst += 360
        }
        return gmst * .pi / 180
    }

    /// `sin` of the moon's geocentric altitude. `latSin`/`latCos` are sin/cos of the latitude,
    /// `lon` the longitude in radians (east positive).
    static func sinAltitude(_ time: Timestamp, latSin: Double, latCos: Double, lon: Double) -> Double {
        let (rightAscension, declination) = equatorialPosition(time)
        let hourAngle = greenwichMeanSiderealTime(time) + lon - rightAscension
        return latSin * sin(declination) + latCos * cos(declination) * cos(hourAngle)
    }

    /// Calculate moonrise and moonset for each day in `timeRange`.
    ///
    /// `timeRange` must be aligned to local midnight expressed in UTC (i.e. `dailyDisplay`), exactly
    /// like ``Zensun/calculateSunRiseSet(timeRange:lat:lon:utcOffsetSeconds:)``. Returned timestamps are
    /// in UTC; the display UTC offset is applied later by the writers. On days where the moon does not
    /// rise or set (it can stay up or down for a whole local day), the corresponding entry is
    /// ``Timestamp/noData``.
    public static func calculateMoonRiseSet(timeRange: Range<Timestamp>, lat: Float, lon: Float) -> (rise: [Timestamp], set: [Timestamp]) {
        let nDays = (timeRange.upperBound.timeIntervalSince1970 - timeRange.lowerBound.timeIntervalSince1970) / 86400
        var rises = [Timestamp]()
        var sets = [Timestamp]()
        rises.reserveCapacity(nDays)
        sets.reserveCapacity(nDays)

        let latRad = Double(lat) * .pi / 180
        let lonRad = Double(lon) * .pi / 180
        let latSin = sin(latRad)
        let latCos = cos(latRad)
        /// Standard altitude of the moon's centre at rise/set: mean horizontal parallax (~0.95°) reduced by
        /// `0.7275`, minus refraction (34') and semidiameter, giving h0 ≈ +0.125° (Meeus, Astronomical Algorithms ch.15)
        let sinH0 = sin(0.125 * .pi / 180)

        for day in timeRange.stride(dtSeconds: 86400) {
            var rise = Timestamp.noData
            var set = Timestamp.noData

            // Evaluate sin(altitude) - sin(h0) on an hourly grid and refine each 2-hour window
            // [hour-1, hour+1] with a parabola fitted through its three samples.
            var yMinus = sinAltitude(day, latSin: latSin, latCos: latCos, lon: lonRad) - sinH0
            var hour = 1
            while hour < 24 {
                let y0 = sinAltitude(day.add(hour * 3600), latSin: latSin, latCos: latCos, lon: lonRad) - sinH0
                let yPlus = sinAltitude(day.add((hour + 1) * 3600), latSin: latSin, latCos: latCos, lon: lonRad) - sinH0

                let a = 0.5 * (yMinus + yPlus) - y0
                let b = 0.5 * (yPlus - yMinus)
                let xe = -b / (2 * a)
                let ye = (a * xe + b) * xe + y0
                let dis = b * b - 4 * a * y0
                if dis >= 0 {
                    let dx = 0.5 * dis.squareRoot() / abs(a)
                    var zero1 = xe - dx
                    let zero2 = xe + dx
                    let nz = (abs(zero1) <= 1 ? 1 : 0) + (abs(zero2) <= 1 ? 1 : 0)
                    if zero1 < -1 {
                        zero1 = zero2
                    }
                    if nz == 1 {
                        // single crossing: rising if the interval started below the horizon
                        let event = day.add(Int((Double(hour) + zero1) * 3600))
                        if yMinus < 0 {
                            if rise.isNoData { rise = event }
                        } else {
                            if set.isNoData { set = event }
                        }
                    } else if nz == 2 {
                        // two crossings within the window: the parabola's vertex sign tells the order
                        let eventEarly = day.add(Int((Double(hour) + zero1) * 3600))
                        let eventLate = day.add(Int((Double(hour) + zero2) * 3600))
                        if ye < 0 {
                            if set.isNoData { set = eventEarly }
                            if rise.isNoData { rise = eventLate }
                        } else {
                            if rise.isNoData { rise = eventEarly }
                            if set.isNoData { set = eventLate }
                        }
                    }
                }
                if !rise.isNoData && !set.isNoData {
                    break
                }
                yMinus = yPlus
                hour += 2
            }
            rises.append(rise)
            sets.append(set)
        }
        return (rises, sets)
    }

    /// Geocentric ecliptic longitude of the sun in radians (low precision, ~0.01°), Meeus ch.25.
    static func sunEclipticLongitude(_ time: Timestamp) -> Double {
        let t = (time.julianDate - 2451545.0) / 36525.0
        let l0 = 280.46646 + 36000.76983 * t + 0.0003032 * t * t
        let m = (357.52911 + 35999.05029 * t - 0.0001537 * t * t) * .pi / 180
        let c = (1.914602 - 0.004817 * t - 0.000014 * t * t) * sin(m)
            + (0.019993 - 0.000101 * t) * sin(2 * m)
            + 0.000289 * sin(3 * m)
        return (l0 + c) * .pi / 180
    }

    /// Moon phase as a fraction `[0, 1)` of the synodic cycle: `0` = new moon, `0.25` = first quarter,
    /// `0.5` = full moon, `0.75` = last quarter. Evaluated at local noon of each day in `timeRange`
    /// (which must be aligned to local midnight in UTC, like `dailyDisplay`).
    public static func calculateMoonPhase(timeRange: Range<Timestamp>) -> [Float] {
        let pi2 = 2 * Double.pi
        return timeRange.stride(dtSeconds: 86400).map { day in
            let time = day.add(12 * 3600)
            let elongation = eclipticPosition(time).longitude - sunEclipticLongitude(time)
            var phase = elongation / pi2
            phase -= phase.rounded(.down)
            return Float(phase)
        }
    }
}
