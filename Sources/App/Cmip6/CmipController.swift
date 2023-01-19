import Foundation
import Vapor


struct CmipController {
    func query(_ req: Request) -> EventLoopFuture<Response> {
        do {
            // API should only be used on the subdomain
            if req.headers[.host].contains(where: { $0.contains("open-meteo.com") && !$0.starts(with: "climate-api.") }) {
                throw Abort.init(.notFound)
            }
            let generationTimeStart = Date()
            let params = try req.query.decode(CmipQuery.self)
            try params.validate()
            let elevationOrDem = try params.elevation ?? Dem90.read(lat: params.latitude, lon: params.longitude)
            
            let allowedRange = Timestamp(1950, 1, 1) ..< Timestamp(2051, 1, 1)
            //let timezone = try params.resolveTimezone()
            let time = try params.getTimerange(allowedRange: allowedRange)
            let hourlyTime = time.range.range(dtSeconds: 3600)
            let dailyTime = time.range.range(dtSeconds: 3600*24)
            
            let domains = params.models ?? [.MRI_AGCM3_2_S]
            
            let readers = try domains.map {
                guard let reader = try Cmip6Reader(domain: $0, lat: params.latitude, lon: params.longitude, elevation: elevationOrDem, mode: .terrainOptimised) else {
                    throw ForecastapiError.noDataAvilableForThisLocation
                }
                return reader
            }
            
            guard !readers.isEmpty else {
                throw ForecastapiError.noDataAvilableForThisLocation
            }

            // Start data prefetch to boooooooost API speed :D
            if let hourlyVariables = params.hourly {
                for reader in readers {
                    try reader.prefetchData(variables: hourlyVariables, time: hourlyTime)
                }
            }
            if let dailyVariables = params.daily {
                for reader in readers {
                    try reader.prefetchData(variables: dailyVariables, time: dailyTime)
                }
            }
            
            
            let hourly: ApiSection? = try params.hourly.map { variables in
                var res = [ApiColumn]()
                res.reserveCapacity(variables.count * readers.count)
                for reader in readers {
                    for variable in variables {
                        let name = readers.count > 1 ? "\(variable.rawValue)_\(reader.domain.rawValue)" : variable.rawValue
                        let d = try reader.get(variable: variable, time: hourlyTime).convertAndRound(params: params).toApi(name: name)
                        assert(hourlyTime.count == d.data.count)
                        res.append(d)
                    }
                }
                return ApiSection(name: "hourly", time: hourlyTime, columns: res)
            }
            let daily: ApiSection? = try params.daily.map { dailyVariables in
                var res = [ApiColumn]()
                res.reserveCapacity(dailyVariables.count * readers.count)
                //var riseSet: (rise: [Timestamp], set: [Timestamp])? = nil
                
                for reader in readers {
                    for variable in dailyVariables {
                        /*if variable == .sunrise || variable == .sunset {
                            // only calculate sunrise/set once
                            let times = riseSet ?? Zensun.calculateSunRiseSet(timeRange: time.range, lat: params.latitude, lon: params.longitude, utcOffsetSeconds: time.utcOffsetSeconds)
                            riseSet = times
                            if variable == .sunset {
                                res.append(ApiColumn(variable: variable.rawValue, unit: params.timeformatOrDefault.unit, data: .timestamp(times.set)))
                            } else {
                                res.append(ApiColumn(variable: variable.rawValue, unit: params.timeformatOrDefault.unit, data: .timestamp(times.rise)))
                            }
                            continue
                        }*/
                        let name = readers.count > 1 ? "\(variable.rawValue)_\(reader.domain.rawValue)" : variable.rawValue
                        let d = try reader.get(variable: variable, time: dailyTime).toApi(name: name)
                        // TODO: reanble
                        //assert(dailyTime.count == d.data.count)
                        res.append(d)
                    }
                }
                
                return ApiSection(name: "daily", time: dailyTime, columns: res)
            }
            
            let generationTimeMs = Date().timeIntervalSince(generationTimeStart) * 1000
            let out = ForecastapiResult(
                latitude: readers[0].modelLat,
                longitude: readers[0].modelLon,
                elevation: readers[0].targetElevation,
                generationtime_ms: generationTimeMs,
                utc_offset_seconds: time.utcOffsetSeconds,
                timezone: TimeZone(identifier: "GMT")!,
                current_weather: nil,
                sections: [hourly, daily].compactMap({$0}),
                timeformat: params.timeformatOrDefault
            )
            //let response = Response()
            //try response.content.encode(out, as: .json)

            return req.eventLoop.makeSucceededFuture(try out.response(format: params.format ?? .json))
        } catch {
            return req.eventLoop.makeFailedFuture(error)
        }
    }
}

