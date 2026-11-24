import Testing
@testable import App

struct EcmwfEnsembleDownloadTests {

    private func entry(_ param: String, level: Int = 0, type: String = "surface") -> EcmwfLocalGribFile.Field {
        .init(range: 0..<20, submessage: 0, shortName: param, level: level, typeOfLevel: type, member: 0)
    }

    @Test func matchingDistinguishesPressureAndSoilLevelsFromSurfaceHeights() {
        #expect(EcmwfVariable.soil_temperature_7_to_28cm.matches(entry("sot", level: 2, type: "depthBelowLandLayer")))
        #expect(!EcmwfVariable.soil_temperature_7_to_28cm.matches(entry("sot", level: 1, type: "depthBelowLandLayer")))
        #expect(EcmwfVariable.vertical_velocity_500hPa.matches(entry("w", level: 500, type: "isobaricInhPa")))
        #expect(!EcmwfVariable.vertical_velocity_500hPa.matches(entry("w", level: 700, type: "isobaricInhPa")))
        #expect(!EcmwfVariable.temperature_500hPa.matches(entry("t", level: 500)))
        #expect(EcmwfVariable.geopotential_height_500hPa.matches(entry("z", level: 500, type: "isobaricInhPa")))
    }

    @Test func gustMatchingIncludesIntervalSpecificNames() {
        for parameter in ["10fg", "10fg3", "10fg6", "max_i10fg"] {
            #expect(EcmwfVariable.wind_gusts_10m.matches(entry(parameter)))
            #expect(EcmwfVariable.wind_gusts_10m.matches(shortName: parameter, level: 10))
        }
        #expect(!EcmwfVariable.wind_gusts_10m.matches(entry("10u")))
    }

}
