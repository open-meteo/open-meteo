import Foundation
import FlatBuffers
import OpenMeteoSdk


extension IconWaveVariable: FlatBuffersVariable {
    func getFlatBuffersMeta() -> FlatBufferVariableMeta {
        switch self {
        }
    }
}

extension IconWaveVariableDaily: FlatBuffersVariable {
    func getFlatBuffersMeta() -> FlatBufferVariableMeta {
        switch self {
        }
    }
}

extension IconWaveDomainApi: ModelFlatbufferSerialisable {
    typealias HourlyVariable = IconWaveVariable
    
    typealias HourlyPressureType = ForecastPressureVariableType
    
    typealias DailyVariable = IconWaveVariableDaily
    
    var flatBufferModel: openmeteo_sdk_Model {
        switch self {
        case.best_match:
            return .bestMatch
        case .gwam:
            return .gwam
        case .ewam:
            return .ewam
        }
    }
}
