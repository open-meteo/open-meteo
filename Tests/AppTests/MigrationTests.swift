import Foundation
@testable import App
import XCTest

final class MigrationTests: XCTestCase {
    func testXml() {
        let str = "<Contents><Key>enkfgdas.20210212/00/mem001/gdas.t00z.sfcf003.nemsio</Key></Contents><Contents><Key>enkfgdas.20210212/00/mem001/gdas.t00z.sfcf006.nemsio</Key></Contents>"
        let contents = Array(str.xmlSection("Contents"))
        XCTAssertEqual(contents.count, 2)
        XCTAssertEqual(contents[0], "<Key>enkfgdas.20210212/00/mem001/gdas.t00z.sfcf003.nemsio</Key>")
        XCTAssertEqual(contents[1], "<Key>enkfgdas.20210212/00/mem001/gdas.t00z.sfcf006.nemsio</Key>")

        XCTAssertEqual(contents[0].xmlFirst("Key"), "enkfgdas.20210212/00/mem001/gdas.t00z.sfcf003.nemsio")
        XCTAssertEqual(contents[1].xmlFirst("Key"), "enkfgdas.20210212/00/mem001/gdas.t00z.sfcf006.nemsio")
    }
}
