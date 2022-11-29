import Foundation
import Vapor

struct GloFasMixer: GenericReaderMixer {
    var reader: [GenericReader<GloFasDomain, GloFasVariable>]
}

extension GloFasVariable: GenericVariableMixable {
    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
}

struct GloFasController {
    func query(_ req: Request) -> EventLoopFuture<Response> {
        do {
            // API should only be used on the subdomain
            if req.headers[.host].contains(where: { $0.contains("open-meteo.com") && !$0.starts(with: "flood-api.") }) {
                throw Abort.init(.notFound)
            }
            let generationTimeStart = Date()
            let params = try req.query.decode(GloFasQuery.self)
            try params.validate()
            let currentTime = Timestamp.now()
            
            /// Will be configurable by API later
            //let domain = GloFasDomain.consolidated
            //let members = 1..<domain.nMembers+1
            
            let allowedRange = Timestamp(1984, 1, 1) ..< currentTime.add(86400 * 32)
            let timezone = try params.resolveTimezone()
            let time = try params.getTimerange(timezone: timezone, current: currentTime, forecastDays: params.forecast_days ?? 92, allowedRange: allowedRange)
            let dailyTime = time.range.range(dtSeconds: 3600*24)
            
            let domains = params.models ?? [.consolidated_v4]
            
            let readers = try domains.compactMap {
                try GenericReaderMulti<GloFasVariable>(domain: $0, lat: params.latitude, lon: params.longitude, elevation: .nan, mode: .nearest)
            }
            
            guard !readers.isEmpty else {
                throw ForecastapiError.noDataAvilableForThisLocation
            }
            
            
            // Start data prefetch to boooooooost API speed :D
            for reader in readers {
                try reader.prefetchData(variables: params.daily, time: dailyTime)
            }
            
            let daily = ApiSection(name: "daily", time: dailyTime, columns: try params.daily.flatMap { variable in
                try readers.compactMap { reader in
                    let name = readers.count > 1 ? "\(variable.rawValue)_\(reader.domain.rawValue)" : variable.rawValue
                    guard let d = try reader.get(variable: variable, time: dailyTime)?.convertAndRound(temperatureUnit: .celsius, windspeedUnit: .ms, precipitationUnit: .mm).toApi(name: name) else {
                        return nil
                    }
                    assert(dailyTime.count == d.data.count, "days \(dailyTime.count), values \(d.data.count)")
                    return d
                }
            })
            
            let generationTimeMs = Date().timeIntervalSince(generationTimeStart) * 1000
            let out = ForecastapiResult(
                latitude: readers[0].modelLat,
                longitude: readers[0].modelLon,
                elevation: nil,
                generationtime_ms: generationTimeMs,
                utc_offset_seconds: time.utcOffsetSeconds,
                timezone: timezone,
                current_weather: nil,
                sections: [daily],
                timeformat: params.timeformatOrDefault
            )
            return req.eventLoop.makeSucceededFuture(try out.response(format: params.format ?? .json))
        } catch {
            return req.eventLoop.makeFailedFuture(error)
        }
    }
}

enum GlofasDomainApi: String, Codable, CaseIterable, MultiDomainMixerDomain {
    case seamless_v3
    case forecast_v3
    case consolidated_v3
    
    case consolidated_v4
    
    /// Return the required readers for this domain configuration
    /// Note: last reader has highes resolution data
    func getReader(lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode) throws -> [any GenericReaderMixable] {
        switch self {
        case .seamless_v3:
            return try GloFasMixer(domains: [.forecastv3, .intermediatev3, .consolidatedv3], lat: lat, lon: lon, elevation: elevation, mode: mode)?.reader ?? []
        case .forecast_v3:
            return try GloFasMixer(domains: [.forecastv3, .intermediatev3], lat: lat, lon: lon, elevation: elevation, mode: mode)?.reader ?? []
        case .consolidated_v3:
            return try GenericReader<GloFasDomain, GloFasVariable>(domain: .consolidatedv3, lat: lat, lon: lon, elevation: elevation, mode: mode).flatMap({[$0]}) ?? []
        case .consolidated_v4:
            return try GenericReader<GloFasDomain, GloFasVariable>(domain: .consolidated, lat: lat, lon: lon, elevation: elevation, mode: mode).flatMap({[$0]}) ?? []
        }
    }
}

struct GloFasQuery: Content, QueryWithStartEndDateTimeZone {
    let latitude: Float
    let longitude: Float
    let daily: [GloFasVariable]
    let timeformat: Timeformat?
    let past_days: Int?
    let forecast_days: Int?
    let format: ForecastResultFormat?
    let timezone: String?
    let models: [GlofasDomainApi]?
    
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
        if let timezone = timezone, !timezone.isEmpty {
            throw ForecastapiError.timezoneNotSupported
        }
        if let forecast_days = forecast_days, forecast_days <= 0 || forecast_days >= 367 {
            throw ForecastapiError.forecastDaysInvalid(given: forecast_days, allowed: 0...366)
        }
    }
    
    var timeformatOrDefault: Timeformat {
        return timeformat ?? .iso8601
    }
}
