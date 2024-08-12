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
        precondition(u.count == v.count, "Invalid array dimensions u\(u.count) \(v.count)")
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
        let elevation =  elevation.isNaN ? 0 : elevation
        
        return zip(temperature, pressure).map { (t, p) -> Float in
            /// Sea level temperature in kelvin
            let t0 = (t + 273.15 + 0.0065 * elevation)
            // https://physics.stackexchange.com/questions/14678/pressure-at-a-given-altitude
            // exponent = (g*M/r*L) = (9.80665 * 0.0289644) / (8.31447 * 0.0065)
            let factor = powf(1 - (0.0065 * elevation) / t0, -5.25578129287)
            return p / factor
        }
    }
    
    /// Estimate elevation from sea and surface level pressure
    /// Psurf = Psea / ((1 - (0.0065 * h) / (t + 273.15 + 0.0065 * h))^ -5.25578129287)
    /// h = (153.846 (t (-(Psurf/Psea)^0.1902666690786014) - 273.15 (Psurf/Psea)^0.1902666690786014 + t + 273.15))/(Psurf/Psea)^0.1902666690786014
    static func elevation(sealevelPressure psea: Float, surfacePressure psurf: Float, temperature_2m t: Float) -> Float {
        let r = powf(psurf/psea, 0.1902666690786014)
        return (153.846 * (t * (-1 * r) - 273.15 * r + t + 273.15))/r
    }
    
    /// Estimate elevation from sea and surface level pressure
    /// Psurf = Psea / ((1 - (0.0065 * h) / (t + 273.15 + 0.0065 * h))^ -5.25578129287)
    /// h = (153.846 (t (-(Psurf/Psea)^0.1902666690786014) - 273.15 (Psurf/Psea)^0.1902666690786014 + t + 273.15))/(Psurf/Psea)^0.1902666690786014
    static func elevation(sealevelPressure: [Float], surfacePressure: [Float], temperature_2m: [Float]) -> [Float] {
        return zip(sealevelPressure, zip(surfacePressure, temperature_2m)).map({elevation(sealevelPressure: $0, surfacePressure: $1.0, temperature_2m: $1.1)})
    }
    
    /// Calculate wind component from speed and direction
    @inlinable static func uWind(speed: Float, directionDegree: Float) -> Float {
        return -1 * speed * sin(directionDegree.degreesToRadians)
    }
    
    /// Calculate wind component from speed and direction
    @inlinable static func vWind(speed: Float, directionDegree: Float) -> Float {
        return -1 * speed * cos(directionDegree.degreesToRadians)
    }
    
    /// Calculate mean sea level pressure, corrected by temperature.
    static func sealevelPressure(temperature: [Float], pressure: [Float], elevation: Float) -> [Float] {
        precondition(temperature.count == pressure.count)
        
        return zip(temperature, pressure).map { (t, p) -> Float in
            return p * Meteorology.sealevelPressureFactor(temperature: t, elevation: elevation)
        }
    }
    
    /// Calculate mean sea level pressure, corrected by temperature for an entire field
    static func sealevelPressureSpatial(temperature: [Float], pressure: [Float], elevation: [Float]) -> [Float] {
        return zip(elevation, zip(temperature, pressure)).map {
            let (elevation, (t, p)) = $0
            let e = elevation <= -999 ? 0 : elevation
            return p * Meteorology.sealevelPressureFactor(temperature: t, elevation: e)
        }
    }
    
    /// Calculate mea nsea level pressure, corrected by temperature.
    static func sealevelPressure(temperature2m: Array2DFastTime, surfacePressure: Array2DFastTime, elevation: [Float]) -> [Float] {
        return zip(temperature2m.data, surfacePressure.data).enumerated().map { (i, arg1) -> Float in
            let (t, p) = arg1
            let elevation = elevation[i % temperature2m.nTime]
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
    @inlinable static func apparentTemperature(temperature_2m: Float, relativehumidity_2m: Float, windspeed_10m: Float, shortwave_radiation: Float?) -> Float {
        let windspeed_2m = windspeed_10m * 0.75
        // humidity in hPa
        let e = relativehumidity_2m/100.0 * 6.105 * exp( 17.27 * temperature_2m / ( 237.7 + temperature_2m ) )
        // Radition absorbed by body
        let Q = max(0, 0.1*((shortwave_radiation ?? 550) - 550.0))
        let AT = temperature_2m + 0.348 * e - 0.70 * windspeed_2m + 0.70 * (Q/(windspeed_2m+10)) - 4.25
        return AT
    }
    
    /// Caclculate apparent temperature for an array
    @inlinable static func apparentTemperature(temperature_2m: [Float], relativehumidity_2m: [Float], windspeed_10m: [Float], shortwave_radiation: [Float]?) -> [Float] {
        precondition(temperature_2m.count == relativehumidity_2m.count)
        precondition(temperature_2m.count == windspeed_10m.count)
        if let shortwave_radiation {
            precondition(temperature_2m.count == shortwave_radiation.count)
        }
        
        var out = [Float]()
        out.reserveCapacity(temperature_2m.count)
        for i in temperature_2m.indices {
            let at = Self.apparentTemperature(temperature_2m: temperature_2m[i], relativehumidity_2m: relativehumidity_2m[i], windspeed_10m: windspeed_10m[i], shortwave_radiation: shortwave_radiation?[i])
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
    
    /// Factor that need to be applied to scale wind from onee level to another. Only valid for altitude below 100 meters.
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
        return max(min(100 * exp((β * dewpoint) / (λ + dewpoint)) / exp((β * temperature) / (λ + temperature)), 100), 0)
    }
    
    /// Calculate relative dewpoint from humidity and temperature
    /// See https://www.omnicalculator.com/physics/relative-humidity
    @inlinable public static func dewpoint(temperature: Float, relativeHumidity: Float) -> Float {
        let β = Float(17.625)
        let λ = Float(243.04)
        return λ*(log(relativeHumidity/100)+((β*temperature)/(λ+temperature)))/(β-log(relativeHumidity/100)-((β*temperature)/(λ+temperature)))
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
    
    /// Calculate relative humidity and correct sea level pressure to surface pressure.
    public static func specificToRelativeHumidity(specificHumidity: Array2DFastTime, temperature: Array2DFastTime, sealLevelPressure: Array2DFastTime, elevation: [Float]) -> [Float] {
        
        return temperature.data.enumerated().map { (i, temp) in
            let asl = elevation[i % sealLevelPressure.nTime]
            let qair = specificHumidity.data[i]
            
            let asl0 = asl.isNaN ? 0 : asl
            /// Sea level temperature in kelvin
            let t0 = (temp + 273.15 + 0.0065 * asl0)
            let factor = powf(1 - (0.0065 * asl0) / t0, -5.25578129287)
            let press = sealLevelPressure.data[i] / factor
            
            
            let β = Float(17.625)
            let λ = Float(243.04)
            
            /// saturation vapor pressure at air temperature Thr. (kPa)
            let es = 6.112 * exp((β * temp)/(temp + λ))
            let e = qair / 1000 * press * 100 / (0.378 * qair / 1000 + 0.622)
            let rh = e / es
            return max(min(rh,100),0)
        }
    }
    
    /// Wetbulb temperature
    /// See https://www.omnicalculator.com/physics/wet-bulb
    public static func wetBulbTemperature(temperature t: Float, relativeHumidity rh: Float) -> Float {
        return t * atan(0.151977*pow(rh+8.313659,1/2))
        + atan(t+rh) - atan(rh-1.676331)
        + 0.00391838*pow(rh,3/2) * atan(0.023101*rh)
        - 4.686035
    }
    
    /// Convert pressure vertical velocity `omega` (Pa/s) to geometric vertical velocity `w` (m/s)
    /// See https://www.ncl.ucar.edu/Document/Functions/Contributed/omega_to_w.shtml
    /// Temperature in Celsius
    /// PressureLevel in hPa e.g. 1000
    public static func verticalVelocityPressureToGeometric(omega: [Float], temperature: [Float], pressureLevel: Float) -> [Float] {
        
        let p = pressureLevel * 100
        let rgas: Float = 287.058 // J/(kg-K) => m2/(s2 K)
        let g: Float    = 9.80665            // m/s2
        return zip(omega, temperature).map { (omega, temperature) in
            let t = temperature + 273.15
            let  rho  = p/(rgas*t)         // density => kg/m3
            let w    = -omega/(rho*g)     // array operation
            return w
        }
    }
    
    /// Calculate U and V wind vectors using the geostrophic approximation. Uses straight flow at the equator.
    public static func geostrophicWind(geopotentialHeightMeters gph: [Float], grid: RegularGrid) -> (u: [Float], v: [Float]) {
        precondition(grid.isGlobal, "Grid must be global to use circular differences")
        
        let g: Float = 9.80665
        let earth_radius: Float = 6371e3
        let nx = grid.nx
        let ny = grid.ny
        
        var gphSmooth = [Float](repeating: .nan, count: gph.count)
        for y in 0..<ny {
            for x in 0..<nx {
                gphSmooth[y * nx + x] = (
                      gph[((y + 0 + ny) % ny) * nx + (x + 2 + nx) % nx]
                    + gph[((y + 0 + ny) % ny) * nx + (x + 1 + nx) % nx]
                    + gph[((y + 0 + ny) % ny) * nx + (x + 0 + nx) % nx]
                    + gph[((y + 0 + ny) % ny) * nx + (x - 1 + nx) % nx]
                    + gph[((y + 0 + ny) % ny) * nx + (x - 2 + nx) % nx]
                    + gph[((y + 1 + ny) % ny) * nx + (x + 2 + nx) % nx]
                    + gph[((y + 1 + ny) % ny) * nx + (x + 1 + nx) % nx]
                    + gph[((y + 1 + ny) % ny) * nx + (x + 0 + nx) % nx]
                    + gph[((y + 1 + ny) % ny) * nx + (x - 1 + nx) % nx]
                    + gph[((y + 1 + ny) % ny) * nx + (x - 2 + nx) % nx]
                    + gph[((y + 2 + ny) % ny) * nx + (x + 2 + nx) % nx]
                    + gph[((y + 2 + ny) % ny) * nx + (x + 1 + nx) % nx]
                    + gph[((y + 2 + ny) % ny) * nx + (x + 0 + nx) % nx]
                    + gph[((y + 2 + ny) % ny) * nx + (x - 1 + nx) % nx]
                    + gph[((y + 2 + ny) % ny) * nx + (x - 2 + nx) % nx]
                    + gph[((y - 1 + ny) % ny) * nx + (x + 2 + nx) % nx]
                    + gph[((y - 1 + ny) % ny) * nx + (x + 1 + nx) % nx]
                    + gph[((y - 1 + ny) % ny) * nx + (x + 0 + nx) % nx]
                    + gph[((y - 1 + ny) % ny) * nx + (x - 1 + nx) % nx]
                    + gph[((y - 1 + ny) % ny) * nx + (x - 2 + nx) % nx]
                    + gph[((y - 2 + ny) % ny) * nx + (x + 2 + nx) % nx]
                    + gph[((y - 2 + ny) % ny) * nx + (x + 1 + nx) % nx]
                    + gph[((y - 2 + ny) % ny) * nx + (x + 0 + nx) % nx]
                    + gph[((y - 2 + ny) % ny) * nx + (x - 1 + nx) % nx]
                    + gph[((y - 2 + ny) % ny) * nx + (x - 2 + nx) % nx])/25
            }
        }
        
        var u = [Float](repeating: .nan, count: nx * ny)
        var v = [Float](repeating: .nan, count: nx * ny)
        for y in 0..<ny {
            let latitude = grid.getCoordinates(gridpoint: y * nx).latitude
            let f = 2 * 7.2921e-5 * sin(latitude.degreesToRadians)  // Coriolis parameter calculation
            
            for x in 0..<nx {
                let gridpoint = y * nx + x
                // calculate gph differences. Handles cyclic grids
                let z_diff_east = gphSmooth[y * nx + (x + 1) % nx] - gphSmooth[y * nx + (x - 1 + nx) % nx]
                let z_diff_north = gphSmooth[((y + 1) % ny) * nx + x] - gphSmooth[gridpoint]
                
                // Calculate grid spacing
                let dx = earth_radius * Float(grid.dx).degreesToRadians /* cos(latitude.degreesToRadians) */
                let dy = earth_radius * Float(grid.dy).degreesToRadians
                
                // geostrophic wind
                let uGeostropic = f == 0 ? 0 : -(g / (f * dx)) * (z_diff_north /*/ 2*/)
                let vGeostropic = f == 0 ? 0 : (g / (f * dy)) * ((z_diff_east /*/ 2*/) /*+ omega[gridpoint]*/)
                
                // straight wind at equator
                let uStraight = z_diff_north * g / 2
                let vStraight = -z_diff_east * g / 2
                
                // 0 = straight flow
                // 1 = geostropic flow
                let fraction = (Float(5)..<15).fraction(of: abs(latitude))
                u[gridpoint] = uGeostropic * fraction + uStraight * (1-fraction)
                v[gridpoint] = vGeostropic * fraction + vStraight * (1-fraction)
            }
        }
        return (u, v)

    }
    
    /// Calculate upper level clouds from relative humidity using Sundqvist et al. (1989):
    /// See https://www.ecmwf.int/sites/default/files/elibrary/2005/16958-parametrization-cloud-cover.pdf
    /// https://agupubs.onlinelibrary.wiley.com/doi/10.1029/2018MS001400  chapter 3.1
    @inlinable public static func relativeHumidityToCloudCover(relativeHumidity rh: Float, pressureHPa: Float) -> Float {
        let a1: Float = 0.7
        let a2: Float = 0.9
        let a3: Float = 4.0
        let pressureSurface: Float = 1013.25
        let rhCrit = a1 + (a2 - a1) * expf(1-powf(pressureSurface / pressureHPa, a3))
        return max(1 - sqrtf(max(1 - rh / 100, 0) / (1 - rhCrit)), 0) * 100
    }
    
    /// Approximate altitude in meters from pressure level in hPa
    @inlinable static func altitudeAboveSeaLevelMeters(pressureLevelHpA: Float) -> Float {
        return -1/2.25577 * 10e4 * (powf(pressureLevelHpA/1013.25, 1/5.25588) - 1)
    }
    
    /// Approximate pressure level from altitude
    @inlinable static func pressureLevelHpA(altitudeAboveSeaLevelMeters: Float) -> Float {
        return 1013.25 * powf(1 - 2.25577 * 10e-6 * altitudeAboveSeaLevelMeters, 5.25588)
    }
}
