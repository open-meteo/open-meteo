import Foundation


/// QDM bias correction to preserve deltas in data. E.g. events of temperature > 20°C are better represented
/// Calculates CDFs for reference and control data on a monthly basis.
/// CDFs for forecast data are sliding averages over 10 years to preserve climat change signal.
/// Without sliding CDF, it is a regular Quantile Mapping QM that reduces climage change signals.
///
/// QM and QDM based on https://link.springer.com/article/10.1007/s00382-020-05447-4
/// QDM paper https://journals.ametsoc.org/view/journals/clim/28/17/jcli-d-14-00754.1.xml
/// Loosly based on https://github.com/btschwertfeger/BiasAdjustCXX/blob/master/src/CMethods.cxx
struct QuantileDeltaMappingBiasCorrection {
    
    enum ChangeType {
        /// Correct offset. E.g. temperature
        case absoluteChage
        
        /// Scale. E.g. Precipitation
        case relativeChange
    }
    
    /// Calculate CDFs over the entire  control and forecast timespan using sliding windows
    /// Important note: If CDF of `forecast` is the same as `control` the climate change signal might be canceled out. It can be used however to just do a simple BIAS transfer from one model to another
    /// TODO: check if dry periods are still correct
    static func quantileDeltaMappingMonthly(reference: ArraySlice<Float>, referenceTime: TimerangeDt, controlAndForecast: ArraySlice<Float>, controlAndForecastTime: TimerangeDt, type: ChangeType) -> [Float] {
        let nQuantiles = 100
        
        // Compute reference distributions
        let binsRefernce = calculateBins(reference, nQuantiles: nQuantiles, min: type == .relativeChange ? 0 : nil)
        let cdfRefernce = CdfMonthly10YearSliding(vector: reference, time: referenceTime, bins: binsRefernce)
        
        let binsControl = calculateBins(controlAndForecast, nQuantiles: nQuantiles, min: type == .relativeChange ? 0 : nil)
        let cdfControl = CdfMonthly10YearSliding(vector: controlAndForecast, time: controlAndForecastTime, bins: binsControl)
        
        // Apply
        let binsForecast = binsControl
        let cdfForecast = cdfControl
        
        // Limit time to 5 years before end of reference time. CDFs are averaged over 10 years and this makes sure, that the forecast CDF does not take any future signals into the reference.
        let maxReferenceTime = Timestamp(referenceTime.range.upperBound.timeIntervalSince1970 - Timestamp.secondsPerAverageYear * CdfMonthly10YearSliding.yearsToAggregate / 2)

        switch type {
        case .absoluteChage:
            return zip(controlAndForecastTime, controlAndForecast).map { (time, forecast) in
                /// Limit time to end of reference time, but keep day-of-year correct
                let timeReference = time >= maxReferenceTime ? maxReferenceTime.add(time.timeIntervalSince1970 % Timestamp.secondsPerAverageYear - Timestamp.secondsPerAverageYear) : time
                let epsilon = interpolate(binsForecast, cdfForecast, x: forecast, time: time, extrapolate: false)
                let qdm1 = interpolate(cdfRefernce, binsRefernce, x: epsilon, time: timeReference, extrapolate: false)
                return qdm1 + forecast - interpolate(cdfControl, binsControl, x: epsilon, time: timeReference, extrapolate: false)
            }
        case .relativeChange:
            let maxScaleFactor: Float = 10
            return zip(controlAndForecastTime, controlAndForecast).map { (time, forecast) in
                guard forecast > 0 else {
                    return 0
                }
                /// Limit time to end of reference time, but keep day-of-year correct
                let timeReference = time >= maxReferenceTime ? maxReferenceTime.add(time.timeIntervalSince1970 % Timestamp.secondsPerAverageYear - Timestamp.secondsPerAverageYear) : time
                let epsilon = interpolate(binsForecast, cdfForecast, x: forecast, time: time, extrapolate: false)
                let qdm1 = interpolate(cdfRefernce, binsRefernce, x: epsilon, time: timeReference, extrapolate: false)
                let scale = forecast / interpolate(cdfControl, binsControl, x: epsilon, time: timeReference, extrapolate: false)
                return qdm1 * min(max(scale, maxScaleFactor * -1), maxScaleFactor)
            }
        }
    }
    
