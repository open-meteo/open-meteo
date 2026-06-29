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

    /// Assert the computed rise/set for each day against reference times from timeanddate.com.
    ///
    /// `firstLocalDay` is local midnight of the first reference day labelled as if it were UTC
    /// (e.g. `Timestamp(2024, 1, 1)`); the actual UTC window is recovered by removing the offset,
    /// exactly like `dailyDisplay`. `reference` times are likewise the local clock times labelled
    /// as UTC, so the comparison subtracts the offset back out. A `nil` entry asserts no event.
    /// The compact MiniMoon series reproduces the references to within ~1 minute, hence the ±2 minute tolerance.
    private func expectMoonRiseSet(lat: Float, lon: Float, utcOffsetSeconds: Int, firstLocalDay: Timestamp, reference: [(rise: Timestamp?, set: Timestamp?)], sourceLocation: SourceLocation = #_sourceLocation) {
        let toleranceSeconds = 120
        let start = firstLocalDay.add(-utcOffsetSeconds)
        let times = Moon.calculateMoonRiseSet(timeRange: start..<start.add(reference.count * 86400), lat: lat, lon: lon)
        #expect(times.rise.count == reference.count, sourceLocation: sourceLocation)
        for (day, expected) in reference.enumerated() {
            if let expectedRise = expected.rise {
                #expect(!times.rise[day].isNoData, "day \(day): expected a moonrise", sourceLocation: sourceLocation)
                #expect(abs(times.rise[day].add(utcOffsetSeconds).timeIntervalSince1970 - expectedRise.timeIntervalSince1970) <= toleranceSeconds, "day \(day): moonrise off by more than \(toleranceSeconds)s", sourceLocation: sourceLocation)
            } else {
                #expect(times.rise[day].isNoData, "day \(day): expected no moonrise", sourceLocation: sourceLocation)
            }
            if let expectedSet = expected.set {
                #expect(!times.set[day].isNoData, "day \(day): expected a moonset", sourceLocation: sourceLocation)
                #expect(abs(times.set[day].add(utcOffsetSeconds).timeIntervalSince1970 - expectedSet.timeIntervalSince1970) <= toleranceSeconds, "day \(day): moonset off by more than \(toleranceSeconds)s", sourceLocation: sourceLocation)
            } else {
                #expect(times.set[day].isNoData, "day \(day): expected no moonset", sourceLocation: sourceLocation)
            }
        }
    }

    /// Berlin (52.52°N, 13.41°E, UTC+1), 2026-01-01..08. Reference moonrise/moonset (local CET) from
    /// timeanddate.com/moon/germany/berlin. The week brackets the 2026-01-03 full moon: a waxing
    /// gibbous rising in the afternoon/evening and setting in the morning, with the rise drifting later
    /// each day as the moon wanes.
    @Test func moonRiseSetBerlin() {
        expectMoonRiseSet(lat: 52.52, lon: 13.41, utcOffsetSeconds: 3600, firstLocalDay: Timestamp(2026, 1, 1), reference: [
            (rise: Timestamp(2026, 1, 1, 13, 21), set: Timestamp(2026, 1, 1, 06, 38)),
            (rise: Timestamp(2026, 1, 2, 14, 22), set: Timestamp(2026, 1, 2, 07, 57)),
            (rise: Timestamp(2026, 1, 3, 15, 43), set: Timestamp(2026, 1, 3, 08, 54)),
            (rise: Timestamp(2026, 1, 4, 17, 14), set: Timestamp(2026, 1, 4, 09, 31)),
            (rise: Timestamp(2026, 1, 5, 18, 46), set: Timestamp(2026, 1, 5, 09, 55)),
            (rise: Timestamp(2026, 1, 6, 20, 13), set: Timestamp(2026, 1, 6, 10, 11)),
            (rise: Timestamp(2026, 1, 7, 21, 34), set: Timestamp(2026, 1, 7, 10, 24)),
            (rise: Timestamp(2026, 1, 8, 22, 51), set: Timestamp(2026, 1, 8, 10, 34)),
        ])
    }

    /// Sydney (33.87°S, 151.21°E, UTC+11 AEDT), 2026-01-01..08 — southern hemisphere cross-check.
    /// Reference moonrise/moonset (local AEDT) from timeanddate.com/moon/australia/sydney.
    @Test func moonRiseSetSydney() {
        expectMoonRiseSet(lat: -33.87, lon: 151.21, utcOffsetSeconds: 11 * 3600, firstLocalDay: Timestamp(2026, 1, 1), reference: [
            (rise: Timestamp(2026, 1, 1, 18, 08), set: Timestamp(2026, 1, 1, 02, 52)),
            (rise: Timestamp(2026, 1, 2, 19, 19), set: Timestamp(2026, 1, 2, 03, 48)),
            (rise: Timestamp(2026, 1, 3, 20, 21), set: Timestamp(2026, 1, 3, 04, 54)),
            (rise: Timestamp(2026, 1, 4, 21, 12), set: Timestamp(2026, 1, 4, 06, 06)),
            (rise: Timestamp(2026, 1, 5, 21, 53), set: Timestamp(2026, 1, 5, 07, 21)),
            (rise: Timestamp(2026, 1, 6, 22, 27), set: Timestamp(2026, 1, 6, 08, 32)),
            (rise: Timestamp(2026, 1, 7, 22, 56), set: Timestamp(2026, 1, 7, 09, 40)),
            (rise: Timestamp(2026, 1, 8, 23, 22), set: Timestamp(2026, 1, 8, 10, 43)),
        ])
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
