import Testing
@testable import App

struct EcmwfConcurrentDerivationTests {
    @Test func humidityCalculatorPairsConcurrentMembersAndTimesteps() async throws {
        let calculator = RelativeHumidityCalculator(outVariable: EcmwfVariable.relative_humidity_2m)
        let run = Timestamp(2026, 11, 18)
        let results = await withTaskGroup(of: (member: Int, hour: Int, data: [Float])?.self) { group in
            for member in 0..<2 {
                for hour in [3, 6] {
                    for isTemperature in [false, true] {
                        group.addTask {
                            let value = Float(isTemperature ? 20 + member + hour : 5 + member - hour)
                            let array = Array2D(data: [value, .nan], nx: 2, ny: 1)
                            let input: RelativeHumidityCalculator.Input = isTemperature ? .temperature(array) : .dewpoint(array)
                            guard let data = await calculator.calculate(input, member: member, timestamp: run.add(hours: hour)) else { return nil }
                            return (member, hour, data)
                        }
                    }
                }
            }
            var results = [(member: Int, hour: Int, data: [Float])]()
            for await result in group { if let result { results.append(result) } }
            return results
        }
        #expect(results.count == 4)
        #expect(Set(results.map { "\($0.member):\($0.hour)" }).count == 4)
        for result in results {
            let expected = Meteorology.relativeHumidity(temperature: Float(20 + result.member + result.hour), dewpoint: Float(5 + result.member - result.hour))
            #expect(result.data[0] == expected)
            #expect(result.data[1].isNaN)
        }
        #expect(await calculator.isEmpty)
    }

    @Test(arguments: [false, true])
    func pressureCalculatorsKeepLevelsAndConsumersIndependent(temperatureFirst: Bool) async {
        let velocity = VerticalVelocityCalculator<EcmwfVariable>()
        let humidity = SpecificHumidityCalculator<EcmwfVariable>()
        let time = Timestamp(2026, 11, 18)
        let temperature = Array2D(data: [-10, 20], nx: 2, ny: 1)
        let omega = Array2D(data: [1, -2], nx: 2, ny: 1)
        let specificHumidity = Array2D(data: [1, 2], nx: 2, ny: 1)
        for level in [500, 850] {
            let w = EcmwfVariable.from(shortName: "w", levelhPa: level)!
            let r = EcmwfVariable.from(shortName: "r", levelhPa: level)!
            #expect(await velocity.calculate(temperatureFirst ? .temperature(temperature) : .omega(omega), member: 0, timestamp: time, pressureLevel: Float(level), outVariable: w) == nil)
            #expect(await humidity.calculate(temperatureFirst ? .temperature(temperature) : .specificHumidity(specificHumidity), member: 0, timestamp: time, pressureLevel: Float(level), outVariable: r) == nil)
        }
        for level in [850, 500] {
            let w = EcmwfVariable.from(shortName: "w", levelhPa: level)!
            let r = EcmwfVariable.from(shortName: "r", levelhPa: level)!
            let actualVelocity = await velocity.calculate(temperatureFirst ? .omega(omega) : .temperature(temperature), member: 0, timestamp: time, pressureLevel: Float(level), outVariable: w)
            let actualHumidity = await humidity.calculate(temperatureFirst ? .specificHumidity(specificHumidity) : .temperature(temperature), member: 0, timestamp: time, pressureLevel: Float(level), outVariable: r)
            #expect(actualVelocity == Meteorology.verticalVelocityPressureToGeometric(omega: omega.data, temperature: temperature.data, pressureLevel: Float(level)))
            #expect(actualHumidity == Meteorology.specificToRelativeHumidity(specificHumidity: specificHumidity.data, temperature: temperature.data, pressure: Float(level)))
        }
        #expect(await velocity.isEmpty)
        #expect(await humidity.isEmpty)
    }

    @Test(arguments: [false, true])
    func snowDepthCalculatorPairsEitherOrder(waterEquivalentFirst: Bool) async {
        let calculator = SnowDepthCalculator()
        let time = Timestamp(2026, 11, 18)
        let water = Array2D(data: [20, 60], nx: 2, ny: 1)
        let density = Array2D(data: [100, 200], nx: 2, ny: 1)
        #expect(await calculator.calculate(waterEquivalentFirst ? .waterEquivalent(water) : .density(density), member: 1, timestamp: time) == nil)
        let depth = await calculator.calculate(waterEquivalentFirst ? .density(density) : .waterEquivalent(water), member: 1, timestamp: time)
        #expect(depth == [0.2, 0.3])
        #expect(await calculator.isEmpty)
    }
}
