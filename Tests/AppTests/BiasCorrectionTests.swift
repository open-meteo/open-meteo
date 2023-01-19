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
        let control = ArraySlice([Float(0),  -3,4,5,6,7,1,3,5,6,7,8,9,9,8,5.5,1,2,3,4,9.1,11])
        let forecast = ArraySlice([Float(1),3,4,5,6,7,8,5,3,7])
        
        let qdm = BiasCorrection.quantileDeltaMappingMonthly(reference: reference, control: control, referenceTime: TimerangeDt(start: Timestamp(2021,1,1), nTime: reference.count, dtSeconds: 86400), forecast: forecast, forecastTime: TimerangeDt(start: Timestamp(2021,1,1), nTime: forecast.count, dtSeconds: 86400), type: .absoluteChage)
        print(qdm)
        XCTAssertEqualArray(qdm, [1.0230918, 2.0224493, 2.1090956, 3.0580835, 3.962638, 6.964262, 6.079171, 3.0605016, 2.0267951, 6.975686], accuracy: 0.001)
        
        let qdmRelative = BiasCorrection.quantileDeltaMappingMonthly(reference: reference, control: control, referenceTime: TimerangeDt(start: Timestamp(2021,1,1), nTime: reference.count, dtSeconds: 86400), forecast: forecast, forecastTime: TimerangeDt(start: Timestamp(2021,1,1), nTime: forecast.count, dtSeconds: 86400), type: .relativeChange)
        print(qdmRelative)
        XCTAssertEqualArray(qdmRelative, [0.663053, 1.9030098, 3.5860853, 4.774967, 5.8174477, 11.54507, 7.788539, 4.769123, 1.9050246, 11.579601], accuracy: 0.001)
    }
}
