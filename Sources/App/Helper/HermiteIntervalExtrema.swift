import Foundation

/// Extrema of the same equally spaced cubic Hermite curve used by interpolateHermite.
/// Time is normalized to [0, 1] between b and c; changing the sample spacing does not
/// change its extrema. Only endpoints and the (at most two) derivative roots are evaluated.
enum HermiteIntervalExtrema {
    static func calculate(a: Float, b: Float, c: Float, d: Float, lower: Double = 0, upper: Double = 1) -> (min: Float, max: Float) {
        guard b.isFinite, c.isFinite else { return (.nan, .nan) }
        let b = Double(b), c = Double(c)
        // Missing outer neighbors use the nearest endpoint, as at interpolation boundaries.
        let a = a.isFinite ? Double(a) : b
        let d = d.isFinite ? Double(d) : c
        let slope0 = (c - a) / 2
        let slope1 = (d - b) / 2
        let cubic = 2 * (b - c) + slope0 + slope1
        let quadratic = 3 * (c - b) - 2 * slope0 - slope1
        func value(_ t: Double) -> Double {
            ((cubic * t + quadratic) * t + slope0) * t + b
        }
        var minimum = Swift.min(value(lower), value(upper))
        var maximum = Swift.max(value(lower), value(upper))
        func include(_ t: Double) {
            guard t > lower, t < upper else { return }
            let v = value(t)
            minimum = Swift.min(minimum, v)
            maximum = Swift.max(maximum, v)
        }
        let qa = 3 * cubic, qb = 2 * quadratic, qc = slope0
        if qa == 0 {
            if qb != 0 { include(-qc / qb) }
        } else {
            let discriminant = qb * qb - 4 * qa * qc
            if discriminant >= 0 {
                // Avoid cancellation in the quadratic formula; the other root follows
                // from the product of the roots. Also handles a repeated zero root.
                let q = -0.5 * (qb + (qb >= 0 ? 1 : -1) * sqrt(discriminant))
                include(q / qa)
                if q != 0 { include(qc / q) }
            }
        }
        return (Float(minimum), Float(maximum))
    }

    /// Native-grid samples covering [first output - output dt, last output], with
    /// one extra neighbor on either side for the Hermite slopes.
    static func readTime(output: TimerangeDt, modelDtSeconds: Int) -> TimerangeDt {
        let first = output.range.lowerBound.add(-output.dtSeconds).floor(toNearest: modelDtSeconds)
        let last = output.range.upperBound.add(-output.dtSeconds).ceil(toNearest: modelDtSeconds)
        return TimerangeDt(start: first.add(-modelDtSeconds), to: last.add(2 * modelDtSeconds), dtSeconds: modelDtSeconds)
    }

    static func calculate(data: [Float], time: TimerangeDt, output: TimerangeDt, minimum: Bool) -> [Float] {
        precondition(data.count == time.count)
        return output.map { end in
            var cursor = end.add(-output.dtSeconds)
            var result: Float = minimum ? .infinity : -.infinity
            while cursor < end {
                let segmentStart = cursor.floor(toNearest: time.dtSeconds)
                let segmentEnd = Swift.min(segmentStart.add(time.dtSeconds), end)
                let index = (segmentStart.timeIntervalSince1970 - time.range.lowerBound.timeIntervalSince1970) / time.dtSeconds
                let lower = Double(cursor.timeIntervalSince1970 - segmentStart.timeIntervalSince1970) / Double(time.dtSeconds)
                let upper = Double(segmentEnd.timeIntervalSince1970 - segmentStart.timeIntervalSince1970) / Double(time.dtSeconds)
                let extrema = calculate(a: data[index - 1], b: data[index], c: data[index + 1], d: data[index + 2], lower: lower, upper: upper)
                let value = minimum ? extrema.min : extrema.max
                // A missing interval endpoint leaves this output interval unknown.
                guard value.isFinite else { return .nan }
                result = minimum ? Swift.min(result, value) : Swift.max(result, value)
                cursor = segmentEnd
            }
            return result
        }
    }
}
