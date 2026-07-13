@testable import App
import Logging
import Testing

private struct IconVariableTestReader: GenericReaderProtocol {
    typealias MixingVar = IconVariable

    let modelElevation: ElevationOrSea
    let targetElevation: Float
    let modelLat: Float = 47
    let modelLon: Float = 8
    let modelDtSeconds: Int = 3600

    func get(variable: IconVariable, time: TimerangeDtAndSettings) async throws -> DataAndUnit {
        fatalError("Not used by mapping tests")
    }

    func prefetchData(variable: IconVariable, time: TimerangeDtAndSettings) async throws {
        fatalError("Not used by mapping tests")
    }

    func getStatic(type: ReaderStaticVariable) async throws -> Float? {
        nil
    }
}

private final class ReaderCallCounter {
    var count = 0
}

private struct OptionalSurfaceTestReader: GenericReaderOptionalProtocol {
    typealias VariableOpt = ForecastSurfaceVariable

    let data: DataAndUnit?
    let counter: ReaderCallCounter
    let modelElevation: ElevationOrSea = .elevation(0)
    let targetElevation: Float = 0
    let modelLat: Float = 0
    let modelLon: Float = 0
    let modelDtSeconds: Int = 3600

    func get(variable: ForecastSurfaceVariable, time: TimerangeDtAndSettings) async throws -> DataAndUnit? {
        counter.count += 1
        return data
    }

    func prefetchData(variable: ForecastSurfaceVariable, time: TimerangeDtAndSettings) async throws -> Bool {
        data != nil
    }

    func getStatic(type: ReaderStaticVariable) async throws -> Float? {
        nil
    }
}

@Suite struct IconReaderTests {
    private func makeDeriver(
        targetElevation: Float = 100,
        modelElevation: Float = 200,
        pressureLevelInterpolations: [Int: PressureLevelInterpolation] = [:]
    ) throws -> VariableHourlyDeriver<IconVariableTestReader> {
        VariableHourlyDeriver(
            reader: IconVariableTestReader(modelElevation: .elevation(modelElevation), targetElevation: targetElevation),
            options: try GenericReaderOptions(logger: Logger(label: "IconReaderTests"), httpClient: nil),
            pressureLevelInterpolations: pressureLevelInterpolations
        )
    }

    private var time: TimerangeDtAndSettings {
        TimerangeDtAndSettings(
            time: TimerangeDt(start: Timestamp(0), nTime: 3, dtSeconds: 3600),
            ensembleMember: 0,
            ensembleMemberLevel: 0,
            previousDay: 0,
            run: nil
        )
    }

    @Test func mapsLegacyVariableAliases() throws {
        let deriver = try makeDeriver()
        let aliases: [(ForecastSurfaceVariable, String)] = [
            (.snow_height, "snow_depth"),
            (.sensible_heatflux, "sensible_heat_flux"),
            (.latent_heatflux, "latent_heat_flux"),
            (.soil_moisture_0_1cm, "soil_moisture_0_to_1cm"),
            (.soil_moisture_1_3cm, "soil_moisture_1_to_3cm"),
            (.soil_moisture_3_9cm, "soil_moisture_3_to_9cm"),
            (.soil_moisture_9_27cm, "soil_moisture_9_to_27cm"),
            (.soil_moisture_27_81cm, "soil_moisture_27_to_81cm")
        ]

        for (alias, expectedRawValue) in aliases {
            let mapping = try #require(deriver.getDeriverMap(variable: alias))
            guard case .direct(let raw) = mapping else {
                Issue.record("Expected direct mapping for \(alias.rawValue)")
                continue
            }
            #expect(raw.rawValue == expectedRawValue)
        }
    }

    @Test func et0ElevationFallsBackForGridpoints() throws {
        #expect(try makeDeriver(targetElevation: 123, modelElevation: 456).elevationForEt0 == 123)
        #expect(try makeDeriver(targetElevation: .nan, modelElevation: 456).elevationForEt0 == 456)
    }

    @Test func clampsNegativeRadiation() throws {
        let deriver = try makeDeriver()
        let mapping = try #require(deriver.getDeriverMap(variable: ForecastSurfaceVariable.direct_radiation))
        guard case .one(.raw(let raw), let derive) = mapping else {
            Issue.record("Expected radiation clamping mapping")
            return
        }
        #expect(raw.rawValue == "direct_radiation")
        let result = derive(DataAndUnit([-0.2, 0, 12], .wattPerSquareMetre), time)
        #expect(result.data == [0, 0, 12])
        #expect(result.unit == .wattPerSquareMetre)
    }