extension Cmip6Domain: MultiDomainMixerDomain {
    func getReader(lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode) throws -> [any GenericReaderMixable] {
        fatalError()
    }
}

enum Cmip6VariableDerived: String, Codable, GenericVariableMixable {
    case snowfall_sum
    case rain_sum
    case temperature_2m_max_qdm
    case temperature_2m_max_linear
    case temperature_2m_max_reference
    case temperature_2m_max_trend
    
    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
}

typealias Cmip6VariableOrDerived = VariableOrDerived<Cmip6Variable, Cmip6VariableDerived>

extension Sequence where Element == (Float, Float) {
    func rmse() -> Float {
        var count = 0
        var sum = Float(0)
        for v in self {
            sum += abs(v.0 - v.1)
            count += 1
        }
        return sqrt(sum / Float(count))
    }
    func meanError() -> Float {
        var count = 0
        var sum = Float(0)
        for v in self {
            sum += v.0 - v.1
            count += 1
        }
        return sum / Float(count)
    }
}

extension Sequence where Element == Float {
    func accumulateCount(below threshold: Float) -> [Float] {
        var count: Float = 0
        return self.map( {
            if $0 < threshold {
                count += 1
            }
            return count
        })
    }
}

extension Sequence where Element == (Timestamp, Float) {
    /// With weighted coorections:
    /// Linear bias projected rmse: 0.42046037
    /// Linear bias projected me: 0.0006844627
    /// without
    /// Linear bias projected rmse: 0.41812837
    /// Linear bias projected me: 0.00029334115
    func meanPerMonth(binsPerYear: Int) -> [Float] {
        var sums = [Float](repeating: 0, count: binsPerYear)
        var weights = [Float](repeating: 0, count: binsPerYear)
        for (t, v) in self {
            let fractionalDayOfYear = ((t.timeIntervalSince1970 % 31_557_600) + 31_557_600) % 31_557_600
            let monthBin = fractionalDayOfYear / (31_557_600 / binsPerYear)
            let fraction = Float(fractionalDayOfYear).truncatingRemainder(dividingBy: Float(31_557_600 / binsPerYear)) / Float(31_557_600 / binsPerYear)
            sums[monthBin] += v * (1-fraction)
            weights[monthBin] += (1-fraction)
            sums[(monthBin+1) % binsPerYear] += v * fraction
            weights[(monthBin+1) % binsPerYear] += fraction
        }
        return zip(weights, sums).map({ $0.0 <= 0.001 ? .nan : $0.1 / $0.0 })
    }
}

struct Cmip6Reader: GenericReaderDerivedSimple, GenericReaderMixable {
    typealias MixingVar = Cmip6VariableOrDerived
    
    typealias Domain = Cmip6Domain
    
    typealias Variable = Cmip6Variable
    
    typealias Derived = Cmip6VariableDerived
    
    var reader: GenericReaderCached<Cmip6Domain, Cmip6Variable>
    
