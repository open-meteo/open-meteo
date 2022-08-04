import Foundation

enum CamsVariableDaily: String, Codable {
    case uv_index
    
}

extension CamsMixer {
    func getDaily(variable: CamsVariableDaily) throws -> DataAndUnit {
        switch variable {
        case .uv_index:
            let data = try get(variable: .uv_index)
            return DataAndUnit(data.data.max(by: 24), data.unit)
        }
    }
    
    func prefetchData(variables: [CamsVariableDaily]) throws {
        for variable in variables {
            switch variable {
            case .uv_index:
                try prefetchData(variable: .uv_index)
            }
        }
    }
}
