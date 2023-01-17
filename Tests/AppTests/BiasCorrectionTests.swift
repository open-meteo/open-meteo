import Foundation
@testable import App
import XCTest


final class BiasCorrectionTests: XCTestCase {
    func testInterpolate() {
        let a = [Float(0),1,2,3,4,5]
        let b = [Float(2),3,4,5,6,7]
        XCTAssertEqual(BiasCorrection.interpolate(a, b, x: 0.5, extrapolate: false), 2.5)
        XCTAssertEqual(BiasCorrection.interpolate(a, b, x: 4.5, extrapolate: false), 6.5)
        XCTAssertEqual(BiasCorrection.interpolate(a, b, x: 5.5, extrapolate: false), 7.0)
        XCTAssertEqual(BiasCorrection.interpolate(a, b, x: 5.5, extrapolate: true), 7.5)
        XCTAssertEqual(BiasCorrection.interpolate(a, b, x: -0.5, extrapolate: false), 2.0)
    }
    
    func testCdf() {
        let a = [Float(0),1,2,3,4,4,5,6,5,1,2,3,4,7,8,5.5,1,2,3,4,9.1,11]
        let bins = Bins(min: 0, max: 10, nQuantiles: 10)
        XCTAssertEqual(BiasCorrection.calculateCdf(ArraySlice(a), bins: bins), [0, 1, 4, 7, 10, 14, 17, 18, 19, 22])
    }
    
    func testQuantileMapping() {
        let reference = ArraySlice([Float(0),-1,2,3,4,4,5,6,5,1,2,3,4,7,8,5.5,1,2,3,4,9.1,11])
        let control = ArraySlice([Float(0),-3,4,5,6,7,1,3,5,6,7,8,9,9,8,5.5,1,2,3,4,9.1,11])
        let forecast = ArraySlice([Float(0),3,4,5,6,7])
        XCTAssertEqualArray(BiasCorrection.quantileMapping(reference: reference, control: control, forecast: forecast, type: .absoluteChage), [0.011428531, 2.1085713, 2.12, 3.0514286, 3.9971428, 5.051429], accuracy: 0.001)
        XCTAssertEqualArray(BiasCorrection.quantileMapping(reference: reference, control: control, forecast: forecast, type: .relativeChange), [0.011428531, 2.1085713, 2.12, 3.0514286, 3.9971428, 5.051429], accuracy: 0.001)
    }
}