    @Test func correctsPrecipitationPhaseForElevationAdjustedTemperature() throws {
        let deriver = try makeDeriver(targetElevation: 0, modelElevation: 200)
        let temperature: [Float] = [-1, 0, 2]
        let snowMapping = try #require(deriver.getDeriverMap(variable: ForecastSurfaceVariable.snowfall_water_equivalent))
        guard case .two(_, _, let correctSnow) = snowMapping else {
            Issue.record("Expected snowfall correction mapping")
            return
        }
        let snow = correctSnow(DataAndUnit([2, 2, 2], .millimetre), DataAndUnit(temperature, .celsius), time)
        #expect(snow.data == [2, 0, 0])

        let rainMapping = try #require(deriver.getDeriverMap(variable: ForecastSurfaceVariable.rain))
        guard case .three(_, _, _, let correctRain) = rainMapping else {
            Issue.record("Expected rain correction mapping")
            return
        }
        let rain = correctRain(
            DataAndUnit([1, 1, 1], .millimetre),
            DataAndUnit([2, 2, 2], .millimetre),
            DataAndUnit(temperature, .celsius),
            time
        )
        #expect(rain.data == [1, 3, 3])
    }

    @Test func interpolatesMissingPressureLevels() throws {
        let interpolation = PressureLevelInterpolation(lowerLevel: 700, upperLevel: 850)
        let deriver = try makeDeriver(pressureLevelInterpolations: [800: interpolation])
        let variable = VariableOrSpread(
            variable: ForecastPressureVariable(variable: .temperature, level: 800),
            isSpread: false
        )
        let mapping = try #require(deriver.getDeriverMap(variable: variable))
        guard case .two(.raw(let lower), .raw(let upper), let interpolate) = mapping else {
            Issue.record("Expected pressure interpolation mapping")
            return
        }
        #expect(lower.rawValue == "temperature_700hPa")
        #expect(upper.rawValue == "temperature_850hPa")
        let temperature = interpolate(DataAndUnit([10], .celsius), DataAndUnit([25], .celsius), time)
        #expect(temperature.data == [20])
        #expect(temperature.unit == .celsius)

        let humidityDeriver = try makeDeriver(pressureLevelInterpolations: [925: PressureLevelInterpolation(lowerLevel: 850, upperLevel: 950)])
        let humidityVariable = VariableOrSpread(
            variable: ForecastPressureVariable(variable: .relative_humidity, level: 925),
            isSpread: false
        )
        let humidityMapping = try #require(humidityDeriver.getDeriverMap(variable: humidityVariable))
        guard case .two(_, _, let interpolateHumidity) = humidityMapping else {
            Issue.record("Expected humidity interpolation mapping")
            return
        }
        let humidity = interpolateHumidity(DataAndUnit([40], .percentage), DataAndUnit([80], .percentage), time)
        #expect(humidity.data == [60])
        #expect(humidity.unit == .percentage)
    }

    @Test func iconDomainsConfigureOnlyMissingPressureLevels() {
        #expect(IconDomains.icon.pressureLevelInterpolations[975]?.lowerLevel == 950)
        #expect(IconDomains.iconEu.pressureLevelInterpolations[975]?.upperLevel == 1000)
        #expect(IconDomains.iconD2.pressureLevelInterpolations[800]?.lowerLevel == 700)
        #expect(IconDomains.iconD2.pressureLevelInterpolations[925]?.upperLevel == 950)
        #expect(IconDomains.iconD2_15min.pressureLevelInterpolations.isEmpty)
    }

    @Test func completeHighResolutionResultSkipsFallbackReader() async throws {
        let fallbackCounter = ReaderCallCounter()
        let highResolutionCounter = ReaderCallCounter()
        let mixer = GenericReaderMultiSameType<ForecastSurfaceVariable>(reader: [
            OptionalSurfaceTestReader(data: DataAndUnit([3, 4], .celsius), counter: fallbackCounter),
            OptionalSurfaceTestReader(data: DataAndUnit([1, 2], .celsius), counter: highResolutionCounter)
        ])

        let result = try #require(try await mixer.get(variable: .temperature_2m, time: time))
        #expect(result.data == [1, 2])
        #expect(highResolutionCounter.count == 1)
        #expect(fallbackCounter.count == 0)
    }
}
