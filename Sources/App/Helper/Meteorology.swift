import Foundation
import CHelper


struct Meteorology {
    /// Calculate windspeed from u/v components
    @inlinable static func windspeed(u: Float, v: Float) -> Float {
        return sqrt(u * u + v * v)
    }
    
    /// Calculate wind direction in degrees
    //@inlinable static func windirection(u: Float, v: Float) -> Float {
    //    return atan2(u, v).radiansToDegrees + 180
    //}
    
    /// Calculate wind direction in degrees
    @inlinable static func windirectionFast(u: [Float], v: [Float]) -> [Float] {
        precondition(u.count == v.count)
        return [Float](unsafeUninitializedCapacity: u.count) { buffer, initializedCount in
            CHelper.windirectionFast(u.count, u, v, buffer.baseAddress)
            initializedCount += u.count
        }
    }
    
    /// Calculate evapotranspiration
    @inlinable static func evapotranspiration(latentHeatFlux: Float) -> Float {
        return max(0, latentHeatFlux * -3600 / 2.5e6)
    }
    
    /// Calculate surface pressure, corrected by temperature.
    static func surfacePressure(temperature: [Float], pressure: [Float], elevation: Float) -> [Float] {
        precondition(temperature.count == pressure.count)
        
        return zip(temperature, pressure).map { (t, p) -> Float in
            /// Sea level temperature in kelvin
            let t0 = (t + 273.15 + 0.0065 * elevation)
            // https://physics.stackexchange.com/questions/14678/pressure-at-a-given-altitude
            // exponent = (g*M/r*L) = (9.80665 * 0.0289644) / (8.31447 * 0.0065)
            let factor = powf(1 - (0.0065 * elevation) / t0, -5.25578129287)
            return p / factor
        }
    }
    
    /// Calculate mea nsea level pressure, corrected by temperature.
    static func sealevelPressure(temperature: [Float], pressure: [Float], elevation: Float) -> [Float] {
        precondition(temperature.count == pressure.count)
        
        return zip(temperature, pressure).map { (t, p) -> Float in
            return p * Meteorology.sealevelPressureFactor(temperature: t, elevation: elevation)
        }
    }
    
    /// Calculate mean sea level pressure, corrected by temperature.
    @inlinable static func sealevelPressureFactor(temperature: Float, elevation: Float) -> Float {
        let t0 = (temperature + 273.15 + 0.0065 * elevation)
        // https://physics.stackexchange.com/questions/14678/pressure-at-a-given-altitude
        // exponent = (g*M/r*L) = (9.80665 * 0.0289644) / (8.31447 * 0.0065)
        let factor = powf(1 - (0.0065 * elevation) / t0, -5.25578129287)
        return factor
    }
    
    /// Estimate total cloudcover from low, mid and high cloud cover
    static func cloudCoverTotal(low: [Float], mid: [Float], high: [Float]) -> [Float] {
        precondition(low.count == mid.count)
        precondition(low.count == high.count)

        var out = [Float]()
        out.reserveCapacity(low.count)
        for i in low.indices {
            out.append(min(low[i] * 0.9 + mid[i] * 0.6 + high[i] * 0.3, 100))
        }
        return out
    }
    
    /// Apparent temperature which combines the effects of humidity, solar radiation and wind on the feels-like temperature should be added. It is similar to the Wet-bulb globe temperature
    /// See https://github.com/open-meteo/open-meteo/issues/13
    /// Formular from https://calculator.academy/apparent-temperature-calculator/
    @inlinable static func apparentTemperature(temperature_2m: Float, relativehumidity_2m: Float, windspeed_10m: Float, shortware_radiation: Float) -> Float {
        let windspeed_2m = windspeed_10m * 0.75
        // humidity in hPa
        let e = relativehumidity_2m/100.0 * 6.105 * exp( 17.27 * temperature_2m / ( 237.7 + temperature_2m ) )
        // Radition absorbed by body
        let Q = max(0, 0.1*(shortware_radiation-550.0))
        let AT = temperature_2m + 0.348 * e - 0.70 * windspeed_2m + 0.70 * (Q/(windspeed_2m+10)) - 4.25
        return AT
    }
    
    /// Caclculate apparent temperature for an array
    @inlinable static func apparentTemperature(temperature_2m: [Float], relativehumidity_2m: [Float], windspeed_10m: [Float], shortware_radiation: [Float]) -> [Float] {
        precondition(temperature_2m.count == relativehumidity_2m.count)
        precondition(temperature_2m.count == windspeed_10m.count)
        precondition(temperature_2m.count == shortware_radiation.count)
        
        var out = [Float]()
        out.reserveCapacity(temperature_2m.count)
        for i in temperature_2m.indices {
            let at = Self.apparentTemperature(temperature_2m: temperature_2m[i], relativehumidity_2m: relativehumidity_2m[i], windspeed_10m: windspeed_10m[i], shortware_radiation: shortware_radiation[i])
            out.append(at)
        }
        return out
    }

    /// Calculate vapor pressure deficit from temperature and dewpoint in celesius. Returns kiloPascal (kPa)
    @inlinable static public func vaporPressureDeficit(temperature2mCelsius: Float, dewpointCelsius: Float) -> Float {
        /// saturation vapor pressure at air temperature Thr. (kPa)
        let esat = 0.6108 * exp((17.27 * temperature2mCelsius) / (temperature2mCelsius + 237.3))
        
        /// actual vapour pressure [kPa]
        let ea = 0.6108 * exp((17.27 * dewpointCelsius) / (dewpointCelsius + 237.3))
        
        /// just in case dewpoint is larger than temperature
        return max(esat-ea, 0)
    }
    
    /// Factor that need to be applied to scale wind from onee level to another
    /// http://www.fao.org/3/x0490e/x0490e07.htm
    public static func scaleWindFactor(from: Float, to: Float) -> Float {
        let factorFrom = 4.87/(log(67.8*from-5.42))
        let factorTo = 4.87/(log(67.8*to-5.42))
        return factorFrom / factorTo
    }
    
    /// Calculate relative humidity from temperature and dewpoint
    /// See https://www.omnicalculator.com/physics/relative-humidity
    @inlinable public static func relativeHumidity(temperature: Float, dewpoint: Float) -> Float {
        let β = Float(17.625)
        let λ = Float(243.04)
        return 100 * exp((β * dewpoint) / (λ + dewpoint)) / exp((β * temperature) / (λ + temperature))
    }
    
    /// Calculate relative humidity. All variables should be on the same level
    /// https://cran.r-project.org/web/packages/humidity/vignettes/humidity-measures.html
    /// humudity in g/kg, temperature in celsius, pressure in hPa
    public static func specificToRelativeHumidity(specificHumidity: [Float], temperature: [Float], pressure: [Float]) -> [Float] {
        return zip(temperature, zip(specificHumidity, pressure)).map {
            let (temp, (qair, press)) = $0
            
            let β = Float(17.625)
            let λ = Float(243.04)
            
            /// saturation vapor pressure at air temperature Thr. (kPa)
            let es = 6.112 * exp((β * temp)/(temp + λ))
            let e = qair / 1000 * press * 100 / (0.378 * qair / 1000 + 0.622)
            let rh = e / es
            return max(min(rh,100),0)
        }
    }
}
