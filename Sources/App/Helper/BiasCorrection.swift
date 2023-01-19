

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
    
    /// Important note: If CDF of `forecast` is the same as `control` the climate change signal might be canceled out. It can be used however to just do a simple BIAS transfer from one model to another
    static func quantileDeltaMappingMonthly(reference: ArraySlice<Float>, control: ArraySlice<Float>, referenceTime: TimerangeDt, forecast: ArraySlice<Float>, forecastTime: TimerangeDt, type: ChangeType) -> [Float] {
        // calculate CDF
        //let binsControl = calculateBins(control, nQuantiles: 250, min: type == .relativeChange ? 0 : nil)
        let binsControl = Bins(min: control.min()!, max: control.max()!, nQuantiles: 100)
        //let bins = Bins(min: min(reference.min()!, control.min()!), max: max(reference.max()!, control.max()!), nQuantiles: 100)
        print("Bins min=\(binsControl.min) max=\(binsControl.max) delta=\((binsControl.max-binsControl.min)/Float(binsControl.nQuantiles))")
        let binsRefernce = Bins(min: reference.min()!, max: reference.max()!, nQuantiles: 100) //calculateBins(reference, min: type == .relativeChange ? 0 : reference.min()! - 10)
        let binsForecast = binsControl // Bins(min: forecast.min()!, max: forecast.max()!, nQuantiles: 100)
        
        let cdfRefernce = CdfMonthly(vector: reference, time: referenceTime, bins: binsRefernce)
        let cdfControl = CdfMonthly(vector: control, time: referenceTime, bins: binsControl)
        
        // Apply
        let cdfForecast = cdfControl// CdfMonthly10YearSliding(vector: forecast, time: forecastTime, bins: binsForecast)

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


/*
 Before
 QDM projected rmse: 2.1441827
 QDM projected me: -0.008521517
 QDM qctime rmse: 2.1524856
 QDM qctime me: 0.33143386
 
 QDM projected rmse: 2.1441827
 QDM projected me: -0.008521517
 QDM qctime rmse: 2.1524856
 QDM qctime me: 0.33143386
 
 with interpolation
 QDM projected rmse: 2.144915
 QDM projected me: -0.021453733
 QDM qctime rmse: 2.1539917
 QDM qctime me: 0.3202337
 
 inverted factors
 QDM projected rmse: 2.1443715
 QDM projected me: -0.016594684
 QDM qctime rmse: 2.153304
 QDM qctime me: 0.3233069
 
 inverted 4x bin:
 QDM projected rmse: 2.1475098
 QDM projected me: 0.027171426
 QDM qctime rmse: 2.155336
 QDM qctime me: 0.37284786
 
 normal: 12x bin FIXED offset
 QDM projected rmse: 2.1433
 QDM projected me: 0.015121117
 QDM qctime rmse: 2.1498253
 QDM qctime me: 0.36447984
 
 inverted: 12x bin FIXED offset
 QDM projected rmse: 2.14071
 QDM projected me: 0.002004539
 QDM qctime rmse: 2.1490934
 QDM qctime me: 0.3547897
 
 normal...
 QDM projected rmse: 2.14162
 QDM projected me: 0.017507693
 QDM qctime rmse: 2.154178
 QDM qctime me: 0.36449537
 
 4 months normal:
 QDM projected rmse: 2.1469715
 QDM projected me: -0.00023381515
 QDM qctime rmse: 2.1521297
 QDM qctime me: 0.3463871
 
 4 month inverted:
 QDM projected rmse: 2.1462765
 QDM projected me: -0.007172498
 QDM qctime rmse: 2.1524358
 QDM qctime me: 0.33949688
 
 QUESTION: only do 4 season split?
 */

protocol MonthlyBinable {
    func get(bin: Int, time t: Timestamp) -> Float
    var nBins: Int { get }
}

/// Calculate CDF for each month individually
struct CdfMonthly: MonthlyBinable {
    let cdf: [Float]
    let bins: Bins
    
    static var binsPerYear: Int { 4 }
    
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
                if value < bin {
                    cdf[monthBin * count + i] += 1-fraction
                    cdf[((monthBin+1) % Self.binsPerYear) * count + i] += fraction
                    //cdf[monthBin * count + i] += 1
                    //cdf[((monthBin+1) % binsPerYear) * count + i] += 1
                    //cdf[((monthBin-1+binsPerYear) % binsPerYear) * count + i] += 1
                } else {
                    break
                }
            }
        }
        /// normalise to 1
        for j in 0..<cdf.count / bins.count {
            // last value is always count... could also scale to something between bin min/max to make it compressible more easily
            let count = cdf[(j+1) * bins.count - 1]
            for i in j * bins.count ..< (j+1) * bins.count {
                cdf[i] = cdf[i] / count
            }
        }
        self.cdf = cdf
        self.bins = bins
    }
    
    /// month starting at 0
    func get(time t: Timestamp) -> ArraySlice<Float> {
        let fractionalDayOfYear = ((t.timeIntervalSince1970 % 31_557_600) + 31_557_600) % 31_557_600
        let monthBin = fractionalDayOfYear / (31_557_600 / Self.binsPerYear)
        
        let binLength = cdf.count / Self.binsPerYear
        return cdf[binLength * monthBin ..< binLength * (monthBin+1)]
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
    
    static var binsPerYear: Int { 4 }
    
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
                if value < bin {
                    for y in max(yearBin-5, 0) ..< min(yearBin+5+1, nYears) {
                        cdf[(monthBin * count + i) + count * Self.binsPerYear * y] += 1-fraction
                        cdf[(((monthBin+1) % Self.binsPerYear) * count + i) + count * Self.binsPerYear * y] += fraction
                        //cdf[(monthBin * count + i) + count * binsPerYear * y] += 1
                        //cdf[(((monthBin+1) % binsPerYear) * count + i) + count * binsPerYear * y] += 1
                        //cdf[(((monthBin-1+binsPerYear) % binsPerYear) * count + i) + count * binsPerYear * y] += 1
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
            for i in j * bins.count ..< (j+1) * bins.count {
                cdf[i] = cdf[i] / count
            }
        }
        self.cdf = cdf
        self.bins = bins
        self.yearMin = yearMin
    }
    
    /// month starting at 0
    func get(time t: Timestamp) -> ArraySlice<Float> {
        // TODO: interpolate between two CDFs... maybe do it upstream to prevent array allocations
        
        let fractionalDayOfYear = ((t.timeIntervalSince1970 % 31_557_600) + 31_557_600) % 31_557_600
        let monthBin = fractionalDayOfYear / (31_557_600 / Self.binsPerYear)
        
        let fractionalYear = Float(t.timeIntervalSince1970 / 3600) / 24 / 365.25
        let yearBin = Int(fractionalYear - yearMin)
        
        return cdf[nBins * monthBin + nBins * Self.binsPerYear * yearBin ..< nBins * (monthBin+1)  + nBins * Self.binsPerYear * yearBin]
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

/// Calculate differnet bins for each month
/*struct BinsPerMonth {
    let min: [Float]
    let max: [Float]
    let nQuantiles: Int
    
    init(_ vector: ArraySlice<Float>, time: TimerangeDt, nQuantiles: Int, binsPerYear: Int) {
        var min = [Float](repeating: .nan, count: binsPerYear)
        var max = [Float](repeating: .nan, count: binsPerYear)
        for (t, value) in (time, vector) {
            
        }
    }
}*/

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
