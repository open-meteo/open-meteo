import Foundation

/// European Air Quality index: https://www.euronews.com/weather/copernicus-air-quality-index
struct AirQuality {
    @inlinable static func europeanIndex(no2: Float) -> Float {
        switch no2 {
        case 0..<50: return no2 / 2
        case 50..<100: return no2 / 2
        case 100..<200: return 25 + no2 / 4
        case 200...400: return 50 + no2 / 8
        case 400...: return 50 + no2 / 8
        default: return .nan
        }
    }
    
    @inlinable static func europeanIndex(pm10: Float) -> Float {
        switch pm10 {
        case 0..<25: return pm10
        case 25..<50: return pm10
        case 50..<90: return pm10.piecewiseLinear(from: 50..<90, to: 50..<75)
        case 90..<180: fallthrough
        case 180...: return pm10.piecewiseLinear(from: 90..<180, to: 75..<100)
        default: return .nan
        }
    }
    
    @inlinable static func europeanIndex(pm2_5: Float) -> Float {
        switch pm2_5 {
        case 0..<15: return pm2_5.piecewiseLinear(from: 0..<15, to: 0..<25)
        case 15..<30: return pm2_5.piecewiseLinear(from: 15..<30, to: 25..<50)
        case 30..<55: return pm2_5.piecewiseLinear(from: 30..<55, to: 50..<75)
        case 55..<110: fallthrough
        case 110...: return pm2_5.piecewiseLinear(from: 55..<110, to: 75..<100)
        default: return .nan
        }
    }
    
    @inlinable static func europeanIndex(o3: Float) -> Float {
        switch o3 {
        case 0..<60: return o3.piecewiseLinear(from: 0..<60, to: 0..<25)
        case 60..<120: return o3.piecewiseLinear(from: 60..<120, to: 25..<50)
        case 120..<180: return o3.piecewiseLinear(from: 120..<180, to: 50..<75)
        case 180..<240: fallthrough
        case 240...: return o3.piecewiseLinear(from: 180..<240, to: 75..<100)
        default: return .nan
        }
    }
    
    @inlinable static func europeanIndex(pm2_5: Float, pm10: Float, no2: Float, o3: Float, so2: Float, co: Float) -> Float {
        
        fatalError()
    }
}

extension Float {
    @inlinable func piecewiseLinear(from: Range<Float>, to: Range<Float>) -> Float {
        let dOld = from.upperBound-from.lowerBound
        let dNew = to.upperBound-to.lowerBound
        return to.lowerBound + (self - from.lowerBound) * dNew / dOld
    }
}
