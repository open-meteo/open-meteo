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