    func get(derived: Cmip6VariableDerived, time: TimerangeDt) throws -> DataAndUnit {
        /*let referenceTime = TimerangeDt(start: Timestamp(1959,1,1), to: Timestamp(1995,1,1), dtSeconds: 24*3600)
        let forecastTime = TimerangeDt(start: Timestamp(1995,1,1), to: Timestamp(2015,1,1), dtSeconds: 24*3600)*/
        let breakyear = 2000
        let referenceTime = TimerangeDt(start: Timestamp(1959,1,1), to: Timestamp(breakyear,1,1), dtSeconds: 24*3600)
        let forecastTime = TimerangeDt(start: Timestamp(breakyear,1,1), to: Timestamp(2050,1,1), dtSeconds: 24*3600)
        let qcTime = TimerangeDt(start: Timestamp(breakyear,1,1), to: Timestamp(2022,1,1), dtSeconds: 24*3600)
                
        switch derived {
        case .temperature_2m_max_trend:
            let temp = try get(raw: .temperature_2m_max, time: time).data
            
            var sumx = 0
            var sumxsq = 0
            var sumy: Float = 0
            var sumxy: Float = 0
            
            for (i, t) in temp.enumerated() {
                sumx=sumx+i;
                sumxsq=sumxsq+(i*i);
                sumy=sumy+t;
                sumxy=sumxy+Float(i)*t;
            }
            let d=Float(temp.count*sumxsq-sumx*sumx)
            let m=(Float(temp.count)*sumxy-Float(sumx)*sumy)/d
            let c=(sumy*Float(sumxsq)-Float(sumx)*sumxy)/d
            
            return DataAndUnit(temp.indices.map { Float($0) * m + c }, .celsius)
            
        case .temperature_2m_max_qdm:
            let control = try get(raw: .temperature_2m_max, time: referenceTime).data
            let era5Reader = try Era5Reader(domain: .era5_land, lat: reader.modelLat, lon: reader.modelLon, elevation: reader.modelElevation, mode: .terrainOptimised)!
            let reference = try era5Reader.get(raw: .temperature_2m, time: referenceTime.with(dtSeconds: 3600)).data.max(by: 24)
            
            /*let forecast = try get(raw: .temperature_2m_max, time: forecastTime).data
            let start = DispatchTime.now()
            let correctedControl = BiasCorrection.quantileDeltaMappingMonthly(reference: ArraySlice(reference), control: ArraySlice(control), referenceTime: referenceTime, forecast: ArraySlice(control), forecastTime: referenceTime, type: .absoluteChage)
            let correctedForecast = BiasCorrection.quantileDeltaMappingMonthly(reference: ArraySlice(reference), control: ArraySlice(control), referenceTime: referenceTime, forecast: ArraySlice(forecast), forecastTime: forecastTime, type: .absoluteChage)
            print("QDM time \(start.timeElapsedPretty())")
            
            print("QDM control rmse: \(zip(reference, correctedControl).rmse())")
            print("QDM control error: \(zip(reference, correctedControl).meanError())")
            
            let era5projectedTime = try era5Reader.get(raw: .temperature_2m, time: forecastTime.with(dtSeconds: 3600)).data.max(by: 24)
            print("QDM projected rmse: \(zip(era5projectedTime, correctedForecast).rmse())")
            print("QDM projected error: \(zip(era5projectedTime, correctedForecast).meanError())")
             
            return DataAndUnit(correctedControl + correctedForecast, .celsius)*/
            
            let forecast = try get(raw: .temperature_2m_max, time: time).data
            let start = DispatchTime.now()
            let correctedForecast = BiasCorrection.quantileDeltaMappingMonthly(reference: ArraySlice(reference), control: ArraySlice(control), referenceTime: referenceTime, forecast: ArraySlice(forecast), forecastTime: time, type: .absoluteChage)
            print("QDM time \(start.timeElapsedPretty())")
            
            let qc = try era5Reader.get(raw: .temperature_2m, time: qcTime.with(dtSeconds: 3600)).data.max(by: 24)
            let reference2 = reference
            let control2 = control
            let correctedForecast2 = correctedForecast
            
            print("Raw control rmse: \(zip(reference2, control2).rmse())")
            print("Raw control me: \(zip(reference2, control2).meanError())")
            
            print("QDM projected rmse: \(zip(reference2, correctedForecast2).rmse())")
            print("QDM projected me: \(zip(reference2, correctedForecast2).meanError())")
            
            print("QDM qctime rmse: \(zip(qc, correctedForecast2[reference.count ..< reference.count + qc.count]).rmse())")
            print("QDM qctime me: \(zip(qc, correctedForecast2[reference.count ..< reference.count + qc.count]).meanError())")
            
            
            print(">30°C QDM projected rmse: \(zip(reference2.map{$0 > 30 ? 1 : 0}, correctedForecast2.map{$0 > 30 ? 1 : 0}).rmse())")
            print(">30°C QDM projected me: \(zip(reference2.map{$0 > 30 ? 1 : 0}, correctedForecast2.map{$0 > 30 ? 1 : 0}).meanError())")
            
            print(">30°C QDM qctime rmse: \(zip(qc.map{$0 > 30 ? 1 : 0}, correctedForecast2[reference.count ..< reference.count + qc.count].map{$0 > 30 ? 1 : 0}).rmse())")
            print(">30°C QDM qctime me: \(zip(qc.map{$0 > 30 ? 1 : 0}, correctedForecast2[reference.count ..< reference.count + qc.count].map{$0 > 30 ? 1 : 0}).meanError())")
            
            return DataAndUnit(correctedForecast2, .celsius)
            
        case .temperature_2m_max_linear:
            let control = try get(raw: .temperature_2m_max, time: referenceTime).data
            let era5Reader = try Era5Reader(domain: .era5_land, lat: reader.modelLat, lon: reader.modelLon, elevation: reader.modelElevation, mode: .nearest)!
            let reference = try era5Reader.get(raw: .temperature_2m, time: referenceTime.with(dtSeconds: 3600)).data.max(by: 24)
            
            let forecast = try get(raw: .temperature_2m_max, time: time).data
            let start = DispatchTime.now()
            let offset = control.reduce(0, +) / Float(control.count) - reference.reduce(0, +) / Float(reference.count)
            
            let binsPerYear = 12
            let mean = zip(zip(referenceTime, reference).meanPerMonth(binsPerYear: binsPerYear), zip(referenceTime, control).meanPerMonth(binsPerYear: binsPerYear)).map(-)
            print("Monthly offsets: \(mean)")
            
            print("Linear correction coef: \(offset)")
            
            let correctedForecast = zip(time, forecast).map { (t,v) in
                let fractionalDayOfYear = ((t.timeIntervalSince1970 % 31_557_600) + 31_557_600) % 31_557_600
                let monthBin = fractionalDayOfYear / (31_557_600 / binsPerYear)
                let fraction = Float(fractionalDayOfYear).truncatingRemainder(dividingBy: Float(31_557_600 / binsPerYear)) / Float(31_557_600 / binsPerYear)
                return v + mean[monthBin] * (1-fraction) + mean[(monthBin+1) % binsPerYear] * fraction
            }
            print("Linear bias time \(start.timeElapsedPretty())")
            
            let reference2 = reference
            let correctedForecast2 = correctedForecast
            let qc = try era5Reader.get(raw: .temperature_2m, time: qcTime.with(dtSeconds: 3600)).data.max(by: 24)
            
            print("Linear bias projected rmse: \(zip(reference2, correctedForecast2).rmse())")
            print("Linear bias projected me: \(zip(reference2, correctedForecast2).meanError())")
            print("Linear bias qctime rmse: \(zip(qc, correctedForecast2[reference.count ..< reference.count + qc.count]).rmse())")
            print("Linear bias qctime me: \(zip(qc, correctedForecast2[reference.count ..< reference.count + qc.count]).meanError())")
            
            print(">30°C Linear bias projected rmse: \(zip(reference2.map{$0 > 30 ? 1 : 0}, correctedForecast2.map{$0 > 30 ? 1 : 0}).rmse())")
            print(">30°C Linear bias projected me: \(zip(reference2.map{$0 > 30 ? 1 : 0}, correctedForecast2.map{$0 > 30 ? 1 : 0}).meanError())")
            print(">30°C Linear bias qctime rmse: \(zip(qc.map{$0 > 30 ? 1 : 0}, correctedForecast2[reference.count ..< reference.count + qc.count].map{$0 > 30 ? 1 : 0}).rmse())")
            print(">30°C Linear bias qctime me: \(zip(qc.map{$0 > 30 ? 1 : 0}, correctedForecast2[reference.count ..< reference.count + qc.count].map{$0 > 30 ? 1 : 0}).meanError())")
            
            return DataAndUnit(correctedForecast2, .celsius)
            
        case .snowfall_sum:
            let snowwater = try get(raw: .snowfall_water_equivalent_sum, time: time).data
            let snowfall = snowwater.map { $0 * 0.7 }
            return DataAndUnit(snowfall, .centimeter)
        case .rain_sum:
            let snowwater = try get(raw: .snowfall_water_equivalent_sum, time: time)
            let precip = try get(raw: .precipitation_sum, time: time)
            let rain = zip(precip.data, snowwater.data).map({
                return max($0.0-$0.1, 0)
            })
            return DataAndUnit(rain, precip.unit)
        case .temperature_2m_max_reference:
            let era5Reader = try Era5Reader(domain: .era5_land, lat: reader.modelLat, lon: reader.modelLon, elevation: .nan, mode: .nearest)!
            let reference = try era5Reader.get(raw: .temperature_2m, time: time.with(dtSeconds: 3600)).data.max(by: 24)
            return DataAndUnit(reference, .celsius)
        }
    }
    
