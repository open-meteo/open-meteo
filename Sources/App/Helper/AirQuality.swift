import Foundation

/// European Air Quality index: https://www.eea.europa.eu/themes/air/air-quality-index in the right legend press "About the European Air Quality Index"
struct EuropeanAirQuality {
    static let no2HourlyThresholds: [Float] = [0, 40, 90, 120, 230, 340]
    static let o3HourlyThresholds: [Float] = [0, 50, 100, 130, 240, 380]
    static let so2HourlyThresholds: [Float] = [0, 100, 200, 350, 500, 750]
    static let pm2_5_24HourlyMeanThresholds: [Float] = [0, 10, 20, 25, 50, 75]
    static let pm10_24HourlyMeanThresholds: [Float] = [0, 20, 40, 50, 100, 150]
    
    /// Accept hourly values
    @inlinable static func indexNo2(no2: Float) -> Float {
        return no2HourlyThresholds.positionExtrapolated(of: no2) * 20
    }
    
    /// Accept hourly values
    @inlinable static func indexO3(o3: Float) -> Float {
        return o3HourlyThresholds.positionExtrapolated(of: o3) * 20
    }
    
    /// Accept hourly values
    @inlinable static func indexSo2(so2: Float) -> Float {
        return so2HourlyThresholds.positionExtrapolated(of: so2) * 20
    }
    
    /// Accept 24h running mean
    @inlinable static func indexPm10(pm10_24h_mean: Float) -> Float {
        return pm10_24HourlyMeanThresholds.positionExtrapolated(of: pm10_24h_mean) * 20
    }
    
    /// Accept 24h running mean
    @inlinable static func indexPm2_5(pm2_5_24h_mean: Float) -> Float {
        return pm2_5_24HourlyMeanThresholds.positionExtrapolated(of: pm2_5_24h_mean) * 20
    }
}

/// https://en.wikipedia.org/wiki/Air_quality_index#United_States
struct UnitedStatesAirQuality {
    static let o3_HourlyThresholds: [Float] = [.nan , .nan, 125, 165, 205, 405, 505, 605]
    static let o3_8HourlyThresholds: [Float] = [0, 55, 70, 85, 105, 200, .nan, .nan]
    
    static let pm2_5_24HourlyMeanThresholds: [Float] = [0, 12, 35.5, 55.5, 150.5, 250.5, 350.1, 500.5]
    static let pm10_24HourlyMeanThresholds: [Float] = [0, 55, 155, 255, 355, 425, 505, 605]
    
    static let co_8HourlyThresholds: [Float] = [0, 4.5, 9.5, 12.5, 15.5, 30.5, 40.5, 50.5]
    
    static let so2_HourlyThresholds: [Float] = [0, 35, 75, 185, 305, .nan, .nan, .nan]
    static let so2_24HourlyThresholds: [Float] = [.nan, .nan, .nan, .nan, 305, 605, 805, 1005]
    
    static let no2_HourlyThresholds: [Float] = [0, 54, 100, 360, 650, 1250, 1650, 2050]
    
    /// Scale class value 0...7 to AQI index 0...500
    @inlinable static func scale(_ val: Float) -> Float {
        return val <= 4 ? (val*50) : (val*100 - 200)
    }
    
    /// Accept hourly values
    @inlinable static func indexNo2(no2: Float) -> Float {
        return scale(no2_HourlyThresholds.positionExtrapolated(of: no2))
    }
    
    /// Accept 8h avg
    @inlinable static func indexCo(co_8h_mean: Float) -> Float {
        return scale(co_8HourlyThresholds.positionExtrapolated(of: co_8h_mean))
    }
    
    /// Accept hourly values and 8h avg
    @inlinable static func indexO3(o3: Float, o3_8h_mean: Float) -> Float {
        let x1 = o3_HourlyThresholds.positionExtrapolated(of: o3)
        let x2 = o3_8HourlyThresholds.positionExtrapolated(of: o3_8h_mean)
        if x1.isNaN {
            return scale(x2)
        }
        if x2.isNaN {
            return scale(x1)
        }
        return scale(max(x1, x2))
    }
    
    /// Accept hourly values and 24h avg
    @inlinable static func indexSo2(so2: Float, so2_24h_mean: Float) -> Float {
        let x1 = so2_HourlyThresholds.positionExtrapolated(of: so2)
        let x2 = so2_24HourlyThresholds.positionExtrapolated(of: so2_24h_mean)
        return x1.isNaN ? scale(x2) : scale(x1)
    }
    
    /// Accept 24h running mean
    @inlinable static func indexPm10(pm10_24h_mean: Float) -> Float {
        return scale(pm10_24HourlyMeanThresholds.positionExtrapolated(of: pm10_24h_mean))
    }
    
    /// Accept 24h running mean
    @inlinable static func indexPm2_5(pm2_5_24h_mean: Float) -> Float {
        return scale(pm2_5_24HourlyMeanThresholds.positionExtrapolated(of: pm2_5_24h_mean))
    }
}

extension Array where Element == Float {
    // Find the postion in an array and return a linear interpolated position in case it is between 2 values
    // If the search values is larger then the maximum, an extrapolated value will be returned
    fileprivate func positionExtrapolated(of search: Float) -> Float {
        var previous = Float.nan
        var slope = Float.nan
        for (i, value) in self.enumerated() {
            slope = (value - previous)
            if search < value {
                return Float(i-1) + (search - previous) / slope
            }
            previous = value
        }
        return Float(count-1) + (search - previous) / slope
    }
}
