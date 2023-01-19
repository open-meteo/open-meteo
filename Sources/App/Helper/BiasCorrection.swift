import Foundation


/// QM and QDM based on https://link.springer.com/article/10.1007/s00382-020-05447-4
/// QDM paper https://journals.ametsoc.org/view/journals/clim/28/17/jcli-d-14-00754.1.xml
/// Loosly based on https://github.com/btschwertfeger/BiasAdjustCXX/blob/master/src/CMethods.cxx
/// Question: calculate CDF for each month? sliding doy? -> Distrubution based bias control does ot require this?
struct BiasCorrection {
    
    enum ChangeType {
        /// Correct offset. E.g. temperature
        case absoluteChage
        
        /// Scale. E.g. Precipitation
        case relativeChange
    }
    
    /// Important note: If CDF of `forecast` is the same as `control` the climate change signal might be canceled out. It can be used however to just do a simple BIAS transfer from one model to another
    static func quantileDeltaMappingMonthly(reference: ArraySlice<Float>, control: ArraySlice<Float>, referenceTime: TimerangeDt, forecast: ArraySlice<Float>, forecastTime: TimerangeDt, type: ChangeType) -> [Float] {
        let nQuantiles = 100
        
        // Compute reference distributions
        let binsControl = calculateBins(control, nQuantiles: nQuantiles, min: type == .relativeChange ? 0 : nil)
        let binsRefernce = calculateBins(reference, nQuantiles: nQuantiles, min: type == .relativeChange ? 0 : nil)
        let cdfRefernce = CdfMonthly(vector: reference, time: referenceTime, bins: binsRefernce)
        let cdfControl = CdfMonthly(vector: control, time: referenceTime, bins: binsControl)
        
        // Apply
        let binsForecast = calculateBins(forecast, nQuantiles: nQuantiles, min: type == .relativeChange ? 0 : nil)
        let cdfForecast = CdfMonthly10YearSliding(vector: forecast, time: forecastTime, bins: binsForecast)

        switch type {
        case .absoluteChage:
            return zip(forecastTime, forecast).map { (time, forecast) in
                let epsilon = interpolate(binsForecast, cdfForecast, x: forecast, time: time, extrapolate: false)
                let qdm1 = interpolate(cdfRefernce, binsRefernce, x: epsilon, time: time, extrapolate: false)
                return qdm1 + forecast - interpolate(cdfControl, binsControl, x: epsilon, time: time, extrapolate: false)
            }
        case .relativeChange:
            let maxScaleFactor: Float = 10
            return zip(forecastTime, forecast).map { (time, forecast) in
                let epsilon = interpolate(binsForecast, cdfForecast, x: forecast, time: time, extrapolate: false)
                let qdm1 = interpolate(cdfRefernce, binsRefernce, x: epsilon, time: time, extrapolate: false)
                let scale = forecast / interpolate(cdfControl, binsControl, x: epsilon, time: time, extrapolate: false)
                return qdm1 / min(max(scale, maxScaleFactor * -1), maxScaleFactor)
            }
        }
    }
    
    /// Calcualte min/max from vector and return bins
    /// nQuantiles of 100 should be sufficient
    static func calculateBins(_ vector: ArraySlice<Float>, nQuantiles: Int = 100, min: Float? = nil) -> Bins {
        guard let minMax = vector.minAndMax() else {
            return Bins(min: .nan, max: .nan, nQuantiles: nQuantiles)
        }
        return Bins(min: min ?? minMax.min, max: minMax.max, nQuantiles: nQuantiles)
    }
    
