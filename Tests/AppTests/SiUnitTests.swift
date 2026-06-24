import Foundation
@testable import App
import Testing

@Suite struct SiUnitTests {
    /// Specific humidity (g/kg) gets 5 output decimals; the SDK default stays 2; other units unchanged.
    @Test func apiSignificantDigitsRaisesSpecificHumidity() {
        #expect(SiUnit.gramPerKilogram.apiSignificantDigits == 5)
        #expect(SiUnit.gramPerKilogram.significantDigits == 2)        // SDK default untouched
        #expect(SiUnit.celsius.apiSignificantDigits == SiUnit.celsius.significantDigits)
        #expect(SiUnit.hectopascal.apiSignificantDigits == SiUnit.hectopascal.significantDigits)
    }

    /// A dry-layer qv that rounded to "0.00" at 2 decimals now formats with real digits at 5.
    @Test func dryLayerSpecificHumidityFormatsNonZero() {
        let v: Float = 0.00043
        #expect(v.formatted(decimals: SiUnit.gramPerKilogram.apiSignificantDigits) == "0.00043")
        #expect(v.formatted(decimals: SiUnit.gramPerKilogram.significantDigits) == "0.00")
    }
}
