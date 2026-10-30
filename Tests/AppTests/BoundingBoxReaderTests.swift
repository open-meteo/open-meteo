import Testing
@testable import App

@Suite struct BoundingBoxReaderTests {
    @Test(arguments: [true, false])
    func boundingBoxPreservesOutputCoordinatesWithMixedSources(mixedVariableSchemas: Bool) async throws {
        let output = BoundingBoxFixtureDomain(grid: RegularGrid(nx: 3, ny: 1, latMin: 45, lonMin: -75, dx: 0.02, dy: 0.02))
        let native = BoundingBoxFixtureDomain(
            domainRegistry: .cmc_gem_rdps_10km,
            grid: RegularGrid(nx: 1, ny: 1, latMin: 45.01, lonMin: -74.98, dx: 1, dy: 1)
        )
        let group = mixedVariableSchemas
            ? RawReaderDerivationGroup(primary: (native, GemVariable.self), supplemental: (output, ProbabilityVariable.self))
            : RawReaderDerivationGroup(domains: [native], variableType: GemVariable.self, derivationDomain: native)
        let mapping = ReaderPlan(
            primary: [
                .domain(output, GemVariable.self),
                .mixedBeforeDerivation(group)
            ],
            gridForBoundingBoxRequests: output
        )
        let factory = mapping.makeFactory(options: try GenericReaderOptions())
        for position in 0..<3 {
            let result = try await factory.getReaders(gridpoint: position)
            let hourly = try #require(result.hourly)
            let expected = output.grid.getCoordinates(gridpoint: position)
            #expect(hourly.modelLat == expected.latitude)
            #expect(hourly.modelLon == expected.longitude)
            #expect(result.daily?.modelLat == expected.latitude)
            #expect(result.daily?.modelLon == expected.longitude)
            #expect(hourly.targetElevation.isNaN)
            #expect(result.daily?.targetElevation.isNaN == true)
        }
    }

    @Test(arguments: [false, true])
    func mixedReadersPreserveExplicitPointElevation(mixedVariableSchemas: Bool) async throws {
        let output = BoundingBoxFixtureDomain()
        let native = BoundingBoxFixtureDomain(
            domainRegistry: .cmc_gem_rdps_10km,
            grid: RegularGrid(nx: 1, ny: 1, latMin: 45.01, lonMin: -74.98, dx: 1, dy: 1)
        )
        let group = mixedVariableSchemas
            ? RawReaderDerivationGroup(primary: (native, GemVariable.self), supplemental: (output, ProbabilityVariable.self))
            : RawReaderDerivationGroup(domains: [output, native], variableType: GemVariable.self, derivationDomain: native)
        let factory = ReaderPlan(primary: [.mixedBeforeDerivation(group)], gridForBoundingBoxRequests: output)
            .makeFactory(options: try GenericReaderOptions())
        let result = try #require(await factory.getReaders(lat: 45, lon: -74.98, elevation: 500, mode: .nearest))
        #expect(result.hourly?.targetElevation == 500)
        #expect(result.daily?.targetElevation == 500)
    }

    @Test func factoryKeepsStoragePositionsSeparateFromOutputCoordinates() async throws {
        let output = BoundingBoxFixtureDomain(grid: RegularGrid(nx: 3, ny: 1, latMin: 45, lonMin: -75, dx: 0.02, dy: 0.02))
        let source = BoundingBoxFixtureDomain(domainRegistry: .cmc_gem_rdps_10km,
            grid: RegularGrid(nx: 2, ny: 1, latMin: 45, lonMin: -75, dx: 0.04, dy: 0.04))
        let factory = ReaderPlan(primary: [.domain(source, GemVariable.self)], gridForBoundingBoxRequests: output)
            .makeFactory(options: try GenericReaderOptions())
        for (outputPosition, sourcePosition) in [(0, 0), (2, 1), (0, 0)] {
            let result = try await factory.getReaders(gridpoint: outputPosition)
            let mixed = try #require(result.hourly as? GenericReaderMultiSameType<ForecastVariable>)
            let derived = try #require(mixed.reader.first as? VariableHourlyDeriver<GenericReaderCached<BoundingBoxFixtureDomain, GemVariable>>)
            #expect(derived.reader.reader.position == sourcePosition)
            #expect(derived.modelLon == output.grid.getCoordinates(gridpoint: outputPosition).longitude)
            #expect(derived.targetElevation.isNaN)
        }
    }

    @Test(arguments: [Float(500), .nan])
    func resolvedLocationPreservesSourceTerrain(elevation: Float) throws {
        let location = ReaderLocation(source: .init(position: 1, elevation: .elevation(900)),
            output: .init(latitude: 46, longitude: -74, elevation: elevation))
        let reader = GenericReader<BoundingBoxFixtureDomain, GemVariable>(domain: BoundingBoxFixtureDomain(), location: location, run: nil)
        #expect(reader.position == 1)
        #expect(reader.modelElevation.numeric == 900)
        #expect(reader.modelLat == 46)
        #expect(reader.modelLon == -74)
        #expect(elevation.isNaN ? reader.targetElevation.isNaN : reader.targetElevation == elevation)
    }

    @Test func missingOutputTerrainDisablesCorrections() async throws {
        let output = BoundingBoxFixtureDomain()
        let mapping = ReaderPlan(
            primary: [.domain(output, GemVariable.self)], gridForBoundingBoxRequests: output
        )
        let factory = mapping.makeFactory(options: try GenericReaderOptions())
        let result = try await factory.getReaders(gridpoint: 1)
        let hourly = try #require(result.hourly)
        let daily = try #require(result.daily)
        #expect(hourly.targetElevation.isNaN)
        #expect(daily.targetElevation.isNaN)
    }
}

/// No static registry: these readers never access installed weather data.
private struct BoundingBoxFixtureDomain: GenericDomain {
    var domainRegistry = DomainRegistry.cmc_gem_rdps
    let domainRegistryStatic: DomainRegistry? = nil
    var grid: any Gridable = RegularGrid(nx: 2, ny: 1, latMin: 45, lonMin: -75, dx: 0.02, dy: 0.02)
    let dtSeconds = 3600
    let updateIntervalSeconds = 21600
    let masterTimeRange: Range<Timestamp>? = nil
    let omFileLength = 4
    let countEnsembleMember = 1
}
