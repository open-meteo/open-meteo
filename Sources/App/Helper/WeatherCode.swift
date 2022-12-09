//
//  File.swift
//  
//
//  Created by Patrick Zippenfenig on 08.12.22.
//

import Foundation

enum WeatherCode: Int {
    case clearSky = 0
    case mainlyClear = 1
    case partlyCloudy = 2
    case overcast = 3
    case fog = 45
    case depositingTimeFog = 48
    case lightDrizzle = 51
    case moderateDrizzle = 53
    case denseDrizzle = 55
    case lightFreezingDrizzle = 56
    case denseFreezingDrizzle = 57
    case lightRain = 61
    case moderateRain = 63
    case heavyRain = 65
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
    public static func calculate(cloudcover: Float, precipitation: Float, convectivePrecipitation: Float?, snowfallCentimeters: Float, gusts: Float?, cape: Float?, liftedIndex: Float?, modelDtHours: Int) -> WeatherCode? {
        
        let thunderstromStrength: WeatherCode = ((gusts ?? 0) >= 18/3.6 || (precipitation / Float(modelDtHours)) >= 10) ? .thunderstormStrong : ((gusts ?? 0 >= 29/3.6) || (precipitation / Float(modelDtHours)) >= 25) ? .thunderstormStrong : .thunderstormSlightOrModerate
        
        if let liftedIndex, liftedIndex <= -2 {
            return thunderstromStrength
        }
        if let cape, cape >= 1000 {
            return thunderstromStrength
        }
        
        if (convectivePrecipitation ?? 0) > 0 || (cape ?? 0) >= 800 {
            switch snowfallCentimeters / Float(modelDtHours) {
            case 0.01..<0.2: return .slightSnowShowers
            case 0.2..<0.8: return .slightSnowShowers
            case 0.8...: return .heavySnowShowers
            default: break
            }
            switch precipitation / Float(modelDtHours) {
            case 1.3..<2.5: return .slightRainShowers
            case 2.5..<7.6: return .moderateRainShowers
            case 7.6...: return .moderateRainShowers
            default: break
            }
        }
        
        switch snowfallCentimeters / Float(modelDtHours) {
        case 0.01..<0.2: return .slightSnowfall
        case 0.2..<0.8: return .moderateSnowfall
        case 0.8...: return .heavySnowfall
        default: break
        }
        
        switch precipitation / Float(modelDtHours) {
        case 0.1..<0.5: return .lightDrizzle
        case 0.5..<1.3: return .moderateDrizzle
        case 1.3..<2.5: return .lightRain
        case 2.5..<7.6: return .moderateRain
        case 7.6...: return .heavyRain
        default: break
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
    
    public static func calculate(cloudcover: [Float], precipitation: [Float], convectivePrecipitation: [Float]?, snowfallCentimeters: [Float], gusts: [Float]?, cape: [Float]?, liftedIndex: [Float]?, modelDtHours: Int) -> [Float] {
        
        return cloudcover.indices.map { i in
            return calculate(
                cloudcover: cloudcover[i],
                precipitation: precipitation[i],
                convectivePrecipitation: convectivePrecipitation?[i],
                snowfallCentimeters: snowfallCentimeters[i],
                gusts: gusts?[i],
                cape: cape?[i],
                liftedIndex: liftedIndex?[i],
                modelDtHours: modelDtHours
            ).map({Float($0.rawValue)}) ?? .nan
        }
    }
}
