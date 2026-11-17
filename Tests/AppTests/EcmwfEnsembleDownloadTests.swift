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
}
