import Foundation
import Vapor

typealias SeasonalForecastVariable = VariableOrDerived<CfsVariable, CfsVariableDerived>

typealias SeasonalForecastReader = GenericReader<SeasonalForecastDomain, CfsVariable>

enum SeasonalForecastDomainApi: String, RawRepresentableString, CaseIterable, Sendable {
    case cfsv2

    var forecastDomain: SeasonalForecastDomain {
        switch self {
        case .cfsv2:
            return .ncep
        }
    }
}

enum CfsVariableDerived: String, RawRepresentableString {
    case windspeed_10m
    case winddirection_10m
    case wind_speed_10m
    case wind_direction_10m
    case cloudcover
    case relativehumidity_2m
}

enum DailyCfsVariable: String, RawRepresentableString {
    case temperature_2m_max
    case temperature_2m_min
    case precipitation_sum
    // case rain_sum
    case showers_sum
    case shortwave_radiation_sum
    case windspeed_10m_max
    case winddirection_10m_dominant
    case wind_speed_10m_max
    case wind_direction_10m_dominant
    case precipitation_hours
}

extension SeasonalForecastReader {
    func prefetchData(variable: SeasonalForecastVariable, time: TimerangeDtAndSettings) async throws {
        switch variable {
        case .raw(let variable):
            try await prefetchData(variable: variable, time: time)
        case .derived(let variable):
            switch variable {
            case .windspeed_10m, .wind_speed_10m, .winddirection_10m, .wind_direction_10m:
                try await prefetchData(variable: .wind_u_component_10m, time: time)
                try await prefetchData(variable: .wind_v_component_10m, time: time)
            case .cloudcover:
                try await prefetchData(variable: .cloud_cover, time: time)
            case .relativehumidity_2m:
                try await prefetchData(variable: .relative_humidity_2m, time: time)
            }
        }
    }

    func get(variable: SeasonalForecastVariable, time: TimerangeDtAndSettings) async throws -> DataAndUnit {
        switch variable {
        case .raw(let variable):
            return try await get(variable: variable, time: time)
        case .derived(let variable):
            switch variable {
            case .windspeed_10m, .wind_speed_10m:
                let u = try await get(variable: .wind_u_component_10m, time: time)
                let v = try await get(variable: .wind_v_component_10m, time: time)
                let speed = zip(u.data, v.data).map(Meteorology.windspeed)
                return DataAndUnit(speed, u.unit)
            case .winddirection_10m, .wind_direction_10m:
                let u = try await get(variable: .wind_u_component_10m, time: time)
                let v = try await get(variable: .wind_v_component_10m, time: time)
                let direction = Meteorology.windirectionFast(u: u.data, v: v.data)
                return DataAndUnit(direction, .degreeDirection)
            case .cloudcover:
                return try await get(variable: .cloud_cover, time: time)
            case .relativehumidity_2m:
                return try await get(variable: .relative_humidity_2m, time: time)
            }
        }
    }

    func prefetchData(variable: DailyCfsVariable, time timeDaily: TimerangeDtAndSettings) async throws {
        let time = timeDaily.with(dtSeconds: modelDtSeconds)
        switch variable {
        case .temperature_2m_max:
            try await prefetchData(variable: CfsVariable.temperature_2m_max, time: time)
        case .temperature_2m_min:
            try await prefetchData(variable: CfsVariable.temperature_2m_min, time: time)
        case .precipitation_sum:
            try await prefetchData(variable: .precipitation, time: time)
        case .showers_sum:
            try await prefetchData(variable: .showers, time: time)
        case .shortwave_radiation_sum:
            try await prefetchData(variable: .shortwave_radiation, time: time)
        case .windspeed_10m_max, .wind_speed_10m_max, .winddirection_10m_dominant, .wind_direction_10m_dominant:
            try await prefetchData(variable: .wind_u_component_10m, time: time)
            try await prefetchData(variable: .wind_v_component_10m, time: time)
        case .precipitation_hours:
            try await prefetchData(variable: .precipitation, time: time)
        }
    }

    func getDaily(variable: DailyCfsVariable, params: ApiQueryParameter, time timeDaily: TimerangeDtAndSettings) async throws -> DataAndUnit {
        let time = timeDaily.with(dtSeconds: modelDtSeconds)
        switch variable {
        case .temperature_2m_max:
            let data = try await get(variable: .temperature_2m_max, time: time).convertAndRound(params: params)
            return DataAndUnit(data.data.max(by: 4), data.unit)
        case .temperature_2m_min:
            let data = try await get(variable: .temperature_2m_min, time: time).convertAndRound(params: params)
            return DataAndUnit(data.data.min(by: 4), data.unit)
        case .precipitation_sum:
            let data = try await get(variable: .precipitation, time: time).convertAndRound(params: params)
            return DataAndUnit(data.data.sum(by: 4), data.unit)
        case .showers_sum:
            let data = try await get(variable: .showers, time: time).convertAndRound(params: params)
            return DataAndUnit(data.data.sum(by: 4), data.unit)
        case .shortwave_radiation_sum:
            let data = try await get(variable: .shortwave_radiation, time: time).convertAndRound(params: params)
            // for 6h data
            return DataAndUnit(data.data.sum(by: 4).map({ $0 * 0.0036 * 6 }).round(digits: 2), .megajoulePerSquareMetre)
        case .windspeed_10m_max, .wind_speed_10m_max:
            let data = try await get(variable: .derived(.windspeed_10m), time: time).convertAndRound(params: params)
            return DataAndUnit(data.data.max(by: 4), data.unit)
        case .winddirection_10m_dominant, .wind_direction_10m_dominant:
            let u = try await get(variable: .wind_u_component_10m, time: time).data.sum(by: 4)
            let v = try await get(variable: .wind_v_component_10m, time: time).data.sum(by: 4)
            let direction = Meteorology.windirectionFast(u: u, v: v)
            return DataAndUnit(direction, .degreeDirection)
        case .precipitation_hours:
            let data = try await get(variable: .precipitation, time: time).convertAndRound(params: params)
            return DataAndUnit(data.data.map({ $0 > 0.001 ? 1 : 0 }).sum(by: 4), .hours)
        }
    }
}

