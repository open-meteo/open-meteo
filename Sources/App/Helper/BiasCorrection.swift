

import Foundation

/// QM and QDM based on https://link.springer.com/article/10.1007/s00382-020-05447-4
/// Question: calculate CDF for each month? sliding doy? -> Distrubution based bias control does ot require this?
struct BiasCorrection {
    
    static func quantileMapping() {
        // Get bins
        // calculate CDF for reference and control data
        // For preprocessing have to store bin definiton (min,max,steps), reference CDF (int array n_bins), control CDF (tn n_bins)
        // Apply
    }
    
    static func quantileDeltaMapping() {
        // Get bins
        // calculate CDF for reference and control data
        // For preprocessing have to store bin definiton (min,max,steps), reference CDF (int array n_bins), control CDF (tn n_bins)
        // Calulate CDF of future data, derive epsilon
        // Apply
    }
    
    /// nQuantiles of 100 should be sufficient
    static func calculateBins(_ vec1: ArraySlice<Float>, _ vec2: ArraySlice<Float>, nQuantiles: Int, startAtZero: Bool) -> Bins {
        // calculate min/max of both vectors
        // if startAtZero use 0 instead of minimum
        // return range of float
        fatalError()
    }
    
    static func calculateCdf(_ vector: ArraySlice<Float>, bins: Bins) -> [Int] {
        // caulate probability density and accumulate
        // Technically integer, but could also use as Float
        fatalError()
    }
    
    /// Interpolate 2 vectors with binary search
    static func interpolate(_ vec1: ArraySlice<Float>, _ vec2: ArraySlice<Float>, pos: Float) -> Float {
        fatalError()
    }
}

struct Bins {
    let min: Float
    let max: Float
    let by: Float
}
