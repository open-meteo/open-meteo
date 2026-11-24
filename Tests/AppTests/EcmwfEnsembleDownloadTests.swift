import Testing
@testable import App

struct EcmwfEnsembleDownloadTests {

    @Test func highResolutionFilesSeparateAtmosphereAndWaves() {
        let run = Timestamp(2026, 11, 24)
        let base = "https://example.com/"
        let root = base + "20261124/00z/ifs/0p1/"
        let prefix = "20261124000000-3h"
        let control = root + "oper/\(prefix)-oper-fc-sfc.grib2"
        #expect(EcmwfDomain.ifs01.getUrl(base: base, run: run, hour: 3) == [control])
        #expect(EcmwfDomain.ifs01_ensemble.getUrl(base: base, run: run, hour: 3) == [control, root + "enfo/\(prefix)-enfo-ef-sfc.grib2"])
        #expect(EcmwfDomain.ifs01_pressure_levels.getUrl(base: base, run: run, hour: 3) == [root + "oper/\(prefix)-oper-fc-pl.grib2"])
        #expect(EcmwfDomain.wam01.getUrl(base: base, run: run, hour: 3) == [root + "wave/\(prefix)-wave-fc-sfc.grib2"])
        // Wave ensembles include the control in the waef file.
        #expect(EcmwfDomain.wam01_ensemble.getUrl(base: base, run: run, hour: 3) == [root + "waef/\(prefix)-waef-ef-sfc.grib2"])
    }

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
