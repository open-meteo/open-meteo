import Foundation

/// Computes ensemble mean and spread using Welford's online algorithm.
/// - Parameters:
///   - data3d: Input data in Array3DFastTime layout: [loc * nMembers * nTime + member * nTime + t]
///   - nLoc: Number of spatial locations
///   - nMembers: Total ensemble member slots (may include uninitialized)
///   - nMembersActual: Actual members to iterate (≤ nMembers); use this when fewer members were downloaded
///   - nTime: Number of time steps
/// - Returns: Tuple of (mean, spread) arrays, each with nLoc * nTime elements in [loc * nTime + t] layout
func welfordMeanSpread(data3d: ArraySlice<Float>, nLoc: Int, nMembers: Int, nMembersActual: Int, nTime: Int) -> (mean: [Float], spread: [Float]) {
    var chunkMean = [Float](repeating: 0, count: nLoc * nTime)
    var chunkM2 = [Float](repeating: 0, count: nLoc * nTime)
    
    // Welford's online algorithm — iterate only nMembersActual to avoid NaN from uninitialized slots
    for member in 0..<nMembersActual {
        for loc in 0..<nLoc {
            for t in 0..<nTime {
                let x = data3d[data3d.startIndex + loc * nMembers * nTime + member * nTime + t]
                let dstIdx = loc * nTime + t
                let delta = x - chunkMean[dstIdx]
                chunkMean[dstIdx] += delta / Float(member + 1)
                chunkM2[dstIdx] += delta * (x - chunkMean[dstIdx])
            }
        }
    }
    
    let chunkSpread = chunkM2.map {
        nMembersActual > 1 ? sqrt($0 / Float(nMembersActual - 1)) : 0
    }
    
    return (mean: chunkMean, spread: chunkSpread)
}