    /// Find value `x` on first array, then interpolate on the second array to return the value
    static func interpolate<Cdf: MonthlyBinable>(_ xData: Bins, _ yData: Cdf, x: Float, time: Timestamp, extrapolate: Bool) -> Float {
        //assert(xData.count == yData.count)
        let size = xData.count

        var i = 0;  // find left end of interval for interpolation
        if x >= xData[xData.index(xData.startIndex, offsetBy: size - 2)] {
            i = size - 2;  // special case: beyond right end
        } else {
            while (x > xData[xData.index(xData.startIndex, offsetBy: i + 1)]) { i += 1 }
        }
        let xL = xData[xData.index(xData.startIndex, offsetBy: i)]
        var yL = yData.get(bin: i, time: time)
        let xR = xData[xData.index(xData.startIndex, offsetBy: i + 1)]
        var yR = yData.get(bin: i+1, time: time) // points on either side (unless beyond ends)

        if !extrapolate {  // if beyond ends of array and not extrapolating
            if (x < xL) { yR = yL }
            if (x > xR) { yL = yR }
        }
        let dydx = xR - xL == 0 ? 0 : (yR - yL) / (xR - xL);  // gradient
        return yL + dydx * (x - xL);       // linear interpolation
    }
    
    /// Find value `x` on first array, then interpolate on the second array to return the value
    static func interpolate<Cdf: MonthlyBinable>(_ xData: Cdf, _ yData: Bins, x: Float, time: Timestamp, extrapolate: Bool) -> Float {
        //assert(xData.count == yData.count)
        let size = xData.nBins

        var i = 0;  // find left end of interval for interpolation
        if x >= xData.get(bin: size - 2, time: time) {
            i = size - 2;  // special case: beyond right end
        } else {
            while (x > xData.get(bin: i+1, time: time)) { i += 1 }
        }
        let xL = xData.get(bin: i, time: time)
        var yL = yData[yData.index(yData.startIndex, offsetBy: i)]
        let xR = xData.get(bin: i+1, time: time)
        var yR = yData[yData.index(yData.startIndex, offsetBy: i + 1)] // points on either side (unless beyond ends)

        if !extrapolate {  // if beyond ends of array and not extrapolating
            if (x < xL) { yR = yL }
            if (x > xR) { yL = yR }
        }
        let dydx = xR - xL == 0 ? 0 : (yR - yL) / (xR - xL);  // gradient
        return yL + dydx * (x - xL);       // linear interpolation
    }
}

/// Calculate and/or apply a linear bias correction to correct a fixed offset
struct BiasCorrectionSeasonalLinear {
    /// Could be one mean value for each month
    let meansPerYear: [Float]
    
    public init(_ data: ArraySlice<Float>, time: TimerangeDt, binsPerYear: Int = 12) {
        var sums = [Float](repeating: 0, count: binsPerYear)
        var weights = [Float](repeating: 0, count: binsPerYear)
        for (t, v) in zip(time, data) {
            let fractionalDayOfYear = ((t.timeIntervalSince1970 % 31_557_600) + 31_557_600) % 31_557_600
            let monthBin = fractionalDayOfYear / (31_557_600 / binsPerYear)
            let fraction = Float(fractionalDayOfYear).truncatingRemainder(dividingBy: Float(31_557_600 / binsPerYear)) / Float(31_557_600 / binsPerYear)
            sums[monthBin] += v * (1-fraction)
            weights[monthBin] += (1-fraction)
            sums[(monthBin+1) % binsPerYear] += v * fraction
            weights[(monthBin+1) % binsPerYear] += fraction
        }
        self.meansPerYear = zip(weights, sums).map({ $0.0 <= 0.001 ? .nan : $0.1 / $0.0 })
    }
    
    func applyOffset(on data: inout [Float], otherWeights: BiasCorrectionSeasonalLinear, time: TimerangeDt, type: BiasCorrection.ChangeType, indices: Range<Int>? = nil) {
        let indices = indices ?? data.indices
        let binsPerYear = meansPerYear.count
        assert(time.count == indices.count)
        for (i ,t) in zip(indices, time) {
            let fractionalDayOfYear = ((t.timeIntervalSince1970 % 31_557_600) + 31_557_600) % 31_557_600
            let monthBin = fractionalDayOfYear / (31_557_600 / binsPerYear)
            let fraction = Float(fractionalDayOfYear).truncatingRemainder(dividingBy: Float(31_557_600 / binsPerYear)) / Float(31_557_600 / binsPerYear)
            let m0 = meansPerYear[monthBin]
            let m1 = meansPerYear[(monthBin+1) % binsPerYear]
            let o0 = otherWeights.meansPerYear[monthBin]
            let o1 = otherWeights.meansPerYear[(monthBin+1) % binsPerYear]
            switch type {
            case .absoluteChage:
                data[i] += (m0 - o0) * (1-fraction) + (m1 - o1) * fraction
            case .relativeChange:
                data[i] *= (m0 / o0) * (1-fraction) + (m1 / o1) * fraction
            }
        }
    }
}




