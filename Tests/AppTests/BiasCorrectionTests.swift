import Foundation
@testable import App
import XCTest


final class BiasCorrectionTests: XCTestCase {
    func testQuantileDeltaMapping() {
        // TODO: new QDM test
        /*let reference = ArraySlice([Float(0),-1,2,3,4,4,5,6,5,1,2,3,4,7,8,5.5,1,2,3,4,9.1,11])
        let control = ArraySlice([Float(0),  -3,4,5,6,7,1,3,5,6,7,8,9,9,8,5.5,1,2,3,4,9.1,11])
        let forecast = ArraySlice([Float(1),3,4,5,6,7,8,5,3,7])
        
        let qdm = QuantileDeltaMappingBiasCorrection.quantileDeltaMappingMonthly(reference: reference, control: control, referenceTime: TimerangeDt(start: Timestamp(2021,1,1), nTime: reference.count, dtSeconds: 86400), forecast: forecast, forecastTime: TimerangeDt(start: Timestamp(2021,1,1), nTime: forecast.count, dtSeconds: 86400), type: .absoluteChage)
        print(qdm)
        XCTAssertEqualArray(qdm, [1.0230918, 2.0224493, 2.1090956, 3.0580835, 3.962638, 6.964262, 6.079171, 3.0605016, 2.0267951, 6.975686], accuracy: 0.001)
        
        let qdmRelative = QuantileDeltaMappingBiasCorrection.quantileDeltaMappingMonthly(reference: reference, control: control, referenceTime: TimerangeDt(start: Timestamp(2021,1,1), nTime: reference.count, dtSeconds: 86400), forecast: forecast, forecastTime: TimerangeDt(start: Timestamp(2021,1,1), nTime: forecast.count, dtSeconds: 86400), type: .relativeChange)
        print(qdmRelative)
        XCTAssertEqualArray(qdmRelative, [0.0, 1.9981737, 2.443818, 3.3550663, 4.1394744, 6.2328215, 6.263566, 3.356181, 2.0023994, 6.937058], accuracy: 0.001)*/
    }
    
    func testInterpolation() {
        XCTAssertEqual(Interpolations.linear(a: 2, b: 4, fraction: 0.75), 3.5)
        
        let inverse = Interpolations.linearWeighted(value: 3.5, fraction: 0.75)
        XCTAssertEqual(inverse.a, 0.875)
        XCTAssertEqual(inverse.b, 2.625)
        XCTAssertEqual(inverse.weightA, 0.25)
        XCTAssertEqual(inverse.weightB, 0.75)
    }
}