    func prefetchData(derived: Cmip6VariableDerived, time: TimerangeDt) throws {
        switch derived {
        case .temperature_2m_max_linear:
            break
        case .temperature_2m_max_reference:
            break
        case .temperature_2m_max_qdm:
            break
        case .temperature_2m_max_trend:
            break
        case .snowfall_sum:
            try prefetchData(raw: .snowfall_water_equivalent_sum, time: time)
        case .rain_sum:
            try prefetchData(raw: .precipitation_sum, time: time)
            try prefetchData(raw: .snowfall_water_equivalent_sum, time: time)
        }
    }
}

struct CmipQuery: Content, QueryWithTimezone, ApiUnitsSelectable {
    let latitude: Float
    let longitude: Float
    let hourly: [Cmip6VariableOrDerived]?
    let daily: [Cmip6VariableOrDerived]?
    //let current_weather: Bool?
    let elevation: Float?
    //let timezone: String?
    let temperature_unit: TemperatureUnit?
    let windspeed_unit: WindspeedUnit?
    let precipitation_unit: PrecipitationUnit?
    let timeformat: Timeformat?
    let format: ForecastResultFormat?
    
    /// not used, because only daily data
    let timezone: String?
    let models: [Cmip6Domain]?
    
    /// iso starting date `2022-02-01`
    let start_date: IsoDate
    /// included end date `2022-06-01`
    let end_date: IsoDate
    
