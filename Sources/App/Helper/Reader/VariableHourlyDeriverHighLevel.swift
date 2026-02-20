///// Derive variables that are independent of the specific weather model
//struct VariableHourlyDeriverHighLevel: GenericDeriverOptionalProtocol {
//    typealias ReaderVariable = ForecastVariable
//    
//    typealias VariableOpt = ForecastVariable
//    
//    let reader: any GenericReaderOptionalProtocol<ReaderVariable>
//    
//    func getDeriverMap(variable: ForecastVariable) -> DerivedMapping<ForecastVariable>? {
//        switch variable {
//        case .surface(let surface):
//            switch surface.variable {
//            case .terrestrial_radiation:
//                return .independent({ time in
//                    let solar = Zensun.extraTerrestrialRadiationBackwards(latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time)
//                    return DataAndUnit(solar, .wattPerSquareMetre)
//                })
//            case .terrestrial_radiation_instant:
//                return .independent({ time in
//                    let solar = Zensun.extraTerrestrialRadiationInstant(latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time)
//                    return DataAndUnit(solar, .wattPerSquareMetre)
//                })
//            default:
//                return .direct(variable)
//            }
//        case .pressure(_):
//            return .direct(variable)
//        case .height(_):
//            return .direct(variable)
//        }
//    }
//}
