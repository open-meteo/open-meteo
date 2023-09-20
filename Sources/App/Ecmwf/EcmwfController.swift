import Foundation
import Vapor


struct EcmwfController {
    func query(_ req: Request) throws -> EventLoopFuture<Response> {
        try req.ensureSubdomain("api")
        let params = try req.query.decode(ApiQueryParameter.self)
        let currentTime = Timestamp.now()
        let allowedRange = Timestamp(2022, 6, 8) ..< currentTime.add(86400 * 16)
        
        let prepared = try params.prepareCoordinates(allowTimezones: false)
        let paramsHourly = try EcmwfHourlyVariable.load(commaSeparatedOptional: params.hourly)
        let nVariables = (paramsHourly?.count ?? 0)
        
        let result = ForecastapiResultSet(timeformat: params.timeformatOrDefault, results: try prepared.map { prepared in
            let coordinates = prepared.coordinate
            let timezone = prepared.timezone
            let time = try params.getTimerange(timezone: timezone, current: currentTime, forecastDays: params.forecast_days ?? 10, forecastDaysMax: 14, startEndDate: prepared.startEndDate, allowedRange: allowedRange, pastDaysMax: 92)
            /// For fractional timezones, shift data to show only for full timestamps
            let utcOffsetShift = time.utcOffsetSeconds - timezone.utcOffsetSeconds
            let hourlyTime = time.range.range(dtSeconds: 3600 * 3)
            
            guard let reader = try EcmwfReader(domain: EcmwfDomain.ifs04, lat: coordinates.latitude, lon: coordinates.longitude, elevation: coordinates.elevation, mode: params.cell_selection ?? .land) else {
                throw ForecastapiError.noDataAvilableForThisLocation
            }
            
            return ForecastapiResult(
                latitude: reader.reader.modelLat,
                longitude: reader.reader.modelLon,
                elevation: reader.reader.targetElevation,
                timezone: timezone,
                time: time,
                prefetch: {
                    if let hourlyVariables = paramsHourly {
                        for variable in hourlyVariables {
                            switch variable {
                            case .raw(let raw):
                                try reader.prefetchData(variable: .raw(.init(raw, 0)), time: hourlyTime)
                            case .derived(let derived):
                                try reader.prefetchData(variable: .derived(.init(derived, 0)), time: hourlyTime)
                            }
                            
                        }
                    }
                },
                current_weather: nil,
                current: nil,
                hourly: paramsHourly.map { variables in
                    return {
                        var res = [ApiColumn]()
                        res.reserveCapacity(variables.count)
                        for variable in variables {
                            switch variable {
                            case .raw(let raw):
                                res.append(try reader.get(variable: .raw(.init(raw, 0)), time: hourlyTime).convertAndRound(params: params).toApi(name: variable.name))
                            case .derived(let derived):
                                res.append(try reader.get(variable: .derived(.init(derived, 0)), time: hourlyTime).convertAndRound(params: params).toApi(name: variable.name))
                            }
                        }
                        return ApiSection(name: "hourly", time: hourlyTime.add(utcOffsetShift), columns: res)
                    }
                },
                daily: nil,
                sixHourly: nil,
                minutely15: nil
            )
        })
        req.incrementRateLimiter(weight: result.calculateQueryWeight(nVariablesModels: nVariables))
        return result.response(format: params.format ?? .json)
    }
}

typealias EcmwfHourlyVariable = VariableOrDerived<EcmwfVariable, EcmwfVariableDerived>
