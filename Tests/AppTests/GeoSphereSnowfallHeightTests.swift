import Testing
@testable import App

@Suite struct GeoSphereSnowfallHeightTests {
    private struct Reader: GenericReaderProtocol {
        let modelLat: Float = 47
        let modelLon: Float = 12
        let modelElevation: ElevationOrSea
        let targetElevation: Float
        let modelDtSeconds = 3600

        func getStatic(type: ReaderStaticVariable) async throws -> Float? { nil }
        func prefetchData(variable: GeoSphereVariable, time: TimerangeDtAndSettings) async throws {}
        func get(variable: GeoSphereVariable, time: TimerangeDtAndSettings) async throws -> DataAndUnit {
            DataAndUnit([4260, 1000, .nan], variable.unit)
        }
    }

    @Test func correctsOnlyAromeUsingModelElevation() async throws {
        let options = try GenericReaderOptions()
        let variable = try #require(ForecastVariable(rawValue: "snowfall_height"))
        for date in [Timestamp(2026, 3, 25), Timestamp(2026, 10, 30)] {
            let time = TimerangeDt(start: date, nTime: 3, dtSeconds: 3600).toSettings()
            let reader = Reader(modelElevation: .elevation(3000), targetElevation: 100)
            for (domain, expected): (DomainRegistry, [Float]) in [
                (.geosphere_arome_austria, [1260, -2000]),
                (.geosphere_claef_austria, [4260, 1000]),
                (.dwd_icon_d2, [4260, 1000])
            ] {
                let deriver = VariableHourlyDeriver(reader: reader, options: options, domainRegistry: domain)
                let result = try #require(try await deriver.get(variable: variable, time: time))
                #expect(Array(result.data.prefix(2)) == expected)
                #expect(result.data[2].isNaN)
                #expect(result.unit == .metre)
            }
        }
    }

    @Test func handlesSeaAndMissingElevation() async throws {
        let options = try GenericReaderOptions()
        let variable = try #require(ForecastVariable(rawValue: "snowfall_height"))
        let time = TimerangeDt(start: Timestamp(2026, 10, 30), nTime: 3, dtSeconds: 3600).toSettings()
        for elevation in [ElevationOrSea.sea, .noData, .landWithoutElevation] {
            let reader = Reader(modelElevation: elevation, targetElevation: 2000)
            let deriver = VariableHourlyDeriver(reader: reader, options: options, domainRegistry: .geosphere_arome_austria)
            let result = try #require(try await deriver.get(variable: variable, time: time))
            if elevation.isSea {
                #expect(result.data[0] == 4260)
            } else {
                #expect(result.data.allSatisfy(\.isNaN))
            }
        }
    }

    @Test func seamlessUsesClaefNotArome() async throws {
        let mapping = try #require(try await MultiDomains.geosphere_seamless.getDomainAndVariable())
        let domains = mapping.primary.compactMap { source -> DomainRegistry? in
            guard case .domain(let domain, _) = source else { return nil }
            return domain.domainRegistry
        }
        #expect(domains == [.ecmwf_ifs025, .ecmwf_ifs, .geosphere_claef_austria])
        let arome = try #require(try await MultiDomains.geosphere_arome_austria.getDomainAndVariable())
        #expect(arome.primary.count == 1)
        guard case .domain(let domain, _) = arome.primary[0] else {
            Issue.record("Expected a single AROME source")
            return
        }
        #expect(domain.domainRegistry == .geosphere_arome_austria)
    }
}
