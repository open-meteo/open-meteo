import Foundation
@testable import App
import XCTest
//import Vapor


final class HelperTests: XCTestCase {
    func testIndexedCurl() {
        let index = """
            1:0:d=2022080800:UFLX:surface:anl:
            2:52676:d=2022080800:VFLX:surface:anl:
            3:104746:d=2022080800:SHTFL:surface:anl:
            4:147011:d=2022080800:LHTFL:surface:anl:
            5:191888:d=2022080800:TMP:surface:anl:
            6:276987:d=2022080800:SOILW:0-0.1 m below ground:anl:
            7:310844:d=2022080800:SOILW:0.1-0.4 m below ground:anl:
            8:344851:d=2022080800:TMP:0-0.1 m below ground:anl:
            9:387832:d=2022080800:TMP:0.1-0.4 m below ground:anl:
            10:430543:d=2022080800:WEASD:surface:anl:
            11:447714:d=2022080800:DLWRF:surface:anl:
            12:490126:d=2022080800:ULWRF:surface:anl:
            13:520276:d=2022080800:ULWRF:top of atmosphere:anl:
            14:564311:d=2022080800:USWRF:top of atmosphere:anl:
            """
        let range = index.split(separator: "\n").indexToRange { line in
            line.contains("SHTFL") || line.contains("LHTFL") || line.contains("USWRF") || line.contains("TMP")
        }
        XCTAssertEqual(range, "104746-276986,344851-430542,564311-")
        
        let range2 = index.split(separator: "\n").indexToRange { line in
            return true
        }
        XCTAssertEqual(range2, "0-")
        
        let range3 = index.split(separator: "\n").indexToRange { line in
            return false
        }
        XCTAssertTrue(range3 == nil)
        
        let range4 = index.split(separator: "\n").indexToRange { line in
            line.contains("TMP") || line.contains("UFLX")
        }
        XCTAssertEqual(range4, "0-52675,191888-276986,344851-430542")
        
        /*let curl = Curl(logger: Logger(label: ""))
        try! curl.downloadIndexedGrib(url: "https://nomads.ncep.noaa.gov/pub/data/nccf/com/cfs/prod/cfs.20220808/00/6hrly_grib_01/flxf2022080812.01.2022080800.grb2", to: "/Users/patrick/Downloads/test.grib", include: { line in
            line.contains(":")
        })*/
    }
    
    func testSpawn() async throws {
        let time = DispatchTime.now()
        async let a: () = try Process.spawn(cmd: "sleep", args: ["1"])
        async let b: () = try Process.spawn(cmd: "sleep", args: ["1"])
        try await a
        try await b
        let elapsedMs = Double((DispatchTime.now().uptimeNanoseconds - time.uptimeNanoseconds) / 1_000_000)
        XCTAssertLessThan(elapsedMs, 1200)
    }
}
