import Testing
@testable import App

struct EcmwfConcurrentDerivationTests {
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