    /// Calculate CDFs over the entire  control and forecast timespan using sliding windows
    /// Important note: If CDF of `forecast` is the same as `control` the climate change signal might be canceled out. It can be used however to just do a simple BIAS transfer from one model to another
    /// TODO: check if dry periods are still correct
    static func quantileDeltaMappingMonthlyDetrend(reference: ArraySlice<Float>, referenceTime: TimerangeDt, controlAndForecast: ArraySlice<Float>, controlAndForecastTime: TimerangeDt, type: ChangeType) -> [Float] {
        let nQuantiles = 100
        
        //return controlAndForecast.detrendLinear().map({$0})
        
        // Compute reference distributions
        let referenceDetrended = reference.detrendLinear()
        let binsRefernce = calculateBins(referenceDetrended, nQuantiles: nQuantiles, min: type == .relativeChange ? 0 : nil)
        let cdfRefernce = CdfMonthly(vector: referenceDetrended, time: referenceTime, bins: binsRefernce)
        
        let controlDetrended = controlAndForecast[0..<reference.count].detrendLinear()
        let binsControl = calculateBins(controlDetrended, nQuantiles: nQuantiles, min: type == .relativeChange ? 0 : nil)
        let cdfControl = CdfMonthly(vector: controlDetrended, time: referenceTime, bins: binsControl)
        
        // Apply
        let binsForecast = calculateBins(controlAndForecast, nQuantiles: nQuantiles, min: type == .relativeChange ? 0 : nil)
        let cdfForecast = CdfMonthly10YearSliding(vector: controlAndForecast, time: controlAndForecastTime, bins: binsForecast)

        switch type {
        case .absoluteChage:
            return zip(controlAndForecastTime, controlAndForecast).map { (time, forecast) in
                let epsilon = interpolate(binsForecast, cdfForecast, x: forecast, time: time, extrapolate: false)
                let qdm1 = interpolate(cdfRefernce, binsRefernce, x: epsilon, time: time, extrapolate: false)
                return qdm1 + forecast - interpolate(cdfControl, binsControl, x: epsilon, time: time, extrapolate: false)
            }
        case .relativeChange:
            let maxScaleFactor: Float = 10
            return zip(controlAndForecastTime, controlAndForecast).map { (time, forecast) in
                guard forecast > 0 else {
                    return 0
                }
                let epsilon = interpolate(binsForecast, cdfForecast, x: forecast, time: time, extrapolate: false)
                let qdm1 = interpolate(cdfRefernce, binsRefernce, x: epsilon, time: time, extrapolate: false)
                let scale = forecast / interpolate(cdfControl, binsControl, x: epsilon, time: time, extrapolate: false)
                return qdm1 * min(max(scale, maxScaleFactor * -1), maxScaleFactor)
            }
        }
    }
    
    /// Important note: If CDF of `forecast` is the same as `control` the climate change signal might be canceled out. It can be used however to just do a simple BIAS transfer from one model to another
    /*static func quantileDeltaMappingMonthly(reference: ArraySlice<Float>, control: ArraySlice<Float>, referenceTime: TimerangeDt, forecast: ArraySlice<Float>, forecastTime: TimerangeDt, type: ChangeType) -> [Float] {
        let nQuantiles = 100
        
        // Compute reference distributions
        let binsControl = calculateBins(control, nQuantiles: nQuantiles, min: type == .relativeChange ? 0 : nil)
        let binsRefernce = calculateBins(reference, nQuantiles: nQuantiles, min: type == .relativeChange ? 0 : nil)
        let cdfRefernce = CdfMonthly10YearSliding(vector: reference, time: referenceTime, bins: binsRefernce)
        let cdfControl = CdfMonthly10YearSliding(vector: control, time: referenceTime, bins: binsControl)
        
        // NOTE: cdf of forecast and control should use the same sliding CDFs!
        
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
                return scale == 0 ? 0 : qdm1 * min(max(scale, maxScaleFactor * -1), maxScaleFactor)
            }
        }
    }*/
    
