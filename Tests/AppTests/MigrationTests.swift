import Foundation
@testable import App
import Testing

@Suite struct MigrationTests {
    @Test func xml() {
        let str = "<Contents><Key>enkfgdas.20210212/00/mem001/gdas.t00z.sfcf003.nemsio</Key></Contents><Contents><Key>enkfgdas.20210212/00/mem001/gdas.t00z.sfcf006.nemsio</Key></Contents>"
        let contents = Array(str.xmlSection("Contents"))
        #expect(contents.count == 2)
        #expect(contents[0] == "<Key>enkfgdas.20210212/00/mem001/gdas.t00z.sfcf003.nemsio</Key>")
        #expect(contents[1] == "<Key>enkfgdas.20210212/00/mem001/gdas.t00z.sfcf006.nemsio</Key>")

        #expect(contents[0].xmlFirst("Key") == "enkfgdas.20210212/00/mem001/gdas.t00z.sfcf003.nemsio")
        #expect(contents[1].xmlFirst("Key") == "enkfgdas.20210212/00/mem001/gdas.t00z.sfcf006.nemsio")
    }
}
