import Foundation
import Testing
import SwiftZarr
@testable import App

@Suite struct WeatherNext3Tests {
    @Test func spreadAndUnits() {
        #expect(abs(WeatherNext3Variable.estimatedSpread(low: 270, high: 272.563103, scale: 1) - 1) < 0.00001)
        #expect(WeatherNext3Variable.estimatedSpread(low: 3, high: 2, scale: 1).isNaN)
        #expect(WeatherNext3Variable.estimatedSpread(low: .nan, high: 2, scale: 1).isNaN)
        #expect(WeatherNext3Variable(rawValue: "temperature_2m_spread")?.unit == .kelvin)
        #expect(WeatherNext3Variable(rawValue: "precipitation_spread") == nil)
        #expect(WeatherNext3Variable(rawValue: "wind_speed_10m_spread") == nil)
    }
    @Test func hourlyPathsAndHorizons() throws {
        let main = try Timestamp.fromRunHourOrYYYYMMDD("2026110800")
        let interim = main.add(hours: 1)
        #expect(WeatherNext3Domain.hours(run: main) == 360)
        #expect(WeatherNext3Domain.hours(run: interim) == 48)
        #expect(WeatherNext3Domain.path(run: interim).contains("20261108_01hr_01_preds"))
    }
    @Test func observedZstdDatetimeChunk() throws {
        // Authenticated statistics run 20261108_00hr_01_preds, datetime/c/0.
        let compressed = Data([40,181,47,253,32,8,65,0,0,0,160,171,165,20,236,229,24])
        let decoded = try ZstdCodec().decode(compressed)
        #expect(decoded.count == 8)
        let value = decoded.withUnsafeBytes { Int64(littleEndian: $0.loadUnaligned(as: Int64.self)) }
        #expect(value == 1794099600000000000)
    }

    private struct SampleReader<V: GenericVariable>: GenericReaderProtocol {
        let modelLat: Float = 10
        let modelLon: Float = 100
        let modelElevation: ElevationOrSea = .noData
        let targetElevation: Float = 0
        let modelDtSeconds = 3600
        let values: [String: Float]
        func getStatic(type: ReaderStaticVariable) async throws -> Float? { nil }
        func prefetchData(variable: V, time: TimerangeDtAndSettings) async throws {}
        func get(variable: V, time: TimerangeDtAndSettings) async throws -> DataAndUnit {
            DataAndUnit([values[variable.rawValue] ?? .nan], variable.unit)
        }
    }

    @Test func composedReaderPreservesNativeMeansAndRestrictsSpreads() async throws {
        typealias Station = WeatherNext3GridVariable<WeatherNext3StationGrid>
        typealias Surface = WeatherNext3GridVariable<WeatherNext3SurfaceGrid>
        #expect(Station(rawValue: "wind_speed_10m") == nil)
        #expect(Surface(rawValue: "temperature_2m") == nil)
        let mixer = GenericReaderMixerByVariableName<VariableSchemaUnion<Station, Surface>>(reader: [
            SampleReader<Surface>(values: ["wind_speed_10m": 8, "wind_u_component_10m": 3, "wind_v_component_10m": 4, "pressure_msl": 1013]),
            SampleReader<Station>(values: ["temperature_2m": 20, "dew_point_2m": 20, "temperature_2m_spread": 1.2])
        ])
        let reader = VariableHourlyDeriver(reader: mixer, options: try GenericReaderOptions(), domainRegistry: .google_weathernext3_station_ensemble_mean)
        let time = TimerangeDt(start: Timestamp(2026, 11, 8), nTime: 1, dtSeconds: 3600).toSettings()
        for (name, expected) in [("temperature_2m", Float(20)), ("wind_speed_10m", 8), ("relative_humidity_2m", 100), ("temperature_2m_spread", 1.2)] {
            let variable = try #require(ForecastVariable(rawValue: name))
            let output = try await reader.get(variable: variable, time: time)
            #expect(output?.data == [expected])
        }
        for name in ["wind_speed_10m_spread", "wind_direction_10m_spread", "relative_humidity_2m_spread", "precipitation_spread"] {
            let variable = try #require(ForecastVariable(rawValue: name))
            let output = try await reader.get(variable: variable, time: time)
            #expect(output == nil)
        }
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["WEATHERNEXT3_FIXTURE_DIRECTORY"] != nil))
    func inspectedTemperatureChunkThroughZarr() async throws {
        let source = try #require(ProcessInfo.processInfo.environment["WEATHERNEXT3_FIXTURE_DIRECTORY"])
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: source + "/zarr.json"))) as! [String: Any]
        let metadata = (json["consolidated_metadata"] as! [String: Any])["metadata"] as! [String: Any]
        let arrayMetadata = try JSONDecoder().decode(V3ArrayMetadata.self, from: JSONSerialization.data(withJSONObject: metadata["temperature_2m_mean"]!))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory.appendingPathComponent("c/0/0"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.copyItem(atPath: source + "/temperature_2m_mean-0_0_0.zst", toPath: directory.appendingPathComponent("c/0/0/0").path)
        let array = try ZarrArray(metadata: arrayMetadata, storage: LocalFileStorage(basePath: directory.path), path: "")
        let values: [Float] = try await array.retrieveArraySubset([0..<1, 1000..<1001, 1000..<1001])
        #expect(values == [301.8550720214844])
    }
}
