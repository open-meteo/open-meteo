import Foundation
import Logging
import OpenMeteoSdk
@testable import App
import Testing
@preconcurrency import SwiftEccodes

private final class AirQualityReaderRecorder: @unchecked Sendable {
    struct Request {
        let variable: CamsVariable
        let time: TimerangeDt
    }

    private let lock = NSLock()
    private var storedReads: [Request] = []
    private var storedPrefetches: [Request] = []

    func recordRead(variable: CamsVariable, time: TimerangeDt) {
        lock.lock()
        defer { lock.unlock() }
        storedReads.append(.init(variable: variable, time: time))
    }

    func recordPrefetch(variable: CamsVariable, time: TimerangeDt) {
        lock.lock()
        defer { lock.unlock() }
        storedPrefetches.append(.init(variable: variable, time: time))
    }

    func reads() -> [Request] {
        lock.lock()
        defer { lock.unlock() }
        return storedReads
    }

    func prefetches() -> [Request] {
        lock.lock()
        defer { lock.unlock() }
        return storedPrefetches
    }

    func reset() {
        lock.lock()
        defer { lock.unlock() }
        storedReads.removeAll()
        storedPrefetches.removeAll()
    }
}

private struct AirQualityStubReader: GenericReaderProtocol {
    typealias MixingVar = CamsVariable

    let values: [CamsVariable: Float]
    let recorder: AirQualityReaderRecorder

    var modelLat: Float { 47 }
    var modelLon: Float { 8 }
    var modelElevation: ElevationOrSea { .elevation(500) }
    var targetElevation: Float { 500 }
    var modelDtSeconds: Int { 3600 }

    func getStatic(type: ReaderStaticVariable) async throws -> Float? {
        return nil
    }

    func get(variable: CamsVariable, time: TimerangeDtAndSettings) async throws -> DataAndUnit {
        recorder.recordRead(variable: variable, time: time.time)
        return DataAndUnit(time.time.map { _ in values[variable] ?? .nan }, variable.unit)
    }

    func prefetchData(variable: CamsVariable, time: TimerangeDtAndSettings) async throws {
        recorder.recordPrefetch(variable: variable, time: time.time)
    }
}

@Suite struct AirQualityTests {
    @Test func europeanAirQuality() {
        #expect(EuropeanAirQuality.indexNo2(no2: -1).isNaN)
        #expect(EuropeanAirQuality.indexNo2(no2: 0) == 0)
        #expect(EuropeanAirQuality.indexNo2(no2: 5) == 10)
        #expect(EuropeanAirQuality.indexNo2(no2: 17.5) == 30)
        #expect(EuropeanAirQuality.indexNo2(no2: 42.5) == 50)
        #expect(EuropeanAirQuality.indexNo2(no2: 80) == 70)
        #expect(EuropeanAirQuality.indexNo2(no2: 125) == 90)
        #expect(EuropeanAirQuality.indexNo2(no2: 175) == 110)

        #expect(EuropeanAirQuality.indexO3(o3: 30) == 10)
        #expect(EuropeanAirQuality.indexO3(o3: 80) == 30)
        #expect(EuropeanAirQuality.indexO3(o3: 110) == 50)
        #expect(EuropeanAirQuality.indexO3(o3: 140) == 70)
        #expect(EuropeanAirQuality.indexO3(o3: 170) == 90)
        #expect(EuropeanAirQuality.indexO3(o3: 190) == 110)

        #expect(EuropeanAirQuality.indexPm2_5(pm2_5: 2.5) == 10)
        #expect(EuropeanAirQuality.indexPm2_5(pm2_5: 10) == 30)
        #expect(EuropeanAirQuality.indexPm2_5(pm2_5: 32.5) == 50)
        #expect(EuropeanAirQuality.indexPm2_5(pm2_5: 70) == 70)
        #expect(EuropeanAirQuality.indexPm2_5(pm2_5: 115) == 90)

        #expect(EuropeanAirQuality.indexPm10(pm10: 7.5) == 10)
        #expect(EuropeanAirQuality.indexPm10(pm10: 30) == 30)
        #expect(EuropeanAirQuality.indexPm10(pm10: 82.5) == 50)
        #expect(EuropeanAirQuality.indexPm10(pm10: 157.5) == 70)
        #expect(EuropeanAirQuality.indexPm10(pm10: 232.5) == 90)
    }

