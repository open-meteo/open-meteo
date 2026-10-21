import Foundation
@testable import OmTime
import Testing

@Suite struct NumberExtensionsTests {
    @Test func fixedDecimals() {
        for (value, decimals, expected) in [
            (12.5, 0, "13"), (-12.5, 0, "-13"),
            (12.25, 1, "12.3"), (-12.25, 1, "-12.3"),
            (1.999, 2, "2.00"), (-0.001, 2, "-0.00"),
            (0, 3, "0.000"), (1.25, 7, "1.2500000")
        ] {
            #expect(value.formatted(decimals: decimals) == expected)
            #expect(Float(value).formatted(decimals: decimals) == expected)
        }
    }

    @Test func precisionOutsideLookupTable() {
        #expect(Double(1.25).formatted(decimals: 8) == "1.25000000")
        #expect(Float(1.25).formatted(decimals: 8) == "1.25000000")
    }

    @Test(arguments: [0, 1, 7]) func largeFiniteValues(decimals: Int) throws {
        // Cover Int boundaries, scaling beyond Int, and scaling to infinity.
        let floats: [Float] = [
            Float(Int.max).nextDown, Float(Int.max), Float(Int.min),
            1e18, -1e18, .greatestFiniteMagnitude, -.greatestFiniteMagnitude
        ]
        for value in floats {
            let formatted = value.formatted(decimals: decimals)
            #expect(formatted == String(format: "%.*f", decimals, Double(value)))
            #expect(try JSONDecoder().decode([Float].self, from: Data("[\(formatted)]".utf8)) == [value])
        }
        let doubles: [Double] = [
            Double(Int.max).nextDown, Double(Int.max), Double(Int.min),
            1e18, -1e18, .greatestFiniteMagnitude, -.greatestFiniteMagnitude
        ]
        for value in doubles {
            let formatted = value.formatted(decimals: decimals)
            #expect(formatted == String(format: "%.*f", decimals, value))
            #expect(try JSONDecoder().decode([Double].self, from: Data("[\(formatted)]".utf8)) == [value])
        }
    }

    @Test(arguments: [0, 1, 7]) func nonFiniteValues(decimals: Int) {
        for (value, expected): (Double, String) in [(.nan, "nan"), (.infinity, "inf"), (-.infinity, "-inf")] {
            #expect(value.formatted(decimals: decimals) == expected)
            #expect(Float(value).formatted(decimals: decimals) == expected)
        }
    }
}
