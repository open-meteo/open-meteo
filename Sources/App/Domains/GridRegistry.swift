/// Complete grid identity for metadata and static-resource dependencies, without loading geometry.
enum GridRegistry: Hashable, Sendable {
    case synchronous(SyncGridRegistry)
    case asynchronous(AsyncGridRegistry)

    var staticDomain: DomainRegistry? {
        switch self {
        case .synchronous(let grid):
            return grid.staticDomain
        case .asynchronous(let grid):
            return grid.staticDomain
        }
    }
}
