import Foundation
import OmFileIO
@preconcurrency import OmFileFormat

/// Write ensemble statistics from the spatial blocks already loaded by conversion.
/// Only the current block's mean, M2 and probability arrays are held in memory.
struct OmEnsembleStatisticsWriter {
    let calculateMeanAndSpread: Bool
    let calculateProbability: Bool
    let time: TimerangeDt
    let outputs: [(variable: any GenericVariable, domain: any GenericDomain, handle: FileHandle, file: OmFileWriter<FileHandle>, array: OmFileWriterArray<Float, FileHandle>)]

    init(domain: (any GenericDomain)?, variable: any GenericVariable, time: TimerangeDt, chunkLocations: Int, probabilityDomain: (any GenericDomain)? = nil) throws {
        self.calculateMeanAndSpread = domain != nil
        self.calculateProbability = probabilityDomain != nil
        self.time = time
        try FileManager.default.createDirectory(atPath: OpenMeteo.tempDirectory, withIntermediateDirectories: true)
        var variables = [(variable: any GenericVariable, domain: any GenericDomain)]()
        if let domain {
            variables += [(variable, domain), (variable.asSpreadVariableGeneric, domain)]
        }
        if let probabilityDomain {
            variables.append((ProbabilityVariable.precipitation_probability, probabilityDomain))
        }
        outputs = try variables.map { variable, domain in
            let path = "\(OpenMeteo.tempDirectory)\(UUID().uuidString).om"
            let handle = try FileHandle.createNewFile(file: path, overwrite: true, temporary: true)
            let file = OmFileWriter(fn: handle, initialCapacity: 1024 * 1024)
            let array = try file.prepareArray(
                type: Float.self,
                dimensions: [UInt64(domain.grid.ny), UInt64(domain.grid.nx), UInt64(time.count)],
                chunkDimensions: [1, UInt64(chunkLocations), UInt64(time.count)],
                compression: .pfor_delta2d_int16,
                scale_factor: variable.scalefactor,
                add_offset: 0
            )
            return (variable, domain, handle, file, array)
        }
    }

    /// Pure block calculation can run in parallel; file writes stay ordered.
    static func calculate(data: Array3DFastTime, meanAndSpread: Bool, probability: Bool, dtSeconds: Int) -> [[Float]] {
        var arrays = [[Float]]()
        if meanAndSpread {
            let statistics = data.ensembleMeanAndSpread()
            arrays += [statistics.mean, statistics.spread]
        }
        if probability {
            arrays.append(data.precipitationProbability(dtSeconds: dtSeconds))
        }
        return arrays
    }

    func write(arrays: [[Float]], yCount: Int, xCount: Int) throws {
        precondition(arrays.count == outputs.count)
        let dimensions = [UInt64(yCount), UInt64(xCount), UInt64(time.count)]
        for (output, array) in zip(outputs, arrays) {
            precondition(array.count == yCount * xCount * time.count)
            try output.array.writeData(array: array, arrayDimensions: dimensions)
        }
    }

    func write(data: Array3DFastTime, yCount: Int, xCount: Int) throws {
        precondition(data.nLocations == yCount * xCount && data.nTime == time.count)
        try write(arrays: Self.calculate(data: data, meanAndSpread: calculateMeanAndSpread, probability: calculateProbability, dtSeconds: time.dtSeconds), yCount: yCount, xCount: xCount)
    }

    func finalise() async throws -> [GenericVariableHandle] {
        var handles = [GenericVariableHandle]()
        for output in outputs {
            let root = try output.file.write(array: output.array.finalise(), name: "", children: [])
            try output.file.writeTrailer(rootVariable: root)
            handles.append(try await GenericVariableHandle(variable: output.variable, time: time.range.lowerBound, member: 0, fn: output.handle, domain: output.domain))
        }
        return handles
    }
}

extension Array3DFastTime {
    /// Percentage of members with at least 0.1 mm/h in each interpolated timestep.
    /// Preserve NaN when any member is missing, including the initial forecast step.
    func precipitationProbability(dtSeconds: Int) -> [Float] {
        precondition(nLevel > 0 && dtSeconds > 0)
        let threshold = Float(dtSeconds) / 3600 * 0.1
        var probability = [Float](repeating: 0, count: nLocations * nTime)
        for location in 0..<nLocations {
            let outputOffset = location * nTime
            for member in 0..<nLevel {
                let inputOffset = (location * nLevel + member) * nTime
                for t in 0..<nTime {
                    let value = data[inputOffset + t]
                    if value.isNaN {
                        probability[outputOffset + t] = .nan
                    } else if value >= threshold {
                        probability[outputOffset + t] += 1
                    }
                }
            }
        }
        let percentPerMember = 100 / Float(nLevel)
        for i in probability.indices {
            probability[i] *= percentPerMember
        }
        return probability
    }

    /// Reduce [location, member, time] to [location, time], retaining a fast time axis.
    /// Match the sampler's Welford calculation, including propagation of missing members.
    func ensembleMeanAndSpread() -> (mean: [Float], spread: [Float]) {
        precondition(nLevel > 0)
        var mean = [Float](repeating: 0, count: nLocations * nTime)
        var m2 = [Float](repeating: 0, count: nLocations * nTime)
        for location in 0..<nLocations {
            let outputOffset = location * nTime
            for member in 0..<nLevel {
                let inputOffset = (location * nLevel + member) * nTime
                let count = Float(member + 1)
                for t in 0..<nTime {
                    let i = outputOffset + t
                    let value = data[inputOffset + t]
                    let delta = value - mean[i]
                    mean[i] += delta / count
                    m2[i] += delta * (value - mean[i])
                }
            }
        }
        for i in m2.indices {
            m2[i] = sqrt(m2[i] / Float(nLevel - 1))
        }
        return (mean, m2)
    }
}
