import Foundation

enum WeatherCode: Int {
    case clearSky = 0
    case mainlyClear = 1
    case partlyCloudy = 2
    case overcast = 3
    case fog = 45
    case depositingRimeFog = 48
    case lightDrizzle = 51
    case moderateDrizzle = 53
    case denseDrizzle = 55
    case lightFreezingDrizzle = 56
    case moderateOrDenseFreezingDrizzle = 57
    case lightRain = 61
    case moderateRain = 63
    case heavyRain = 65
    case lightFreezingRain = 66
    case moderateOrHeavyFreezingRain = 67
    case slightSnowfall = 71
    case moderateSnowfall = 73
    case heavySnowfall = 75
    case snowGrains = 77
    case slightRainShowers = 80
    case moderateRainShowers = 81
    case heavyRainShowers = 82
    case slightSnowShowers = 85
    case heavySnowShowers = 86
    case thunderstormSlightOrModerate = 95
    case thunderstormStrong = 96
    case thunderstormHeavy = 99

    /// Calculate weather interpretation code
    /// http://www.cosmo-model.org/content/model/documentation/newsLetters/newsLetter06/cnl6_hoffmann.pdf
    /// https://www.dwd.de/DE/leistungen/pbfb_verlag_promet/pdf_promethefte/28_1_2_pdf.pdf?__blob=publicationFile&v=8
    public static func calculate(cloudcover: Float, precipitation: Float, convectivePrecipitation: Float?, snowfallCentimeters: Float, gusts: Float?, cape: Float?, liftedIndex: Float?, convectiveInhibition: Float?, pblHeight: Float?, visibilityMeters: Float?, categoricalFreezingRain: Float?, modelDtSeconds: Int, latitude: Float) -> WeatherCode? {
        guard cloudcover.isFinite, precipitation.isFinite, snowfallCentimeters.isFinite else {
            return nil
        }
        
        let modelDtHours = Float(modelDtSeconds) / 3600
        
        // let thunderstromStrength: WeatherCode = ((gusts ?? 0) >= 18/3.6 || (precipitation / modelDtHours) >= 10) ? .thunderstormStrong : ((gusts ?? 0 >= 29/3.6) || (precipitation / modelDtHours) >= 25) ? .thunderstormStrong : .thunderstormSlightOrModerate
        
        if let cape {
            let thunderstroms = calculateThunderstormProbability(convectivePrecipitation: convectivePrecipitation, precipitation: precipitation, cloudcover: cloudcover, gusts: gusts, cape: cape, liftedIndex: liftedIndex, convectiveInhibition: convectiveInhibition, pblHeight: pblHeight, modelDtSeconds: modelDtSeconds, latitude: latitude)
            if thunderstroms > 85 {
                return .thunderstormStrong
            }
            if thunderstroms > 60 {
                return .thunderstormSlightOrModerate
            }
        }

        if let categoricalFreezingRain, categoricalFreezingRain >= 1 {
            switch precipitation / modelDtHours {
            case 0.01..<0.5: return .lightFreezingDrizzle
            case 0.5..<1.0: return .moderateOrDenseFreezingDrizzle
            case 1.0..<1.3: return .moderateOrDenseFreezingDrizzle
            case 1.3..<2.5: return .lightFreezingRain
            case 2.5..<7.6: return .moderateOrHeavyFreezingRain
            case 7.6...: return .moderateOrHeavyFreezingRain
            default: break
            }
        }

        if (convectivePrecipitation ?? 0) > 0 || (cape ?? 0) >= 800 {
            switch snowfallCentimeters / modelDtHours {
            case 0.01..<0.2: return .slightSnowShowers
            case 0.2..<0.8: return .slightSnowShowers
            case 0.8...: return .heavySnowShowers
            default: break
            }
            switch precipitation / modelDtHours {
            case 1.3..<2.5: return .slightRainShowers
            case 2.5..<7.6: return .moderateRainShowers
            case 7.6...: return .heavyRainShowers
            default: break
            }
        }

        switch snowfallCentimeters / modelDtHours {
        case 0.01..<0.2: return .slightSnowfall
        case 0.2..<0.8: return .moderateSnowfall
        case 0.8...: return .heavySnowfall
        default: break
        }

        switch precipitation / modelDtHours {
        case 0.01..<0.5: return .lightDrizzle
        case 0.5..<1.0: return .moderateDrizzle
        case 1.0..<1.3: return .denseDrizzle
        case 1.3..<2.5: return .lightRain
        case 2.5..<7.6: return .moderateRain
        case 7.6...: return .heavyRain
        default: break
        }

        if let visibilityMeters, visibilityMeters <= 1000 {
            return .fog
        }

        switch cloudcover {
        case 0..<20: return .clearSky
        case 20..<50: return .mainlyClear
        case 50..<80: return .partlyCloudy
        case 80...: return .overcast
        default: break
        }

        return nil
    }