    @Test func usAirQuality() {
        #expect(UnitedStatesAirQuality.indexPm10(pm10_24h_mean: 40).isApproximatelyEqual(to: 36.363636, absoluteTolerance: 0.001))
        #expect(UnitedStatesAirQuality.indexPm10(pm10_24h_mean: 100).isApproximatelyEqual(to: 72.5, absoluteTolerance: 0.001))
        #expect(UnitedStatesAirQuality.indexPm10(pm10_24h_mean: 170).isApproximatelyEqual(to: 107.50001, absoluteTolerance: 0.001))
        #expect(UnitedStatesAirQuality.indexPm10(pm10_24h_mean: 260).isApproximatelyEqual(to: 152.5, absoluteTolerance: 0.001))
        #expect(UnitedStatesAirQuality.indexPm10(pm10_24h_mean: 356).isApproximatelyEqual(to: 201.42856, absoluteTolerance: 0.001))
        #expect(UnitedStatesAirQuality.indexPm10(pm10_24h_mean: 424).isApproximatelyEqual(to: 298.57144, absoluteTolerance: 0.001))
        #expect(UnitedStatesAirQuality.indexPm10(pm10_24h_mean: 600).isApproximatelyEqual(to: 495.0, absoluteTolerance: 0.001))

        #expect(UnitedStatesAirQuality.indexO3(o3: 30, o3_8h_mean: 10).isApproximatelyEqual(to: 9.090909, absoluteTolerance: 0.001))
        #expect(UnitedStatesAirQuality.indexO3(o3: 90, o3_8h_mean: 50).isApproximatelyEqual(to: 45.454548, absoluteTolerance: 0.001))
        #expect(UnitedStatesAirQuality.indexO3(o3: 150, o3_8h_mean: 100).isApproximatelyEqual(to: 187.5, absoluteTolerance: 0.001))
        #expect(UnitedStatesAirQuality.indexO3(o3: 210, o3_8h_mean: 150).isApproximatelyEqual(to: 247.36844, absoluteTolerance: 0.001))
        #expect(UnitedStatesAirQuality.indexO3(o3: 260, o3_8h_mean: 190).isApproximatelyEqual(to: 289.47366, absoluteTolerance: 0.001))
        #expect(UnitedStatesAirQuality.indexO3(o3: 406, o3_8h_mean: 410).isApproximatelyEqual(to: 301.00003, absoluteTolerance: 0.001))
        #expect(UnitedStatesAirQuality.indexO3(o3: 600, o3_8h_mean: 410).isApproximatelyEqual(to: 495.0, absoluteTolerance: 0.001))
    }

