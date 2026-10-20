import Foundation
@testable import App
@testable import ReducedLatLon
import Testing
import Logging

@Suite struct AiconTests {
    @Test func storageRetainsNativeCellOrder() async throws {
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
        let domain = IconNativeDomain(definition: .aiconNative, nativeGrid: grid)
        #expect(domain.nativeGrid.storage === storage)
        #expect(domain.grid.nx == points.count)
        #expect(domain.grid.ny == 1)
        #expect(domain.grid.findPoint(lat: 20, lon: 20) == 0)
        #expect(domain.grid.findPoint(lat: 0, lon: 0) == 1)
        #expect(domain.grid.findPoint(lat: -30, lon: 80) == 2)
        #expect(domain.domainRegistryStatic == .dwd_icon_global_native)
        #expect(domain.definition.nativeGridFile.identity == .global)

        let outputs = IconDownloadOutputs(.aiconNative, grid: grid)
        #expect(outputs.modelLevel == nil)
        #expect(outputs.remapped == nil)
        #expect(outputs.ensembleMean == nil)
        #expect(outputs.fifteenMinute == nil)
        #expect(IconNativeDomains.aiconNative.staticResourceDomain == .iconNative)
        #expect(outputs.downloadDomain.getVarAndLevel(AiconSurfaceVariable.temperature_2m)?.cat == "single-level")

        try FileManager.default.createDirectory(atPath: OpenMeteo.tempDirectory, withIntermediateDirectories: true)
        let run = Timestamp(2026, 10, 7)
        let surfaceWriter = OmSpatialTimestepWriter(domain: outputs.primary, run: run, time: run.add(hours: 3),
            storeOnDisk: false, realm: nil, logger: Logger(label: "aicon-tests"))
        try await surfaceWriter.write(member: 0, variable: AiconSurfaceVariable.temperature_2m, data: [10, 20, 30])
        let surfaceHandles = try await surfaceWriter.finalise()
        #expect(surfaceHandles.count == 1)
        #expect(surfaceHandles[0].domain.domainRegistry == .dwd_aicon_global_native)
        #expect(try await surfaceHandles[0].reader.read() == [10, 20, 30])
    }

    @Test func schedulingMetadataDoesNotRequireGridFiles() throws {
        let metadata = try #require(DomainRegistry.dwd_aicon_global_native.timeSeriesMetadata)
        #expect(metadata.dtSeconds == 3 * 3600)
        #expect(metadata.omFileLength == 84)
        #expect(metadata.updateIntervalSeconds == 3 * 3600)
    }

    @Test(arguments: [0, 3, 6, 9, 12, 15, 18, 21])
    func forecastStepsAndV1Urls(runHour: Int) throws {
        let model = IconDownloadDomains.aicon
        let run = Timestamp(2026, 10, 7, runHour)
        let lastHour = runHour.isMultiple(of: 12) ? 180 : runHour.isMultiple(of: 6) ? 120 : 48
        #expect(try model.getDownloadForecastSteps(run: runHour) == Array(stride(from: 3, through: lastHour, by: 3)))
        #expect(model.getGribUrl(field: ("T_2M", "single-level", nil), run: run, leadSeconds: 3 * 3600)
            == "https://opendata.dwd.de/weather/nwp/v1/m/aicon/p/T_2M/r/2026-10-07T\(runHour.zeroPadded(len: 2)):00/s/PT003H00M.grib2")

    }

    @Test func runSelectionCrossesMidnight() throws {
        #expect(IconDownloadDomains.aicon.lastRun(now: Timestamp(2026, 10, 7, 1)) == Timestamp(2026, 10, 6, 21))
        #expect(IconDownloadDomains.aicon.lastRun(now: Timestamp(2026, 10, 7, 5)) == Timestamp(2026, 10, 7, 3))
        #expect(throws: (any Error).self) { try IconDownloadDomains.aicon.getDownloadForecastSteps(run: 1) }
    }

    @Test func surfaceVariableSelection() throws {
        let variables = try DownloadIconCommand.variables(feed: .aicon, group: .all, onlyVariables: nil)
        #expect(variables.map { $0.omFileName.file } == AiconSurfaceVariable.allCases.map(\.rawValue))
        let selected = try DownloadIconCommand.variables(feed: .aicon, group: .all, onlyVariables: "temperature_2m,precipitation")
        #expect(selected.map { $0.omFileName.file } == ["temperature_2m", "precipitation"])
        #expect(throws: (any Error).self) {
            try DownloadIconCommand.variables(feed: .aicon, group: .all, onlyVariables: "t_level13")
        }
        for group in [DownloadIconCommand.VariableGroup.modelLevel, .pressureLevel, .pressureLevelGt500, .pressureLevelLtE500] {
            #expect(throws: (any Error).self) {
                try DownloadIconCommand.variables(feed: .aicon, group: group, onlyVariables: nil)
            }
        }
    }

    @Test func precipitationIsDeaccumulatedInSeconds() async throws {
        let deaverager = GribDeaverager()
        var amounts = [Float]()
        for (index, cumulative) in [Float(2), 5, 6].enumerated() {
            var array = Array2D(data: [cumulative], nx: 1, ny: 1)
            let step = try IconStepInterval(start: 0, end: (index + 1) * 3, unit: 1)
            #expect(await deaverager.deaccumulateIfRequired(variable: AiconSurfaceVariable.precipitation, member: 0,
                stepType: "accum", startStep: step.start, currentStep: step.end, array2d: &array))
            amounts.append(array.data[0])
        }
        #expect(amounts == [2, 3, 1])
    }
}
