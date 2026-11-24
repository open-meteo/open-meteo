import OmTime

/// Keep values from previous timestep. Actori isolated, because of concurrent data conversion
actor GribDeaverager {
    var data: [Int: (step: Int, data: [Float])]

    /// Set new value and get previous value out
    func set<V: Hashable>(variable: V, member: Int, step: Int, data d: [Float]) -> (step: Int, data: [Float])? {
        var hash = Hasher()
        hash.combine(variable)
        hash.combine(member)
        let key = hash.finalize()
        let previous = data[key]
        data[key] = (step, d)
        return previous
    }
    
    /// Get the last step of variable + member
    func lastStep<V: Hashable>(_ variable: V, _ member: Int) -> Int? {
        var hash = Hasher()
        hash.combine(variable)
        hash.combine(member)
        let key = hash.finalize()
        return data[key]?.step
    }

    /// Release the final cumulative field after its variable/member is complete.
    func remove<V: Hashable>(variable: V, member: Int) {
        var hash = Hasher()
        hash.combine(variable)
        hash.combine(member)
        data.removeValue(forKey: hash.finalize())
    }

    /// Make a deep copy
    func copy() -> GribDeaverager {
        return .init(data: data)
    }

    public init(data: [Int: (step: Int, data: [Float])] = .init()) {
        self.data = data
    }
    
    /// Returns false if step should be skipped.
    func deaccumulateIfRequired<V: Hashable>(variable: V, member: Int, stepType: String, stepRange: String, array2d: inout Array2D, nConcurrent: Int = 4) async -> Bool {
        if stepType != "accum" && stepType != "avg" { return true }
        guard let (start, end) = stepRange.splitTo2Integer() else { return false }
        return await deaccumulateIfRequired(variable: variable, member: member, stepType: stepType, startStep: start, currentStep: end, array2d: &array2d, nConcurrent: nConcurrent)
    }

    /// Numeric intervals must use the same unit for every step of a variable/member stream.
    /// Callers process timesteps for each variable/member in order; only spatial work runs concurrently.
    func deaccumulateIfRequired<V: Hashable>(variable: V, member: Int, stepType: String, startStep: Int, currentStep: Int, array2d: inout Array2D, nConcurrent: Int = 4) async -> Bool {
        precondition(nConcurrent > 0)
        guard stepType == "accum" || stepType == "avg" else { return true }
        guard startStep != currentStep else { return false }
        // Retain the original cumulative field before the output array is modified.
        let previous = set(variable: variable, member: member, step: currentStep, data: array2d.data)
        // First timesteps and interval resets do not need deaccumulation.
        guard let previous, previous.step != startStep, currentStep > previous.step else { return true }
        precondition(previous.data.count == array2d.data.count)
        guard !array2d.data.isEmpty else { return true }
        await deaccumulateConcurrent(&array2d.data, previous: previous.data, count: previous.data.count, isAverage: stepType == "avg", delta: Float(currentStep - startStep), previousDelta: Float(previous.step - startStep), nConcurrent: nConcurrent)
        return true
    }

    private func deaccumulateConcurrent(_ values: UnsafeMutablePointer<Float>, previous: UnsafePointer<Float>, count: Int, isAverage: Bool, delta: Float, previousDelta: Float, nConcurrent: Int) async {
        // Array-to-pointer conversions keep both buffers alive until every worker has finished.
        nonisolated(unsafe) let output = values
        let input = previous
        let workers = min(nConcurrent, count)
        await withTaskGroup(of: Void.self) { group in
            for worker in 0..<workers {
                let range = (count * worker / workers)..<(count * (worker + 1) / workers)
                group.addTask {
                    if isAverage {
                        for i in range {
                            output[i] = (output[i] * delta - input[i] * previousDelta) / (delta - previousDelta)
                        }
                    } else {
                        for i in range {
                            output[i] -= input[i]
                        }
                    }
                }
            }
            await group.waitForAll()
        }
    }

    /// Returns false if step should be skipped.
    func deaccumulateIfRequired<V: Hashable>(variable: V, member: Int, stepType: String, stepRange: String, grib2d: inout GribArray2D, nConcurrent: Int = 4) async -> Bool {
        return await deaccumulateIfRequired(variable: variable, member: member, stepType: stepType, stepRange: stepRange, array2d: &grib2d.array, nConcurrent: nConcurrent)
    }
}
