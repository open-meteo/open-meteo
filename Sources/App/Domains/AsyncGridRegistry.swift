/// Grids whose geometry and static fields must be loaded before use.
enum AsyncGridRegistry: String, CaseIterable, Sendable {
    case dwd_icon_global_native
    case dwd_icon_eu_native
    case dwd_icon_d2_native
    case dwd_icon_global_eps_native
    case dwd_icon_eu_eps_native

    var staticDomain: DomainRegistry {
        switch self {
        case .dwd_icon_global_native:
            return .dwd_icon_global_native
        case .dwd_icon_eu_native:
            return .dwd_icon_eu_native
        case .dwd_icon_d2_native:
            return .dwd_icon_d2_native
        case .dwd_icon_global_eps_native:
            return .dwd_icon_global_eps_native
        case .dwd_icon_eu_eps_native:
            return .dwd_icon_eu_eps_native
        }
    }

    func load() async throws -> any Gridable {
        try await IconNativeGridLoader.shared.load(grid: self)
    }
}