protocol MonthlyBinable {
    func get(bin: Int, time t: Timestamp) -> Float
    var nBins: Int { get }
}

/// Calculate CDF for each month individually
struct CdfMonthly: MonthlyBinable {
    let cdf: [Float]
    let bins: Bins
    
    static var binsPerYear: Int { 6 }
    
    var nBins: Int {
        cdf.count / Self.binsPerYear
    }
    
    /// input temperature and time axis
    init(vector: ArraySlice<Float>, time: TimerangeDt, bins: Bins) {
        let count = bins.nQuantiles
        var cdf = [Float](repeating: 0, count: count * Self.binsPerYear)
        for (t, value) in zip(time, vector) {
            let fractionalDayOfYear = ((t.timeIntervalSince1970 % 31_557_600) + 31_557_600) % 31_557_600
            let monthBin = fractionalDayOfYear / (31_557_600 / Self.binsPerYear)
            let fraction = Float(fractionalDayOfYear).truncatingRemainder(dividingBy: Float(31_557_600 / Self.binsPerYear)) / Float(31_557_600 / Self.binsPerYear)
            for (i, bin) in bins.enumerated().reversed() {
                if value >= bin && value < bins[i+1] {
                    // value exactly inside a bin, adjust weight
                    let interBinFraction = (bins[i+1]-value)/(bins[i+1]-bin)
                    assert(interBinFraction >= 0 && interBinFraction <= 1)
                    cdf[monthBin * count + i] += (1-fraction) * interBinFraction
                    cdf[((monthBin+1) % Self.binsPerYear) * count + i] += fraction * interBinFraction
                } else if value < bin {
                    cdf[monthBin * count + i] += 1-fraction
                    cdf[((monthBin+1) % Self.binsPerYear) * count + i] += fraction
                } else {
                    break
                }
            }
        }
        /// normalise to 1
        for j in 0..<cdf.count / bins.count {
            // last value is always count... could also scale to something between bin min/max to make it compressible more easily
            let count = cdf[(j+1) * bins.count - 1]
            guard count > 0 else {
                continue
            }
            for i in j * bins.count ..< (j+1) * bins.count {
                cdf[i] = cdf[i] / count
            }
        }
        self.cdf = cdf
        self.bins = bins
    }
    
    /// linear interpolate between 2 months CDF
    func get(bin: Int, time t: Timestamp) -> Float {
        let fractionalDayOfYear = ((t.timeIntervalSince1970 % 31_557_600) + 31_557_600) % 31_557_600
        let monthBin = fractionalDayOfYear / (31_557_600 / Self.binsPerYear)
        let fraction = Float(fractionalDayOfYear).truncatingRemainder(dividingBy: Float(31_557_600 / Self.binsPerYear)) / Float(31_557_600 / Self.binsPerYear)
        
        let binLength = cdf.count / Self.binsPerYear
        return cdf[binLength * monthBin + bin] * (1-fraction) + cdf[binLength * ((monthBin+1) % Self.binsPerYear) + bin] * (fraction)
    }
}


/// Calculate CDF for each month individually, but over a sliding window of 10 years
struct CdfMonthly10YearSliding: MonthlyBinable {
    let cdf: [Float]
    var nBins: Int { bins.nQuantiles }
    let yearMin: Float
    let bins: Bins
    
    static var binsPerYear: Int { 6 }
    