    /// Calcualte min/max from vector and return bins
    /// nQuantiles of 100 should be sufficient
    static func calculateBins<T: Sequence>(_ vector: T, nQuantiles: Int = 100, min: Float? = nil) -> Bins where T.Element == Float {
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

extension RandomAccessCollection where Element == Float {
    /// Linearly detrend data
    func detrendLinear() -> LazyMapSequence<EnumeratedSequence<Self>, Float> {
        var sumx = 0
        var sumxsq = 0
        var sumy: Float = 0
        var sumxy: Float = 0
        
        for (i, t) in self.enumerated() {
            sumx=sumx+i;
            sumxsq=sumxsq+(i*i);
            sumy=sumy+t;
            sumxy=sumxy+Float(i)*t;
        }
        let d=Float(self.count*sumxsq-sumx*sumx)
        let m=(Float(self.count)*sumxy-Float(sumx)*sumy)/d
        let c=(sumy*Float(sumxsq)-Float(sumx)*sumxy)/d
        return self.enumerated().lazy.map { (i,v) in v - Float(i) * m - c/2}
    }
}


/// Calculate and/or apply a linear bias correction to correct a fixed offset
/// Deltas are calculated for each month individually and use linear interpolation
struct BiasCorrectionSeasonalLinear {
    /// Could be one mean value for each month. Depends on `binsPerYear`
    /// Values are a mean of input data
    let meansPerYear: [Float]
    
    /// Calculate means using the inverse of linear interpolation
    public init(_ data: ArraySlice<Float>, time: TimerangeDt, binsPerYear: Int = 12) {
        var sums = [Float](repeating: 0, count: binsPerYear)
        var weights = [Float](repeating: 0, count: binsPerYear)
        for (t, v) in zip(time, data) {
            let monthBin = t.secondInAverageYear / (Timestamp.secondsPerAverageYear / binsPerYear)
            let fraction = Float(t.secondInAverageYear).truncatingRemainder(dividingBy: Float(Timestamp.secondsPerAverageYear / binsPerYear)) / Float(Timestamp.secondsPerAverageYear / binsPerYear)
            let weighted = Interpolations.linearWeighted(value: v, fraction: fraction)
            sums[monthBin] += weighted.a
            weights[monthBin] += weighted.weightA
            sums[(monthBin+1) % binsPerYear] += weighted.b
            weights[(monthBin+1) % binsPerYear] += weighted.weightB
        }
        self.meansPerYear = zip(weights, sums).map({ $0.0 <= 0.001 ? .nan : $0.1 / $0.0 })
    }
    
    func applyOffset(on data: inout [Float], otherWeights: BiasCorrectionSeasonalLinear, time: TimerangeDt, type: QuantileDeltaMappingBiasCorrection.ChangeType, indices: Range<Int>? = nil) {
        let indices = indices ?? data.indices
        let binsPerYear = meansPerYear.count
        assert(time.count == indices.count)
        for (i ,t) in zip(indices, time) {
            let monthBin = t.secondInAverageYear / (Timestamp.secondsPerAverageYear / binsPerYear)
            let fraction = Float(t.secondInAverageYear).truncatingRemainder(dividingBy: Float(Timestamp.secondsPerAverageYear / binsPerYear)) / Float(Timestamp.secondsPerAverageYear / binsPerYear)
            let m = Interpolations.linear(a: meansPerYear[monthBin], b: meansPerYear[(monthBin+1) % binsPerYear], fraction: fraction)
            let o = Interpolations.linear(a: otherWeights.meansPerYear[monthBin], b: otherWeights.meansPerYear[(monthBin+1) % binsPerYear], fraction: fraction)
            switch type {
            case .absoluteChage:
                data[i] += m - o
            case .relativeChange:
                data[i] *= m / o
            }
        }
    }
}

/// Calculate and/or apply a linear bias correction to correct a fixed offset
/// Deltas are calculated for each month individually and use linear interpolation
struct BiasCorrectionSeasonalHermite {
    /// Could be one mean value for each month. Depends on `binsPerYear`
    /// Values are a mean of input data
    let meansPerYear: [Float]
    
    /// Calculate means using the inverse of linear interpolation
    public init(_ data: ArraySlice<Float>, time: TimerangeDt, binsPerYear: Int = 12) {
        var sums = [Double](repeating: 0, count: binsPerYear)
        var weights = [Double](repeating: 0, count: binsPerYear)
        for (t, v) in zip(time, data) {
            let monthBin = t.secondInAverageYear / (Timestamp.secondsPerAverageYear / binsPerYear)
            let fraction = Float(t.secondInAverageYear).truncatingRemainder(dividingBy: Float(Timestamp.secondsPerAverageYear / binsPerYear)) / Float(Timestamp.secondsPerAverageYear / binsPerYear)
            let weighted = Interpolations.hermiteWeighted(value: v, fraction: fraction)
            sums[(monthBin-1+binsPerYear) % binsPerYear] += Double(weighted.a)
            weights[(monthBin-1+binsPerYear) % binsPerYear] +=  Double(weighted.weightA)
            sums[monthBin] +=  Double(weighted.b)
            weights[monthBin] +=  Double(weighted.weightB)
            sums[(monthBin+1) % binsPerYear] +=  Double(weighted.c)
            weights[(monthBin+1) % binsPerYear] +=  Double(weighted.weightC)
            sums[(monthBin+2) % binsPerYear] +=  Double(weighted.d)
            weights[(monthBin+2) % binsPerYear] +=  Double(weighted.weightD)

        }
        self.meansPerYear = zip(weights, sums).map({ $0.0 <= 0.001 ? .nan : Float($0.1 / $0.0) })
    }
    
    func applyOffset(on data: inout [Float], otherWeights: BiasCorrectionSeasonalHermite, time: TimerangeDt, type: QuantileDeltaMappingBiasCorrection.ChangeType, indices: Range<Int>? = nil) {
        let indices = indices ?? data.indices
        let binsPerYear = meansPerYear.count
        assert(time.count == indices.count)
        for (i ,t) in zip(indices, time) {
            let monthBin = t.secondInAverageYear / (Timestamp.secondsPerAverageYear / binsPerYear)
            let fraction = Float(t.secondInAverageYear).truncatingRemainder(dividingBy: Float(Timestamp.secondsPerAverageYear / binsPerYear)) / Float(Timestamp.secondsPerAverageYear / binsPerYear)
            let m = Interpolations.hermite(
                A: meansPerYear[(monthBin-1+binsPerYear) % binsPerYear],
                B: meansPerYear[monthBin],
                C: meansPerYear[(monthBin+1) % binsPerYear],
                D: meansPerYear[(monthBin+2) % binsPerYear],
                fraction: fraction
            )
            let o = Interpolations.hermite(
                A: otherWeights.meansPerYear[(monthBin-1+binsPerYear) % binsPerYear],
                B: otherWeights.meansPerYear[monthBin],
                C: otherWeights.meansPerYear[(monthBin+1) % binsPerYear],
                D: otherWeights.meansPerYear[(monthBin+2) % binsPerYear],
                fraction: fraction
            )
            switch type {
            case .absoluteChage:
                data[i] += m - o
            case .relativeChange:
                data[i] *= m / o
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
    
    static var nMonths: Int { 12 / monthsToAggregate }
    
    /// How many months to aggregate per year
    static var monthsToAggregate: Int { 3 }
    
    var nBins: Int {
        cdf.count / Self.monthsToAggregate
    }
    
    /// input temperature and time axis
    init<T: Sequence>(vector: T, time: TimerangeDt, bins: Bins) where T.Element == Float {
        let count = bins.nQuantiles
        var cdf = [Float](repeating: 0, count: count * Self.monthsToAggregate)
        for (t, value) in zip(time, vector) {
            let monthBin = t.secondInAverageYear / (Timestamp.secondsPerAverageYear / Self.monthsToAggregate)
            let fraction = Float(t.secondInAverageYear).truncatingRemainder(dividingBy: Float(Timestamp.secondsPerAverageYear / Self.monthsToAggregate)) / Float(Timestamp.secondsPerAverageYear / Self.monthsToAggregate)
            for (i, bin) in bins.enumerated().reversed() {
                if value >= bin && value < bins[i+1] {
                    // value exactly inside a bin, adjust weight
                    let interBinFraction = (bins[i+1]-value)/(bins[i+1]-bin)
                    let weigthted = Interpolations.linearWeighted(value: fraction, fraction: interBinFraction)
                    assert(interBinFraction >= 0 && interBinFraction <= 1)
                    cdf[monthBin * count + i] += weigthted.a
                    cdf[((monthBin+1) % Self.monthsToAggregate) * count + i] += weigthted.b
                } else if value < bin {
                    cdf[monthBin * count + i] += 1-fraction
                    cdf[((monthBin+1) % Self.monthsToAggregate) * count + i] += fraction
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
        let monthBin = t.secondInAverageYear / (Timestamp.secondsPerAverageYear / Self.monthsToAggregate)
        let fraction = Float(t.secondInAverageYear).truncatingRemainder(dividingBy: Float(Timestamp.secondsPerAverageYear / Self.monthsToAggregate)) / Float(Timestamp.secondsPerAverageYear / Self.monthsToAggregate)
        
        let binLength = cdf.count / Self.monthsToAggregate
        return Interpolations.linear(a: cdf[binLength * monthBin + bin], b: cdf[binLength * ((monthBin+1) % Self.monthsToAggregate) + bin], fraction: fraction)
    }
}

/// Calculate CDF sliding over 3 months and sliding 10 years
struct CdfMonthly10YearSliding: MonthlyBinable {
    let cdf: [Float]
    var nBins: Int { bins.nQuantiles }
    let yearMin: Int
    let nYears: Int
    let bins: Bins
    
    static var nMonths: Int { 12 / monthsToAggregate }
    
    /// How many months to aggregate per year
    static var monthsToAggregate: Int { 3 }
    
    /// How many years to aggreate
    static var yearsToAggregate: Int { 10 }
    
    /// input temperature and time axis
    init(vector: ArraySlice<Float>, time: TimerangeDt, bins: Bins) {
        //print(time.prettyString())
        self.yearMin = Int(round(Float(time.range.lowerBound.timeIntervalSince1970) / Float(Timestamp.secondsPerAverageYear)))
        let yearMax = Int(round(Float(time.range.upperBound.timeIntervalSince1970) / Float(Timestamp.secondsPerAverageYear)))
        
        let nYears = (yearMax - yearMin + 1) / Self.yearsToAggregate
        //print("n Years \(nYears) yearMin=\(years.lowerBound) yearMax=\(years.upperBound)")
        
        let nQuantiles = bins.nQuantiles
        var cdf = Array3D(repeating: 0, dim0: nYears, dim1: Self.nMonths, dim2: nQuantiles)
        for (t, value) in zip(time, vector) {
            let monthBin = t.secondInAverageYear / (Timestamp.secondsPerAverageYear / Self.nMonths)
            let monthFraction = Float(t.secondInAverageYear).truncatingRemainder(dividingBy: Float(Timestamp.secondsPerAverageYear / Self.nMonths)) / Float(Timestamp.secondsPerAverageYear / Self.nMonths)
            
            //let fractionalYear = Float(t.timeIntervalSince1970 / 3600) / (24 * 365.25 * Float(Self.yearsPerBin)) - Float(yearMin)
            let fractionalYear = (Float(t.timeIntervalSince1970) / Float(Timestamp.secondsPerAverageYear) - Float(yearMin) - Float(Self.yearsToAggregate)/2) / Float(Self.yearsToAggregate)
            let yearFraction = fractionalYear - floor(fractionalYear)
            let yearBin = Int(floor(fractionalYear))
            
            for (i, bin) in bins.enumerated().reversed() {
                let binFraction = value < bin ? 1 : (bins[i+1]-value)/(bins[i+1]-bin)
                assert(binFraction >= -0.0001 && binFraction <= 1.0001)
                
                if yearBin >= 0 {
                    cdf[yearBin, monthBin, i] += (1-yearFraction) * (1-monthFraction) * binFraction
                    cdf[yearBin, (monthBin+1) % Self.nMonths, i] += (1-yearFraction) * monthFraction * binFraction
                }
                if yearBin < nYears-1 {
                    cdf[yearBin+1, monthBin, i] += yearFraction * (1-monthFraction) * binFraction
                    cdf[yearBin+1, (monthBin+1) % Self.nMonths, i] += yearFraction * monthFraction * binFraction
                }
                
                if value >= bin {
                    break
                }
            }
        }
        /// normalise to 1
        for y in 0..<nYears {
            for m in 0..<Self.nMonths {
                // last value is always count... could also scale to something between bin min/max to make it compressible more easily
                let count = cdf[y, m, nQuantiles-1]
                for b in 0..<nQuantiles-1 {
                    cdf[y, m, b] /= count
                }
            }
        }
        self.cdf = cdf.data
        self.bins = bins
        self.nYears = nYears
    }
    
    /// linear interpolate between 2 months CDF
    func get(bin: Int, time t: Timestamp) -> Float {
        let monthBin = t.secondInAverageYear / (Timestamp.secondsPerAverageYear / Self.nMonths)
        let fraction = Float(t.secondInAverageYear).truncatingRemainder(dividingBy: Float(Timestamp.secondsPerAverageYear / Self.nMonths)) / Float(Timestamp.secondsPerAverageYear / Self.nMonths)
        
        let fractionalYear = (Float(t.timeIntervalSince1970) / Float(Timestamp.secondsPerAverageYear) - Float(yearMin) - Float(Self.yearsToAggregate)/2) / Float(Self.yearsToAggregate)
        let yearFraction = fractionalYear - floor(fractionalYear)
        let yearBin = Int(floor(fractionalYear))
        
        if yearBin < 0 {
            return Interpolations.linear(
                a: cdf[nBins * monthBin + bin],
                b: cdf[nBins * ((monthBin+1) % Self.nMonths) + bin],
                fraction: fraction
            )
        }
        if yearBin >= nYears-1 {
            return Interpolations.linear(
                a: cdf[nBins * Self.nMonths * (nYears-1) + nBins * monthBin + bin],
                b: cdf[nBins * Self.nMonths * (nYears-1) + nBins * ((monthBin+1) % Self.nMonths) + bin],
                fraction: fraction
            )
        }
        
        return Interpolations.linear(
            a: Interpolations.linear(
                a: cdf[nBins * Self.nMonths * yearBin + nBins * monthBin + bin],
                b: cdf[nBins * Self.nMonths * (yearBin+1) + nBins * monthBin + bin],
                fraction: yearFraction),
            b: Interpolations.linear(
                a: cdf[nBins * Self.nMonths * yearBin + nBins * ((monthBin+1) % Self.nMonths) + bin],
                b: cdf[nBins * Self.nMonths * (yearBin+1) + nBins * ((monthBin+1) % Self.nMonths) + bin],
                fraction: yearFraction),
            fraction: fraction
        )
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

struct Interpolations {
    @inlinable static func linear(a: Float, b: Float, fraction: Float) -> Float {
        return a * (1-fraction) + b * fraction
    }
    
    @inlinable static func linearWeighted(value: Float, fraction: Float) -> (a: Float, b: Float, weightA: Float, weightB: Float) {
        return (value * (1-fraction), value * fraction, (1-fraction), fraction)
    }
    
    // Hermite interpolate between point B and C
    @inlinable static func hermite(A: Float, B: Float, C: Float, D: Float, fraction: Float) -> Float {
        let a = -A/2.0 + (3.0*B)/2.0 - (3.0*C)/2.0 + D/2.0
        let b = A - (5.0*B)/2.0 + 2.0*C - D / 2.0
        let c = -A/2.0 + C/2.0
        let d = B
        return a*fraction*fraction*fraction + b*fraction*fraction + c*fraction + d
    }
    
    @inlinable static func hermiteWeighted(value: Float, fraction: Float) -> (a: Float, b: Float, c: Float, d: Float, weightA: Float, weightB: Float, weightC: Float, weightD: Float) {
        return (value*fraction*fraction*fraction, value*fraction*fraction, value*fraction, value, fraction*fraction*fraction, fraction*fraction, fraction, 1)
    }
}
