import OmFileIO
import Testing
@testable import App

struct EcmwfConcurrentDeaccumulationTests {
    @Test(arguments: [1, 2, 8], ["accum", "avg"])
    func drainsOutOfOrderFieldsAcrossIntervalChanges(nConcurrent: Int, stepType: String) async throws {
        let storage = VariablePerMemberStorage<DownloadEcmwfCommand.EnsembleAccumulation>()
        let deaverager = GribDeaverager()
        let run = Timestamp(2026, 11, 18)
        let hours = [3, 6, 9, 15]
        // Deliberately buffer later steps before the first. The last interval
        // changes to six hours and resets, rather than accumulating from zero.
        let jobs = [9, 15, 6, 3].flatMap { hour in [0, 1].map { (hour: hour, member: $0) } }
        let samples: [Int: Float] = stepType == "accum" ? [3: 6, 6: 18, 9: 36, 15: 30] : [3: 10, 6: 15, 9: 20, 15: 30]
        let expected: [Int: Float] = stepType == "accum" ? [3: 6, 6: 12, 9: 18, 15: 30] : [3: 10, 6: 20, 9: 30, 15: 30]
        var outputs = [(member: Int, hour: Int, data: [Float])]()
        for try await completed in jobs.mapStream(nConcurrent: nConcurrent, nBuffered: 2 * nConcurrent, body: { job in
            let start = job.hour == 15 ? 9 : 0
            let metadata = DownloadEcmwfCommand.EnsembleAccumulation(variable: .precipitation, shortName: "tp", stepType: stepType, stepRange: "\(start)-\(job.hour)")
            let input = Array2D(data: [Float](repeating: samples[job.hour]! * Float(job.member + 1), count: 65539), nx: 65539, ny: 1)
            await storage.set(variable: metadata, timestamp: run.add(hours: job.hour), member: job.member, data: input)
            var completed = [(member: Int, hour: Int, data: [Float])]()
            while true {
                let previous = await deaverager.lastStep(EcmwfVariable.precipitation, job.member) ?? 0
                guard let step = hours.first(where: { $0 > previous }) else { break }
                let timestamp = run.add(hours: step)
                guard let field = await storage.remove(where: {
                    $0.variable.variable == .precipitation && $0.member == job.member && $0.timestamp == timestamp
                }) else { break }
                // Exercise the gap between claiming a step and advancing lastStep.
                await Task.yield()
                var values = field.data
                let success = await deaverager.deaccumulateIfRequired(variable: EcmwfVariable.precipitation, member: job.member, stepType: field.key.variable.stepType, stepRange: field.key.variable.stepRange, array2d: &values)
                #expect(success)
                completed.append((job.member, step, values.data))
                if step == hours.last {
                    await deaverager.remove(variable: EcmwfVariable.precipitation, member: job.member)
                    break
                }
            }
            return completed
        }) {
            outputs += completed
        }
        #expect(outputs.count == 8)
        for member in 0..<2 {
            for hour in hours {
                let matching = outputs.filter { $0.member == member && $0.hour == hour }
                #expect(matching.count == 1)
                let values = try #require(matching.first?.data)
                #expect(values.allSatisfy { $0 == expected[hour]! * Float(member + 1) })
            }
        }
        #expect(await storage.data.isEmpty)
        #expect(await deaverager.data.isEmpty)
    }
}
