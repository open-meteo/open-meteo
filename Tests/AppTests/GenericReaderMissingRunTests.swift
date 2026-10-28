import Foundation
import Testing
import Vapor
@testable import App

@Suite struct GenericReaderMissingRunTests {
    private let run = Timestamp(1902, 1, 1, 6).toIsoDateTime()

    private func options(run: IsoDateTime? = nil) throws -> GenericReaderOptions {
        try GenericReaderOptions(run: run)
    }

    @Test(arguments: [true, false])
    func missingRunThrowsDuringInitialization(byCoordinates: Bool) async throws {
        let domain = RunFixtureDomain(availability: .missing)
        let options = try options(run: run)
        await #expect {
            if byCoordinates {
                _ = try await GenericReader<RunFixtureDomain, GemVariable>(domain: domain, lat: 45, lon: -75, elevation: 100, mode: .nearest, options: options)
            } else {
                _ = try await GenericReader<RunFixtureDomain, GemVariable>(domain: domain, position: 0, options: options)
            }
        } throws: { error in
            guard case ForecastApiError.modelRunUnavailable(let model, let timestamp) = error else { return false }
            return model == domain.domainRegistry && timestamp == run.toTimestamp()
        }
    }

    @Test func ordinaryReaderDoesNotRequireRunMetadata() async throws {
        // Any metadata lookup throws, proving that readers without a run skip it.
        let domain = RunFixtureDomain(availability: .failure)
        let reader = try await GenericReader<RunFixtureDomain, GemVariable>(domain: domain, position: 0, options: options())
        #expect(reader.run == nil)
        #expect(reader.modelLat == 45)
        #expect(reader.modelLon == -75)
    }

    @Test func outsideGridStillReturnsNilWithoutRun() async throws {
        let reader = try await GenericReader<RunFixtureDomain, GemVariable>(domain: .init(availability: .failure), lat: -80, lon: 100, elevation: 0, mode: .nearest, options: options())
        #expect(reader == nil)
    }

    @Test(arguments: [true, false], [true, false])
    func primaryCoverageFlagControlsSecondaryFallback(localCoverage: Bool, requirePrimaryCoverage: Bool) async throws {
        let mapping = MultiDomains.DomainReaderMapping(
            primary: [.domain(RunFixtureDomain(grid: grid(coversLocation: localCoverage)), GemVariable.self)],
            secondary: [.domain(RunFixtureDomain(), GemVariable.self)],
            requirePrimaryCoverage: requirePrimaryCoverage
        )
        let result = try await mapping.getReaders(lat: 45, lon: -75, elevation: .nan, mode: .nearest, options: options())
        #expect((result?.hourly != nil) == (localCoverage || !requirePrimaryCoverage))
        #expect(mapping.singleDomain == nil)
    }

    @Test(arguments: [true, false])
    func singleWithPrecipitationProbabilityRequiresPrimaryCoverage(localCoverage: Bool) async throws {
        let mapping = MultiDomains.DomainReaderMapping.singleWithPrecipitationProbability(
            RunFixtureDomain(grid: grid(coversLocation: localCoverage)), GemVariable.self, precipitationProb: RunFixtureDomain()
        )
        let result = try await mapping.getReaders(lat: 45, lon: -75, elevation: .nan, mode: .nearest, options: options())
        if localCoverage {
            #expect(result?.hourly != nil)
        } else {
            #expect(result == nil)
        }
    }

    @Test func queryPassesRunToReaderOptions() throws {
        let query = try JSONDecoder().decode(ApiQueryParameter.self, from: Data(#"{"run":"2026-06-01T06:00"}"#.utf8))
        let options = try query.readerOptions()
        #expect(options.run == query.run)
    }

    @Test(arguments: [true, false])
    func explicitRunAlsoRespectsPrimaryCoverage(requirePrimaryCoverage: Bool) async throws {
        let mapping = MultiDomains.DomainReaderMapping(
            primary: [.domain(RunFixtureDomain(grid: grid(coversLocation: false), availability: .available(run.toTimestamp())), GemVariable.self)],
            secondary: [.domain(RunFixtureDomain(availability: .available(run.toTimestamp())), GemVariable.self)],
            requirePrimaryCoverage: requirePrimaryCoverage
        )
        let result = try await mapping.getReaders(lat: 45, lon: -75, elevation: .nan, mode: .nearest, options: options(run: run))
        #expect((result?.hourly != nil) == !requirePrimaryCoverage)
    }

    @Test func readerRetainsValidatedRun() async throws {
        let domain = RunFixtureDomain(availability: .available(run.toTimestamp()))
        var options = try options(run: run)
        let positioned = try await GenericReader<RunFixtureDomain, GemVariable>(domain: domain, position: 0, options: options)
        let located = try #require(await GenericReader<RunFixtureDomain, GemVariable>(domain: domain, lat: 45, lon: -75, elevation: .nan, mode: .nearest, options: options))
        options.run = nil
        #expect(positioned.run == run)
        #expect(located.run == run)
    }

    @Test(arguments: [true, false], [true, false])
    func eitherGenerationCanSupplyRun(oldAvailable: Bool, newAvailable: Bool) async throws {
        let old = RunFixtureDomain(availability: oldAvailable ? .available(run.toTimestamp()) : .missing)
        let new = RunFixtureDomain(domainRegistry: .cmc_gem_rdps_10km, availability: newAvailable ? .available(run.toTimestamp()) : .missing)
        let mapping = MultiDomains.DomainReaderMapping(
            primary: [.mixedBeforeDerivation(.init(domains: [old, new], variableType: GemVariable.self, derivationDomain: new))],
            requirePrimaryCoverage: true
        )
        if oldAvailable || newAvailable {
            let result = try await mapping.getReaders(lat: 45, lon: -75, elevation: 100, mode: .nearest, options: options(run: run))
            #expect(result?.hourly != nil)
        } else {
            await #expect {
                _ = try await mapping.getReaders(lat: 45, lon: -75, elevation: 100, mode: .nearest, options: options(run: run))
            } throws: { error in
                guard case ForecastApiError.modelRunUnavailable(let model, let timestamp) = error else { return false }
                return model == new.domainRegistry && timestamp == run.toTimestamp()
            }
        }
    }

    @Test(arguments: [true, false], [true, false])
    func secondaryRunDoesNotDetermineAvailability(primaryAvailable: Bool, secondaryAvailable: Bool) async throws {
        let primary = RunFixtureDomain(availability: primaryAvailable ? .available(run.toTimestamp()) : .missing)
        let secondary = RunFixtureDomain(domainRegistry: .cmc_gem_geps, availability: secondaryAvailable ? .available(run.toTimestamp()) : .missing)
        let mapping = MultiDomains.DomainReaderMapping.singleWithPrecipitationProbability(primary, GemVariable.self, precipitationProb: secondary)
        if primaryAvailable {
            let result = try await mapping.getReaders(lat: 45, lon: -75, elevation: 100, mode: .nearest, options: options(run: run))
            #expect(result?.hourly != nil)
        } else {
            await #expect {
                _ = try await mapping.getReaders(lat: 45, lon: -75, elevation: 100, mode: .nearest, options: options(run: run))
            } throws: { error in
                guard case ForecastApiError.modelRunUnavailable(let model, let timestamp) = error else { return false }
                return model == primary.domainRegistry && timestamp == run.toTimestamp()
            }
        }
    }

    @Test func availableRawGroupOutsideCoverageDoesNotReportMissingRun() async throws {
        let old = RunFixtureDomain(availability: .available(run.toTimestamp()))
        let new = RunFixtureDomain(domainRegistry: .cmc_gem_rdps_10km, availability: .missing)
        let mapping = MultiDomains.DomainReaderMapping(
            primary: [.mixedBeforeDerivation(.init(domains: [old, new], variableType: GemVariable.self, derivationDomain: new))],
            requirePrimaryCoverage: true
        )
        let result = try await mapping.getReaders(lat: -80, lon: 100, elevation: 0, mode: .nearest, options: options(run: run))
        #expect(result == nil)
    }

    @Test(arguments: [true, false])
    func metadataErrorsAreNotSuppressed(secondaryFails: Bool) async throws {
        let primary = RunFixtureDomain(availability: secondaryFails ? .available(run.toTimestamp()) : .failure)
        let secondary = RunFixtureDomain(domainRegistry: .cmc_gem_geps, availability: secondaryFails ? .failure : .available(run.toTimestamp()))
        let mapping = MultiDomains.DomainReaderMapping.singleWithPrecipitationProbability(primary, GemVariable.self, precipitationProb: secondary)
        await #expect(throws: DecodingError.self) {
            _ = try await mapping.getReaders(lat: 45, lon: -75, elevation: 100, mode: .nearest, options: options(run: run))
        }
    }

    @Test(arguments: [true, false])
    func boundingBoxSkipsMissingPrimaryRuns(newAvailable: Bool) async throws {
        let old = RunFixtureDomain(availability: .missing)
        let new = RunFixtureDomain(domainRegistry: .cmc_gem_rdps_10km, availability: newAvailable ? .available(run.toTimestamp()) : .missing)
        let mapping = MultiDomains.DomainReaderMapping(
            primary: [
                .domain(old, GemVariable.self),
                .mixedBeforeDerivation(.init(domains: [new], variableType: GemVariable.self, derivationDomain: new))
            ],
            gridForBoundingBoxRequests: old,
            prefetchAllReaders: true, smoothTransitions: false
        )
        if newAvailable {
            let result = try await MultiDomains.cmc_gem_rdps.getReaders(gridpoint: 0, mapping: mapping, options: options(run: run))
            #expect(result.hourly != nil)
        } else {
            await #expect {
                _ = try await MultiDomains.cmc_gem_rdps.getReaders(gridpoint: 0, mapping: mapping, options: options(run: run))
            } throws: { error in
                guard case ForecastApiError.modelRunUnavailable = error else { return false }
                return true
            }
        }
    }

    @Test(arguments: [true, false])
    func boundingBoxPreservesOutputCoordinatesWithMixedSources(mixedSchemas: Bool) async throws {
        let output = RunFixtureDomain(grid: RegularGrid(nx: 3, ny: 1, latMin: 45, lonMin: -75, dx: 0.02, dy: 0.02))
        let native = RunFixtureDomain(
            domainRegistry: .cmc_gem_rdps_10km,
            grid: RegularGrid(nx: 1, ny: 1, latMin: 45.01, lonMin: -74.98, dx: 1, dy: 1)
        )
        let group = mixedSchemas
            ? MultiDomains.RawReaderDerivationGroup(primary: (native, GemVariable.self), supplemental: (output, GemVariable.self))
            : MultiDomains.RawReaderDerivationGroup(domains: [native], variableType: GemVariable.self, derivationDomain: native)
        let mapping = MultiDomains.DomainReaderMapping(
            primary: [
                .domain(output, GemVariable.self),
                .mixedBeforeDerivation(group)
            ], 
            gridForBoundingBoxRequests: output
        )
        for position in 0..<3 {
            let result = try await MultiDomains.dwd_icon_d2.getReaders(gridpoint: position, mapping: mapping, options: options())
            let hourly = try #require(result.hourly)
            let expected = output.grid.getCoordinates(gridpoint: position)
            let remapped = try await GenericReader<RunFixtureDomain, GemVariable>(
                domain: native, position: 0, modelCoordinates: expected, elevation: 500, options: options()
            )
            #expect(remapped.targetElevation == 500)
            #expect(remapped.modelLat == expected.latitude)
            #expect(remapped.modelLon == expected.longitude)
            let rawGroup = try #require(await group.makeReader(coordinate: expected, options: options()))
            #expect(rawGroup.reader.modelLat == expected.latitude)
            #expect(rawGroup.reader.modelLon == expected.longitude)
            #expect(hourly.modelLat == expected.latitude)
            #expect(hourly.modelLon == expected.longitude)
            #expect(result.daily?.modelLat == expected.latitude)
            #expect(result.daily?.modelLon == expected.longitude)
        }
    }

    private func grid(coversLocation: Bool) -> RegularGrid {
        RegularGrid(nx: 1, ny: 1, latMin: coversLocation ? 45 : 0, lonMin: -75, dx: 1, dy: 1)
    }
}

/// An in-memory domain: run availability is explicit and static files are disabled.
private struct RunFixtureDomain: GenericDomain {
    enum Availability: Sendable {
        case available(Timestamp)
        case missing
        case failure
    }

    var domainRegistry = DomainRegistry.cmc_gem_rdps
    let domainRegistryStatic: DomainRegistry? = nil
    var grid: any Gridable = RegularGrid(nx: 1, ny: 1, latMin: 45, lonMin: -75, dx: 1, dy: 1)
    var availability: Availability = .missing
    let dtSeconds = 3600
    let updateIntervalSeconds = 21600
    let masterTimeRange: Range<Timestamp>? = nil
    let omFileLength = 4
    let countEnsembleMember = 1

    func isRunAvailable(run: Timestamp) async throws -> Bool {
        switch availability {
        case .available(let expectedRun):
            #expect(run == expectedRun)
            return run == expectedRun
        case .missing:
            return false
        case .failure:
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Invalid run metadata"))
        }
    }
}
