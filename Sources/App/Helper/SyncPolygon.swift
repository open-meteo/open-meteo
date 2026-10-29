import Foundation

/// WGS84 adapter for `sync --polygon`. Rings must not cross the antimeridian.
struct SyncPolygon: Sendable {
    private let geometry: Polygon

    /// GeoJSON MultiPolygon coordinates starting with `[[[[`, or `@path` to a UTF-8 file containing it.
    init(argument: String) throws {
        guard argument.hasPrefix("@") else {
            try self.init(text: argument)
            return
        }
        let text: String
        do {
            text = try String(contentsOfFile: String(argument.dropFirst()), encoding: .utf8)
        } catch {
            throw ForecastApiError.generic(message: "--polygon: cannot read the file \(argument.dropFirst()): \(error)")
        }
        try self.init(text: text)
    }

    init(text: String) throws {
        do {
            geometry = try Polygon(text: text)
        } catch {
            throw ForecastApiError.generic(message: "--polygon: \(error)")
        }
    }

    func contains(latitude: Float, longitude: Float) -> Bool {
        geometry.contains(x: longitude, y: latitude)
    }
}
