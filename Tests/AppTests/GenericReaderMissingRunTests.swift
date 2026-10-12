import Foundation
import OmFileFormat
import OmFileIO
import Testing
import Vapor
@testable import App

@Suite struct GenericReaderMissingRunTests {
    @Test(arguments: [true, false])
    func missingRunThrowsDuringInitialization(byCoordinates: Bool) async throws {
        let run = Timestamp(1900, 6, 1, 6).toIsoDateTime()
        let options = try GenericReaderOptions(logger: Logger(label: "missing-run-test"), httpClient: nil, run: run)
        await #expect {
            if byCoordinates {
                _ = try await GenericReader<IconDomains, IconVariable>(domain: .icon, lat: 45, lon: 8, elevation: 100, mode: .nearest, options: options)
            } else {
                _ = try await GenericReader<IconDomains, IconVariable>(domain: .icon, position: 0, options: options)
            }
        } throws: { error in
            guard case ForecastApiError.modelRunUnavailable(let model, let timestamp) = error else { return false }
            return model == IconDomains.icon.domainRegistry && timestamp == run.toTimestamp()
        }
    }

    @Test func ordinaryReaderDoesNotRequireRunMetadata() async throws {
        let options = try GenericReaderOptions(logger: Logger(label: "missing-run-test"), httpClient: nil)
        let reader = try await GenericReader<GemDomain, GemVariable>(domain: .gem_regional, position: 0, options: options)
        #expect(reader.domain == .gem_regional)
    }

    @Test func outsideGridStillReturnsNilWithoutRun() async throws {
        let options = try GenericReaderOptions(logger: Logger(label: "missing-run-test"), httpClient: nil)
        let reader = try await GenericReader<GemDomain, GemVariable>(domain: .gem_regional, lat: -80, lon: 100, elevation: 0, mode: .nearest, options: options)
        #expect(reader == nil)
    }

    @Test(arguments: [true, false], [true, false])
    func primaryCoverageFlagControlsSecondaryFallback(localCoverage: Bool, requirePrimaryCoverage: Bool) async throws {
        let coverage = RegularGrid(nx: 1, ny: 1, latMin: localCoverage ? 45 : 0, lonMin: -75, dx: 1, dy: 1)
        let mapping = MultiDomains.DomainReaderMapping(
            primary: [.domain(RunFixtureDomain(grid: coverage), GemVariable.self)],
            secondary: [.domain(RunFixtureDomain(), GemVariable.self)],
            requirePrimaryCoverage: requirePrimaryCoverage
        )
        let options = try GenericReaderOptions(logger: Logger(label: "coverage-test"), httpClient: nil)
        let result = try await mapping.getReaders(lat: 45, lon: -75, elevation: .nan, mode: .nearest, options: options)
        #expect((result?.hourly != nil) == (localCoverage || !requirePrimaryCoverage))
        #expect(mapping.singleDomain == nil)
    }

    @Test func queryPassesRunToReaderOptions() throws {
        let query = try JSONDecoder().decode(ApiQueryParameter.self, from: Data(#"{"run":"2026-06-01T06:00"}"#.utf8))
        let options = try query.readerOptions(logger: Logger(label: "missing-run-test"), httpClient: .shared)
        #expect(options.run == query.run)
    }
}

/// Supply an isolated DATA_RUN_DIRECTORY to exercise actual metadata files.
@Suite(.serialized, .enabled(if: OpenMeteo.dataRunDirectory != nil))
struct ReaderRunInitializationTests {
    private let variable = ForecastVariable.surface(.init(.temperature_2m, 0))

    private func withMetadata(run: Timestamp, available: [DomainRegistry], corrupt: [DomainRegistry] = [], body: (GenericReaderOptions) async throws -> Void) async throws {
        let root = try #require(OpenMeteo.dataRunDirectory)
        var created: [String] = []
        defer {
            for path in created {
                try? FileManager.default.removeItem(atPath: path)
            }
        }
        for domain in available + corrupt {
            let directory = "\(root)\(domain.rawValue)/\(run.format_directoriesYYYYMMddhhmm)/"
            try #require(!FileManager.default.fileExists(atPath: directory))
            try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
            created.append(directory)
            // Deliberately no variable files: a valid run with missing values is still available.
            let metadata = corrupt.contains(domain) ? Data("invalid json".utf8) : Data(#"{"reference_time":"1901-01-01T00:00:00Z","created_at":"1901-01-01T00:00:00Z","variables":[],"valid_times":[],"temporal_resolution_seconds":3600}"#.utf8)
            try metadata.write(to: URL(fileURLWithPath: directory + "meta.json"))
        }
        await OmFileSystemManager.instance.updateLocalDirectory(path: "data_run/")
        for domain in available + corrupt {
            var path = "data_run/\(domain.rawValue)/"
            await OmFileSystemManager.instance.updateLocalDirectory(path: path)
            for component in run.format_directoriesYYYYMMddhhmm.split(separator: "/") {
                path += "\(component)/"
                await OmFileSystemManager.instance.updateLocalDirectory(path: path)
            }
        }
        try await body(GenericReaderOptions(logger: Logger(label: "run-init-test"), httpClient: nil, run: run.toIsoDateTime()))
    }

    @Test(arguments: [true, false])
    func explicitRunAlsoRespectsPrimaryCoverage(requirePrimaryCoverage: Bool) async throws {
        let run = Timestamp(1902, 6, requirePrimaryCoverage ? 1 : 2, 0)
        try await withMetadata(run: run, available: [RunFixtureDomain().domainRegistry]) { options in
            let mapping = MultiDomains.DomainReaderMapping(
                primary: [.domain(RunFixtureDomain(grid: RegularGrid(nx: 1, ny: 1, latMin: 0, lonMin: 0, dx: 1, dy: 1)), GemVariable.self)],
                secondary: [.domain(RunFixtureDomain(), GemVariable.self)],
                requirePrimaryCoverage: requirePrimaryCoverage
            )
            let result = try await mapping.getReaders(lat: 45, lon: -75, elevation: .nan, mode: .nearest, options: options)
            #expect((result?.hourly != nil) == !requirePrimaryCoverage)
        }
    }

    @Test func readerKeepsSelectedRunAcrossTimeSettings() async throws {
        let run = Timestamp(1902, 5, 1, 0)
        let domain = RunFixtureDomain()
        try await withMetadata(run: run, available: [domain.domainRegistry]) { options in
            let root = try #require(OpenMeteo.dataRunDirectory)
            let directory = "\(domain.domainRegistry.rawValue)/\(run.format_directoriesYYYYMMddhhmm)/"
            let file = try FileHandle.createNewFile(file: root + directory + "temperature_2m.om", overwrite: false)
            let writer = OmFileWriter(fn: file, initialCapacity: 4096)
            let values: [Float] = [10, 20, 30, 40]
            let data = try writer.writeArray(data: values, dimensions: [1, 1, 4], chunkDimensions: [1, 1, 4], compression: .pfor_delta2d_int16, scale_factor: 1, add_offset: 0)
            let times = try writer.writeArray(data: (0..<4).map { run.add(hours: $0).timeIntervalSince1970 }, dimensions: [4], chunkDimensions: [4], compression: .pfor_delta2d, scale_factor: 1, add_offset: 0)
            let timeVariable = try writer.write(array: times, name: "time", children: [])
            let dataVariable = try writer.write(array: data, name: "", children: [timeVariable])
            try writer.writeTrailer(rootVariable: dataVariable)
            await OmFileSystemManager.instance.updateLocalDirectory(path: "data_run/" + directory)

            let positioned = try await GenericReader<RunFixtureDomain, GemVariable>(domain: domain, position: 0, options: options)
            let located = try #require(await GenericReader<RunFixtureDomain, GemVariable>(domain: domain, lat: 45, lon: -75, elevation: .nan, mode: .nearest, options: options))
            let time = TimerangeDt(start: run, nTime: 4, dtSeconds: 3600).toSettings()
            for reader in [positioned, located] {
                #expect(reader.run == options.run)
                try await reader.prefetchData(variable: .surface(.temperature_2m), time: time)
                #expect(try await reader.get(variable: .surface(.temperature_2m), time: time).data == values)
                #expect(try await reader.get(variable: .surface(.temperature_2m), time: time.with(start: run.add(hours: 1))).data == [20, 30, 40])
            }

            let sources: [MultiDomains.DomainReaderMapping.Source] = [
                .domain(domain, GemVariable.self),
                .mixedBeforeDerivation(.init(domains: [domain], variableType: GemVariable.self, derivationDomain: domain))
            ]
            for source in sources {
                let mapping = MultiDomains.DomainReaderMapping(primary: [source], gridForBoundingBoxRequests: domain)
                let located = try #require(await mapping.getReaders(lat: 45, lon: -75, elevation: .nan, mode: .nearest, options: options)?.hourly)
                let positioned = try #require(await MultiDomains.cmc_gem_rdps.getReaders(gridpoint: 0, mapping: mapping, options: options).hourly)
                for reader in [located, positioned] {
                    _ = try await reader.prefetchData(variable: variable, time: time)
                    #expect(try await reader.get(variable: variable, time: time)?.data == values)
                }
            }
        }
    }

    @Test(arguments: [true, false], [true, false])
    func eitherRdpsGenerationCanSupplyRun(oldAvailable: Bool, newAvailable: Bool) async throws {
        let run = Timestamp(1902, 1, 1 + (oldAvailable ? 1 : 0) + (newAvailable ? 2 : 0), 0)
        let available: [DomainRegistry] = [(GemDomain.gem_regional, oldAvailable), (.gem_rdps_10km, newAvailable)].compactMap { $0.1 ? $0.0.domainRegistry : nil }
        try await withMetadata(run: run, available: available) { options in
            for model in [MultiDomains.cmc_gem_rdps, .gem_regional] {
                if oldAvailable || newAvailable {
                    let result = try #require(await model.getReaders(lat: 45, lon: -75, elevation: 100, mode: .nearest, options: options, biasCorrection: false, include15Min: false))
                    let reader = try #require(result.hourly)
                    let time = TimerangeDt(start: run, nTime: 4, dtSeconds: 3600).toSettings()
                    #expect(try await reader.prefetchData(variable: variable, time: time))
                    let data = try #require(await reader.get(variable: variable, time: time))
                    #expect(data.data.count == 4)
                    #expect(data.data.allSatisfy { $0.isNaN })
                } else {
                    await #expect {
                        _ = try await model.getReaders(lat: 45, lon: -75, elevation: 100, mode: .nearest, options: options, biasCorrection: false, include15Min: false)
                    } throws: { error in
                        guard case ForecastApiError.modelRunUnavailable = error else { return false }
                        return true
                    }
                }
            }
        }
    }

    @Test(arguments: [true, false], [true, false])
    func secondaryRunDoesNotDetermineAvailability(primaryAvailable: Bool, secondaryAvailable: Bool) async throws {
        let run = Timestamp(1902, 2, 1 + (primaryAvailable ? 1 : 0) + (secondaryAvailable ? 2 : 0), 0)
        let available: [DomainRegistry] = [(GemDomain.gem_regional, primaryAvailable), (.gem_global_ensemble, secondaryAvailable)].compactMap { $0.1 ? $0.0.domainRegistry : nil }
        let mapping = MultiDomains.DomainReaderMapping(
            primary: [
                .domain(GemDomain.gem_regional, GemVariable.self),
                .mixedBeforeDerivation(.init(domains: [GemDomain.gem_rdps_10km], variableType: GemVariable.self, derivationDomain: .gem_rdps_10km))
            ],
            secondary: [.domain(GemDomain.gem_global_ensemble, ProbabilityVariable.self)]
        )
        try await withMetadata(run: run, available: available) { options in
            if primaryAvailable {
                let result = try #require(await mapping.getReaders(lat: 45, lon: -75, elevation: 100, mode: .nearest, options: options))
                #expect(result.hourly != nil)
            } else {
                await #expect {
                    _ = try await mapping.getReaders(lat: 45, lon: -75, elevation: 100, mode: .nearest, options: options)
                } throws: { error in
                    guard case ForecastApiError.modelRunUnavailable(let model, _) = error else { return false }
                    return model != GemDomain.gem_global_ensemble.domainRegistry
                }
            }
        }
    }

    @Test func availableRawGroupOutsideCoverageDoesNotReportMissingRun() async throws {
        let run = Timestamp(1902, 7, 1, 0)
        let mapping = MultiDomains.DomainReaderMapping(
            primary: [.mixedBeforeDerivation(.init(
                domains: [GemDomain.gem_regional, .gem_rdps_10km],
                variableType: GemVariable.self, derivationDomain: .gem_rdps_10km
            ))],
            requirePrimaryCoverage: true
        )
        try await withMetadata(run: run, available: [GemDomain.gem_regional.domainRegistry]) { options in
            let result = try await mapping.getReaders(lat: -80, lon: 100, elevation: 0, mode: .nearest, options: options)
            #expect(result == nil)
        }
    }

    @Test func corruptSecondaryMetadataIsNotSuppressed() async throws {
        let run = Timestamp(1902, 3, 1, 0)
        try await withMetadata(run: run, available: [GemDomain.gem_regional.domainRegistry], corrupt: [GemDomain.gem_global_ensemble.domainRegistry]) { options in
            let mapping = MultiDomains.DomainReaderMapping.singleWithPrecipitationProbability(GemDomain.gem_regional, GemVariable.self, precipitationProb: GemDomain.gem_global_ensemble)
            await #expect(throws: DecodingError.self) {
                _ = try await mapping.getReaders(lat: 45, lon: -75, elevation: 100, mode: .nearest, options: options)
            }
        }
    }

    @Test(arguments: [true, false])
    func boundingBoxSkipsMissingPrimaryRuns(newAvailable: Bool) async throws {
        let run = Timestamp(1902, 4, newAvailable ? 1 : 2, 0)
        let mapping = MultiDomains.DomainReaderMapping(
            primary: [
                .domain(GemDomain.gem_regional, GemVariable.self),
                .mixedBeforeDerivation(.init(domains: [GemDomain.gem_rdps_10km], variableType: GemVariable.self, derivationDomain: .gem_rdps_10km))
            ],
            gridForBoundingBoxRequests: GemDomain.gem_regional,
            prefetchAllReaders: true, smoothTransitions: false
        )
        let position = try #require(GemDomain.gem_regional.grid.findPoint(lat: 45, lon: -75))
        try await withMetadata(run: run, available: newAvailable ? [GemDomain.gem_rdps_10km.domainRegistry] : []) { options in
            if newAvailable {
                let result = try await MultiDomains.cmc_gem_rdps.getReaders(gridpoint: position, mapping: mapping, options: options)
                #expect(result.hourly != nil)
            } else {
                await #expect(throws: ForecastApiError.self) {
                    _ = try await MultiDomains.cmc_gem_rdps.getReaders(gridpoint: position, mapping: mapping, options: options)
                }
            }
        }
    }
}


private struct RunFixtureDomain: GenericDomain {
    let domainRegistry = DomainRegistry.cmc_gem_rdps
    let domainRegistryStatic: DomainRegistry? = nil
    var grid: any Gridable = RegularGrid(nx: 1, ny: 1, latMin: 45, lonMin: -75, dx: 1, dy: 1)
    let dtSeconds = 3600
    let updateIntervalSeconds = 21600
    let hasYearlyFiles = false
    let masterTimeRange: Range<Timestamp>? = nil
    let omFileLength = 4
    let countEnsembleMember = 1
}
