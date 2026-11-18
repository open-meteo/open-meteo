import Foundation
import OmFileIO


/** Actor isolation to calculate ensemble mean and spread for a single timestep */
actor EnsembleMeanCalculator {
    fileprivate var variablesAndStats: [(any GenericVariable, (any GenericVariable)?, ArrayMeanStdDevSampler)] = []
    
    func ingest(variable: any GenericVariable, spreadVariable: (any GenericVariable)?, data: [Float]) async {
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
    
    func ingest(time: Timestamp, variable: any GenericVariable, spreadVariable: (any GenericVariable)?, data: [Float]) async {
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
actor ArrayMeanStdDevSampler {
    private(set) var count: Int = 0
    private final class Storage {
        var means: [Float] = []
        /// Sum of squares of differences from the current mean.
        var m2s: [Float] = []
    }

    private let storage = Storage()

    var means: [Float] { storage.means }

    /// Callers await each member's ingestion before submitting the next member.
    func ingest(_ values: [Float], nConcurrent: Int = 4) async {
        precondition(nConcurrent > 0)
        let storage = storage
        if storage.means.isEmpty {
            storage.means = Array(repeating: 0, count: values.count)
            storage.m2s = Array(repeating: 0, count: values.count)
        }
        precondition(values.count == storage.means.count, "Input array must have \(storage.means.count) elements")
        count += 1
        await processConcurrent(values, valueCount: values.count, means: &storage.means, m2s: &storage.m2s, nConcurrent: nConcurrent)
    }

    private func processConcurrent(_ values: UnsafePointer<Float>, valueCount: Int, means: UnsafeMutablePointer<Float>, m2s: UnsafeMutablePointer<Float>, nConcurrent: Int) async {
        let n = Float(count)
        // The caller owns all buffers for this call; child tasks read shared input and update disjoint ranges.
        nonisolated(unsafe) let valuesPointer = values
        nonisolated(unsafe) let meansPointer = means
        nonisolated(unsafe) let m2Pointer = m2s
        await withTaskGroup(of: Void.self) { group in
            for (index, range) in (0..<valueCount).chunks(ofCount: 65_536).enumerated() {
                if index >= nConcurrent {
                    await group.next()
                }
                group.addTask {
                    for i in range {
                        let x = valuesPointer[i]
                        let delta = x - meansPointer[i]
                        meansPointer[i] += delta / n
                        let delta2 = x - meansPointer[i]
                        m2Pointer[i] += delta * delta2
                    }
                }
            }
            await group.waitForAll()
        }
    }

    /// Per-element standard deviation (sample stddev).
    var standardDeviation: [Float] {
        storage.m2s.map { sqrt($0 / Float(count - 1)) }
    }

    /// Write the accumulated time series and release the statistics arrays.
    func writeTimeSeries(variable: any GenericVariable, time: TimerangeDt, domain: any GenericDomain) async throws -> [GenericVariableHandle] {
        guard count > 0 else { return [] }
        let grid = domain.grid
        let chunkLocations = min(grid.nx, OmFileSplitter(domain, nMembers: 1).chunknLocations)
        let writer = OmFileWriterHelper(dimensions: [grid.ny, grid.nx, time.count], chunks: [1, chunkLocations, time.count])
        try FileManager.default.createDirectory(atPath: OpenMeteo.tempDirectory, withIntermediateDirectories: true)
        let meanFile = try writer.writeTemporary(compressionType: .pfor_delta2d_int16, scalefactor: variable.scalefactor, all: means)
        storage.means = []
        let mean = try await GenericVariableHandle(variable: variable, time: time.range.lowerBound, member: 0, fn: meanFile, domain: domain)
        // Reuse M2 storage for the sample standard deviation.
        for i in storage.m2s.indices {
            storage.m2s[i] = sqrt(storage.m2s[i] / Float(count - 1))
        }
        let spreadVariable = variable.asSpreadVariableGeneric
        let spreadFile = try writer.writeTemporary(compressionType: .pfor_delta2d_int16, scalefactor: spreadVariable.scalefactor, all: storage.m2s)
        storage.m2s = []
        count = 0
        let spread = try await GenericVariableHandle(variable: spreadVariable, time: time.range.lowerBound, member: 0, fn: spreadFile, domain: domain)
        return [mean, spread]
    }
}
