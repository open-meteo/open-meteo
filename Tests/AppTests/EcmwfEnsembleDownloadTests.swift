import Testing
@testable import App

struct EcmwfEnsembleDownloadTests {

    private func entry(_ param: String, member: String? = nil, level: String? = nil, type: Curl.EcmwfIndexEntry.LevelType = .sfc, offset: Int = 10) -> Curl.EcmwfIndexEntry {
        .init(levtype: type, levelist: level, number: member, param: param, _offset: offset, _length: 5)
    }

    @Test func matchingDistinguishesPressureAndSoilLevelsFromSurfaceHeights() {
        #expect(EcmwfVariable.temperature_2m.matches(entry("2t")))
        #expect(EcmwfVariable.relative_humidity_2m.matches(entry("2d")))
        #expect(EcmwfVariable.snow_depth.matches(entry("rsn")))
        #expect(EcmwfVariable.snow_depth_water_equivalent.matches(entry("sd")))
        #expect(EcmwfVariable.temperature_2m_max.matches(entry("max_2t")))
        #expect(EcmwfVariable.temperature_2m_max.matches(entry("mx2t6")))
        #expect(EcmwfVariable.soil_temperature_7_to_28cm.matches(entry("sot", level: "2", type: .sol)))
        #expect(!EcmwfVariable.soil_temperature_7_to_28cm.matches(entry("sot", level: "1", type: .sol)))
        #expect(EcmwfVariable.soil_temperature_7_to_28cm.matches(entry("sot", type: .sol)))
        #expect(EcmwfVariable.soil_temperature_7_to_28cm.matches(shortName: "sot", level: 2))
        #expect(!EcmwfVariable.soil_temperature_7_to_28cm.matches(shortName: "sot", level: 1))
        #expect(EcmwfVariable.vertical_velocity_500hPa.matches(entry("w", level: "500", type: .pl)))
        #expect(!EcmwfVariable.vertical_velocity_500hPa.matches(entry("w", level: "700", type: .pl)))
        #expect(!EcmwfVariable.temperature_500hPa.matches(entry("t", level: "500")))
        #expect(EcmwfVariable.geopotential_height_500hPa.matches(entry("z", level: "500", type: .pl)))
    }

    @Test func gustMatchingIncludesIntervalSpecificNames() {
        for parameter in ["10fg", "10fg3", "10fg6", "max_i10fg"] {
            #expect(EcmwfVariable.wind_gusts_10m.matches(entry(parameter)))
            #expect(EcmwfVariable.wind_gusts_10m.matches(shortName: parameter, level: 10))
        }
        #expect(!EcmwfVariable.wind_gusts_10m.matches(entry("10u")))
    }

}
