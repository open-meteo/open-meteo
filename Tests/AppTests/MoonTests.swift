import Foundation
@testable import App
import Testing

@Suite struct MoonTests {
    /// Geocentric ecliptic and equatorial position against Meeus, "Astronomical Algorithms", example 47.a
    /// (1992 April 12, 0h TD). The compact MiniMoon series is only accurate to a few arc-minutes, hence the loose tolerance.
    @Test func moonPosition() {
        let time = Timestamp(1992, 4, 12)
        let ecliptic = Moon.eclipticPosition(time)
        #expect((ecliptic.longitude * 180 / .pi).isApproximatelyEqual(to: 133.162655, absoluteTolerance: 0.1))
        #expect((ecliptic.latitude * 180 / .pi).isApproximatelyEqual(to: -3.229126, absoluteTolerance: 0.1))

        let equatorial = Moon.equatorialPosition(time)
        #expect((equatorial.rightAscension * 180 / .pi).isApproximatelyEqual(to: 134.688470, absoluteTolerance: 0.2))
        #expect((equatorial.declination * 180 / .pi).isApproximatelyEqual(to: 13.768368, absoluteTolerance: 0.2))
    }

    /// Moon phase against known new and full moon instants.
    @Test func moonPhase() {
        // New moon 2024-01-11 11:57 UTC -> phase close to 0 (or 1)
        let newMoon = Moon.calculateMoonPhase(timeRange: Timestamp(2024, 1, 11)..<Timestamp(2024, 1, 12))[0]
        #expect(min(newMoon, 1 - newMoon) < 0.04)

        // Full moon 2024-01-25 17:54 UTC -> phase close to 0.5
        let fullMoon = Moon.calculateMoonPhase(timeRange: Timestamp(2024, 1, 25)..<Timestamp(2024, 1, 26))[0]
        #expect(abs(fullMoon - 0.5) < 0.04)

        // First quarter 2024-01-18 03:52 UTC -> phase close to 0.25
        let firstQuarter = Moon.calculateMoonPhase(timeRange: Timestamp(2024, 1, 18)..<Timestamp(2024, 1, 19))[0]
        #expect(abs(firstQuarter - 0.25) < 0.04)
    }

    /// Rise/set are found by root-finding the altitude. Verify that the moon is actually at the rise/set
    /// standard altitude (+0.125°) at the returned timestamps, which validates the position model and the solver together.
    @Test func moonRiseSetConsistency() {
        let lat: Float = 52.52
        let lon: Float = 13.41
        let times = Moon.calculateMoonRiseSet(timeRange: Timestamp(2024, 1, 1)..<Timestamp(2024, 1, 8), lat: lat, lon: lon)
        #expect(times.rise.count == 7)
        #expect(times.set.count == 7)

        let latRad = Double(lat) * .pi / 180
        let latSin = sin(latRad)
        let latCos = cos(latRad)
        let lonRad = Double(lon) * .pi / 180
        let sinH0 = sin(0.125 * .pi / 180)

        for event in times.rise + times.set where !event.isNoData {
            let sinAlt = Moon.sinAltitude(event, latSin: latSin, latCos: latCos, lon: lonRad)
            // within ~0.2° of the horizon crossing
            #expect(abs(asin(sinAlt) - asin(sinH0)) < 0.2 * .pi / 180)
        }
    }

    /// Berlin 2024-01-01 (UTC+1). A few days after the 2023-12-27 full moon the moon is a waning
    /// gibbous that rises in the evening and sets in the late morning. `timeRange` is local midnight
    /// expressed in UTC, exactly like `dailyDisplay`.
    @Test func moonRiseSetBerlin() {
        let utcOffsetSeconds = 3600
        // local midnight 2024-01-01 00:00 CET == 2023-12-31 23:00 UTC
        let localMidnightInUtc = Timestamp(2023, 12, 31, 23)
        let times = Moon.calculateMoonRiseSet(timeRange: localMidnightInUtc..<localMidnightInUtc.add(86400), lat: 52.52, lon: 13.41)
        #expect(times.rise.count == 1)
        let rise = times.rise[0].add(utcOffsetSeconds)
        let set = times.set[0].add(utcOffsetSeconds)
        #expect(!times.rise[0].isNoData)
        #expect(!times.set[0].isNoData)
        // both events fall on the requested local day
        #expect(rise.iso8601_YYYY_MM_dd == "2024-01-01")
        #expect(set.iso8601_YYYY_MM_dd == "2024-01-01")
        // waning gibbous: rises in the evening, sets in the late morning (local time)
        #expect((20...23).contains(rise.hour))
        #expect((10...12).contains(set.hour))
    }

    /// At high latitudes the moon can remain above or below the horizon for a whole day,
    /// in which case the corresponding entry must be the `noData` sentinel.
    @Test func moonRiseSetPolar() {
        // Longyearbyen, Svalbard (78.22°N). Verify the function tolerates missing events without crashing.
        let times = Moon.calculateMoonRiseSet(timeRange: Timestamp(2024, 1, 1)..<Timestamp(2024, 1, 31), lat: 78.22, lon: 15.65)
        #expect(times.rise.count == 30)
        // at least one day in January has no moonrise or no moonset at this latitude
        #expect(times.rise.contains(where: { $0.isNoData }) || times.set.contains(where: { $0.isNoData }))
    }
}