    public static func calculate(cloudcover: [Float], precipitation: [Float], convectivePrecipitation: [Float]?, snowfallCentimeters: [Float], gusts: [Float]?, cape: [Float]?, liftedIndex: [Float]?, convectiveInhibition: [Float]?, pblHeight: [Float]?, visibilityMeters: [Float]?, categoricalFreezingRain: [Float]?, modelDtSeconds: Int, latitude: Float) -> [Float] {
        return cloudcover.indices.map { i in
            return calculate(
                cloudcover: cloudcover[i],
                precipitation: precipitation[i],
                convectivePrecipitation: convectivePrecipitation?[i],
                snowfallCentimeters: snowfallCentimeters[i],
                gusts: gusts?[i],
                cape: cape?[i],
                liftedIndex: liftedIndex?[i],
                convectiveInhibition: convectiveInhibition?[i],
                pblHeight: pblHeight?[i],
                visibilityMeters: visibilityMeters?[i],
                categoricalFreezingRain: categoricalFreezingRain?[i],
                modelDtSeconds: modelDtSeconds,
                latitude: latitude
            ).map({ Float($0.rawValue) }) ?? .nan
        }
    }
    
    public static func calculateThunderstormProbability(
        convectivePrecipitation: Float?,
        precipitation: Float,
        cloudcover: Float,
        gusts: Float?,
        cape: Float,
        liftedIndex: Float?,
        convectiveInhibition: Float?,
        pblHeight: Float?,
        modelDtSeconds: Int,
        latitude: Float // Added latitude to scale tropical behavior
    ) -> Float {
        
        // 1. HARD BLOCKERS
        if cape <= 10.0 { return 0.0 }
        if cloudcover < 30.0 { return 0.0 }
        if let cin = convectiveInhibition, cin > 250.0 { return 0.0 }
        if let li = liftedIndex, li > 2.0 { return 0.0 }
        
        // 2. LATITUDE SCALING FACTOR
        // 1.0 at mid-latitudes (>= 30°), scales down to 0.8 at the equator (0°)
        let absLat = Swift.abs(latitude)
        let latitudeFactor: Float
        if absLat >= 30.0 {
            latitudeFactor = 1.0
        } else {
            latitudeFactor = 0.8 + (0.2 * (absLat / 30.0))
        }
        
        // Dynamic weight accumulation tracking
        var accumulatedScore: Float = 0.0
        var totalWeight: Float = 0.0
        
        // 3. CAPE Score (Base Weight: 25%)
        // Shifting CAPE baseline higher in tropics to account for naturally high baseline environments.
        let capeWeight: Float = 0.25
        let maxCapeThreshold: Float = 2500.0 + (1500.0 * (1.0 - (Swift.min(absLat, 30.0) / 30.0)))
        let capeScore = Swift.max(0.0, Swift.min((cape - 300.0) / (maxCapeThreshold - 300.0), 1.0))
        accumulatedScore += (capeScore * capeWeight)
        totalWeight += capeWeight
        
        // 4. CIN Score (Base Weight: 15%)
        if let cin = convectiveInhibition {
            let cinWeight: Float = 0.15
            let cinScore: Float
            if cin <= 15.0 {
                cinScore = 1.0
            } else {
                cinScore = Swift.max(0.0, Swift.min(1.0 - ((cin - 15.0) / 135.0), 1.0))
            }
            accumulatedScore += (cinScore * cinWeight)
            totalWeight += cinWeight
        }
        
        // 5. Lifted Index Score (Base Weight: 15%)
        if let li = liftedIndex {
            let liWeight: Float = 0.15
            let liScore = Swift.max(0.0, Swift.min((0.0 - li) / 8.0, 1.0))
            accumulatedScore += (liScore * liWeight)
            totalWeight += liWeight
        }
        
        // 6. Precipitation Trigger Score (Base Weight: 25%)
        // Prefer convective showers. If unavailable, use regular precipitation with a penalty.
        let dtHours = Float(modelDtSeconds) / 3600.0
        let referencePrecipPerHour: Float = 2.0 + (3.0 * (1.0 - (Swift.min(absLat, 30.0) / 30.0)))
        let referencePrecip = referencePrecipPerHour * dtHours

        let precipWeight: Float = 0.25
        if let showers = convectivePrecipitation, showers > 0.0 {
            let precipScore = Swift.max(0.0, Swift.min(showers / referencePrecip, 1.0))
            accumulatedScore += (precipScore * precipWeight)
            totalWeight += precipWeight
        } else {
            // Without explicit showers, require stronger total rain and cap confidence lower.
            let fallbackReferencePrecip = referencePrecip * 1.6
            let fallbackPrecipScore = Swift.max(0.0, Swift.min(precipitation / fallbackReferencePrecip, 1.0))
            accumulatedScore += (fallbackPrecipScore * precipWeight * 0.6)
            totalWeight += (precipWeight * 0.6)
        }

        // 6. Boundary Layer Height Score (Base Weight: 7.5%)
        // Scale from 0.0 (at 300m) to 1.0 (at 1500m+)
        if let pbl = pblHeight {
            let pblWeight: Float = 0.075
            let pblScore = Swift.max(0.0, Swift.min((pbl - 300.0) / 1200.0, 1.0))
            accumulatedScore += (pblScore * pblWeight)
            totalWeight += pblWeight
        }

        // 7. Wind Gust Score (Base Weight: 7.5%)
        // Scale from 0.0 (at 5 m/s) to 1.0 (at 18+ m/s)
        if let g = gusts {
            let gustWeight: Float = 0.075
            let gustScore = Swift.max(0.0, Swift.min((g - 5.0) / 13.0, 1.0))
            accumulatedScore += (gustScore * gustWeight)
            totalWeight += gustWeight
        }

        // Calculate base probability normalized to the actual weights available
        var baseProbability = (accumulatedScore / totalWeight) * 100.0

        // 8. TRIGGER DYNAMICS AMPLIFIER
        // If the model actively simulates convective rain in an unstable airmass, the cap has broken.
        if let precip = convectivePrecipitation, let cin = convectiveInhibition {
            let triggerRainThreshold = 0.1 * dtHours
            if precip > triggerRainThreshold && cape > 300.0 && cin < 50.0 {
                baseProbability = Swift.min(baseProbability * 1.3, 100.0)
            }
        }

        // Reduce confidence when no convective shower signal is present.
        if (convectivePrecipitation ?? precipitation) <= 0.0 {
            baseProbability *= 0.7
        }

        // If the cap is highly restrictive (CIN > 100 J/kg), heavily suppress the final index
        if let cin = convectiveInhibition, cin > 100.0 {
            baseProbability *= 0.3
        }
        
        // 9. APPLY CLOUD COVER AND LATITUDE DAMPENING
        // Additional suppression between 30-60% cloud cover, then no penalty above 60%.
        let cloudCoverFactor: Float
        if cloudcover >= 60.0 {
            cloudCoverFactor = 1.0
        } else {
            cloudCoverFactor = 0.6 + (0.4 * ((cloudcover - 30.0) / 30.0))
        }
        baseProbability *= cloudCoverFactor
        baseProbability *= latitudeFactor
        
        return Swift.max(0.0, Swift.min(baseProbability, 100.0))
    }

