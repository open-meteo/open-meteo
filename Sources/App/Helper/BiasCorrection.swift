

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
    
    static func quantileMapping(reference: ArraySlice<Float>, control: ArraySlice<Float>, forecast: ArraySlice<Float>, type: ChangeType) -> [Float] {
        // calculate CDF
        let binsRefernce = calculateBins(reference, min: type == .relativeChange ? 0 : nil)
        let binsControl = calculateBins(control, min: type == .relativeChange ? 0 : nil)
        let cdfRefernce = calculateCdf(reference, bins: binsRefernce)
        let cdfControl = calculateCdf(control, bins: binsControl)
        
        // Apply
        switch type {
        case .absoluteChage:
            return forecast.map {
                let qm = interpolate(binsControl, cdfControl, x: $0, extrapolate: false)
                return interpolate(cdfRefernce, binsRefernce, x: qm, extrapolate: false)
            }
        case .relativeChange:
            return forecast.map {
                let qm = max(interpolate(binsControl, cdfControl, x: $0, extrapolate: true), 0)
                return max(interpolate(cdfRefernce, binsRefernce, x: qm, extrapolate: true), 0)
            }
        }
    }
    
    static func quantileDeltaMapping(reference: ArraySlice<Float>, control: ArraySlice<Float>, forecast: ArraySlice<Float>, type: ChangeType) -> [Float] {
        // calculate CDF
        //let binsControl = calculateBins(control, nQuantiles: 250, min: type == .relativeChange ? 0 : nil)
        let binsControl = Bins(min: min(reference.min()!, control.min()!), max: max(reference.max()!, control.max()!), nQuantiles: 100)
        print("Bins min=\(binsControl.min) max=\(binsControl.max) delta=\((binsControl.max-binsControl.min)/Float(binsControl.nQuantiles))")
        let binsRefernce = binsControl// calculateBins(reference, min: type == .relativeChange ? 0 : nil)
        
        let cdfRefernce = calculateCdf(reference, bins: binsRefernce)
        let cdfControl = calculateCdf(control, bins: binsControl)
        
        // Apply
        let binsForecast = binsControl//calculateBins(forecast, min: type == .relativeChange ? 0 : nil)
        let cdfForecast = calculateCdf(forecast, bins: binsForecast)
        
        // TODO: forcast data CDF needs to be calculated on a sliding window of a couple of years
        // TODO: do we need to correct for seasonal chang? For QM this is a huge issue.. Maybe QDM is less effected

        switch type {
        case .absoluteChage:
            return forecast.map { forecast in
                let epsilon = interpolate(binsForecast, cdfForecast, x: forecast, extrapolate: false)
                let qdm1 = interpolate(cdfRefernce, binsRefernce, x: epsilon, extrapolate: false)
                return qdm1 + forecast - interpolate(cdfControl, binsControl, x: epsilon, extrapolate: false)
            }
        case .relativeChange:
            let maxScaleFactor: Float = 10
            return forecast.map { forecast in
                let epsilon = interpolate(binsForecast, cdfForecast, x: forecast, extrapolate: false)
                let qdm1 = interpolate(cdfRefernce, binsRefernce, x: epsilon, extrapolate: false)
                let scale = forecast / interpolate(cdfControl, binsControl, x: epsilon, extrapolate: false)
                return qdm1 / min(max(scale, maxScaleFactor * -1), maxScaleFactor)
            }
        }
    }
    
    static func quantileDeltaMappingMonthly(reference: ArraySlice<Float>, control: ArraySlice<Float>, referenceTime: TimerangeDt, forecast: ArraySlice<Float>, forecastTime: TimerangeDt, type: ChangeType) -> [Float] {
        // calculate CDF
        //let binsControl = calculateBins(control, nQuantiles: 250, min: type == .relativeChange ? 0 : nil)
        let bins = Bins(min: min(reference.min()!, control.min()!), max: max(reference.max()!, control.max()!), nQuantiles: 100)
        print("Bins min=\(bins.min) max=\(bins.max) delta=\((bins.max-bins.min)/Float(bins.nQuantiles))")
        
        let cdfRefernce = CdfMonthly(vector: reference, time: referenceTime, bins: bins)
        let cdfControl = CdfMonthly(vector: control, time: referenceTime, bins: bins)
        
        // Apply
        let cdfForecast = CdfMonthly10YearSliding(vector: forecast, time: forecastTime, bins: bins)

        switch type {
        case .absoluteChage:
            return zip(forecastTime, forecast).map { (time, forecast) in
                let epsilon = interpolate(bins, cdfForecast.get(time: time), x: forecast, extrapolate: false)
                let qdm1 = interpolate(cdfRefernce.get(time: time), bins, x: epsilon, extrapolate: false)
                return qdm1 + forecast - interpolate(cdfControl.get(time: time), bins, x: epsilon, extrapolate: false)
            }
        case .relativeChange:
            let maxScaleFactor: Float = 10
            return zip(forecastTime, forecast).map { (time, forecast) in
                let epsilon = interpolate(bins, cdfForecast.get(time: time), x: forecast, extrapolate: false)
                let qdm1 = interpolate(cdfRefernce.get(time: time), bins, x: epsilon, extrapolate: false)
                let scale = forecast / interpolate(cdfControl.get(time: time), bins, x: epsilon, extrapolate: false)
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
    
    /// Calculate sumulative distribution function. First value is always 0.
    static func calculateCdf(_ vector: ArraySlice<Float>, bins: Bins) -> [Float] {
        // Technically integer, but uses float for calualtions later
        let count = bins.count
        var cdf = [Float](repeating: 0, count: count)
        for value in vector {
            for (i, bin) in bins.enumerated().reversed() {
                if value < bin || i == count-1 { // Note sure if we need `i == pbf.count-1` -> count all larger than bin.max
                    cdf[i] += 1
                } else {
                    break
                }
            }
        }
        return cdf
    }
    
    /// Find value `x` on first array, then interpolate on the second array to return the value
    static func interpolate<A: RandomAccessCollection<Float>, B: RandomAccessCollection<Float>>(_ xData: A, _ yData: B, x: Float, extrapolate: Bool) -> Float {
        assert(xData.count == yData.count)
        let size = xData.count

        var i = 0;  // find left end of interval for interpolation
        if x >= xData[xData.index(xData.startIndex, offsetBy: size - 2)] {
            i = size - 2;  // special case: beyond right end
        } else {
            while (x > xData[xData.index(xData.startIndex, offsetBy: i + 1)]) { i += 1 }
        }
        let xL = xData[xData.index(xData.startIndex, offsetBy: i)]
        var yL = yData[yData.index(yData.startIndex, offsetBy: i)]
        let xR = xData[xData.index(xData.startIndex, offsetBy: i + 1)]
        var yR = yData[yData.index(yData.startIndex, offsetBy: i + 1)] // points on either side (unless beyond ends)

        if !extrapolate {  // if beyond ends of array and not extrapolating
            if (x < xL) { yR = yL }
            if (x > xR) { yL = yR }
        }
        let dydx = xR - xL == 0 ? 0 : (yR - yL) / (xR - xL);  // gradient
        return yL + dydx * (x - xL);       // linear interpolation
    }
}


/// Calculate CDF for each month individually
struct CdfMonthly {
    let cdf: [Float]
    
    /// input temperature and time axis
    init(vector: ArraySlice<Float>, time: TimerangeDt, bins: Bins) {
        let binsPerYear = 12
        
        let count = bins.count
        var cdf = [Float](repeating: 0, count: count * binsPerYear)
        for (t, value) in zip(time, vector) {
            let fractionalDayOfYear = Float(t.timeIntervalSince1970 / 3600) / 24
            let monthBin = (Int(round(fractionalDayOfYear / Float(binsPerYear))) % binsPerYear + binsPerYear) % binsPerYear
            for (i, bin) in bins.enumerated().reversed() {
                if value < bin {
                    cdf[monthBin * count + i] += 1
                    
                    cdf[((monthBin+1) % binsPerYear) * count + i] += 1
                    cdf[((monthBin-1+binsPerYear) % binsPerYear) * count + i] += 1
                } else {
                    break
                }
            }
        }
        /// normalise to 1
        for j in 0..<cdf.count / bins.count {
            for i in j * bins.count ..< (j+1) * bins.count {
                cdf[i] = cdf[i] / cdf[(j+1) * bins.count - 1]
            }
        }
        self.cdf = cdf
    }
    
    /// month starting at 0
    func get(time t: Timestamp) -> ArraySlice<Float> {
        let binsPerYear = 12
        let fractionalDayOfYear = Float(t.timeIntervalSince1970 / 3600) / 24
        let monthBin = (Int(round(fractionalDayOfYear / Float(binsPerYear))) % binsPerYear + binsPerYear) % binsPerYear
        
        let binLength = cdf.count / binsPerYear
        return cdf[binLength * monthBin ..< binLength * (monthBin+1)]
    }
}

/// Calculate CDF for each month individually, but over a sliding window of 10 years
struct CdfMonthly10YearSliding {
    let cdf: [Float]
    let binLength: Int
    let yearMin: Float
    
    /// input temperature and time axis
    init(vector: ArraySlice<Float>, time: TimerangeDt, bins: Bins) {
        let binsPerYear = 12
        
        let yearMax = Float(time.range.upperBound.timeIntervalSince1970 / 3600) / 24 / 365.25
        let yearMin = Float(time.range.lowerBound.timeIntervalSince1970 / 3600) / 24 / 365.25
        let nYears = Int(yearMax - yearMin) + 2
        
        let count = bins.count
        var cdf = [Float](repeating: 0, count: count * binsPerYear * nYears)
        for (t, value) in zip(time, vector) {
            let fractionalDayOfYear = Float(t.timeIntervalSince1970 / 3600) / 24
            let monthBin = (Int(round(fractionalDayOfYear / Float(binsPerYear))) % binsPerYear + binsPerYear) % binsPerYear
            
            let fractionalYear = Float(t.timeIntervalSince1970 / 3600) / 24 / 365.25
            let yearBin = Int(fractionalYear - yearMin)
            
            for (i, bin) in bins.enumerated().reversed() {
                if value < bin {
                    for y in max(yearBin-5, 0) ..< min(yearBin+5+1, nYears) {
                        cdf[(monthBin * count + i) + count * binsPerYear * y] += 1
                        cdf[(((monthBin+1) % binsPerYear) * count + i) + count * binsPerYear * y] += 1
                        cdf[(((monthBin-1+binsPerYear) % binsPerYear) * count + i) + count * binsPerYear * y] += 1
                    }
                } else {
                    break
                }
            }
        }
        /// normalise to 1
        for j in 0..<cdf.count / bins.count {
            for i in j * bins.count ..< (j+1) * bins.count {
                cdf[i] = cdf[i] / cdf[(j+1) * bins.count - 1]
            }
        }
        self.cdf = cdf
        self.binLength = count
        self.yearMin = yearMin
    }
    
    /// month starting at 0
    func get(time t: Timestamp) -> ArraySlice<Float> {
        let binsPerYear = 12
        let fractionalDayOfYear = Float(t.timeIntervalSince1970 / 3600) / 24
        let monthBin = (Int(round(fractionalDayOfYear / Float(binsPerYear))) % binsPerYear + binsPerYear) % binsPerYear
        
        let fractionalYear = Float(t.timeIntervalSince1970 / 3600) / 24 / 365.25
        let yearBin = Int(fractionalYear - yearMin)
        
        return cdf[binLength * monthBin + binLength * binsPerYear * yearBin ..< binLength * (monthBin+1)  + binLength * binsPerYear * yearBin]
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
