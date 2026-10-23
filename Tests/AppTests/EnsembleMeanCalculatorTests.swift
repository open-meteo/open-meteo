import Foundation
import Logging
import OmFileIO
import Testing
@testable import App

@Suite struct EnsembleMeanCalculatorTests {
    private func makeWriter(members: Int) throws -> OmSpatialTimestepWriter {
        try FileManager.default.createDirectory(atPath: OpenMeteo.tempDirectory, withIntermediateDirectories: true)
        let run = Timestamp(2026, 10, 21)
        return OmSpatialTimestepWriter(
            domain: StatisticsTestDomain(countEnsembleMember: members), run: run, time: run,
            storeOnDisk: false, realm: nil, logger: Logger(label: "ensemble-statistics-test"),
            ensembleMeanDomain: StatisticsTestDomain(countEnsembleMember: 1)
        )
    }

    @Test func writesCompletedVariablesEarlyAndFlushesPartialVariables() async throws {
        let writer = try makeWriter(members: 3)
        let mean = try #require(await writer.ensembleMean)
        let temperature = EcmwfVariable.temperature_2m
        let precipitation = EcmwfVariable.precipitation

        try await writer.write(member: 0, variable: temperature, data: [1, .nan])
        try await writer.write(member: 0, variable: precipitation, data: [1, 3])
        try await writer.write(member: 1, variable: temperature, data: [3, 4])
        #expect(await mean.calculator.pendingVariableCount == 2)
        #expect(await !mean.writer.contains(member: 0, variable: temperature))

        // Duplicate writes must not advance the ensemble count.
        try await writer.write(member: 1, variable: temperature, data: [100, 100])
        #expect(await !mean.writer.contains(member: 0, variable: temperature))
        try await writer.write(member: 2, variable: temperature, data: [5, 6])
        #expect(await mean.calculator.pendingVariableCount == 1)
        #expect(await mean.writer.contains(member: 0, variable: temperature))
        #expect(await mean.writer.contains(member: 0, variable: temperature.asSpreadVariableGeneric))

        try await writer.write(member: 1, variable: precipitation, data: [3, 5])
        #expect(await !mean.writer.contains(member: 0, variable: precipitation))
        let handles = try await writer.finalise()
        #expect(await mean.calculator.pendingVariableCount == 0)
        #expect(await mean.writer.variableString.count == 4)

        func read(_ name: String) async throws -> [Float] {
            let handle = try #require(handles.first(where: { $0.variable.rawValue == name && $0.domain.countEnsembleMember == 1 }))
            return try await handle.reader.read(range: [0..<1, 0..<2])
        }
        let temperatures = try await read("temperature_2m")
        let temperatureSpread = try await read("temperature_2m_spread")
        #expect(temperatures[0] == 3 && temperatures[1].isNaN)
        #expect(temperatureSpread[0] == 2 && temperatureSpread[1].isNaN)
        #expect(try await read("precipitation") == [2, 4])
        let precipitationSpread = try await read("precipitation_spread")
        #expect(precipitationSpread.allSatisfy { abs($0 - sqrt(Float(2))) < 0.1 })
    }

    @Test func concurrentMembersShareOneSampler() async throws {
        let writer = try makeWriter(members: 51)
        let mean = try #require(await writer.ensembleMean)
        try await withThrowingTaskGroup(of: Void.self) { group in
            for member in 0..<51 {
                group.addTask {
                    try await writer.write(member: member, variable: EcmwfVariable.temperature_2m, data: [Float(member), 7])
                }
            }
            try await group.waitForAll()
        }
        #expect(await mean.calculator.pendingVariableCount == 0)
        #expect(await mean.writer.variableString.count == 2)
        let handles = try await writer.finalise()
        let average = try #require(handles.last(where: { $0.variable.rawValue == "temperature_2m" && $0.domain.countEnsembleMember == 1 }))
        let spread = try #require(handles.first(where: { $0.variable.rawValue == "temperature_2m_spread" }))
        let values = try await average.reader.read(range: [0..<1, 0..<2])
        let deviations = try await spread.reader.read(range: [0..<1, 0..<2])
        #expect(values == [25, 7])
        #expect(abs(deviations[0] - sqrt(Float(221))) < 0.1)
        #expect(deviations[1] == 0)
    }
}

private struct StatisticsTestDomain: GenericDomain {
    let countEnsembleMember: Int
    var grid: any Gridable { RegularGrid(nx: 2, ny: 1, latMin: 0, lonMin: 0, dx: 1, dy: 1) }
    var domainRegistry: DomainRegistry { .ecmwf_ifs01_ensemble_mean }
    var domainRegistryStatic: DomainRegistry? { nil }
    var dtSeconds: Int { 3600 }
    var updateIntervalSeconds: Int { 21600 }
    var masterTimeRange: Range<Timestamp>? { nil }
    var omFileLength: Int { 157 }
}
