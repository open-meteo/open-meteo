import Foundation
import Vapor

/**
 TODO:
 - air quality index (european)
 */
struct CamsController {
    func query(_ req: Request) -> EventLoopFuture<Response> {
        do {
            // API should only be used on the subdomain
            if req.headers[.host].contains(where: { $0.contains("open-meteo.com") && !$0.starts(with: "air-quality-api.") }) {
                throw Abort.init(.notFound)
            }
            let generationTimeStart = Date()
            let params = try req.query.decode(CamsQuery.self)
            try params.validate()
            let currentTime = Timestamp.now()
            
            let allowedRange = Timestamp(2022, 7, 29) ..< currentTime.add(86400 * 6)
            let timezone = try params.resolveTimezone()
            let time = try params.getTimerange(timezone: timezone, current: currentTime, forecastDays: 5, allowedRange: allowedRange)
            let hourlyTime = time.range.range(dtSeconds: 3600)
            //let dailyTime = time.range.range(dtSeconds: 3600*24)
            
            let domains = (params.domains ?? .auto).camsDomains
            
            guard let reader = try CamsMixer(domains: domains, lat: params.latitude, lon: params.longitude, elevation: .nan, mode: .nearest) else {
                throw ForecastapiError.noDataAvilableForThisLocation
            }
            // Start data prefetch to boooooooost API speed :D
            if let hourlyVariables = params.hourly {
                try reader.prefetchData(variables: hourlyVariables, time: hourlyTime)
            }
            /*if let dailyVariables = params.daily {
                try reader.prefetchData(variables: dailyVariables)
            }*/
            
            let hourly: ApiSection? = try params.hourly.map { variables in
                var res = [ApiColumn]()
                res.reserveCapacity(variables.count)
                for variable in variables {
                    let d = try reader.get(variable: variable, time: hourlyTime).toApi(name: variable.name)
                    res.append(d)
                }
                return ApiSection(name: "hourly", time: hourlyTime, columns: res)
            }
            
            /*let daily: ApiSection? = try params.daily.map { dailyVariables in
                return ApiSection(name: "daily", time: dailyTime, columns: try dailyVariables.map { variable in
                    let d = try reader.getDaily(variable: variable).toApi(name: variable.rawValue)
                    assert(dailyTime.count == d.data.count)
                    return d
                })
            }*/
            
            let generationTimeMs = Date().timeIntervalSince(generationTimeStart) * 1000
            let out = ForecastapiResult(
                latitude: reader.modelLat,
                longitude: reader.modelLon,
                elevation: nil,
                generationtime_ms: generationTimeMs,
                utc_offset_seconds: time.utcOffsetSeconds,
                timezone: timezone,
                current_weather: nil,
                sections: [hourly /*, daily*/].compactMap({$0}),
                timeformat: params.timeformatOrDefault
            )
            return req.eventLoop.makeSucceededFuture(try out.response(format: params.format ?? .json))
        } catch {
            return req.eventLoop.makeFailedFuture(error)
        }
    }
}

/// TODO can later be used for air quality index
enum CamsVariableDerived: String, Codable, GenericVariableMixable {
    case none
    
    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
}

struct CamsReader: GenericReaderDerivedSimple, GenericReaderMixable {
    typealias Domain = CamsDomain
    
    typealias Raw = CamsVariable
    
    typealias Derived = CamsVariableDerived
    
    var reader: GenericReaderCached<CamsDomain, CamsVariable>
    
    func get(derived: CamsVariableDerived, time: TimerangeDt) throws -> DataAndUnit {
        fatalError()
    }
    
    func prefetchData(derived: CamsVariableDerived, time: TimerangeDt) throws {
        fatalError()
    }
}

typealias CamsMixer = GenericReaderMixer<CamsReader>

struct CamsQuery: Content, QueryWithStartEndDateTimeZone {
    let latitude: Float
    let longitude: Float
    let hourly: [VariableOrDerived<CamsVariable, CamsVariableDerived>]?
    //let daily: [CamsVariableDaily]?
    //let temperature_unit: TemperatureUnit?
    //let windspeed_unit: WindspeedUnit?
    //let precipitation_unit: PrecipitationUnit?
    let timeformat: Timeformat?
    let past_days: Int?
    let format: ForecastResultFormat?
    let timezone: String?
    let domains: Domain?
    
    /// iso starting date `2022-02-01`
    let start_date: IsoDate?
    /// included end date `2022-06-01`
    let end_date: IsoDate?
    
    func validate() throws {
        if latitude > 90 || latitude < -90 || latitude.isNaN {
            throw ForecastapiError.latitudeMustBeInRangeOfMinus90to90(given: latitude)
        }
        if longitude > 180 || longitude < -180 || longitude.isNaN {
            throw ForecastapiError.longitudeMustBeInRangeOfMinus180to180(given: longitude)
        }
        /*if daily?.count ?? 0 > 0 && timezone == nil {
            throw ForecastapiError.timezoneRequired
        }*/
    }
    
    var timeformatOrDefault: Timeformat {
        return timeformat ?? .iso8601
    }
}

extension CamsQuery {
    enum Domain: String, Codable {
        case auto
        case cams_global
        case cams_europe
        
        var camsDomains: [CamsDomain] {
            switch self {
            case .auto:
                return CamsDomain.allCases
            case .cams_global:
                return [.cams_global]
            case .cams_europe:
                return [.cams_europe]
            }
        }
    }
}
