import Foundation
@testable import App
import XCTest

final class MigrationTests: XCTestCase {
    func testFileTransform() {
        let m = MigrationCommand()
        var new = m.transform(file: "temperature_2m_89.om", type: "chunk")
        XCTAssertEqual(new?.directory, "temperature_2m")
        XCTAssertEqual(new?.file, "chunk_89.om")
        
        new = m.transform(file: "lat_-81.om", type: "chunk")
        XCTAssertEqual(new?.directory, "static")
        XCTAssertEqual(new?.file, "lat_-81.om")
        
        new = m.transform(file: "river_discharge_member02_89.om", type: "chunk")
        XCTAssertEqual(new?.directory, "river_discharge_member02")
        XCTAssertEqual(new?.file, "chunk_89.om")
        
        // ncep cfs -> add memberNN to variable name
        new = m.transform(file: "soil_moisture_0_to_10cm_1_96.om", type: "chunk")
        XCTAssertEqual(new?.directory, "soil_moisture_0_to_10cm_member01")
        XCTAssertEqual(new?.file, "chunk_96.om")
        
        new = m.transform(file: "soil_temperature_28_to_100cm_mean_linear_bias_seasonal.om", type: "chunk")
        XCTAssertEqual(new?.directory, "soil_temperature_28_to_100cm_mean")
        XCTAssertEqual(new?.file, "linear_bias_seasonal.om")
        
        new = m.transform(file: "HSURF.om", type: "chunk")
        XCTAssertEqual(new?.directory, "static")
        XCTAssertEqual(new?.file, "HSURF.om")
        
        new = m.transform(file: "wind_u_component_10m_1978.om", type: "year")
        XCTAssertEqual(new?.directory, "wind_u_component_10m")
        XCTAssertEqual(new?.file, "year_1978.om")
        
        new = m.transform(file: "temperature_2m_mean_0.om", type: "master")
        XCTAssertEqual(new?.directory, "temperature_2m_mean")
        XCTAssertEqual(new?.file, "master_0.om")
    }
    
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
