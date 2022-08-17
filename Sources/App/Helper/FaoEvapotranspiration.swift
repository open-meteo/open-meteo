import Foundation


extension Meteorology {
    static public let boltzmanConstant = Float(0.20429166e-9)
    
    /// Watt per square meter
    static public let solarConstant = Float(1367.7)
    
    /// Watt per square meter
    public static func extraTerrestrialRadiationBackwards(latitude: Float, longitude: Float, timerange: TimerangeDt) -> [Float] {
        // compute hourly mean radiation flux
        return Zensun.calculateRadiationBackwardsAveraged(grid: RegularGrid(nx: 1, ny: 1, latMin: latitude, lonMin: longitude, dx: 1, dy: 1), timerange: timerange).data.map {
            $0 * solarConstant
        }
    }
    
    public static func extraTerrestrialRadiationInstant(latitude: Float, longitude: Float, timerange: TimerangeDt) -> [Float] {
        // compute hourly mean radiation flux
        return Zensun.calculateRadiationInstant(grid: RegularGrid(nx: 1, ny: 1, latMin: latitude, lonMin: longitude, dx: 1, dy: 1), timerange: timerange).map {
            max($0 * solarConstant, 0)
        }
    }

    /// FAO et0 calculation based on https://marais.ch/doc/fao56.pdf
    public static func et0Evapotranspiration(temperature2mCelsius: Float, windspeed10mMeterPerSecond: Float, dewpointCelsius: Float, shortwaveRadiationWatts: Float, elevation: Float, extraTerrestrialRadiation: Float, dtSeconds: Int) -> Float {
        
        let Rs = shortwaveRadiationWatts
                
        let windspeed2m = scaleWindFactor(from: 10, to: 2) * windspeed10mMeterPerSecond

        /// Slope of saturation vapour pressure curve at air temperature T [kPa °C-1], (Page 37)
        let β = Float(17.27) // Actaually 17.625 is now recommended. FAO uses the old one.
        let λ = Float(237.3) // 243.04 new recommendation
        let vaporPressurCurveSlope = 4098 * (0.6108 * exp(β * temperature2mCelsius / (temperature2mCelsius + λ))) / powf((temperature2mCelsius + λ), 2)
        
        /// Air pressure in kPa. Evaporation at high altitudes is promoted due to low atmospheric pressure as expressed in the psychrometric constant. The effect is, however, small and in the calculation procedures, the average value for a location is sufficient.
        let simplifiedAtmosphericPressure = 101.3 * powf((293 - 0.0065 * elevation)/293.0, 5.26)

        /// psychrometric constant [kPa °C-1], (Equation 8)
        let γ = 0.000665 * simplifiedAtmosphericPressure
        
        /// saturation vapor pressure at air temperature Thr. (kPa)
        let esat = 0.6108 * exp((β * temperature2mCelsius) / (temperature2mCelsius + λ))
        
        /// actual vapour pressure [kPa], (Page 37)
        let ea = 0.6108 * exp((β * dewpointCelsius) / (dewpointCelsius + λ))
        
        let vaporPressureDeficit = esat-ea

        /// 0.23 is defined by FAO for albedo
        let albedo = Float(0.23)
        
        /// net solar or shortwave radiation [MJ m-2 day-1], (Page 51)
        let Rns = Rs * (1-albedo) * 0.0864/24
        
        /// clear-sky solar radiation [MJ m-2 day-1] approximated, (Page 51)
        let Rso = (0.75 + 0.00002 * elevation) * extraTerrestrialRadiation
        
        let relativeHumidity = relativeHumidity(temperature: temperature2mCelsius, dewpoint: dewpointCelsius)
        
        /// As a more approximate alternative, one can assume Rs/Rso = 0.4 to 0.6 during nighttime periods in humid and subhumid climates and Rs/Rso = 0.7 to 0.8 in arid and semiarid climates. (Page 75)
        let RrelAproximation = 0.4 + relativeHumidity / 100 * 0.4
        
        /// relative shortwave radiation (limited to ≤ 1.0
        let Rrel = extraTerrestrialRadiation <= 0 ? RrelAproximation : min(Rs/Rso, 1)

        /// net outgoing longwave radiation [MJ m-2 day-1]
        let Rnl = boltzmanConstant * powf(temperature2mCelsius + 273.16, 4) * (0.34 - 0.14 * sqrt(ea)) * (1.35 * Rrel - 0.35)

        // radiation balance
        let Rn = Rns-Rnl

        /// soil heat flux [MJ m-2 day-1], During night, calculation is different
        let Ghr = (Rs <= 0) ? 0.5 * Rn : 0.1 * Rn

        // evapotranspiration
        let et0 = (0.408 * vaporPressurCurveSlope * (Rn-Ghr) + γ *  (37.0 / (temperature2mCelsius + 273)) * windspeed2m * vaporPressureDeficit) / (vaporPressurCurveSlope + γ * (1+0.34*windspeed2m))

        return max(et0 * Float(dtSeconds / 3600), 0)
    }

}
