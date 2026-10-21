@testable import App
import Foundation
import Testing

@Suite struct ErrorMiddlewareTests {
    private enum Model: String, Decodable {
        case bestMatch = "best_match"
    }

    private struct ForecastQuery: Decodable {
        let models: Model
    }

    private struct Location: Decodable {
        let latitude: Int
    }

    private struct Locations: Decodable {
        let locations: [Location]
    }

    private func decodingError<T: Decodable>(
        decoding type: T.Type,
        from json: String
    ) throws -> DecodingError {
        do {
            _ = try JSONDecoder().decode(type, from: Data(json.utf8))
            Issue.record("Expected JSON decoding to fail")
            throw CancellationError()
        } catch let error as DecodingError {
            return error
        }
    }

    @Test func readableInvalidEnumValue() throws {
        let error = try decodingError(
            decoding: ForecastQuery.self,
            from: #"{"models":"hrrr"}"#
        )

        #expect(error.readableDescription == "Invalid value at 'models': Cannot initialize Model from invalid String value hrrr")
    }

    @Test func readableTypeMismatchWithNestedPath() throws {
        let error = try decodingError(
            decoding: Locations.self,
            from: #"{"locations":[{"latitude":1},{"latitude":2},{"latitude":"north"}]}"#
        )

        #expect(error.readableDescription == "Expected Int at 'locations[2].latitude': Expected to decode Int but found a string instead.")
    }
}
