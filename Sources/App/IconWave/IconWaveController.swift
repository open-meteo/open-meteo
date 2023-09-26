import Foundation
import Vapor


struct IconWaveController {
    func query(_ req: Request) throws -> EventLoopFuture<Response> {
        fatalError()
        /*try req.ensureSubdomain("marine-api")
        let params = try req.query.decode(ApiQueryParameter.self)
        let currentTime = Timestamp.now()
        let allowedRange = Timestamp(2022, 7, 29) ..< currentTime.add(86400 * 11)
        
        let prepared = try params.prepareCoordinates(allowTimezones: true)
        let paramsHourly = try IconWaveVariable.load(commaSeparatedOptional: params.hourly)
        let paramsDaily = try IconWaveVariableDaily.load(commaSeparatedOptional: params.daily)
        let nVariables = (paramsHourly?.count ?? 0) * (paramsDaily?.count ?? 0)
        
        let result = ForecastapiResultSet(timeformat: params.timeformatOrDefault, results: try prepared.map { prepared in
            let coordinates = prepared.coordinate
            let timezone = prepared.timezone
            let time = try params.getTimerange(timezone: timezone, current: currentTime, forecastDays: params.forecast_days ?? 7, forecastDaysMax: 14, startEndDate: prepared.startEndDate, allowedRange: allowedRange, pastDaysMax: 92)
            /// For fractional timezones, shift data to show only for full timestamps
            let utcOffsetShift = time.utcOffsetSeconds - timezone.utcOffsetSeconds
            let hourlyTime = time.range.range(dtSeconds: 3600)
            let dailyTime = time.range.range(dtSeconds: 3600*24)
            
            guard let reader = try IconWaveMixer(domains: IconWaveDomain.allCases, lat: coordinates.latitude, lon: coordinates.longitude, elevation: .nan, mode: params.cell_selection ?? .sea) else {
                throw ForecastapiError.noDataAvilableForThisLocation
            }
            
            return ForecastapiResult(
                latitude: reader.modelLat,
                longitude: reader.modelLon,
                elevation: nil,
                timezone: timezone,
                time: time,
                prefetch: {
                    if let hourlyVariables = paramsHourly {
                        try reader.prefetchData(variables: hourlyVariables, time: hourlyTime)
                    }
                    if let dailyVariables = paramsDaily {
                        try reader.prefetchData(variables: dailyVariables, time: dailyTime)
                    }
                },
                current_weather: nil,
                current: nil,
                hourly:
                    paramsHourly.map { variables in
                        return {
                            var res = [ApiColumn]()
                            res.reserveCapacity(variables.count)
                            for variable in variables {
                                let d = try reader.get(variable: variable, time: hourlyTime).convertAndRound(params: params).toApi(name: variable.rawValue)
                                res.append(d)
                            }
                            return ApiSection(name: "hourly", time: hourlyTime.add(utcOffsetShift), columns: res)
                        }
                    },
                daily: paramsDaily.map { dailyVariables in
                    return {
                        return ApiSection(name: "daily", time: dailyTime.add(utcOffsetShift), columns: try dailyVariables.map { variable in
                            let d = try reader.getDaily(variable: variable, time: dailyTime).convertAndRound(params: params).toApi(name: variable.rawValue)
                            assert(dailyTime.count == d.data.count)
                            return d
                        })
                    }
                },
                sixHourly: nil,
                minutely15: nil
            )
        })
        req.incrementRateLimiter(weight: result.calculateQueryWeight(nVariablesModels: nVariables))
        return result.response(format: params.format ?? .json)*/
    }
}

typealias IconWaveReader = GenericReader<IconWaveDomain, IconWaveVariable>

struct IconWaveMixer: GenericReaderMixer {
    let reader: [IconWaveReader]
    
    static func makeReader(domain: IconWaveDomain, lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode) throws -> IconWaveReader? {
        return try IconWaveReader(domain: domain, lat: lat, lon: lon, elevation: elevation, mode: mode)
    }
}
