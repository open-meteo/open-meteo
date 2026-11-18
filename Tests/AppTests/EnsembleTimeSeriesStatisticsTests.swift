import Foundation
import Testing
@testable import App

struct EnsembleTimeSeriesStatisticsTests {
    @Test(arguments: [3600, 10800, 21600])
    func conversionProbabilityUsesInterpolatedTimestepThreshold(dtSeconds: Int) {
        let threshold = Float(dtSeconds) / 3600 * 0.1
        var block = Array3DFastTime(nLocations: 2, nLevel: 4, nTime: 3)
        for member in 0..<4 {
            block[0, member, 1] = [Float(0), threshold / 2, threshold, threshold * 2][member]
            block[0, member, 2] = 0
            block[1, member, 0] = threshold
            block[1, member, 1] = member == 3 ? .nan : threshold
            block[1, member, 2] = member == 0 ? threshold : 0
        }
        let probability = block.precipitationProbability(dtSeconds: dtSeconds)
        #expect(probability[0].isNaN)
        #expect(probability[1] == 50)
        #expect(probability[2] == 0)
        #expect(probability[3] == 100)
        #expect(probability[4].isNaN)
        #expect(probability[5] == 25)
    }

    @Test(arguments: [false, true])
    func conversionProbabilityWritesToEnsembleDomain(includeMean: Bool) async throws {
        let meanDomain = StatisticsTestDomain()
        let ensembleDomain = StatisticsTestDomain(domainRegistry: .ecmwf_ifs01_ensemble)
        let time = TimerangeDt(start: Timestamp(2026, 11, 17), nTime: 4, dtSeconds: ensembleDomain.dtSeconds)
        let writer = try OmEnsembleStatisticsWriter(domain: includeMean ? meanDomain : nil, variable: EcmwfVariable.precipitation, time: time, chunkLocations: 8, probabilityDomain: ensembleDomain)
        for _ in 0..<2 {
            for x in stride(from: 0, to: 800, by: 384) {
                let count = min(384, 800 - x)
                var block = Array3DFastTime(nLocations: count, nLevel: 4, nTime: 4)
                for location in 0..<count {
                    for member in 0..<4 {
                        for t in 1..<4 {
                            block[location, member, t] = Float(member) * 0.2
                        }
                    }
                }
                try writer.write(data: block, yCount: 1, xCount: count)
            }
        }
        let outputs = try await writer.finalise()
        #expect(outputs.count == (includeMean ? 3 : 1))
        let probability = outputs.last!
        #expect(probability.variable.omFileName.file == "precipitation_probability")
        #expect(probability.domain.domainRegistry == .ecmwf_ifs01_ensemble)
        // The output remains a single-member field even on a 51-member model.
        #expect(probability.domain.countEnsembleMember == 51)
        #expect(probability.member == 0)
        #expect(probability.time == time)
        #expect(probability.reader.getDimensions() == [2, 800, 4])
        let values = try await probability.reader.read()
        for i in values.indices {
            if i % 4 == 0 {
                #expect(values[i].isNaN)
            } else {
                #expect(values[i] == 50)
            }
        }
        for statistics in outputs.dropLast() {
            #expect(statistics.domain.domainRegistry == .ecmwf_ifs01_ensemble_mean)
        }
    }

    @Test func conversionBlockStatisticsMatchMemberSampler() async {
        for members in [1, 3, 51] {
            var block = Array3DFastTime(nLocations: 7, nLevel: members, nTime: 13)
            let sampler = ArrayMeanStdDevSampler()
            for member in 0..<members {
                var values = [Float]()
                for location in 0..<7 {
                    for t in 0..<13 {
                        let value: Float = t == 0 || (member == members - 1 && t == 5) ? .nan : Float(location * 100 + t) + Float(member) * 0.25
                        block[location, member, t] = value
                        values.append(value)
                    }
                }
                await sampler.ingest(values)
            }
            let statistics = block.ensembleMeanAndSpread()
            let means = await sampler.means
            let spreads = await sampler.standardDeviation
            for i in means.indices {
                #expect(statistics.mean[i] == means[i] || (statistics.mean[i].isNaN && means[i].isNaN))
                #expect(statistics.spread[i] == spreads[i] || (statistics.spread[i].isNaN && spreads[i].isNaN))
            }
        }
    }

