import Foundation
import Vapor

struct DemController {
    func query(_ req: Request) async throws -> Response {
        try await req.withApiParameter("api") { _, params in
            let latitude = try Float.load(commaSeparated: params.latitude)
            let longitude = try Float.load(commaSeparated: params.longitude)

            guard latitude.count == longitude.count else {
                throw ForecastapiError.latitudeAndLongitudeSameCount
            }
            guard !latitude.isEmpty else {
                throw ForecastapiError.latitudeAndLongitudeNotEmpty
            }
            guard latitude.count <= 100 else {
                throw ForecastapiError.latitudeAndLongitudeMaximum(max: 100)
            }
            try zip(latitude, longitude).forEach { latitude, longitude in
                if latitude > 90 || latitude < -90 || latitude.isNaN {
                    throw ForecastapiError.latitudeMustBeInRangeOfMinus90to90(given: latitude)
                }
                if longitude > 180 || longitude < -180 || longitude.isNaN {
                    throw ForecastapiError.longitudeMustBeInRangeOfMinus180to180(given: longitude)
                }
            }
            return DemResponder(latitude: latitude, longitude: longitude)
        }
    }
}

fileprivate struct DemResponder: ForecastapiResponder {
    var numberOfLocations: Int { 1 }

    let latitude: [Float]
    let longitude: [Float]

    func calculateQueryWeight(nVariablesModels: Int?) -> Float {
        return Float(nVariablesModels ?? latitude.count)
    }

    func response(format: ForecastResultFormat?, timestamp: Timestamp, fixedGenerationTime: Double?, concurrencySlot: Int?) async throws -> Response {
        return try await ForecastapiController.runLoop.next().submit({
            let elevation = try zip(latitude, longitude).map { latitude, longitude in
                try Dem90.read(lat: latitude, lon: longitude)
            }
            var headers = HTTPHeaders()
            headers.add(name: .contentType, value: "application/json")
            return Response(status: .ok, headers: headers, body: .init(string: """
               {"elevation":\(elevation)}
               """))
        }).get()
    }
}