    /// input temperature and time axis
    init(vector: ArraySlice<Float>, time: TimerangeDt, bins: Bins) {
        let yearMax = Float(time.range.upperBound.timeIntervalSince1970 / 3600) / 24 / 365.25
        let yearMin = Float(time.range.lowerBound.timeIntervalSince1970 / 3600) / 24 / 365.25
        let nYears = Int(yearMax - yearMin) + 2
        
        let count = bins.nQuantiles
        var cdf = [Float](repeating: 0, count: count * Self.binsPerYear * nYears)
        for (t, value) in zip(time, vector) {
            let fractionalDayOfYear = ((t.timeIntervalSince1970 % 31_557_600) + 31_557_600) % 31_557_600
            let monthBin = fractionalDayOfYear / (31_557_600 / Self.binsPerYear)
            let fraction = Float(fractionalDayOfYear).truncatingRemainder(dividingBy: Float(31_557_600 / Self.binsPerYear)) / Float(31_557_600 / Self.binsPerYear)
            
            let fractionalYear = Float(t.timeIntervalSince1970 / 3600) / 24 / 365.25
            let yearBin = Int(fractionalYear - yearMin)
            
            for (i, bin) in bins.enumerated().reversed() {
                if value >= bin && value < bins[i+1] {
                    // value exactly inside a bin, adjust weight
                    let interBinFraction = (bins[i+1]-value)/(bins[i+1]-bin)
                    assert(interBinFraction >= 0 && interBinFraction <= 1)
                    for y in max(yearBin-5, 0) ..< min(yearBin+5+1, nYears) {
                        cdf[(monthBin * count + i) + count * Self.binsPerYear * y] += (1-fraction) * interBinFraction
                        cdf[(((monthBin+1) % Self.binsPerYear) * count + i) + count * Self.binsPerYear * y] += fraction * interBinFraction
                    }
                } else if value < bin {
                    for y in max(yearBin-5, 0) ..< min(yearBin+5+1, nYears) {
                        cdf[(monthBin * count + i) + count * Self.binsPerYear * y] += 1-fraction
                        cdf[(((monthBin+1) % Self.binsPerYear) * count + i) + count * Self.binsPerYear * y] += fraction
                    }
                } else {
                    break
                }
            }
        }
        /// normalise to 1
        for j in 0..<cdf.count / bins.count {
            // last value is always count... could also scale to something between bin min/max to make it compressible more easily
            let count = cdf[(j+1) * bins.count - 1]
            guard count > 0 else {
                continue
            }
            for i in j * bins.count ..< (j+1) * bins.count {
                cdf[i] = cdf[i] / count
            }
        }
        self.cdf = cdf
        self.bins = bins
        self.yearMin = yearMin
    }
    
    /// linear interpolate between 2 months CDF
    func get(bin: Int, time t: Timestamp) -> Float {
        // TODO: interpolate between two CDFs... maybe do it upstream to prevent array allocations
        
        let fractionalDayOfYear = ((t.timeIntervalSince1970 % 31_557_600) + 31_557_600) % 31_557_600
        let monthBin = fractionalDayOfYear / (31_557_600 / Self.binsPerYear)
        let fraction = Float(fractionalDayOfYear).truncatingRemainder(dividingBy: Float(31_557_600 / Self.binsPerYear)) / Float(31_557_600 / Self.binsPerYear)
        
        let fractionalYear = Float(t.timeIntervalSince1970 / 3600) / 24 / 365.25
        let yearBin = Int(fractionalYear - yearMin)
        
        return cdf[nBins * monthBin + nBins * Self.binsPerYear * yearBin + bin] * (1-fraction) + cdf[nBins * ((monthBin+1) % Self.binsPerYear) + nBins * Self.binsPerYear * yearBin + bin + 1] * (fraction)
    }
}

/// Represent bin sizes. Iteratable like an array, but only stores min/max/nQuantiles
struct Bins {
    let min: Float
    let max: Float
    let nQuantiles: Int
}

extension Bins: RandomAccessCollection {
    subscript(position: Int) -> Float {
        get {
            return min + (max - min) / Float(nQuantiles) * Float(position)
        }
    }
    
    var indices: Range<Int> {
        return startIndex..<endIndex
    }
    
    var startIndex: Int {
        return 0
    }
    
    var endIndex: Int {
        return nQuantiles
    }
    
    func index(before i: Int) -> Int {
        i - 1
    }
    
    func index(after i: Int) -> Int {
        i + 1
    }
}
