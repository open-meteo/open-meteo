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
}
