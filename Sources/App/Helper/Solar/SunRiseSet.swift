import Foundation

extension Zensun {
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
                rises.append(time)
                sets.append(time)
            case .polarDay:
                rises.append(time)
                sets.append(time.add(24 * 3600))
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
        let utcOffsetApproximated = Int((-lon / 15) * 3600)
        return calculateDaylightDuration(localMidnight: utcMidnight.add(utcOffsetApproximated), lat: lat)
    }

    /// Calculate daylight duration. `localMidnight` should be be aligned to 0:00 localtime. E.g. 22 UTC for CEST.
    public static func calculateDaylightDuration(localMidnight: Range<Timestamp>, lat: Float) -> [Float] {
        return localMidnight.stride(dtSeconds: 86400).map { date in
            let t1 = date.add(12 * 3600).getSunDeclination().degreesToRadians
            let alpha = Float(0.83333).degreesToRadians
            let t0 = lat.degreesToRadians
            let arg = -(sin(alpha) + sin(t0) * sin(t1)) / (cos(t0) * cos(t1))
            guard arg <= 1 && arg >= -1 else {
                // polar night or day
                return arg > 1 ? 0 : 24 * 3600
            }
            let dtime = acos(arg) / (Float(15).degreesToRadians)
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
        let localMidday = utcMidnight.add(Int((12 - lon / 15) * 3600))
        let eqtime = localMidday.getSunEquationOfTime()
        let t1 = localMidday.getSunDeclination().degreesToRadians
        let alpha = Float(0.83333).degreesToRadians
        let noon = 12 - lon / 15
        let t0 = lat.degreesToRadians
        let arg = -(sin(alpha) + sin(t0) * sin(t1)) / (cos(t0) * cos(t1))

        guard arg <= 1 && arg >= -1 else {
            return arg > 1 ? .polarNight : .polarDay
        }

        let dtime = acos(arg) / (Float(15).degreesToRadians)
        let sunrise = noon - dtime - eqtime
        let sunset = noon + dtime - eqtime
        return .transit(rise: Int(sunrise * 3600), set: Int(sunset * 3600))
    }

    /// Calculate if a given timestep has daylight (`1`) or not (`0`) using sun transit calculation
    public static func calculateIsDay(timeRange: TimerangeDt, lat: Float, lon: Float) -> [Float] {
        let universalUtcOffsetSeconds = Int(lon / 15 * 3600)
        var lastCalculatedTransit: (date: Timestamp, transit: SunTransit)?
        return timeRange.map({ time -> Float in
            // As we iteratate over an hourly range, caculate local-time midnight night for the given timestamp
            let localMidnight = time.add(universalUtcOffsetSeconds).floor(toNearest: 24 * 3600).add(-1 * universalUtcOffsetSeconds)

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
                return secondsSinceMidnight > (rise + universalUtcOffsetSeconds) && secondsSinceMidnight < (set + universalUtcOffsetSeconds) ? 1 : 0
            }
        })
    }

    /// Approximate daylight duration (DNI > 120 w/m2) in seconds. `directRadiation` must be backwards averaged over dt.
    /// Assumes a linear distribution over 60-180 watts instead of a hard cut of 120 watts.
    /// Timeinterval `dt`is adjusted to sunrise and sunset to ensure. Only considering DNI will lead to sunshine greated than daylight duration.
    public static func calculateBackwardsSunshineDuration(directRadiation: [Float], latitude: Float, longitude: Float, timerange: TimerangeDt) -> [Float] {
        let dt = Float(timerange.dtSeconds)

        return zip(directRadiation, timerange).map { dhi, timestamp in
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

            let t0 = (90 - latitude).degreesToRadians

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

            // limit dt to sunrise/set
            let dtBound = dt * abs((p1_l - p10_l) / (p10 - p1))

            // solve integral to get sun elevation dt
            // integral(cos(t0) cos(t1) + sin(t0) sin(t1) cos(p - p0)) dp = sin(t0) sin(t1) sin(p - p0) + p cos(t0) cos(t1) + constant
            let left = sin(t0) * sin(t1) * sin(p1_l - p0) + p1_l * cos(t0) * cos(t1)
            let right = sin(t0) * sin(t1) * sin(p10_l - p0) + p10_l * cos(t0) * cos(t1)
            let zzBackwards = (left - right) / (p1_l - p10_l)
            let dni = dhi / zzBackwards
            // Prevent possible division by zero
            // See https://github.com/open-meteo/open-meteo/discussions/395
            let dniBounded = zzBackwards <= 0.0001 ? dhi : dni
            // >120 watts would be a "hard-cut" and not realistic as data is averaged over 1 hours. Instead, linearly interpolate between 60 and 180 watts.
            return min(max(dniBounded - 60, 0) / (180 - 60) * dtBound, dtBound)
        }
    }
}
