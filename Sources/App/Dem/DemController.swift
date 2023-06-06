import Foundation
import Vapor


struct DemController {
    struct Query: Content {
        let latitude: [Float]
        let longitude: [Float]
        
        func validate() throws {
            guard latitude.count == longitude.count else {
                throw ForecastapiError.latitudeAndLongitudeSameCount
            }
            guard !latitude.isEmpty else {
                throw ForecastapiError.latitudeAndLongitudeNotEmpty
            }
            guard latitude.count <= 100 else {
                throw ForecastapiError.latitudeAndLongitudeMaximum(max: 100)
            }
            try zip(latitude, longitude).forEach { (latitude, longitude) in
                if latitude > 90 || latitude < -90 || latitude.isNaN {
                    throw ForecastapiError.latitudeMustBeInRangeOfMinus90to90(given: latitude)
                }
                if longitude > 180 || longitude < -180 || longitude.isNaN {
                    throw ForecastapiError.longitudeMustBeInRangeOfMinus180to180(given: longitude)
                }
            }
        }
    }

    func query(_ req: Request) throws -> EventLoopFuture<Response> {
        if req.headers[.host].contains(where: { $0 == "open-meteo.com"}) {
            throw Abort.init(.notFound)
        }
        let params = try req.query.decode(Query.self)
        try params.validate()
        // Run query on separat thread pool to not block the main pool
        return ForecastapiController.runLoop.next().submit({
            let elevation = try zip(params.latitude, params.longitude).map { (latitude, longitude) in
                try Dem90.read(lat: latitude, lon: longitude)
            }
            var headers = HTTPHeaders()
            headers.add(name: .contentType, value: "application/json")
            return Response(status: .ok, headers: headers, body: .init(string: """
               {"elevation":\(elevation)}
               """))
        })
    }
}

