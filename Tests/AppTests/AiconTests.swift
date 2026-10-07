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

        let outputs = DwdDownloadDomains(.aiconNative, grid: grid)
        let modelLevel = try #require(outputs.modelLevel)
        #expect(outputs.remapped == nil)
        #expect(outputs.ensembleMean == nil)
        #expect(outputs.fifteenMinute == nil)
        #expect(modelLevel.domainRegistry == .dwd_aicon_global_model_level)
        #expect(modelLevel.domainRegistryStatic == .dwd_icon_global_native)
        #expect(IconNativeDomains.aiconNativeModelLevel.staticResourceDomain == .iconNative)
        #expect(DwdModel.aicon.staticSource == .icon(.icon))
        #expect(!outputs.isModelLevel(AiconSurfaceVariable.temperature_2m))

        try FileManager.default.createDirectory(atPath: OpenMeteo.tempDirectory, withIntermediateDirectories: true)
        let run = Timestamp(2026, 10, 7)
        let surfaceWriter = OmSpatialTimestepWriter(domain: outputs.primary, run: run, time: run.add(hours: 3),
            storeOnDisk: false, realm: nil, logger: Logger(label: "aicon-tests"))
        let modelWriter = OmSpatialTimestepWriter(domain: modelLevel, run: run, time: run.add(hours: 3),
            storeOnDisk: false, realm: nil, logger: Logger(label: "aicon-tests"))
        try await surfaceWriter.write(member: 0, variable: AiconSurfaceVariable.temperature_2m, data: [10, 20, 30])
        // Surface output can be finalized before any model-level field is available.
        let surfaceHandles = try await surfaceWriter.finalise()
        #expect(surfaceHandles.count == 1)
        #expect(surfaceHandles[0].domain.domainRegistry == .dwd_aicon_global)
        #expect(try await surfaceHandles[0].reader.read() == [10, 20, 30])
        for level in 1...13 {
            let variable = AiconModelLevelVariable(variable: .temperature, level: level)
            #expect(outputs.isModelLevel(variable))
            try await modelWriter.write(member: 0, variable: variable, data: Array(repeating: Float(level), count: 3))
        }
        let modelHandles = try await modelWriter.finalise()
        #expect(modelHandles.count == 13)
        for (index, handle) in modelHandles.enumerated() {
            #expect(handle.domain.domainRegistry == .dwd_aicon_global_model_level)
            #expect(handle.variable.omFileName.file == "t_level\(index + 1)")
            #expect(try await handle.reader.read() == Array(repeating: Float(index + 1), count: 3))
        }

        let unitWriter = OmSpatialTimestepWriter(domain: modelLevel, run: run, time: run.add(hours: 3),
            storeOnDisk: false, realm: nil, logger: Logger(label: "aicon-tests"))
        let humidity = AiconModelLevelVariable(variable: .specificHumidity, level: 13)
        let pressure = AiconModelLevelVariable(variable: .pressure, level: 13)
        for (variable, values) in [(humidity, [Float(0.01), 0.005123, .nan]), (pressure, [Float(85005), 101325, .nan])] {
            var converted = values
            let conversion = try #require(variable.multiplyAdd)
            converted.multiplyAdd(multiply: conversion.multiply, add: conversion.add)
            try await unitWriter.write(member: 0, variable: variable, data: converted)
        }
        let unitHandles = try await unitWriter.finalise()
        let humidityValues = try await unitHandles[0].reader.read()
        let pressureValues = try await unitHandles[1].reader.read()
        #expect(abs(humidityValues[0] - 10) < 0.001)
        #expect(abs(humidityValues[1] - 5.123) < 0.001)
        #expect(humidityValues[2].isNaN)
        #expect(abs(pressureValues[0] - 850.05) < 0.051)
        #expect(abs(pressureValues[1] - 1013.25) < 0.051)
        #expect(pressureValues[2].isNaN)
    }

    @Test func modelLevelsHaveDistinctStorageFiles() throws {
        let variables = try DownloadIconCommand.variables(model: .aicon, group: .modelLevel, onlyVariables: nil)
        // The writer and converter group by filename and do not use the legacy level field.
        #expect(variables.count == 65)
        #expect(Set(variables.map { $0.omFileName.file }).count == 65)
        #expect(variables.allSatisfy { $0.omFileName.level == 0 })
    }

    @Test func schedulingMetadataDoesNotRequireGridFiles() throws {
        let metadata = try #require(DomainRegistry.dwd_aicon_global.timeSeriesMetadata)
        #expect(metadata.dtSeconds == 3 * 3600)
        #expect(metadata.omFileLength == 84)
        #expect(metadata.updateIntervalSeconds == 3 * 3600)
    }

    @Test(arguments: [0, 3, 6, 9, 12, 15, 18, 21])
    func forecastStepsAndV1Urls(runHour: Int) throws {
        let model = DwdModel.aicon
        let run = Timestamp(2026, 10, 7, runHour)
        let lastHour = runHour.isMultiple(of: 12) ? 180 : runHour.isMultiple(of: 6) ? 120 : 48
        #expect(try model.getDownloadForecastSteps(run: runHour) == Array(stride(from: 3, through: lastHour, by: 3)))
        #expect(model.getGribUrl(field: ("T_2M", "single-level", nil), run: run, leadSeconds: 3 * 3600)
            == "https://opendata.dwd.de/weather/nwp/v1/m/aicon/p/T_2M/r/2026-10-07T\(runHour.zeroPadded(len: 2)):00/s/PT003H00M.grib2")
        #expect(model.getGribUrl(field: ("T", "model-level", 13), run: run, leadSeconds: 120 * 3600)
            == "https://opendata.dwd.de/weather/nwp/v1/m/aicon/p/T/lvt1/150/lv1/13/r/2026-10-07T\(runHour.zeroPadded(len: 2)):00/s/PT120H00M.grib2")
    }

    @Test func runSelectionCrossesMidnight() throws {
        #expect(DwdModel.aicon.lastRun(now: Timestamp(2026, 10, 7, 1)) == Timestamp(2026, 10, 6, 21))
        #expect(DwdModel.aicon.lastRun(now: Timestamp(2026, 10, 7, 5)) == Timestamp(2026, 10, 7, 3))
        #expect(throws: (any Error).self) { try DwdModel.aicon.getDownloadForecastSteps(run: 1) }
    }

    @Test func modelLevelSelectionUsesIndices() throws {
        let selected = try DownloadIconCommand.variables(model: .aicon, group: .all, onlyVariables: "temperature_2m,qv_level13,t_level1")
        #expect(selected.map { $0.omFileName.file } == ["temperature_2m", "qv_level13", "t_level1"])
        #expect(AiconModelLevelVariable(rawValue: "T_13m") == nil)
        #expect(AiconModelLevelVariable(rawValue: "t_level0") == nil)
        #expect(AiconModelLevelVariable(rawValue: "t_level14") == nil)
        #expect(AiconModelLevelVariable(rawValue: "t_level13")?.isElevationCorrectable == false)
        #expect(throws: (any Error).self) {
            try DownloadIconCommand.variables(model: .aicon, group: .pressureLevel, onlyVariables: nil)
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
