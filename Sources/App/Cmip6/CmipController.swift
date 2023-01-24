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
                guard var reader = try Cmip6Reader(domain: $0, lat: params.latitude, lon: params.longitude, elevation: elevationOrDem, mode: .terrainOptimised) else {
                    throw ForecastapiError.noDataAvilableForThisLocation
                }
                reader.lat = params.latitude
                reader.lon = params.longitude
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
    
    case precipitation_qdm
    case precipitation_linear
    
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



struct Cmip6Reader: GenericReaderDerivedSimple, GenericReaderMixable {
    typealias MixingVar = Cmip6VariableOrDerived
    
    typealias Domain = Cmip6Domain
    
    typealias Variable = Cmip6Variable
    
    typealias Derived = Cmip6VariableDerived
    
    var reader: GenericReaderCached<Cmip6Domain, Cmip6Variable>
    
    var lat: Float = 0
    var lon: Float = 0
    
    init(reader: GenericReaderCached<Cmip6Domain, Cmip6Variable>) {
        self.reader = reader
    }

    func get(derived: Cmip6VariableDerived, time: TimerangeDt) throws -> DataAndUnit {
        /*let referenceTime = TimerangeDt(start: Timestamp(1959,1,1), to: Timestamp(1995,1,1), dtSeconds: 24*3600)
        let forecastTime = TimerangeDt(start: Timestamp(1995,1,1), to: Timestamp(2015,1,1), dtSeconds: 24*3600)*/
        let breakyear = 2005
        let referenceTime = TimerangeDt(start: Timestamp(1965,1,1), to: Timestamp(breakyear,1,1), dtSeconds: 24*3600)
        //let forecastTime = TimerangeDt(start: Timestamp(breakyear,1,1), to: Timestamp(2050,1,1), dtSeconds: 24*3600)
        let qcTime = TimerangeDt(start: Timestamp(breakyear,1,1), to: Timestamp(2022,1,1), dtSeconds: 24*3600)
                
        switch derived {
        case .precipitation_qdm:
            let controlAndForecast = try get(raw: .precipitation_sum, time: time).data
            let era5Reader = try Era5Reader(domain: .era5, lat: lat, lon: lon, elevation: reader.targetElevation, mode: .terrainOptimised)!
            var reference = try era5Reader.get(raw: .precipitation, time: referenceTime.with(dtSeconds: 3600)).data.sum(by: 24)
            
            if reference.containsNaN() {
                for i in reference.indices {
                    if reference[i].isNaN {
                        reference[i] = 0
                    }
                }
            }
            if controlAndForecast.containsNaN() {
                fatalError("control contsains NaNs")
            }

            let start = DispatchTime.now()
            let corrected = QuantileDeltaMappingBiasCorrection.quantileDeltaMappingMonthly(
                reference: ArraySlice(reference),
                referenceTime: referenceTime,
                controlAndForecast: ArraySlice(controlAndForecast),
                controlAndForecastTime: time,
                type: .relativeChange
            )
            print("QDM time \(start.timeElapsedPretty())")
            
            let qc = try era5Reader.get(raw: .precipitation, time: qcTime.with(dtSeconds: 3600)).data.sum(by: 24)
            let qcBinsPerYearBy = Float(31_557_600) / 86400 / 1
            
            print("Raw control rmse: \(zip(reference, controlAndForecast).rmse())")
            print("Raw control me: \(zip(reference, controlAndForecast).meanError())")
            
            print("QDM projected rmse: \(zip(reference, corrected).rmse())")
            print("QDM projected me: \(zip(reference, corrected).meanError())")
            
            print("QDM qctime rmse: \(zip(qc, corrected[reference.count ..< reference.count + qc.count]).rmse())")
            print("QDM qctime me: \(zip(qc, corrected[reference.count ..< reference.count + qc.count]).meanError())")
            
            let thres: Float = 15
            let referenceEvents = reference.map{$0 > thres ? 1 : 0}.sum(by: qcBinsPerYearBy)
            let qcEvents = qc.map{$0 > thres ? 1 : 0}.sum(by: qcBinsPerYearBy)
            let forecastEventsQcLength = corrected[reference.count ..< reference.count + qc.count].map{$0 > thres ? 1 : 0}.sum(by: qcBinsPerYearBy)
            let forecastEventsReferenceTime = corrected[0 ..< reference.count].map{$0 > thres ? 1 : 0}.sum(by: qcBinsPerYearBy)
            print("mean per year reference=\(referenceEvents.mean(by: referenceEvents.count)) refForecast=\(forecastEventsReferenceTime.mean(by: forecastEventsReferenceTime.count)) qc=\(qcEvents.mean(by: qcEvents.count)) qcForecast=\(forecastEventsQcLength.mean(by: forecastEventsQcLength.count))")
            print(">\(thres)mm QDM projected rmse: \(zip(referenceEvents, forecastEventsReferenceTime).rmse())")
            print(">\(thres)mm QDM projected me: \(zip(referenceEvents, forecastEventsReferenceTime).meanError())")
            print(">\(thres)mm QDM qctime rmse: \(zip(qcEvents, forecastEventsQcLength).rmse())")
            print(">\(thres)mm QDM qctime me: \(zip(qcEvents, forecastEventsQcLength).meanError())")
            
            return DataAndUnit(corrected, .millimeter)
            
        case .precipitation_linear:
            let control = try get(raw: .precipitation_sum, time: referenceTime).data
            let era5Reader = try Era5Reader(domain: .era5, lat: lat, lon: lon, elevation: reader.targetElevation, mode: .terrainOptimised)!
            var reference = try era5Reader.get(raw: .precipitation, time: referenceTime.with(dtSeconds: 3600)).data.sum(by: 24)
            
            if reference.containsNaN() {
                for i in reference.indices {
                    if reference[i].isNaN {
                        reference[i] = 0
                    }
                }
                //print(reference.firstIndex(where: {$0.isNaN})!)
                //fatalError("reference contsains NaNs")
            }
            if control.containsNaN() {
                fatalError("control contsains NaNs")
            }
            
            let forecast = try get(raw: .precipitation_sum, time: time).data
            let start = DispatchTime.now()
            let referenceWeights = BiasCorrectionSeasonalLinear(ArraySlice(reference), time: referenceTime, binsPerYear: 12)
            let controlWeights = BiasCorrectionSeasonalLinear(ArraySlice(control), time: referenceTime, binsPerYear: 12)
            
            print("mean weight delta",zip(referenceWeights.meansPerYear, controlWeights.meansPerYear).map(/))
            
            var correctedForecast = forecast
            referenceWeights.applyOffset(on: &correctedForecast, otherWeights: controlWeights, time: time, type: .relativeChange)
            print("Linear bias time \(start.timeElapsedPretty())")
            
            let reference2 = reference
            let correctedForecast2 = correctedForecast
            let qc = try era5Reader.get(raw: .precipitation, time: qcTime.with(dtSeconds: 3600)).data.sum(by: 24)
            let qcBinsPerYearBy = Float(31_557_600) / 86400 / 1
            print("Linear bias projected rmse: \(zip(reference2.sum(by: qcBinsPerYearBy), correctedForecast2.sum(by: qcBinsPerYearBy)).rmse())")
            print("Linear bias projected me: \(zip(reference2.sum(by: qcBinsPerYearBy), correctedForecast2.sum(by: qcBinsPerYearBy)).meanError())")
            print("Linear bias qctime rmse: \(zip(qc.sum(by: qcBinsPerYearBy), Array(correctedForecast2[reference.count ..< reference.count + qc.count]).sum(by: qcBinsPerYearBy)).rmse())")
            print("Linear bias qctime me: \(zip(qc.sum(by: qcBinsPerYearBy), Array(correctedForecast2[reference.count ..< reference.count + qc.count]).sum(by: qcBinsPerYearBy)).meanError())")
            
            let thres: Float = 15
            let referenceEvents = reference2.map{$0 > thres ? 1 : 0}.sum(by: qcBinsPerYearBy)
            let qcEvents = qc.map{$0 > thres ? 1 : 0}.sum(by: qcBinsPerYearBy)
            let forecastEventsQcLength = correctedForecast2[reference.count ..< reference.count + qc.count].map{$0 > thres ? 1 : 0}.sum(by: qcBinsPerYearBy)
            let forecastEventsReferenceTime = correctedForecast2[0 ..< reference.count].map{$0 > thres ? 1 : 0}.sum(by: qcBinsPerYearBy)
            print("mean per year reference=\(referenceEvents.mean(by: referenceEvents.count)) refForecast=\(forecastEventsReferenceTime.mean(by: forecastEventsReferenceTime.count)) qc=\(qcEvents.mean(by: qcEvents.count)) qcForecast=\(forecastEventsQcLength.mean(by: forecastEventsQcLength.count))")
            print(">\(thres)mm Linear bias projected rmse: \(zip(referenceEvents, forecastEventsReferenceTime).rmse())")
            print(">\(thres)mm Linear bias projected me: \(zip(referenceEvents, forecastEventsReferenceTime).meanError())")
            print(">\(thres)mm Linear bias qctime rmse: \(zip(qcEvents, forecastEventsQcLength).rmse())")
            print(">\(thres)mm Linear bias qctime me: \(zip(qcEvents, forecastEventsQcLength).meanError())")
            
            
            return DataAndUnit(correctedForecast2, .millimeter)
            
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
            let controlAndForecast = try get(raw: .temperature_2m_max, time: time).data
            let era5Reader = try Era5Reader(domain: .era5_land, lat: lat, lon: lon, elevation: reader.targetElevation, mode: .terrainOptimised)!
            let reference = try era5Reader.get(raw: .temperature_2m, time: referenceTime.with(dtSeconds: 3600)).data.max(by: 24)
            
            /*
             normal 10y sliding
             QDM projected rmse: 2.1408963
             QDM projected me: -0.018368302
             QDM qctime rmse: 2.142249
             QDM qctime me: 0.40969
             mean per year reference=[31.5] refForecast=[31.425] qc=[46.0625] qcForecast=[42.875]
             >25.0°C QDM projected rmse: 4.0031238
             >25.0°C QDM projected me: 0.075
             >25.0°C QDM qctime rmse: 4.175823
             >25.0°C QDM qctime me: 3.1875
             
             detrend 10y sliding
             QDM projected rmse: 2.146497
             QDM projected me: 0.37727377
             QDM qctime rmse: 2.1588807
             QDM qctime me: 0.8117633
             mean per year reference=[31.5] refForecast=[27.1] qc=[46.0625] qcForecast=[41.875]
             >25.0°C QDM projected rmse: 4.1593266
             >25.0°C QDM projected me: 4.4
             >25.0°C QDM qctime rmse: 4.160829
             >25.0°C QDM qctime me: 4.1875
             
             normal 2 years sliding
             QDM projected rmse: 2.1241827
             QDM projected me: -0.047693256
             QDM qctime rmse: 2.1715572
             QDM qctime me: 0.39521652
             mean per year reference=[31.5] refForecast=[32.05] qc=[46.0625] qcForecast=[47.625]
             >25.0°C QDM projected rmse: 3.435113
             >25.0°C QDM projected me: -0.55
             >25.0°C QDM qctime rmse: 4.2646804
             >25.0°C QDM qctime me: -1.5625
             
             detrend 2 years
             QDM projected rmse: 2.1482747
             QDM projected me: 0.37949517
             QDM qctime rmse: 2.1614432
             QDM qctime me: 0.81603646
             mean per year reference=[31.5] refForecast=[27.425] qc=[46.0625] qcForecast=[41.875]
             >25.0°C QDM projected rmse: 4.2337923
             >25.0°C QDM projected me: 4.075
             >25.0°C QDM qctime rmse: 4.1907635
             >25.0°C QDM qctime me: 4.1875
             */
            
            let start = DispatchTime.now()
            let corrected = QuantileDeltaMappingBiasCorrection.quantileDeltaMappingMonthlyDetrend(
                reference: ArraySlice(reference),
                referenceTime: referenceTime,
                controlAndForecast: ArraySlice(controlAndForecast),
                controlAndForecastTime: time,
                type: .absoluteChage
            )
            print("QDM time \(start.timeElapsedPretty())")
            
            let qc = try era5Reader.get(raw: .temperature_2m, time: qcTime.with(dtSeconds: 3600)).data.max(by: 24)
            let qcBinsPerYearBy = Float(31_557_600) / 86400 / 1
            
            print("Raw control rmse: \(zip(reference, controlAndForecast).rmse())")
            print("Raw control me: \(zip(reference, controlAndForecast).meanError())")
            
            print("QDM projected rmse: \(zip(reference, corrected).rmse())")
            print("QDM projected me: \(zip(reference, corrected).meanError())")
            
            print("QDM qctime rmse: \(zip(qc, corrected[reference.count ..< reference.count + qc.count]).rmse())")
            print("QDM qctime me: \(zip(qc, corrected[reference.count ..< reference.count + qc.count]).meanError())")
            
            let thres: Float = 25
            let referenceEvents = reference.map{$0 > thres ? 1 : 0}.sum(by: qcBinsPerYearBy)
            let qcEvents = qc.map{$0 > thres ? 1 : 0}.sum(by: qcBinsPerYearBy)
            let forecastEventsQcLength = corrected[reference.count ..< reference.count + qc.count].map{$0 > thres ? 1 : 0}.sum(by: qcBinsPerYearBy)
            let forecastEventsReferenceTime = corrected[0 ..< reference.count].map{$0 > thres ? 1 : 0}.sum(by: qcBinsPerYearBy)
            print("mean per year reference=\(referenceEvents.mean(by: referenceEvents.count)) refForecast=\(forecastEventsReferenceTime.mean(by: forecastEventsReferenceTime.count)) qc=\(qcEvents.mean(by: qcEvents.count)) qcForecast=\(forecastEventsQcLength.mean(by: forecastEventsQcLength.count))")
            print(">\(thres)°C QDM projected rmse: \(zip(referenceEvents, forecastEventsReferenceTime).rmse())")
            print(">\(thres)°C QDM projected me: \(zip(referenceEvents, forecastEventsReferenceTime).meanError())")
            print(">\(thres)°C QDM qctime rmse: \(zip(qcEvents, forecastEventsQcLength).rmse())")
            print(">\(thres)°C QDM qctime me: \(zip(qcEvents, forecastEventsQcLength).meanError())")
            
            return DataAndUnit(corrected, .celsius)
            
        case .temperature_2m_max_linear:
            let control = try get(raw: .temperature_2m_max, time: referenceTime).data
            let era5Reader = try Era5Reader(domain: .era5_land, lat: lat, lon: lon, elevation: reader.targetElevation, mode: .terrainOptimised)!
            let reference = try era5Reader.get(raw: .temperature_2m, time: referenceTime.with(dtSeconds: 3600)).data.max(by: 24)
            
            let forecast = try get(raw: .temperature_2m_max, time: time).data
            let start = DispatchTime.now()            
            let referenceWeights = BiasCorrectionSeasonalLinear(ArraySlice(reference), time: referenceTime, binsPerYear: 12)
            let controlWeights = BiasCorrectionSeasonalLinear(ArraySlice(control), time: referenceTime, binsPerYear: 12)
            
            print("mean weight delta",zip(referenceWeights.meansPerYear, controlWeights.meansPerYear).map(-))
            
            var correctedForecast = forecast
            referenceWeights.applyOffset(on: &correctedForecast, otherWeights: controlWeights, time: time, type: .absoluteChage)
            print("Linear bias time \(start.timeElapsedPretty())")
            
            print(referenceWeights.meansPerYear)
            print(controlWeights.meansPerYear)
            
            let reference2 = reference
            var correctedForecast2 = correctedForecast
            let qc = try era5Reader.get(raw: .temperature_2m, time: qcTime.with(dtSeconds: 3600)).data.max(by: 24)
            let qcBinsPerYearBy = Float(31_557_600) / 86400 / 1
            
            print("Linear bias projected rmse: \(zip(reference2, correctedForecast2).rmse())")
            print("Linear bias projected me: \(zip(reference2, correctedForecast2).meanError())")
            print("Linear bias qctime rmse: \(zip(qc, correctedForecast2[reference.count ..< reference.count + qc.count]).rmse())")
            print("Linear bias qctime me: \(zip(qc, correctedForecast2[reference.count ..< reference.count + qc.count]).meanError())")
            
            let thres: Float = 25
            let referenceEvents = reference2.map{$0 > thres ? 1 : 0}.sum(by: qcBinsPerYearBy)
            let qcEvents = qc.map{$0 > thres ? 1 : 0}.sum(by: qcBinsPerYearBy)
            let forecastEventsQcLength = correctedForecast2[reference.count ..< reference.count + qc.count].map{$0 > thres ? 1 : 0}.sum(by: qcBinsPerYearBy)
            let forecastEventsReferenceTime = correctedForecast2[0 ..< reference.count].map{$0 > thres ? 1 : 0}.sum(by: qcBinsPerYearBy)
            print("mean per year reference=\(referenceEvents.mean(by: referenceEvents.count)) refForecast=\(forecastEventsReferenceTime.mean(by: forecastEventsReferenceTime.count)) qc=\(qcEvents.mean(by: qcEvents.count)) qcForecast=\(forecastEventsQcLength.mean(by: forecastEventsQcLength.count))")
            print(">\(thres)°C Linear bias projected rmse: \(zip(referenceEvents, forecastEventsReferenceTime).rmse())")
            print(">\(thres)°C Linear bias projected me: \(zip(referenceEvents, forecastEventsReferenceTime).meanError())")
            print(">\(thres)°C Linear bias qctime rmse: \(zip(qcEvents, forecastEventsQcLength).rmse())")
            print(">\(thres)°C Linear bias qctime me: \(zip(qcEvents, forecastEventsQcLength).meanError())")
            
            
            /*let referenceWeights2 = BiasCorrectionSeasonalHermite(ArraySlice(reference), time: referenceTime, binsPerYear: 12)
            let controlWeights2 = BiasCorrectionSeasonalHermite(ArraySlice(control), time: referenceTime, binsPerYear: 12)
                        
            correctedForecast = forecast
            referenceWeights2.applyOffset(on: &correctedForecast, otherWeights: controlWeights2, time: time, type: .absoluteChage)
            correctedForecast2 = correctedForecast
            
            print("Hermite bias projected rmse: \(zip(reference2, correctedForecast2).rmse())")
            print("Hermite bias projected me: \(zip(reference2, correctedForecast2).meanError())")
            print("Hermite bias qctime rmse: \(zip(qc, correctedForecast2[reference.count ..< reference.count + qc.count]).rmse())")
            print("Hermite bias qctime me: \(zip(qc, correctedForecast2[reference.count ..< reference.count + qc.count]).meanError())")
            
            print(">\(thres)°C Hermite bias projected rmse: \(zip(reference2.map{$0 > thres ? 1 : 0}.sum(by: qcBinsPerYearBy), correctedForecast2.map{$0 > thres ? 1 : 0}.sum(by: qcBinsPerYearBy)).rmse())")
            print(">\(thres)°C Hermite bias projected me: \(zip(reference2.map{$0 > thres ? 1 : 0}.sum(by: qcBinsPerYearBy), correctedForecast2.map{$0 > thres ? 1 : 0}.sum(by: qcBinsPerYearBy)).meanError())")
            print(">\(thres)°C Hermite bias qctime rmse: \(zip(qc.map{$0 > thres ? 1 : 0}.sum(by: qcBinsPerYearBy), correctedForecast2[reference.count ..< reference.count + qc.count].map{$0 > thres ? 1 : 0}.sum(by: qcBinsPerYearBy)).rmse())")
            print(">\(thres)°C Hermite bias qctime me: \(zip(qc.map{$0 > thres ? 1 : 0}.sum(by: qcBinsPerYearBy), correctedForecast2[reference.count ..< reference.count + qc.count].map{$0 > thres ? 1 : 0}.sum(by: qcBinsPerYearBy)).meanError())")*/
            
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
            let era5Reader = try Era5Reader(domain: .era5_land, lat: lat, lon: lon, elevation: reader.targetElevation, mode: .terrainOptimised)!
            let reference = try era5Reader.get(raw: .temperature_2m, time: referenceTime.with(dtSeconds: 3600)).data.max(by: 24)
            let detrend: [Float] = reference.detrendLinear().map({$0})
            return DataAndUnit(detrend, .celsius)
        }
    }
    
    func prefetchData(derived: Cmip6VariableDerived, time: TimerangeDt) throws {
        switch derived {
        case .snowfall_sum:
            try prefetchData(raw: .snowfall_water_equivalent_sum, time: time)
        case .rain_sum:
            try prefetchData(raw: .precipitation_sum, time: time)
            try prefetchData(raw: .snowfall_water_equivalent_sum, time: time)
        default:
            break
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