    @Test func genericAirQualityDerivation() async throws {
        let recorder = AirQualityReaderRecorder()
        let reader = AirQualityStubReader(values: [
            .pm2_5: 10,
            .pm10: 30,
            .nitrogen_dioxide: 20,
            .ozone: 100,
            .sulphur_dioxide: 40,
            .carbon_monoxide: 1_000
        ], recorder: recorder)
        let options = try GenericReaderOptions(logger: Logger(label: "AirQualityTests"), httpClient: nil)
        let deriver = VariableHourlyDeriver(reader: reader, options: options, domainRegistry: .cams_global)
        let time = TimerangeDt(start: Timestamp(2025, 1, 2), nTime: 4, dtSeconds: 3600).toSettings()

        func get(_ variable: ForecastSurfaceVariable) async throws -> DataAndUnit {
            return try #require(await deriver.get(variable: .surface(.init(variable, 0)), time: time))
        }

        let europeanNo2 = try await get(.european_aqi_no2)
        let europeanNitrogenDioxide = try await get(.european_aqi_nitrogen_dioxide)
        #expect(europeanNo2.data == europeanNitrogenDioxide.data)
        #expect(europeanNo2.data.allSatisfy { $0 == EuropeanAirQuality.indexNo2(no2: 20) })

        let europeanPm2_5 = try await get(.european_aqi_pm2_5)
        let europeanPm10 = try await get(.european_aqi_pm10)
        let europeanOzone = try await get(.european_aqi_o3)
        let europeanSo2 = try await get(.european_aqi_so2)
        let european = try await get(.european_aqi)
        let expectedEuropean = Swift.max(
            Swift.max(Swift.max(Swift.max(europeanPm2_5.data[0], europeanPm10.data[0]), europeanNo2.data[0]), europeanOzone.data[0]),
            europeanSo2.data[0]
        )
        #expect(european.data.allSatisfy { $0 == expectedEuropean })

        let usPm2_5 = try await get(.us_aqi_pm2_5)
        let usPm10 = try await get(.us_aqi_pm10)
        let usNo2 = try await get(.us_aqi_no2)
        let usOzone = try await get(.us_aqi_o3)
        let usSo2 = try await get(.us_aqi_so2)
        let usCo = try await get(.us_aqi_co)
        #expect(usPm2_5.data.allSatisfy { $0 == UnitedStatesAirQuality.indexPm2_5(pm2_5_24h_mean: 10) })
        #expect(usPm10.data.allSatisfy { $0 == UnitedStatesAirQuality.indexPm10(pm10_24h_mean: 30) })
        #expect(usNo2.data.allSatisfy { $0 == UnitedStatesAirQuality.indexNo2(no2: 20 / 1.88) })
        #expect(usOzone.data.allSatisfy { $0 == UnitedStatesAirQuality.indexO3(o3: 100 / 1.96, o3_8h_mean: 100 / 1.96) })
        #expect(usSo2.data.allSatisfy { $0 == UnitedStatesAirQuality.indexSo2(so2: 40 / 2.62, so2_24h_mean: 40 / 2.62) })
        #expect(usCo.data.allSatisfy { $0 == UnitedStatesAirQuality.indexCo(co_8h_mean: 1_000 / 1.15 / 1_000) })

        let usOzoneAlias = try await get(.us_aqi_ozone)
        let usSo2Alias = try await get(.us_aqi_sulphur_dioxide)
        let usCoAlias = try await get(.us_aqi_carbon_monoxide)
        #expect(usOzone.data == usOzoneAlias.data)
        #expect(usSo2.data == usSo2Alias.data)
        #expect(usCo.data == usCoAlias.data)

        let us = try await get(.us_aqi)
        let expectedUs = Swift.max(
            Swift.max(
                Swift.max(
                    Swift.max(usPm2_5.data[0], Swift.max(usPm10.data[0], usCo.data[0])),
                    usNo2.data[0]
                ),
                usOzone.data[0]
            ),
            usSo2.data[0]
        )
        #expect(us.data.allSatisfy { $0 == expectedUs })
    }

