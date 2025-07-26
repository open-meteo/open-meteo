import Foundation
@testable import App
import Testing

/// Test low level stuff
@Suite struct IntrinsicsTests {
    @Test func _2DSequence() async {
        let seq2d = (1..<3).iterate2D(over: 10..<12)
        let res = seq2d.map({ "\($0)" })
        #expect(res == ["(y: 1, x: 10)", "(y: 1, x: 11)", "(y: 2, x: 10)", "(y: 2, x: 11)"])
        #expect((0..<10).iterate2D(over: 0..<0).map { "\($0)" }.isEmpty)
        #expect((0..<0).iterate2D(over: 0..<10).map { "\($0)" }.isEmpty)
    }
}