    @Test func conversionStatisticsStreamSpatialBlocksToTimeFastFiles() async throws {
        let domain = StatisticsTestDomain()
        let time = TimerangeDt(start: Timestamp(2026, 11, 17), nTime: 4, dtSeconds: domain.dtSeconds)
        let writer = try OmEnsembleStatisticsWriter(domain: domain, variable: EcmwfVariable.temperature_2m, time: time, chunkLocations: 8)
        for y in 0..<2 {
            for x in stride(from: 0, to: 800, by: 384) {
                let count = min(384, 800 - x)
                var block = Array3DFastTime(nLocations: count, nLevel: 3, nTime: 4)
                for location in 0..<count {
                    for member in 0..<3 {
                        for t in 0..<4 {
                            let i = ((y * 800 + x + location) * 4) + t
                            block[location, member, t] = i == 5 && member == 1 ? .nan : Float(i % 100 + 2 * member)
                        }
                    }
                }
                try writer.write(data: block, yCount: 1, xCount: count)
            }
        }
        let outputs = try await writer.finalise()
        #expect(outputs.map { $0.variable.omFileName.file } == ["temperature_2m", "temperature_2m_spread"])
        for output in outputs {
            #expect(output.domain.domainRegistry == .ecmwf_ifs01_ensemble_mean)
            #expect(output.member == 0)
            #expect(output.time == time)
            #expect(output.reader.getDimensions() == [2, 800, 4])
            #expect(output.reader.getChunkDimensions() == [1, 8, 4])
            let values = try await output.reader.read()
            for i in values.indices {
                if i == 5 {
                    #expect(values[i].isNaN)
                } else {
                    let expected = output.variable.omFileName.file.hasSuffix("_spread") ? Float(2) : Float(i % 100 + 2)
                    #expect(abs(values[i] - expected) < 0.1)
                }
            }
        }
    }

    @Test func meanAndSampleSpreadPreserveTimeFastOrderAndMissingValues() async throws {
        let domain = StatisticsTestDomain()
        let run = Timestamp(2026, 11, 17)
        let variable = EcmwfVariable.temperature_2m
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
        _ = try await sampler.writeTimeSeries(variable: EcmwfVariable.temperature_2m, time: time, domain: domain)
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
        let variable = EcmwfVariable.relative_humidity_2m
        let sampler = ArrayMeanStdDevSampler()
        await sampler.ingest(Array(repeating: 5, count: 1600))
        let time = TimerangeDt(start: Timestamp(2026, 11, 17), nTime: 1, dtSeconds: domain.dtSeconds)
        let outputs = try await sampler.writeTimeSeries(variable: variable, time: time, domain: domain)
        #expect(try await outputs[0].reader.read(range: [0..<2, 0..<800, 0..<1]) == Array(repeating: 5, count: 1600))
        #expect(try await outputs[1].reader.read(range: [0..<2, 0..<800, 0..<1]).allSatisfy(\.isNaN))
    }
}

private struct StatisticsTestDomain: GenericDomain {
    var countEnsembleMember: Int { domainRegistry == .ecmwf_ifs01_ensemble ? 51 : 1 }
    var grid: any Gridable { RegularGrid(nx: 800, ny: 2, latMin: 0, lonMin: 0, dx: 0.1, dy: 0.1) }
    var domainRegistry: DomainRegistry = .ecmwf_ifs01_ensemble_mean
    var domainRegistryStatic: DomainRegistry? { nil }
    var dtSeconds: Int { 10800 }
    var updateIntervalSeconds: Int { 21600 }
    var masterTimeRange: Range<Timestamp>? { nil }
    var omFileLength: Int { 104 }
}
