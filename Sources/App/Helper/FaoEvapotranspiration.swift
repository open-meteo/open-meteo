import Foundation


extension Meteorology {
    static public let boltzmanConstant = Float(0.20429166e-9)
    
    enum MaxAndMinOrMean {
        case mean(mean: Float)
        case maxmin(max: Float, min: Float)
    }
    
    /// FAO et0 calculation based on https://marais.ch/doc/fao56.pdf
    public static func et0EvapotranspirationDaily(temperature2mCelsiusDailyMax: Float, temperature2mCelsiusDailyMin: Float, temperature2mCelsiusDailyMean: Float, windspeed10mMeterPerSecondMean: Float, shortwaveRadiationMJSum: Float, elevation: Float, extraTerrestrialRadiationSum: Float, relativeHumidity: MaxAndMinOrMean) -> Float {
        
        /// short wave radiaton or use Hargreaves’ radiation formula (Page 60)
        let Rs = shortwaveRadiationMJSum.isNaN ? 0.16 * sqrtf(temperature2mCelsiusDailyMax - temperature2mCelsiusDailyMin) * extraTerrestrialRadiationSum : shortwaveRadiationMJSum
                
        let windspeed2m = scaleWindFactor(from: 10, to: 2) * windspeed10mMeterPerSecondMean

        /// Slope of saturation vapour pressure curve at air temperature T [kPa °C-1], (Page 37)
        let β = Float(17.27) // Actaually 17.625 is now recommended. FAO uses the old one.
        let λ = Float(237.3) // 243.04 new recommendation
        let e0min = 0.6108 * exp(β * temperature2mCelsiusDailyMin / (temperature2mCelsiusDailyMin + λ))
        let e0max = 0.6108 * exp(β * temperature2mCelsiusDailyMax / (temperature2mCelsiusDailyMax + λ))
        /// saturation vapor pressure at air temperature Thr. (kPa)
        let esat = (e0min + e0max) / 2
        
        ///  the slope of the vapour pressure curve is calculated using mean air temperature
        let vaporPressurCurveSlope = 4098 * (0.6108 * exp(β * temperature2mCelsiusDailyMean / (temperature2mCelsiusDailyMean + λ))) / powf((temperature2mCelsiusDailyMean + λ), 2)
        
        /// Air pressure in kPa. Evaporation at high altitudes is promoted due to low atmospheric pressure as expressed in the psychrometric constant. The effect is, however, small and in the calculation procedures, the average value for a location is sufficient.
        let simplifiedAtmosphericPressure = 101.3 * powf((293 - 0.0065 * elevation)/293.0, 5.26)

        /// psychrometric constant [kPa °C-1], (Equation 8)
        let γ = 0.000665 * simplifiedAtmosphericPressure
        
        /// actual vapour pressure [kPa], (Page 37)
        let ea: Float
        
        /// As a more approximate alternative, one can assume Rs/Rso = 0.4 to 0.6 during nighttime periods in humid and subhumid climates and Rs/Rso = 0.7 to 0.8 in arid and semiarid climates. (Page 75)
        let RrelAproximation: Float
        
        switch relativeHumidity {
        case .mean(mean: let mean):
            ea = mean/100 * (e0max + e0min) / 2
            RrelAproximation = 0.4 + mean / 100 * 0.4
        case .maxmin(max: let max, min: let min):
            ea = (e0min * max / 100 + e0max * min / 100) / 2
            RrelAproximation = 0.4 + (max + min) / 2 / 100 * 0.4
        }
        
        let vaporPressureDeficit = esat-ea

        /// 0.23 is defined by FAO for albedo
        let albedo = Float(0.23)
        
        /// net solar or shortwave radiation [MJ m-2 day-1], (Page 51)
        let Rns = Rs * (1-albedo)
        
        /// clear-sky solar radiation [MJ m-2 day-1] approximated, (Page 51)
        let Rso = (0.75 + 0.00002 * elevation) * extraTerrestrialRadiationSum
        
        /// relative shortwave radiation (limited to ≤ 1.0. Although daily, could still happen at poles
        let Rrel = extraTerrestrialRadiationSum <= 0 ? RrelAproximation : min(Rs/Rso, 1)
        
        /// net outgoing longwave radiation [MJ m-2 day-1]
        let Rnl = boltzmanConstant * (powf(temperature2mCelsiusDailyMax + 273.16, 4) + powf(temperature2mCelsiusDailyMin + 273.16, 4)) / 2 * (0.34 - 0.14 * sqrt(ea)) * (1.35 * Rrel - 0.35)

        // radiation balance
        let Rn = Rns-Rnl

        /// soil heat flux [MJ m-2 day-1], During night, calculation is different
        let Ghr = (Rs <= 0) ? 0.5 * Rn : 0.1 * Rn
        
        // evapotranspiration
        let et0 = (0.408 * vaporPressurCurveSlope * (Rn-Ghr) + γ *  (37.0 / (temperature2mCelsiusDailyMean + 273)) * windspeed2m * vaporPressureDeficit) / (vaporPressurCurveSlope + γ * (1+0.34*windspeed2m))

        return max(et0, 0)
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
