import Testing
@testable import App

struct EcmwfEnsembleDownloadTests {
    typealias Surface = EcmwfIfs01EnsembleSurfaceVariable
    typealias Pressure = EcmwfIfs01EnsemblePressureVariable

    private func entry(_ param: String, member: String? = nil, level: String? = nil, type: Curl.EcmwfIndexEntry.LevelType = .sfc, offset: Int = 10) -> Curl.EcmwfIndexEntry {
        .init(levtype: type, levelist: level, number: member, param: param, _offset: offset, _length: 5)
    }

    @Test func inventoriesCoverFilesTimestepsAndMembersInDeaccumulationOrder() throws {
        let inventories: [DownloadEcmwfCommand.EnsembleInventory] = [
            .init(hour: 6, url: "perturbed6", entries: [entry("tp", member: "2"), entry("tp", member: "1"), entry("2t")]),
            .init(hour: 0, url: "control0", entries: [entry("tp")]),
            .init(hour: 3, url: "control3", entries: [entry("tp")]),
            .init(hour: 6, url: "control6", entries: [entry("tp")]),
            .init(hour: 3, url: "perturbed3", entries: [entry("tp", member: "1"), entry("tp", member: "2")])
        ]
        let jobs = try DownloadEcmwfCommand.ensembleDownloads(inventories: inventories, variable: Surface.precipitation, memberCount: 3)
        #expect(jobs.map(\.hour) == [3, 6, 3, 6, 3, 6])
        #expect(jobs.map(\.member) == [0, 0, 1, 1, 2, 2])
        #expect(jobs.map(\.url) == ["control3", "control6", "perturbed3", "perturbed6", "perturbed3", "perturbed6"])
        #expect(jobs.allSatisfy { $0.range == 10..<15 })
        #expect(try DownloadEcmwfCommand.ensembleDownloads(inventories: inventories, variable: Surface.dew_point_2m, memberCount: 3).isEmpty)
    }

    @Test func matchingDistinguishesPressureAndSoilLevelsFromSurfaceHeights() {
        #expect(Surface.temperature_2m.matches(entry("2t")))
        #expect(Surface.dew_point_2m.matches(entry("2d")))
        #expect(Surface.snow_density.matches(entry("rsn")))
        #expect(Surface.snow_depth_water_equivalent.matches(entry("sd")))
        #expect(Surface.temperature_2m_max.matches(entry("max_2t")))
        #expect(Surface.temperature_2m_max.matches(entry("mx2t6")))
        #expect(Surface.soil_temperature_7_to_28cm.matches(entry("sot", level: "2", type: .sol)))
        #expect(!Surface.soil_temperature_7_to_28cm.matches(entry("sot", level: "1", type: .sol)))
        #expect(Surface.soil_temperature_7_to_28cm.matches(entry("sot", type: .sol)))
        #expect(Surface.soil_temperature_7_to_28cm.matches(shortName: "sot", level: 2))
        #expect(!Surface.soil_temperature_7_to_28cm.matches(shortName: "sot", level: 1))
        #expect(Pressure.vertical_velocity_pressure_500hPa.matches(entry("w", level: "500", type: .pl)))
        #expect(!Pressure.vertical_velocity_pressure_500hPa.matches(entry("w", level: "700", type: .pl)))
        #expect(!Pressure.temperature_500hPa.matches(entry("t", level: "500")))
        #expect(Pressure.geopotential_height_500hPa.matches(entry("z", level: "500", type: .pl)))
    }

    @Test func schemasStoreNativeFieldsUnderDistinctNames() {
        #expect(Surface(rawValue: "relative_humidity_2m") == nil)
        #expect(Surface(rawValue: "snow_depth") == nil)
        #expect(Pressure(rawValue: "vertical_velocity_500hPa") == nil)
        #expect(Pressure.vertical_velocity_pressure_500hPa.omFileName.file == "vertical_velocity_pressure_500hPa")
        #expect(Pressure.vertical_velocity_pressure_500hPa.multiplyAdd(dtSeconds: 10800) == nil)
        #expect(Surface.snow_density.unit == .kilogramPerCubicMetre)
        for variable in Surface.allCases {
            #expect(variable.scalefactor > 0)
            #expect(!variable.gribName.isEmpty)
        }
        for variable in Pressure.allCases {
            #expect(variable.scalefactor > 0)
            #expect(variable.level != nil)
        }
    }

    @Test func precipitationDeaccumulatesBeforeScalingAndSeparatesMembers() async {
        let deaverager = GribDeaverager()
        for (member, hour, value, expected) in [(0, 3, Float(0.003), Float(3)), (1, 3, 0.010, 10), (0, 6, 0.007, 4), (1, 6, 0.012, 2)] {
            var data = Array2D(data: [value], nx: 1, ny: 1)
            let stored = await DownloadEcmwfCommand.prepareEnsembleField(variable: Surface.precipitation, member: member, hour: hour, stepType: "accum", stepRange: "0-\(hour)", shortName: "tp", deaverager: deaverager, data: &data)
            #expect(stored)
            #expect(abs(data.data[0] - expected) < 0.001)
        }
    }

    @Test func radiationUsesActualIntervalIncludingSixHourlyStepsAndResets() async {
        let deaverager = GribDeaverager()
        for (hour, range, energy) in [(144, "144", Float(144 * 3600 * 100)), (150, "150", Float(150 * 3600 * 100)), (156, "150-156", Float(6 * 3600 * 100))] {
            var data = Array2D(data: [energy], nx: 1, ny: 1)
            let stored = await DownloadEcmwfCommand.prepareEnsembleField(variable: Surface.shortwave_radiation, member: 0, hour: hour, stepType: "accum", stepRange: range, shortName: "ssrd", deaverager: deaverager, data: &data)
            #expect(stored)
            #expect(abs(data.data[0] - 100) < 0.001)
        }
    }

    @Test func nativeDewpointSnowAndOmegaNeedNoCompanionFields() async {
        let deaverager = GribDeaverager()
        var dewpoint = Array2D(data: [280], nx: 1, ny: 1)
        #expect(await DownloadEcmwfCommand.prepareEnsembleField(variable: Surface.dew_point_2m, member: 0, hour: 0, stepType: "instant", stepRange: "0", shortName: "2d", deaverager: deaverager, data: &dewpoint))
        #expect(abs(dewpoint.data[0] - 6.85) < 0.001)
        var snow = Array2D(data: [0.1], nx: 1, ny: 1)
        #expect(await DownloadEcmwfCommand.prepareEnsembleField(variable: Surface.snow_depth_water_equivalent, member: 0, hour: 0, stepType: "instant", stepRange: "0", shortName: "sd", deaverager: deaverager, data: &snow))
        #expect(snow.data == [100])
        var omega = Array2D(data: [-0.25], nx: 1, ny: 1)
        #expect(await DownloadEcmwfCommand.prepareEnsembleField(variable: Pressure.vertical_velocity_pressure_500hPa, member: 0, hour: 0, stepType: "instant", stepRange: "0", shortName: "w", deaverager: deaverager, data: &omega))
        #expect(omega.data == [-0.25])
    }
}
