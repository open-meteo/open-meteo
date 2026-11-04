import Foundation
import Testing
@testable import App

@Suite struct GeoSphereSnowfallHeightTests {
    private struct SnowfallHeightReader: GenericReaderProtocol {
        typealias MixingVar = GeoSphereVariable
        let modelLat: Float = 47
        let modelLon: Float = 12.7
        let modelElevation: ElevationOrSea
        let targetElevation: Float = 2000
        let modelDtSeconds = 3600
        let values: [Float]

        func getStatic(type: ReaderStaticVariable) async throws -> Float? { nil }
        func prefetchData(variable: GeoSphereVariable, time: TimerangeDtAndSettings) async throws {}
        func get(variable: GeoSphereVariable, time: TimerangeDtAndSettings) async throws -> DataAndUnit {
            DataAndUnit(values, variable.unit)
        }
    }

    /// 2026-03-26T22Z to 2026-03-27T02Z, the cutover is the third step
    private let time = TimerangeDtAndSettings(time: TimerangeDt(start: Timestamp(2026, 3, 26, 22), nTime: 5, dtSeconds: 3600), ensembleMember: 0, ensembleMemberLevel: 0, previousDay: 0)
    private let stored: [Float] = [2500, 2600, 3000, 1200, .nan]

    private func snowfallHeight(domain: DomainRegistry, modelElevation: ElevationOrSea = .elevation(1500)) async throws -> [Float] {
        let reader = SnowfallHeightReader(modelElevation: modelElevation, values: stored)
        let deriver = VariableHourlyDeriver(reader: reader, options: try GenericReaderOptions(), domainRegistry: domain)
        let variable = try #require(ForecastVariable(rawValue: "snowfall_height"))
        return try #require(try await deriver.get(variable: variable, time: time)).data
    }

    @Test func aromeSubtractsGridElevationFromCutover() async throws {
        let result = try await snowfallHeight(domain: .geosphere_arome_austria)
        #expect(Array(result[0..<4]) == [2500, 2600, 1500, 0])
        #expect(result[4].isNaN)
    }

    @Test func missingModelElevationGivesNaN() async throws {
        let result = try await snowfallHeight(domain: .geosphere_arome_austria, modelElevation: .landWithoutElevation)
        #expect(Array(result[0..<2]) == [2500, 2600])
        #expect(result[2].isNaN && result[3].isNaN && result[4].isNaN)
    }

    @Test func otherDomainsAreUnchanged() async throws {
        let result = try await snowfallHeight(domain: .ecmwf_ifs025)
        #expect(Array(result[0..<4]) == [2500, 2600, 3000, 1200])
        #expect(result[4].isNaN)
    }
}