    func validate() throws {
        if latitude > 90 || latitude < -90 || latitude.isNaN {
            throw ForecastapiError.latitudeMustBeInRangeOfMinus90to90(given: latitude)
        }
        if longitude > 180 || longitude < -180 || longitude.isNaN {
            throw ForecastapiError.longitudeMustBeInRangeOfMinus180to180(given: longitude)
        }
        guard end_date.date >= start_date.date else {
            throw ForecastapiError.enddateMustBeLargerEqualsThanStartdate
        }
        guard start_date.year >= 1950, start_date.year <= 2050 else {
            throw ForecastapiError.dateOutOfRange(parameter: "start_date", allowed: Timestamp(1950,1,1)..<Timestamp(2050,1,1))
        }
        guard end_date.year >= 1950, end_date.year <= 2050 else {
            throw ForecastapiError.dateOutOfRange(parameter: "end_date", allowed: Timestamp(1950,1,1)..<Timestamp(2050,1,1))
        }
        //if daily?.count ?? 0 > 0 && timezone == nil {
            //throw ForecastapiError.timezoneRequired
        //}
    }
    
    func getTimerange(allowedRange: Range<Timestamp>) throws -> TimerangeLocal {
        let start = start_date.toTimestamp()
        let includedEnd = end_date.toTimestamp()
        guard includedEnd.timeIntervalSince1970 >= start.timeIntervalSince1970 else {
            throw ForecastapiError.enddateMustBeLargerEqualsThanStartdate
        }
        guard allowedRange.contains(start) else {
            throw ForecastapiError.dateOutOfRange(parameter: "start_date", allowed: allowedRange)
        }
        guard allowedRange.contains(includedEnd) else {
            throw ForecastapiError.dateOutOfRange(parameter: "end_date", allowed: allowedRange)
        }
        return TimerangeLocal(range: start ..< includedEnd.add(86400), utcOffsetSeconds: 0)
    }
    
    var timeformatOrDefault: Timeformat {
        return timeformat ?? .iso8601
    }
    
    /*func getUtcOffsetSeconds() throws -> Int {
        guard let timezone = timezone else {
            return 0
        }
        guard let tz = TimeZone(identifier: timezone) else {
            throw ForecastapiError.invalidTimezone
        }
        return (tz.secondsFromGMT() / 3600) * 3600
    }*/
}
