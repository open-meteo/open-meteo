import Foundation
import Logging
import Testing
@testable import App

@Suite struct SoilLayerDerivationTests {
    private struct SoilReader<Variable: GenericVariable>: GenericReaderProtocol {
        typealias MixingVar = Variable
        let modelLat: Float = 45
        let modelLon: Float = -100
        let modelElevation: ElevationOrSea = .elevation(100)
        let targetElevation: Float = 100
        let modelDtSeconds = 3600
        var nativeValues: [Float]?

        func getStatic(type: ReaderStaticVariable) async throws -> Float? { nil }
        func prefetchData(variable: Variable, time: TimerangeDtAndSettings) async throws {}
        func get(variable: Variable, time: TimerangeDtAndSettings) async throws -> DataAndUnit {
            if let nativeValues { return DataAndUnit(nativeValues, variable.unit) }
            let depth = try #require(Float(variable.rawValue.split(separator: "_").last!.dropLast(2)))
            return DataAndUnit([0.2, depth / 1000, depth == 30 ? 1 : 0, depth == 60 ? .nan : 1], variable.unit)
        }
    }

    private var time: TimerangeDtAndSettings {
        .init(time: TimerangeDt(start: Timestamp(2026, 9, 20), nTime: 4, dtSeconds: 3600), ensembleMember: 0, ensembleMemberLevel: 0, previousDay: 0, run: nil)
    }

    @Test func weightedRrfsLayers() async throws {
        let options = try GenericReaderOptions(logger: Logger(label: "soil-layer-test"), httpClient: nil)
        for domain in [DomainRegistry.ncep_rrfs_conus, .ncep_rrfs_north_america] {
            let deriver = VariableHourlyDeriver(reader: SoilReader<NcepRrfsSurfaceVariable>(), options: options, domainRegistry: domain)
            for kind in ["temperature", "moisture"] {
                for (layer, midpoint, impulse, missing) in [
                    ("0_to_10", Float(5), Float(0), false),
                    ("10_to_40", 25, 11.0 / 18, true),
                    ("40_to_100", 70, 1.0 / 9, true),
                    ("100_to_200", 150, 0, false)
                ] {
                    let variable = try #require(ForecastVariable(rawValue: "soil_\(kind)_\(layer)cm"))
                    let output = try await deriver.get(variable: variable, time: time)
                    let result = try #require(output)
                    #expect(abs(result.data[0] - 0.2) < 0.000001)
                    #expect(abs(result.data[1] - midpoint / 1000) < 0.000001)
                    #expect(abs(result.data[2] - impulse) < 0.000001)
                    if missing {
                        #expect(result.data[3].isNaN)
                    } else {
                        #expect(abs(result.data[3] - 1) < 0.000001)
                    }
                    #expect(result.unit == (kind == "temperature" ? .celsius : .cubicMetrePerCubicMetre))
                }
            }
        }
    }

    @Test func nativeLayersTakePrecedence() async throws {
        let options = try GenericReaderOptions(logger: Logger(label: "soil-native-test"), httpClient: nil)
        let deriver = VariableHourlyDeriver(reader: SoilReader<Gfs013Variable>(nativeValues: [1, 2, 3, 4]), options: options, domainRegistry: .ncep_gfs013)
        for kind in ["temperature", "moisture"] {
            for layer in ["0_to_10", "10_to_40", "40_to_100", "100_to_200"] {
                let variable = try #require(ForecastVariable(rawValue: "soil_\(kind)_\(layer)cm"))
                let result = try await deriver.get(variable: variable, time: time)
                #expect(result?.data == [1, 2, 3, 4])
            }
        }
    }

    @Test func missingSoilProfileIsUnavailable() throws {
        let options = try GenericReaderOptions(logger: Logger(label: "soil-missing-test"), httpClient: nil)
        let ensemble = VariableHourlyDeriver(reader: SoilReader<NcepRrfsEnsembleSurfaceVariable>(), options: options, domainRegistry: .ncep_rrfs_conus_ensemble)
        let subhourly = VariableHourlyDeriver(reader: SoilReader<NcepRrfs15MinVariable>(), options: options, domainRegistry: .ncep_rrfs_conus_15min)
        for kind in ["temperature", "moisture"] {
            for layer in ["0_to_10", "10_to_40", "40_to_100", "100_to_200"] {
                let variable = try #require(ForecastSurfaceVariable(rawValue: "soil_\(kind)_\(layer)cm"))
                #expect(ensemble.getDeriverMap(variable: variable) == nil)
                #expect(subhourly.getDeriverMap(variable: variable) == nil)
            }
        }
    }
}