/**
 TODO:
 - integrate more providers
 - more daily data
 */
struct SeasonalForecastController {
    func query(_ req: Request) async throws -> Response {
        try await req.withApiParameter("seasonal-api") { _, params in
            let currentTime = Timestamp.now()
            let allowedRange = Timestamp(2022, 6, 8) ..< currentTime.add(86400 * 400)
            let logger = req.logger
            let httpClient = req.application.http.client.shared

            let prepared = try await params.prepareCoordinates(allowTimezones: false, logger: logger, httpClient: httpClient)
            guard case .coordinates(let prepared) = prepared else {
                throw ForecastapiError.generic(message: "Bounding box not supported")
            }
            /// Will be configurable by API later
            let domains = [SeasonalForecastDomainApi.cfsv2]

            let paramsSixHourly = try SeasonalForecastVariable.load(commaSeparatedOptional: params.six_hourly)
            let paramsDaily = try DailyCfsVariable.load(commaSeparatedOptional: params.daily)
            let nVariables = ((paramsSixHourly?.count ?? 0) + (paramsDaily?.count ?? 0)) * domains.reduce(0, { $0 + $1.forecastDomain.nMembers })
            let options = try params.readerOptions(logger: logger, httpClient: httpClient)

            let locations: [ForecastapiResult<SeasonalForecastDomainApi>.PerLocation] = try await prepared.asyncMap { prepared in
                let coordinates = prepared.coordinate
                let timezone = prepared.timezone
                let time = try params.getTimerange2(timezone: timezone, current: currentTime, forecastDaysDefault: 92, forecastDaysMax: 366, startEndDate: prepared.startEndDate, allowedRange: allowedRange, pastDaysMax: 92)
                let timeLocal = TimerangeLocal(range: time.dailyRead.range, utcOffsetSeconds: timezone.utcOffsetSeconds)

                let timeSixHourlyRead = time.dailyRead.with(dtSeconds: 3600 * 6)
                let timeSixHourlyDisplay = time.dailyDisplay.with(dtSeconds: 3600 * 6)

                let readers: [ForecastapiResult<SeasonalForecastDomainApi>.PerModel] = try await domains.asyncCompactMap { domain in
                    guard let reader = try await SeasonalForecastReader(domain: domain.forecastDomain, lat: coordinates.latitude, lon: coordinates.longitude, elevation: coordinates.elevation, mode: params.cell_selection ?? .land, options: options) else {
                        return nil
                    }
                    let members = 1..<domain.forecastDomain.nMembers + 1
                    return .init(
                        model: domain,
                        latitude: reader.modelLat,
                        longitude: reader.modelLon,
                        elevation: reader.targetElevation,
                        prefetch: {
                            if let paramsSixHourly {
                                for varible in paramsSixHourly {
                                    for member in members {
                                        try await reader.prefetchData(variable: varible, time: time.dailyRead.toSettings(ensembleMember: member))
                                    }
                                }
                            }
                            if let paramsDaily {
                                for varible in paramsDaily {
                                    for member in members {
                                        try await reader.prefetchData(variable: varible, time: timeSixHourlyRead.toSettings(ensembleMember: member))
                                    }
                                }
                            }
                        },
                        current: nil,
                        hourly: nil,
                        daily: paramsDaily.map { variables in
                            return {
                                return ApiSection<DailyCfsVariable>(name: "daily", time: time.dailyDisplay, columns: try await variables.asyncCompactMap { variable in
                                    var unit: SiUnit?
                                    let allMembers: [ApiArray] = try await members.asyncCompactMap { member in
                                        let d = try await reader.getDaily(variable: variable, params: params, time: time.dailyRead.toSettings(ensembleMember: member))
                                        unit = d.unit
                                        assert(time.dailyRead.count == d.data.count)
                                        return ApiArray.float(d.data)
                                    }
                                    guard allMembers.count > 0 else {
                                        return nil
                                    }
                                    return ApiColumn<DailyCfsVariable>(variable: variable, unit: unit ?? .undefined, variables: allMembers)
                                })
                            }
                        },
                        sixHourly: paramsSixHourly.map { variables in
                            return {
                                return .init(name: "six_hourly", time: timeSixHourlyDisplay, columns: try await variables.asyncCompactMap { variable in
                                    var unit: SiUnit?
                                    let allMembers: [ApiArray] = try await members.asyncCompactMap { member in
                                        let d = try await reader.get(variable: variable, time: timeSixHourlyRead.toSettings(ensembleMember: member)).convertAndRound(params: params)
                                        unit = d.unit
                                        assert(timeSixHourlyRead.count == d.data.count)
                                        return ApiArray.float(d.data)
                                    }
                                    guard allMembers.count > 0 else {
                                        return nil
                                    }
                                    return .init(variable: .surface(variable), unit: unit ?? .undefined, variables: allMembers)
                                })
                            }
                        },
                        minutely15: nil
                    )
                }
                guard !readers.isEmpty else {
                    throw ForecastapiError.noDataAvilableForThisLocation
                }
                return .init(timezone: timezone, time: timeLocal, locationId: coordinates.locationId, results: readers)
            }
            return ForecastapiResult<SeasonalForecastDomainApi>(timeformat: params.timeformatOrDefault, results: locations, nVariablesTimesDomains: nVariables)
        }
    }
}
