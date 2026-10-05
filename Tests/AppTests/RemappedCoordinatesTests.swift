import Testing
import Vapor
@testable import App

@Suite struct RemappedCoordinatesTests {
    @Test func solarDerivationsUseRemappedCell() async throws {
        let source = RadiationFixtureReader(modelLat: 45, modelLon: 8)
        let target = RadiationFixtureReader(modelLat: 55, modelLon: 25)
        let options = try GenericReaderOptions(tilt: 35, logger: Logger(label: "remapped-coordinates"), httpClient: nil)
        var remappedOptions = options
        remappedOptions.remappedCoordinates = (target.modelLat, target.modelLon)
        let remapped = VariableHourlyDeriver(reader: source, options: remappedOptions, domainRegistry: .dwd_icon)
        let expected = VariableHourlyDeriver(reader: target, options: options, domainRegistry: .dwd_icon)
        let original = VariableHourlyDeriver(reader: source, options: options, domainRegistry: .dwd_icon)
        let time = TimerangeDt(start: Timestamp(2026, 6, 1, 3), nTime: 18, dtSeconds: 3600).toSettings()
        var differsFromSource = false
        for variable: ForecastSurfaceVariable in [
            .shortwave_radiation_instant, .direct_radiation_instant, .diffuse_radiation_instant,
            .direct_normal_irradiance, .direct_normal_irradiance_instant,
            .global_tilted_irradiance, .global_tilted_irradiance_instant,
            .sunshine_duration, .et0_fao_evapotranspiration
        ] {
            let variable = ForecastVariable.surface(.init(variable, 0))
            let actual = try #require(await remapped.get(variable: variable, time: time))
            let targetValues = try #require(await expected.get(variable: variable, time: time))
            let sourceValues = try #require(await original.get(variable: variable, time: time))
            #expect(actual.data.allSatisfy { $0.isFinite })
            #expect(actual.data == targetValues.data)
            differsFromSource = differsFromSource || actual.data != sourceValues.data
        }
        #expect(differsFromSource)
        #expect(remapped.modelLat == source.modelLat)
        #expect(remapped.modelLon == source.modelLon)

        // Rotation of stored grid-relative winds must still use the source cell.
        let wind = ForecastVariable.surface(.init(.wind_direction_10m, 0))
        let remappedWind = VariableHourlyDeriver(reader: source, options: remappedOptions, domainRegistry: .ncep_hrrr_conus)
        let originalWind = VariableHourlyDeriver(reader: source, options: options, domainRegistry: .ncep_hrrr_conus)
        let actualWind = try #require(await remappedWind.get(variable: wind, time: time))
        let expectedWind = try #require(await originalWind.get(variable: wind, time: time))
        #expect(actualWind.data == expectedWind.data)
    }
}

private struct RadiationFixtureReader: GenericReaderProtocol {
    let modelLat: Float
    let modelLon: Float
    let modelElevation = ElevationOrSea.elevation(100)
    let targetElevation: Float = 100
    let modelDtSeconds = 3600

    func get(variable: IconVariable, time: TimerangeDtAndSettings) async throws -> DataAndUnit {
        let value: Float
        switch variable.rawValue {
        case "direct_radiation": value = 200
        case "diffuse_radiation": value = 100
        case "temperature_2m": value = 20
        case "relative_humidity_2m": value = 60
        case "wind_u_component_10m", "wind_v_component_10m": value = 3
        default:
            Issue.record("Unexpected fixture variable: \(variable.rawValue)")
            value = .nan
        }
        return DataAndUnit(Array(repeating: value, count: time.time.count), variable.unit)
    }

    func prefetchData(variable: IconVariable, time: TimerangeDtAndSettings) async throws {}
    func getStatic(type: ReaderStaticVariable) async throws -> Float? { nil }
}
