import Foundation
import Vapor


struct DemController {
    struct Result: Content {
        let elevation: [Float]
    }

    struct Query: Content {
        let latitude: [Double]
        let longitude: [Double]
        
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

    func query(_ req: Request) throws -> Result {
        if req.headers[.host].contains(where: { $0 == "open-meteo.com"}) {
            throw Abort.init(.notFound)
        }
        let params = try req.query.decode(Query.self)
        try params.validate()
        let elevation = try zip(params.latitude, params.longitude).map { (latitude, longitude) in
            try Dem90.read(lat: Float(latitude), lon: Float(longitude))
        }
        return Result(elevation: elevation)
    }
}

