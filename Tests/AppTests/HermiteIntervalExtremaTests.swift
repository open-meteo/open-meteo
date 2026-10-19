import Foundation
import Testing
@testable import App

@Suite struct HermiteIntervalExtremaTests {
    @Test func constantAndLinear() {
        let constant = HermiteIntervalExtrema.calculate(a: 7, b: 7, c: 7, d: 7)
        #expect(constant.min == 7 && constant.max == 7)
        let rising = HermiteIntervalExtrema.calculate(a: -1, b: 0, c: 1, d: 2)
        #expect(rising.min == 0 && rising.max == 1)
        let falling = HermiteIntervalExtrema.calculate(a: 2, b: 1, c: 0, d: -1)
        #expect(falling.min == 0 && falling.max == 1)
    }

    @Test func quadraticInteriorExtrema() {
        let low = HermiteIntervalExtrema.calculate(a: 1, b: 0, c: 0, d: 1)
        #expect(low.min == -0.125 && low.max == 0)
        let high = HermiteIntervalExtrema.calculate(a: -1, b: 0, c: 0, d: -1)
        #expect(high.min == 0 && high.max == 0.125)
    }

    @Test func cubicWithTwoInteriorRoots() {
        // h(t) = t³ - 1.5t² + 0.5t, extrema at (3 ± sqrt(3))/6.
        let extrema = HermiteIntervalExtrema.calculate(a: -1, b: 0, c: 0, d: 1)
        let expected = Float(sqrt(3.0) / 36)
        #expect(abs(extrema.min + expected) < 1e-7)
        #expect(abs(extrema.max - expected) < 1e-7)
        let partial = HermiteIntervalExtrema.calculate(a: -1, b: 0, c: 0, d: 1, lower: 0, upper: 0.1)
        #expect(partial.min == 0)
        #expect(abs(partial.max - 0.036) < 1e-7)
    }

    @Test func repeatedRootAndRootAtEndpoint() {
        let repeated = HermiteIntervalExtrema.calculate(a: -1.25, b: 0, c: 0.25, d: 1.5)
        #expect(repeated.min == 0 && repeated.max == 0.25)
        let endpoint = HermiteIntervalExtrema.calculate(a: 1, b: 0, c: 1, d: 6)
        #expect(endpoint.min == 0 && endpoint.max == 1)
    }

    @Test func missingSamples() {
        let missingEndpoint = HermiteIntervalExtrema.calculate(a: 0, b: .nan, c: 1, d: 2)
        #expect(missingEndpoint.min.isNaN && missingEndpoint.max.isNaN)
        let missingNeighbors = HermiteIntervalExtrema.calculate(a: .nan, b: 0, c: 1, d: .nan)
        #expect(missingNeighbors.min == 0 && missingNeighbors.max == 1)
    }

    @Test(arguments: [900, 3600, 10800, 21600])
    func temperatureArraysAtNativeTimestep(dt: Int) {
        // Samples of x(x - 1), with one neighboring sample on each side.
        let data: [Float] = [2, 0, 0, 2, 6, 12]
        let start = Timestamp(2026, 1, 1)
        let time = TimerangeDt(start: start.add(-dt), nTime: data.count, dtSeconds: dt)
        let output = TimerangeDt(start: start.add(dt), nTime: 3, dtSeconds: dt)

        #expect(HermiteIntervalExtrema.calculate(data: data, time: time, output: output, minimum: true) == [-0.25, 0, 2])
        #expect(HermiteIntervalExtrema.calculate(data: data, time: time, output: output, minimum: false) == [0, 2, 6])
    }

    @Test func hourlyExtremaFromSixHourlyArray() {
        let data: [Float] = [2, 0, 0, 2]
        let start = Timestamp(2026, 1, 1)
        let time = TimerangeDt(start: start.add(hours: -6), nTime: data.count, dtSeconds: 21600)
        let output = TimerangeDt(start: start.add(hours: 1), nTime: 6, dtSeconds: 3600)
        let expectedMin: [Float] = [-0.13888889, -0.22222222, -0.25, -0.25, -0.22222222, -0.13888889]
        let expectedMax: [Float] = [0, -0.13888889, -0.22222222, -0.22222222, -0.13888889, 0]
        let minimum = HermiteIntervalExtrema.calculate(data: data, time: time, output: output, minimum: true)
        let maximum = HermiteIntervalExtrema.calculate(data: data, time: time, output: output, minimum: false)

        #expect(minimum.count == expectedMin.count)
        #expect(maximum.count == expectedMax.count)
        for (actual, expected) in zip(minimum, expectedMin) {
            #expect(abs(actual - expected) < 1e-7)
        }
        for (actual, expected) in zip(maximum, expectedMax) {
            #expect(abs(actual - expected) < 1e-7)
        }
    }

    @Test func sixHourlyExtremaFromThreeHourlyArray() {
        let data: [Float] = [2, 0, 0, 2, 6, 12, 20]
        let start = Timestamp(2026, 1, 1)
        let time = TimerangeDt(start: start.add(hours: -3), nTime: data.count, dtSeconds: 10800)
        let output = TimerangeDt(start: start.add(hours: 6), nTime: 2, dtSeconds: 21600)

        #expect(HermiteIntervalExtrema.calculate(data: data, time: time, output: output, minimum: true) == [-0.25, 2])
        #expect(HermiteIntervalExtrema.calculate(data: data, time: time, output: output, minimum: false) == [2, 12])
    }
}
