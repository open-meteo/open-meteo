import Foundation
@testable import App
import XCTest


final class ArrayTests: XCTestCase {
    func testTranspose() {
        let spatial = Array2DFastSpace(data: [1,2,3,4,5,6], nLocations: 2, nTime: 3)
        let temporal = spatial.transpose()
        XCTAssertEqual(temporal.data, [1, 3, 5, 2, 4, 6])
        let spatial2 = temporal.transpose()
        XCTAssertEqual(spatial2.data, spatial.data)
    }
    
    func testDeaccumulate() {
        var data = Array2DFastTime(data: [1,2,3,1,2,3], nLocations: 1, nTime: 6)
        data.deaccumulateOverTime(slidingWidth: 3, slidingOffset: 0)
        XCTAssertEqual(data.data, [1, 1, 1, 1, 1, 1])
        
        var data2 = Array2DFastTime(data: [.nan,1,2,1,2,3], nLocations: 1, nTime: 6)
        data2.deaccumulateOverTime(slidingWidth: 3, slidingOffset: 0)
        XCTAssertTrue(data2.data[0].isNaN)
        XCTAssertEqual(data2.data[1..<6], [1, 1, 1, 1, 1])
        
        var data3 = Array2DFastTime(data: [.nan,1,2,3,1,2,3], nLocations: 1, nTime: 7)
        data3.deaccumulateOverTime(slidingWidth: 3, slidingOffset: 1)
        XCTAssertTrue(data3.data[0].isNaN)
        XCTAssertEqual(data3.data[1..<7], [1, 1, 1, 1, 1, 1])
    }
}
