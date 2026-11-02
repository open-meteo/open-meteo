import Testing
@testable import App

@Suite struct EumetsatSarahReaderTests {
    private struct Reader: GenericReaderProtocol {
        typealias MixingVar = EumetsatSarahVariable
        let modelLat: Float = 47
        let modelLon: Float = 8
        let modelElevation: ElevationOrSea = .elevation(400)
        let targetElevation: Float = 400
        let modelDtSeconds = 1800
        var missingCorrected = false

        func getStatic(type: ReaderStaticVariable) async throws -> Float? { nil }
        func prefetchData(variable: EumetsatSarahVariable, time: TimerangeDtAndSettings) async throws {}
        func get(variable: EumetsatSarahVariable, time: TimerangeDtAndSettings) async throws -> DataAndUnit {
            let value: Float
            switch variable.omFileName.file {
            case "shortwave_radiation": value = 100
            case "direct_radiation": value = 50
            case "shortwave_radiation_corrected": value = missingCorrected ? .nan : 120
            case "direct_radiation_corrected": value = missingCorrected ? .nan : 60
            default: throw EumetsatSarahCorrect.RepairError.invalid("Unexpected radiation file")
            }
            return DataAndUnit([Float](repeating: value, count: time.time.count), variable.unit)
        }
    }

    private var time: TimerangeDtAndSettings {
        .init(time: TimerangeDt(start: Timestamp(2024, 6, 21, 12), nTime: 2, dtSeconds: 1800),
              ensembleMember: 0, ensembleMemberLevel: 0, previousDay: 0)
    }

    @Test func originalAndCorrectedVariablesReadSeparateFiles() async throws {
        let deriver = VariableHourlyDeriver(reader: Reader(), options: try GenericReaderOptions(), domainRegistry: .eumetsat_sarah3_30min)
        for (name, expected) in [("shortwave_radiation", Float(100)), ("direct_radiation", 50),
                                 ("shortwave_radiation_corrected", 120), ("direct_radiation_corrected", 60)] {
            let variable = try #require(ForecastVariable(rawValue: name))
            try await deriver.prefetchData(variable: variable, time: time)
            let output = try await deriver.get(variable: variable, time: time)
            let result = try #require(output)
            #expect(result.data == [expected, expected])
            #expect(result.unit == .wattPerSquareMetre)
        }
        // Existing derived radiation keeps using the original series.
        let variable = try #require(ForecastVariable(rawValue: "diffuse_radiation"))
        let diffuse = try await deriver.get(variable: variable, time: time)
        #expect(diffuse?.data == [50, 50])
    }

    @Test func missingCorrectedDataDoesNotUseOriginalValues() async throws {
        let deriver = VariableHourlyDeriver(reader: Reader(missingCorrected: true), options: try GenericReaderOptions(), domainRegistry: .eumetsat_sarah3_30min)
        for name in ["shortwave_radiation_corrected", "direct_radiation_corrected"] {
            let variable = try #require(ForecastVariable(rawValue: name))
            let output = try await deriver.get(variable: variable, time: time)
            let result = try #require(output)
            #expect(result.data.allSatisfy { $0.isNaN })
        }
    }
}
