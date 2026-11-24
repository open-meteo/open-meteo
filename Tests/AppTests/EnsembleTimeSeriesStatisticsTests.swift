import Foundation
import Testing
@testable import App

struct EnsembleTimeSeriesStatisticsTests {
    @Test(arguments: [3600, 10800])
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

    @Test func parallelSamplerPreservesMeanSpreadAndMissingValues() async {
        let sampler = ArrayMeanStdDevSampler()
        await sampler.ingest([1, 2, 3, 4, 5, 6, 7])
        #expect(await sampler.standardDeviation.allSatisfy { $0.isNaN })
        await sampler.ingest([3, 4, .nan, 6, 7, 8, 9])
        await sampler.ingest([5, 6, 7, 8, 9, 10, 11])
        let means = await sampler.means
        let spreads = await sampler.standardDeviation
        for i in means.indices {
            #expect(i == 2 ? means[i].isNaN : means[i] == Float(i + 3))
            #expect(i == 2 ? spreads[i].isNaN : spreads[i] == 2)
        }
    }

    @Test(arguments: [false, true])
    func conversionStatisticsStreamSpatialBlocksToTimeFastFiles(includeMean: Bool) async throws {
        let domain = StatisticsTestDomain()
        let time = TimerangeDt(start: Timestamp(2026, 11, 17), nTime: 4, dtSeconds: domain.dtSeconds)
        let ensembleDomain = StatisticsTestDomain(domainRegistry: .ecmwf_ifs01_ensemble)
        let writer = try OmEnsembleStatisticsWriter(domain: includeMean ? domain : nil, variable: EcmwfVariable.precipitation, time: time, chunkLocations: 8, probabilityDomain: ensembleDomain)
        for y in 0..<2 {
            for x in stride(from: 0, to: 17, by: 8) {
                let count = min(8, 17 - x)
                var block = Array3DFastTime(nLocations: count, nLevel: 3, nTime: 4)
                for location in 0..<count {
                    for member in 0..<3 {
                        for t in 0..<4 {
                            let i = ((y * 17 + x + location) * 4) + t
                            block[location, member, t] = i == 5 && member == 1 ? .nan : Float(i % 100 + 2 * member)
                        }
                    }
                }
                try writer.write(data: block, yCount: 1, xCount: count)
            }
        }
        let outputs = try await writer.finalise()
        #expect(outputs.map { $0.variable.omFileName.file } == (includeMean ? ["precipitation", "precipitation_spread", "precipitation_probability"] : ["precipitation_probability"]))
        for output in outputs {
            let isProbability = output.variable.omFileName.file == "precipitation_probability"
            #expect(output.domain.domainRegistry == (isProbability ? .ecmwf_ifs01_ensemble : .ecmwf_ifs01_ensemble_mean))
            #expect(output.member == 0)
            #expect(output.time == time)
            #expect(output.reader.getDimensions() == [2, 17, 4])
            #expect(output.reader.getChunkDimensions() == [1, 8, 4])
            let values = try await output.reader.read()
            for i in values.indices {
                if i == 5 {
                    #expect(values[i].isNaN)
                } else {
                    let expected: Float = isProbability ? (i % 100 == 0 ? 200 / 3 : 100) :
                        output.variable.omFileName.file.hasSuffix("_spread") ? 2 : Float(i % 100 + 2)
                    #expect(abs(values[i] - expected) < 0.6)
                }
            }
        }
    }
}

private struct StatisticsTestDomain: GenericDomain {
    var countEnsembleMember: Int { domainRegistry == .ecmwf_ifs01_ensemble ? 51 : 1 }
    var grid: any Gridable { RegularGrid(nx: 17, ny: 2, latMin: 0, lonMin: 0, dx: 0.1, dy: 0.1) }
    var domainRegistry: DomainRegistry = .ecmwf_ifs01_ensemble_mean
    var domainRegistryStatic: DomainRegistry? { nil }
    var dtSeconds: Int { 10800 }
    var updateIntervalSeconds: Int { 21600 }
    var masterTimeRange: Range<Timestamp>? { nil }
    var omFileLength: Int { 104 }
}