    /// True if weather code is an precipitation event. Thunderstorm, return false as they may only indicate potential
    var isPrecipitationEvent: Bool {
        switch self {
        case .lightDrizzle, .moderateDrizzle, .denseDrizzle, .lightFreezingDrizzle, .moderateOrDenseFreezingDrizzle, .lightRain, .moderateRain, .heavyRain, .lightFreezingRain, .moderateOrHeavyFreezingRain, .slightSnowfall, .moderateSnowfall, .heavySnowfall, .snowGrains, .slightRainShowers, .moderateRainShowers, .heavyRainShowers, .slightSnowShowers, .heavySnowShowers:
            return true
        default:
            return false
        }
    }

    /// DWD ICON weather codes show rain although precipitation is 0
    /// Similar for snow at +2°C or more
    func correctDwdIconWeatherCode(temperature_2m: Float, precipitation: Float, snowfallHeightAboveGrid: Bool) -> WeatherCode {
        if precipitation <= 0 && self.isPrecipitationEvent {
            // Weather code shows drizzle, but no precipitation, demote to overcast
            return .overcast
        }

        if temperature_2m >= 2 || snowfallHeightAboveGrid {
            // Weather code may show snow, although temperature is high
            switch self {
            case .slightSnowfall:
                return .lightRain
            case .moderateSnowfall:
                return .moderateRain
            case .heavySnowfall:
                return .heavyRain
            default:
                break
            }
        }

        if temperature_2m < -1 {
            switch self {
            case .lightRain:
                return .slightSnowfall
            case .moderateRain:
                return .moderateSnowfall
            case .heavyRain:
                return .heavySnowfall
            default:
                break
            }
        }

        return self
    }

    // If temperature smaller or greated 0°C, set or unset snow
    func correctSnowRainHardCutOff(temperature_2m: Float) -> Self {
        if temperature_2m > 0 {
            // Weather code may show snow, although temperature is high
            switch self {
            case .slightSnowfall:
                return .lightRain
            case .moderateSnowfall:
                return .moderateRain
            case .heavySnowfall:
                return .heavyRain
            default:
                break
            }
        }
        if temperature_2m < 0 {
            switch self {
            case .lightRain:
                return .slightSnowfall
            case .moderateRain:
                return .moderateSnowfall
            case .heavyRain:
                return .heavySnowfall
            default:
                break
            }
        }
        return self
    }
}
