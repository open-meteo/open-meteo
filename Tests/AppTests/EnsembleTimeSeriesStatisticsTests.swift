import Foundation
import Testing
@testable import App

struct EnsembleTimeSeriesStatisticsTests {
    @Test func meanAndSampleSpreadPreserveTimeFastOrderAndMissingValues() async throws {
        let domain = StatisticsTestDomain()
        let run = Timestamp(2026, 11, 17)
        let variable = EcmwfIfs01EnsembleSurfaceVariable.temperature_2m
        let time = TimerangeDt(start: run, nTime: 4, dtSeconds: domain.dtSeconds)
        let sampler = ArrayMeanStdDevSampler()
        for member in 0..<3 {
            var values = (0..<6400).map { Float($0 % 100 + 2 * member) }
            values[0] = .nan
            if member == 1 { values[5] = .nan }
            await sampler.ingest(values, nConcurrent: 3)
        }
        let outputs = try await sampler.writeTimeSeries(variable: variable, time: time, domain: domain)
        #expect(outputs.map { $0.variable.omFileName.file } == ["temperature_2m", "temperature_2m_spread"])
        for output in outputs {
            #expect(output.domain.domainRegistry == .ecmwf_ifs01_ensemble_mean)
            #expect(output.member == 0)
            #expect(output.time == time)
            #expect(output.reader.getDimensions() == [2, 800, 4])
            #expect(output.reader.getChunkDimensions().last == 4)
            let values = try await output.reader.read(range: [0..<2, 0..<800, 0..<4])
            for i in values.indices {
                if i == 0 || i == 5 {
                    #expect(values[i].isNaN)
                } else {
                    let expected: Float = output.variable.omFileName.file.hasSuffix("_spread") ? 2 : Float(i % 100 + 2)
                    #expect(abs(values[i] - expected) < 0.1)
                }
            }
        }
    }

    @Test func samplerCanBeReusedAfterWriting() async throws {
        let domain = StatisticsTestDomain()
        let sampler = ArrayMeanStdDevSampler()
        await sampler.ingest(Array(repeating: 5, count: 1600), nConcurrent: 2)
        let time = TimerangeDt(start: Timestamp(2026, 11, 17), nTime: 1, dtSeconds: domain.dtSeconds)
        _ = try await sampler.writeTimeSeries(variable: EcmwfIfs01EnsembleSurfaceVariable.temperature_2m, time: time, domain: domain)
        #expect(await sampler.count == 0)
        #expect(await sampler.means.isEmpty)
        await sampler.ingest([3, 5], nConcurrent: 2)
        #expect(await sampler.means == [3, 5])
        #expect(await sampler.count == 1)
    }

    @Test func concurrentIngestMatchesSerialForUnevenAndEmptyArrays() async {
        for length in [0, 1, 7, 1031, 131_077] {
            for concurrency in [1, 2, 4, 32] {
                let serial = ArrayMeanStdDevSampler()
                let parallel = ArrayMeanStdDevSampler()
                for member in 0..<5 {
                    var values = (0..<length).map { Float($0 % 13) + Float(member) * 0.25 }
                    if length > 2 && member == 2 { values[2] = .nan }
                    await serial.ingest(values)
                    await parallel.ingest(values, nConcurrent: concurrency)
                }
                #expect(await parallel.count == 5)
                let serialMeans = await serial.means
                let parallelMeans = await parallel.means
                let serialSpread = await serial.standardDeviation
                let parallelSpread = await parallel.standardDeviation
                #expect(serialMeans.count == parallelMeans.count)
                for i in serialMeans.indices {
                    #expect(serialMeans[i] == parallelMeans[i] || (serialMeans[i].isNaN && parallelMeans[i].isNaN))
                    #expect(serialSpread[i] == parallelSpread[i] || (serialSpread[i].isNaN && parallelSpread[i].isNaN))
                }
            }
        }
    }

    @Test func controlOnlyMeanHasUndefinedSampleSpread() async throws {
        let domain = StatisticsTestDomain()
        let variable = EcmwfIfs01EnsembleSurfaceVariable.dew_point_2m
        let sampler = ArrayMeanStdDevSampler()
        await sampler.ingest(Array(repeating: 5, count: 1600))
        let time = TimerangeDt(start: Timestamp(2026, 11, 17), nTime: 1, dtSeconds: domain.dtSeconds)
        let outputs = try await sampler.writeTimeSeries(variable: variable, time: time, domain: domain)
        #expect(try await outputs[0].reader.read(range: [0..<2, 0..<800, 0..<1]) == Array(repeating: 5, count: 1600))
        #expect(try await outputs[1].reader.read(range: [0..<2, 0..<800, 0..<1]).allSatisfy(\.isNaN))
    }
}

private struct StatisticsTestDomain: GenericDomain {
    var countEnsembleMember: Int { 1 }
    var grid: any Gridable { RegularGrid(nx: 800, ny: 2, latMin: 0, lonMin: 0, dx: 0.1, dy: 0.1) }
    var domainRegistry: DomainRegistry { .ecmwf_ifs01_ensemble_mean }
    var domainRegistryStatic: DomainRegistry? { nil }
    var dtSeconds: Int { 10800 }
    var updateIntervalSeconds: Int { 21600 }
    var masterTimeRange: Range<Timestamp>? { nil }
    var omFileLength: Int { 104 }
}
