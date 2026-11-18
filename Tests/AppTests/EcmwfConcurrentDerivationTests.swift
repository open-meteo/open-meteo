import OmFileIO
import Testing
@testable import App

struct EcmwfConcurrentDerivationTests {
    @Test(arguments: [["2d", "2t"], ["2t", "2d"]], [1, 2, 8])
    func returnsReadyFieldsWithoutWaiting(parameters: [String], nConcurrent: Int) async throws {
        let storage = VariablePerMemberStorage<String>()
        let run = Timestamp(2026, 11, 18)
        let jobs = (0..<2).flatMap { member in
            parameters.flatMap { parameter in [0, 3, 6].map { (member: member, parameter: parameter, hour: $0) } }
        }
        var result = [(variable: String, member: Int, hour: Int, data: [Float])]()
        var batchSizes = [Int]()
        for try await fields in jobs.mapStream(nConcurrent: nConcurrent, nBuffered: 2 * nConcurrent, body: { job in
            let temperature = Float(10 + job.member + job.hour)
            let values = Array2D(data: [job.parameter == "2t" ? temperature : temperature - 5], nx: 1, ny: 1)
            let timestamp = run.add(hours: job.hour)
            var fields = [(variable: String, member: Int, hour: Int, data: [Float])]()
            if job.parameter == "2t" { fields.append(("temperature", job.member, job.hour, values.data)) }
            await Task.yield()
            await storage.set(variable: job.parameter, timestamp: timestamp, member: job.member, data: values)
            if let pair = await storage.getAllRemoving(variables: ["2t", "2d"], timestamp: timestamp, member: job.member) {
                fields.append(("humidity", job.member, job.hour, zip(pair[0].data, pair[1].data).map(Meteorology.relativeHumidity)))
            }
            return fields
        }) {
            batchSizes.append(fields.count)
            result += fields
        }
        #expect(result.count == 12)
        for member in 0..<2 {
            for hour in [0, 3, 6] {
                let fields = result.filter { $0.member == member && $0.hour == hour }
                #expect(fields.count == 2)
                let temperature = Float(10 + member + hour)
                #expect(fields.first { $0.variable == "temperature" }?.data == [temperature])
                #expect(fields.first { $0.variable == "humidity" }?.data == [Meteorology.relativeHumidity(temperature: temperature, dewpoint: temperature - 5)])
            }
        }
        if nConcurrent == 1 && parameters.first == "2d" {
            #expect(batchSizes == [0, 0, 0, 2, 2, 2, 0, 0, 0, 2, 2, 2])
        }
        #expect(await storage.data.isEmpty)
    }

    @Test func pressureConsumersRemoveOnlyTheirOwnTemperatureReference() async {
        let storage = VariablePerMemberStorage<String>()
        let time = Timestamp(2026, 11, 18)
        let temperature = Array2D(data: [-10, 20], nx: 2, ny: 1)
        let omega = Array2D(data: [1, -2], nx: 2, ny: 1)
        let specificHumidity = Array2D(data: [1, 2], nx: 2, ny: 1)
        await storage.set(variable: "w:500", timestamp: time, member: 0, data: omega)
        #expect(await storage.getAllRemoving(variables: ["t:500>w:500", "w:500"], timestamp: time, member: 0) == nil)
        await storage.set(variable: "t:500>w:500", timestamp: time, member: 0, data: temperature)
        await storage.set(variable: "t:500>q:500", timestamp: time, member: 0, data: temperature)
        let velocityPair = await storage.getAllRemoving(variables: ["t:500>w:500", "w:500"], timestamp: time, member: 0)
        #expect(velocityPair?.first?.data == temperature.data)
        #expect(await storage.get(variable: "t:500>q:500", timestamp: time, member: 0)?.data == temperature.data)
        await storage.set(variable: "q:500", timestamp: time, member: 0, data: specificHumidity)
        let humidityPair = await storage.getAllRemoving(variables: ["t:500>q:500", "q:500"], timestamp: time, member: 0)
        #expect(humidityPair?.first?.data == temperature.data)
        #expect(await storage.data.isEmpty)
    }
}