    @Test func runningMeanRangesAndPrefetch() async throws {
        let recorder = AirQualityReaderRecorder()
        let reader = AirQualityStubReader(values: [.ozone: 100], recorder: recorder)
        let options = try GenericReaderOptions(logger: Logger(label: "AirQualityTests"), httpClient: nil)
        let deriver = VariableHourlyDeriver(reader: reader, options: options, domainRegistry: .cams_global)
        let variable = ForecastVariable.surface(.init(.us_aqi_o3, 0))
        let start = Timestamp(2025, 1, 2)

        for dtSeconds in [3600, 3 * 3600, 6 * 3600] {
            recorder.reset()
            let time = TimerangeDt(start: start, nTime: 4, dtSeconds: dtSeconds).toSettings()
            let result = try #require(await deriver.get(variable: variable, time: time))
            #expect(result.data.count == 4)

            let windowSteps = Swift.max(8 * 3600 / dtSeconds, 1)
            let expectedPaddedStart = start.add(-windowSteps * dtSeconds)
            let ozoneReads = recorder.reads().filter { $0.variable == .ozone }
            #expect(ozoneReads.contains { $0.time.range.lowerBound == start })
            #expect(ozoneReads.contains { $0.time.range.lowerBound == expectedPaddedStart })

            let accepted = try await deriver.prefetchData(variable: variable, time: time)
            #expect(accepted)
            let ozonePrefetches = recorder.prefetches().filter { $0.variable == .ozone }
            #expect(ozonePrefetches.contains { $0.time.range.lowerBound == start })
            #expect(ozonePrefetches.contains { $0.time.range.lowerBound == expectedPaddedStart })
        }
    }

    @Test func airQualityMixesRawFieldsBeforeDerivation() async throws {
        let recorder = AirQualityReaderRecorder()
        let lower = AirQualityStubReader(values: [
            .pm2_5: 5,
            .pm10: 30,
            .nitrogen_dioxide: 20,
            .ozone: 100,
            .sulphur_dioxide: 40
        ], recorder: recorder)
        let higher = AirQualityStubReader(values: [.pm2_5: 90], recorder: recorder)
        let mixer = GenericReaderMixerSameVariableType(reader: [lower, higher])
        let options = try GenericReaderOptions(logger: Logger(label: "AirQualityTests"), httpClient: nil)
        let deriver = VariableHourlyDeriver(reader: mixer, options: options, domainRegistry: .cams_global)
        let time = TimerangeDt(start: Timestamp(2025, 1, 2), nTime: 1, dtSeconds: 3600).toSettings()

        let pm2_5 = try #require(await deriver.get(variable: .surface(.init(.european_aqi_pm2_5, 0)), time: time))
        let pm10 = try #require(await deriver.get(variable: .surface(.init(.european_aqi_pm10, 0)), time: time))
        let aggregate = try #require(await deriver.get(variable: .surface(.init(.european_aqi, 0)), time: time))

        #expect(pm2_5.data == [EuropeanAirQuality.indexPm2_5(pm2_5: 90)])
        #expect(pm10.data == [EuropeanAirQuality.indexPm10(pm10: 30)])
        #expect(aggregate.data[0] >= pm2_5.data[0])
    }

    @Test func camsUsesGenericMappings() throws {
        for model in [MultiDomains.air_quality_best_match, .cams_global, .cams_europe] {
            guard case .mixedBeforeDerivation = try #require(model.getDomainAndVariable()) else {
                Issue.record("Expected a mixed-before-derivation CAMS mapping for \(model.rawValue)")
                continue
            }
        }

        #expect(MultiDomains.air_quality_best_match.genericDomain == nil)
        #expect(MultiDomains.cams_global.genericDomain?.domainRegistry == .cams_global)
        #expect(MultiDomains.cams_europe.genericDomain?.domainRegistry == .cams_europe)
        #expect(CamsApiDomain.auto.multiDomain == .air_quality_best_match)
        #expect(CamsApiDomain.cams_global.multiDomain == .cams_global)
        #expect(CamsApiDomain.cams_europe.multiDomain == .cams_europe)
        #expect(VariableAndPreviousDay(.pm10, 0).getFlatBuffersMeta().variable == .pm10)
        #expect(VariableAndPreviousDay(.european_aqi, 0).getFlatBuffersMeta().variable == .europeanAqi)
        #expect(MultiDomains.air_quality_best_match.flatBufferModel == .bestMatch)
        #expect(MultiDomains.cams_global.flatBufferModel == .camsGlobal)
        #expect(MultiDomains.cams_europe.flatBufferModel == .camsEurope)
    }
}
