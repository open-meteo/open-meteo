import Foundation
@testable import App
import XCTest

/// Test low level stuff
final class IntrinsicsTests: XCTestCase {
    func test2DSequence() async {
        let seq2d = (1..<3).iterate2D(over: 10..<12)
        let res = seq2d.map({ "\($0)" })
        XCTAssertEqual(res, ["(y: 1, x: 10)", "(y: 1, x: 11)", "(y: 2, x: 10)", "(y: 2, x: 11)"])
        XCTAssertTrue((0..<10).iterate2D(over: 0..<0).map{"\($0)"}.isEmpty)
        XCTAssertTrue((0..<0).iterate2D(over: 0..<10).map{"\($0)"}.isEmpty)
    }
}
