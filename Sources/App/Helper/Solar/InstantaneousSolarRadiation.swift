import Foundation

extension Zensun {
    /// Convert one spatial field of instantaneous radiation to the preceding interval's mean.
    /// `previous` contains the KT returned by the preceding call and its actual timestamp.
    /// Returns KT for the next call, reusing it at sunset/low sun and clearing it for fully dark intervals or
    /// missing input. Unavailable KT is NaN.
    /// `dtSeconds` is the averaging interval; the previous sample may have a different time gap.
    /// KT is the clearness index relative to extraterrestrial horizontal radiation, consistent
    /// with the other solar interpolation routines. Blend linearly from current KT at 3°
    /// to cached KT at 1°, retaining the blended KT for the next step.
    /// Without usable history, use current KT above 1°; at or below 1°, leave values unscaled. Missing values stay missing.
    public static func instantaneousSolarRadiationToBackwardsAverage(
        data: inout [Float], previous: (time: Timestamp, clearnessIndex: [Float])?, grid: any Gridable,
        time: Timestamp, dtSeconds: Int
    ) -> [Float] {
        precondition(dtSeconds > 0 && data.count == grid.count)
        precondition(previous == nil || previous?.clearnessIndex.count == data.count)
        precondition(previous == nil || previous!.time < time)
        // Solar geometry is shared by the instantaneous value and the interval integral.
        let radius = time.getSunRadius()
        let radiusSquared = radius * radius
        let minimumElevation = sin(Float(1).degreesToRadians)
        let solarColatitude = (90 - time.getSunDeclination()).degreesToRadians
        let cosSolarColatitude = cos(solarColatitude)
        let sinSolarColatitude = sin(solarColatitude)
        let equationOfTime = time.getSunEquationOfTime()
        let hour = time.hourWithFraction
        let solarLongitude = (-15 * (hour - 12 + equationOfTime)).degreesToRadians
        let previousSolarLongitude = (-15 * (hour - Float(dtSeconds) / 3600 - 12 + equationOfTime)).degreesToRadians
        let longitudeInterval = previousSolarLongitude - solarLongitude
        var clearnessIndex = [Float](repeating: .nan, count: data.count)
        for i in data.indices {
            guard data[i].isFinite else { continue }
            let (latitude, longitude) = grid.getCoordinates(gridpoint: i)
            let colatitude = (90 - latitude).degreesToRadians
            let cosColatitude = cos(colatitude)
            let latitudeTerm = cosColatitude * cosSolarColatitude
            let longitudeTerm = sin(colatitude) * sinSolarColatitude
            var pointLongitude = longitude.degreesToRadians
            let instantaneousElevation = latitudeTerm + longitudeTerm * cos(solarLongitude - pointLongitude)
            let instant = instantaneousElevation / radiusSquared

            // Match the longitude wrapping and daylight-clipped integral used by
            // calculateRadiationBackwardsAveraged, without allocating a radiation field.
            if pointLongitude < solarLongitude - .pi { pointLongitude += 2 * .pi }
            if pointLongitude > solarLongitude + .pi { pointLongitude -= 2 * .pi }
            let argument = -latitudeTerm / longitudeTerm
            let daylightAngle = argument > 1 || argument < -1 ? .pi : acos(argument)
            let sunrise = pointLongitude + daylightAngle
            let sunset = pointLongitude - daylightAngle
            if previousSolarLongitude < sunset || solarLongitude > sunrise {
                data[i] = 0
                continue
            }
            let start = min(sunrise, previousSolarLongitude)
            let end = max(sunset, solarLongitude)
            let left = longitudeTerm * sin(start - pointLongitude) + start * cosColatitude * cosSolarColatitude
            let right = longitudeTerm * sin(end - pointLongitude) + end * cosColatitude * cosSolarColatitude
            let mean = max((left - right) / longitudeInterval / radiusSquared, 0)
            if mean == 0 {
                data[i] = 0
            } else if instantaneousElevation > minimumElevation {
                let currentKt = max(data[i], 0) / (instant * solarConstant)
                let elevation = asin(min(instantaneousElevation, 1)).radiansToDegrees
                let weight = min(max((elevation - 1) / 2, 0), 1)
                if weight < 1, let previous, previous.clearnessIndex[i].isFinite {
                    clearnessIndex[i] = weight * currentKt + (1 - weight) * max(previous.clearnessIndex[i], 0)
                } else {
                    clearnessIndex[i] = currentKt
                }
                data[i] = clearnessIndex[i] * solarConstant * mean
            } else if let previous, previous.clearnessIndex[i].isFinite {
                clearnessIndex[i] = max(previous.clearnessIndex[i], 0)
                data[i] = clearnessIndex[i] * solarConstant * mean
            } else {
                data[i] = max(data[i], 0)
            }
        }
        return clearnessIndex
    }
}
