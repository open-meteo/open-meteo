import Foundation

/*enum CamsVariableDaily: String, Codable {
    case uv_index
    case uv_index_clear_sky
    
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
                try await prefetchData(variable: .uv_index)
            }
        }
    }
}*/
