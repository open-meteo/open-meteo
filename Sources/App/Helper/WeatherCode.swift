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
    public static func calculate(cloudcover: Float, precipitation: Float, convectivePrecipitation: Float?, snowfallCentimeters: Float, gusts: Float?, cape: Float?, liftedIndex: Float?, visibilityMeters: Float?, categoricalFreezingRain: Float?, modelDtSeconds: Int) -> WeatherCode? {
        
        let modelDtHours = Float(modelDtSeconds) / 3600
        
        let thunderstromStrength: WeatherCode = ((gusts ?? 0) >= 18/3.6 || (precipitation / modelDtHours) >= 10) ? .thunderstormStrong : ((gusts ?? 0 >= 29/3.6) || (precipitation / modelDtHours) >= 25) ? .thunderstormStrong : .thunderstormSlightOrModerate
        
        if let cape, cape >= 2000 {
            if let liftedIndex {
                if liftedIndex <= -3 {
                    return thunderstromStrength
                }
            } else {
                return thunderstromStrength
            }
        }
        
        if let categoricalFreezingRain, categoricalFreezingRain >= 1 {
            switch precipitation / modelDtHours {
            case 0.1..<0.5: return .lightFreezingDrizzle
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
            case 7.6...: return .moderateRainShowers
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
        case 0.1..<0.5: return .lightDrizzle
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
    
    public static func calculate(cloudcover: [Float], precipitation: [Float], convectivePrecipitation: [Float]?, snowfallCentimeters: [Float], gusts: [Float]?, cape: [Float]?, liftedIndex: [Float]?, visibilityMeters: [Float]?, categoricalFreezingRain: [Float]?, modelDtSeconds: Int) -> [Float] {
        
        return cloudcover.indices.map { i in
            return calculate(
                cloudcover: cloudcover[i],
                precipitation: precipitation[i],
                convectivePrecipitation: convectivePrecipitation?[i],
                snowfallCentimeters: snowfallCentimeters[i],
                gusts: gusts?[i],
                cape: cape?[i],
                liftedIndex: liftedIndex?[i],
                visibilityMeters: visibilityMeters?[i],
                categoricalFreezingRain: categoricalFreezingRain?[i],
                modelDtSeconds: modelDtSeconds
            ).map({Float($0.rawValue)}) ?? .nan
        }
    }
    
    /// True if weather code is an precipitation event. Thunderstorm, return false as they may only indicate potential
    var isPrecipitationEvent: Bool {
        switch self {
        case .lightDrizzle, .moderateDrizzle, .denseDrizzle:
            fallthrough
        case .lightFreezingDrizzle, .moderateOrDenseFreezingDrizzle:
            fallthrough
        case .lightRain, .moderateRain, .heavyRain:
            fallthrough
        case .lightFreezingRain, .moderateOrHeavyFreezingRain:
            fallthrough
        case .slightSnowfall, .moderateSnowfall, .heavySnowfall, .snowGrains:
            fallthrough
        case .slightRainShowers, .moderateRainShowers,.heavyRainShowers:
            fallthrough
        case .slightSnowShowers, .heavySnowShowers:
            return true
        default:
            return false
        }
    }
    
    /// DWD ICON weather codes show rain although precipitation is 0
    /// Similar for snow at +2°C or more
    func correctDwdIconWeatherCode(temperature_2m: Float, precipitation: Float) -> WeatherCode {
        if precipitation <= 0 && self.isPrecipitationEvent {
            // Weather code shows drizzle, but no precipitation, demote to overcast
            return .overcast
        }
        
        if temperature_2m >= 2 {
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
        
        return self
    }
}
