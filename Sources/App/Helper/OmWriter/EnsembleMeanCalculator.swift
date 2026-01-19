import Foundation


/** Actor isolation to calculate ensemble mean and spread for a single timestep */
actor EnsembleMeanCalculator {
    fileprivate var variablesAndStats: [(any GenericVariable, (any GenericVariable)?, ArrayMeanStdDevSampler)] = []
    
    func ingest(variable: any GenericVariable, spreadVariable: GenericVariable?, data: [Float]) async {
        guard let stats = variablesAndStats.first(where: {$0.0.omFileName == variable.omFileName}) else {
            let stats = ArrayMeanStdDevSampler()
            await stats.ingest(data)
            variablesAndStats.append((variable, spreadVariable, stats))
            return
        }
        await stats.2.ingest(data)
    }
    
    func calculateAndWrite(to writer: OmSpatialTimestepWriter) async throws {
        for (variable, spreadVariable, sampler) in variablesAndStats {
            try await writer.write(member: 0, variable: variable, data: sampler.means)
            if let spreadVariable = spreadVariable {
                try await writer.write(member: 0, variable: spreadVariable, data: sampler.standardDeviation)
            }
        }
    }
}

/** Actor isolation to calculate ensemble mean and spread for multiple timesteps */
actor EnsembleMeanCalculatorMultistep {
    var calculators: [(Timestamp, EnsembleMeanCalculator)] = []
    
    func ingest(time: Timestamp, variable: any GenericVariable, spreadVariable: GenericVariable?, data: [Float]) async {
        guard let calculator = calculators.first(where: {$0.0 == time}) else {
            let calculator = EnsembleMeanCalculator()
            await calculator.ingest(variable: variable, spreadVariable: spreadVariable, data: data)
            calculators.append((time, calculator))
            return
        }
        await calculator.1.ingest(variable: variable, spreadVariable: spreadVariable, data: data)
    }
    
    func calculateAndWrite(to writer: OmSpatialMultistepWriter) async throws {
        for calculator in calculators {
            try await calculator.1.calculateAndWrite(to: writer.getWriter(time: calculator.0))
        }
    }
}



/// Calculate mean and std dev for individual indices of multiple arrays
/// Streams data from 20-50 ensemble members
/// Welford's algorithm
fileprivate actor ArrayMeanStdDevSampler {
    private(set) var count: Int = 0
    private(set) var means: [Float] = []
    /// Sum of squares of differences from the current mean
    private var m2s: [Float] = []

    func ingest(_ values: [Float]) {
        if means.count == 0 {
            means = Array(repeating: 0.0, count: values.count )
            m2s = Array(repeating: 0.0, count: values.count )
        }
        precondition(values.count == means.count, "Input array must have \(means.count) elements")
        count += 1
        let n = Float(count)
        for i in values.indices {
            let x = values[i]
            let delta = x - means[i]
            means[i] += delta / n
            let delta2 = x - means[i]
            m2s[i] += delta * delta2
        }
    }

    /// Per-element variance (sample variance, n - 1)
    var variance: [Float] {
        return m2s.map { $0 / Float(count - 1) }
    }

    /// Per-element standard deviation (sample stddev)
    var standardDeviation: [Float] {
        return m2s.map { sqrt($0 / Float(count - 1)) }
    }
}
