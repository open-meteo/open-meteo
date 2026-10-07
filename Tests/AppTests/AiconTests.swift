import Foundation
@testable import App
@testable import ReducedLatLon
import Testing

@Suite struct AiconTests {
    @Test func storageRetainsNativeCellOrder() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: file) }
        let points: [ReducedLatLonPoint] = [
            .init(latitudeDegrees: 20, longitudeDegrees: 20),
            .init(latitudeDegrees: 0, longitudeDegrees: 0),
            .init(latitudeDegrees: -30, longitudeDegrees: 80)
        ]
        try ReducedLatLonArtifact.Writer.write(to: file,
            metadata: .init(number: 26, uuid: Array(0..<16), coversWholeSphere: true),
            points: points, latitudeBandCount: 2)
        let storage = try ReducedLatLonIndex(file: file)
        let grid = IconNativeGrid(storage: storage, resolutionMeters: 13_200,
            maximumChordDistanceSquared: 1, nearbyMaximumChordDistanceSquared: 1)
        let domain = AiconNativeDomain(definition: .aicon_global, nativeGrid: grid)
        #expect(domain.nativeGrid.storage === storage)
        #expect(domain.grid.nx == points.count)
        #expect(domain.grid.ny == 1)
        #expect(domain.grid.findPoint(lat: 20, lon: 20) == 0)
        #expect(domain.grid.findPoint(lat: 0, lon: 0) == 1)
        #expect(domain.grid.findPoint(lat: -30, lon: 80) == 2)
        #expect(domain.domainRegistryStatic == .dwd_icon_global_native)
        #expect(domain.definition.nativeGridDefinition.nativeGridFile.identity == .global)
    }

    @Test func modelLevelsHaveDistinctStorageFiles() {
        let variables = AiconDomain.aicon_global.modelLevels.flatMap { level in
            AiconModelLevelVariableType.allCases.map { AiconModelLevelVariable(variable: $0, level: level) }
        }
        // The writer and converter group by filename and do not use the legacy level field.
        #expect(variables.count == 65)
        #expect(Set(variables.map { $0.omFileName.file }).count == 65)
        #expect(variables.allSatisfy { $0.omFileName.level == 0 })
    }

    @Test func schedulingMetadataDoesNotRequireGridFiles() throws {
        let metadata = try #require(DomainRegistry.dwd_aicon_global.timeSeriesMetadata)
        #expect(metadata.dtSeconds == 3 * 3600)
        #expect(metadata.omFileLength == 84)
        #expect(metadata.updateIntervalSeconds == 6 * 3600)
    }

    @Test(arguments: [0, 6, 12, 18])
    func forecastStepsAndV1Urls(runHour: Int) {
        let domain = AiconDomain.aicon_global
        let run = Timestamp(2026, 10, 7, runHour)
        let steps = domain.forecastSteps(run: run)
        #expect(steps == Array(stride(from: 3, through: runHour % 12 == 6 ? 120 : 180, by: 3)))
        #expect(domain.surfaceVariableUrl(variable: "T_2M", run: run, forecastHours: 3)
            == "https://opendata.dwd.de/weather/nwp/v1/m/aicon/p/T_2M/r/2026-10-07T\(runHour.zeroPadded(len: 2)):00/s/PT003H00M.grib2")
        #expect(domain.modelLevelVariableUrl(variable: "T", level: 13, run: run, forecastHours: 120)
            == "https://opendata.dwd.de/weather/nwp/v1/m/aicon/p/T/lvt1/150/lv1/13/r/2026-10-07T\(runHour.zeroPadded(len: 2)):00/s/PT120H00M.grib2")
    }
}
