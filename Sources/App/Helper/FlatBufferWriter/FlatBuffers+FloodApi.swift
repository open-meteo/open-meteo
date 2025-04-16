import Foundation
import FlatBuffers
import OpenMeteoSdk

extension GloFasVariable: FlatBuffersVariable {
    func getFlatBuffersMeta() -> FlatBufferVariableMeta {
        switch self {
        case .river_discharge:
            return .init(variable: .riverDischarge)
        }
    }
}

extension GlofasDerivedVariable: FlatBuffersVariable {
    func getFlatBuffersMeta() -> FlatBufferVariableMeta {
        switch self {
        case .river_discharge_mean:
            return .init(variable: .riverDischarge, aggregation: .mean)
        case .river_discharge_min:
            return .init(variable: .riverDischarge, aggregation: .minimum)
        case .river_discharge_max:
            return .init(variable: .riverDischarge, aggregation: .maximum)
        case .river_discharge_median:
            return .init(variable: .riverDischarge, aggregation: .median)
        case .river_discharge_p25:
            return .init(variable: .riverDischarge, aggregation: .p25)
        case .river_discharge_p75:
            return .init(variable: .riverDischarge, aggregation: .p75)
        }
    }
}

extension GlofasDomainApi: ModelFlatbufferSerialisable {
    typealias HourlyVariable = EnsembleSurfaceVariable

    typealias HourlyPressureType = EnsemblePressureVariableType

    typealias HourlyHeightType = ForecastHeightVariableType

    typealias DailyVariable = GloFasVariableOrDerived

    var flatBufferModel: openmeteo_sdk_Model {
        switch self {
        case .best_match:
            return .bestMatch
        case .seamless_v3:
            return .glofasSeamlessV3
        case .forecast_v3:
            return .glofasForecastV3
        case .consolidated_v3:
            return .glofasConsolidatedV3
        case .seamless_v4:
            return .glofasSeamlessV4
        case .forecast_v4:
            return .glofasForecastV4
        case .consolidated_v4:
            return .glofasConsolidatedV4
        }
    }
}
