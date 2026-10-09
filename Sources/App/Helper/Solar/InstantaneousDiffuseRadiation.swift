import Foundation

extension Zensun {
    /// Seed a diffuse-to-total ratio cache from instantaneous fields, without needing an average.
    public static func instantaneousDiffuseRadiationRatio(data: [Float], shortwaveInstant: [Float]) -> [Float] {
        precondition(data.count == shortwaveInstant.count)
        return zip(data, shortwaveInstant).map { diffuse, total in
            guard diffuse.isFinite, total.isFinite, total > 0 else { return .nan }
            return min(max(diffuse / total, 0), 1)
        }
    }

    /// Estimate averaged diffuse flux from the instantaneous diffuse/total ratio and a native
    /// total-flux average. Returns ratios for the next step, separate from the geometry-based KT.
    /// Blend current and cached ratios from 3° to 1°, then reuse the cache below 1°.
    /// Ratios are bounded to 0...1. Without history, a positive total permits a current ratio;
    /// otherwise a sunlit average is missing. Fully dark averages reset the cache.
    public static func instantaneousDiffuseRadiationToBackwardsAverage(
        data: inout [Float], shortwaveInstant: [Float], shortwaveAverage: [Float],
        previous: (time: Timestamp, ratio: [Float])?, grid: any Gridable, time: Timestamp
    ) -> [Float] {
        precondition(data.count == grid.count && shortwaveInstant.count == data.count)
        precondition(shortwaveAverage.count == data.count)
        precondition(previous == nil || previous?.ratio.count == data.count)
        precondition(previous == nil || previous!.time < time)
        let solarColatitude = (90 - time.getSunDeclination()).degreesToRadians
        let cosSolarColatitude = cos(solarColatitude)
        let sinSolarColatitude = sin(solarColatitude)
        let solarLongitude = (-15 * (time.hourWithFraction - 12 + time.getSunEquationOfTime())).degreesToRadians
        var ratios = instantaneousDiffuseRadiationRatio(data: data, shortwaveInstant: shortwaveInstant)
        for i in data.indices {
            guard data[i].isFinite, shortwaveInstant[i].isFinite else {
                data[i] = .nan
                continue
            }
            if shortwaveAverage[i].isFinite, shortwaveAverage[i] <= 0 {
                data[i] = 0
                ratios[i] = .nan
                continue
            }
            let (latitude, longitude) = grid.getCoordinates(gridpoint: i)
            let colatitude = (90 - latitude).degreesToRadians
            let sinElevation = cos(colatitude) * cosSolarColatitude
                + sin(colatitude) * sinSolarColatitude * cos(solarLongitude - longitude.degreesToRadians)
            let elevation = asin(min(max(sinElevation, -1), 1)).radiansToDegrees
            let weight = min(max((elevation - 1) / 2, 0), 1)
            let current = ratios[i]
            if let previous, previous.ratio[i].isFinite {
                let cached = min(max(previous.ratio[i], 0), 1)
                ratios[i] = current.isFinite ? weight * current + (1 - weight) * cached : cached
            } else {
                ratios[i] = current
            }
            data[i] = shortwaveAverage[i].isFinite ? ratios[i] * max(shortwaveAverage[i], 0) : .nan
        }
        return ratios
    }
}
