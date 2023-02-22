import Foundation
import Vapor


struct CmipController {
    func query(_ req: Request) throws -> EventLoopFuture<Response> {
        try req.ensureSubdomain("climate-api")
        let generationTimeStart = Date()
        let params = try req.query.decode(CmipQuery.self)
        try params.validate()
        let elevationOrDem = try params.elevation ?? Dem90.read(lat: params.latitude, lon: params.longitude)
        
        let allowedRange = Timestamp(1950, 1, 1) ..< Timestamp(2051, 1, 1)
        //let timezone = try params.resolveTimezone()
        let time = try params.getTimerange(allowedRange: allowedRange)
        //let hourlyTime = time.range.range(dtSeconds: 3600)
        let dailyTime = time.range.range(dtSeconds: 3600*24)
        let biasCorrection = !(params.disable_bias_correction ?? false)
        
        let domains = params.models ?? [.MRI_AGCM3_2_S]
        
        let readers: [any Cmip6Readerable] = try domains.map { domain -> any Cmip6Readerable in
            if biasCorrection {
                guard let reader = try Cmip6Reader<Cmip6BiasCorrector>(domain: domain, lat: params.latitude, lon: params.longitude, elevation: elevationOrDem, mode: params.cell_selection ?? .land) else {
                    throw ForecastapiError.noDataAvilableForThisLocation
                }
                return reader
            } else {
                guard let reader = try Cmip6Reader<GenericReader<Cmip6Domain, Cmip6Variable>>(domain: domain, lat: params.latitude, lon: params.longitude, elevation: elevationOrDem, mode: params.cell_selection ?? .land) else {
                    throw ForecastapiError.noDataAvilableForThisLocation
                }
                return reader
            }
        }
        
        guard !readers.isEmpty else {
            throw ForecastapiError.noDataAvilableForThisLocation
        }

        // Start data prefetch to boooooooost API speed :D
        /*if let hourlyVariables = params.hourly {
            for reader in readers {
                try reader.prefetchData(variables: hourlyVariables, time: hourlyTime)
            }
        }*/
        if let dailyVariables = params.daily {
            for reader in readers {
                try reader.prefetchData(variables: dailyVariables, time: dailyTime)
            }
        }
        
        
        /*let hourly: ApiSection? = try params.hourly.map { variables in
            var res = [ApiColumn]()
            res.reserveCapacity(variables.count * readers.count)
            for reader in readers {
                for variable in variables {
                    let name = readers.count > 1 ? "\(variable.rawValue)_\(reader.reader.reader.domain.rawValue)" : variable.rawValue
                    let d = try reader.get(variable: variable, time: hourlyTime).convertAndRound(params: params).toApi(name: name)
                    assert(hourlyTime.count == d.data.count)
                    res.append(d)
                }
            }
            return ApiSection(name: "hourly", time: hourlyTime, columns: res)
        }*/
        let daily: ApiSection? = try params.daily.map { dailyVariables in
            var res = [ApiColumn]()
            res.reserveCapacity(dailyVariables.count * readers.count)
            for (reader, domain) in zip(readers, domains) {
                for variable in dailyVariables {
                    let name = readers.count > 1 ? "\(variable.rawValue)_\(domain.rawValue)" : variable.rawValue
                    let d = try reader.get(variable: variable, time: dailyTime).convertAndRound(params: params).toApi(name: name)
                    assert(dailyTime.count == d.data.count)
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
            sections: [/*hourly,*/ daily].compactMap({$0}),
            timeformat: params.timeformatOrDefault
        )
        return req.eventLoop.makeSucceededFuture(try out.response(format: params.format ?? .json))
    }
}

protocol Cmip6Readerable {
    func prefetchData(variables: [Cmip6VariableOrDerived], time: TimerangeDt) throws
    func get(variable: Cmip6VariableOrDerived, time: TimerangeDt) throws -> DataAndUnit
    var modelLat: Float { get }
    var modelLon: Float { get }
    var modelElevation: ElevationOrSea { get }
    var targetElevation: Float { get }
    var modelDtSeconds: Int { get }
}

extension Cmip6Domain: MultiDomainMixerDomain {
    func getReader(lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode) throws -> [any GenericReaderMixable] {
        fatalError()
    }
}

enum Cmip6VariableDerived: String, Codable, GenericVariableMixable {
    case snowfall_sum
    case rain_sum
    case et0_fao_evapotranspiration_sum
    case dewpoint_2m_max
    case dewpoint_2m_min
    case dewpoint_2m_mean
    case vapor_pressure_deficit_mean
    
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

/// Apply bias correction to raw variables
struct Cmip6BiasCorrector: GenericReaderMixable {
    typealias MixingVar = Cmip6Variable
    
    typealias Domain = Cmip6Domain
    
    var modelLat: Float { readerEra5Land?.modelLat ?? readerEra5.modelLat }
    
    var modelLon: Float { readerEra5Land?.modelLon ?? readerEra5.modelLon }
    
    var modelElevation: ElevationOrSea { readerEra5Land?.modelElevation ?? readerEra5.modelElevation }
    
    var targetElevation: Float { reader.targetElevation }
    
    var modelDtSeconds: Int { reader.modelDtSeconds }
    
    var domain: Domain { reader.domain }
    
    /// cmip reader
    let reader: GenericReader<Cmip6Domain, Cmip6Variable>
    
    /// era5 reader
    let readerEra5: GenericReader<CdsDomain, Era5Variable>
    
    /// era5 land reader
    let readerEra5Land: GenericReader<CdsDomain, Era5Variable>?
    
    /// Get Bias correction field from era5-land or era5
    func getEra5BiasCorrectionWeights(for variable: Cmip6Variable) throws -> (weights: BiasCorrectionSeasonalLinear, modelElevation: Float) {
        if let readerEra5Land, let referenceWeightFile = try variable.openBiasCorrectionFile(for: readerEra5Land.domain) {
            let weights = try referenceWeightFile.read(dim0Slow: readerEra5Land.position, dim1: 0..<referenceWeightFile.dim1)
            if !weights.containsNaN() {
                return (BiasCorrectionSeasonalLinear(meansPerYear: weights), readerEra5Land.modelElevation.numeric)
            }
        }
        guard let referenceWeightFile = try variable.openBiasCorrectionFile(for: readerEra5.domain) else {
            throw ForecastapiError.generic(message: "Could not read reference weight file \(variable) for domain \(readerEra5.domain)")
        }
        let weights = try referenceWeightFile.read(dim0Slow: readerEra5.position, dim1: 0..<referenceWeightFile.dim1)
        return (BiasCorrectionSeasonalLinear(meansPerYear: weights), readerEra5.modelElevation.numeric)
    }
    
    
    func get(variable: Cmip6Variable, time: TimerangeDt) throws -> DataAndUnit {
        let raw = try reader.get(variable: variable, time: time)
        var data = raw.data
        
        guard let controlWeightFile = try variable.openBiasCorrectionFile(for: reader.domain) else {
            throw ForecastapiError.generic(message: "Could not read reference weight file \(variable) for domain \(reader.domain)")
        }
        let controlWeights = BiasCorrectionSeasonalLinear(meansPerYear: try controlWeightFile.read(dim0Slow: reader.position, dim1: 0..<controlWeightFile.dim1))
        let referenceWeights = try getEra5BiasCorrectionWeights(for: variable)
        referenceWeights.weights.applyOffset(on: &data, otherWeights: controlWeights, time: time, type: variable.biasCorrectionType)
        if let bounds = variable.interpolation.bounds {
            for i in data.indices {
                data[i] = Swift.min(Swift.max(data[i], bounds.lowerBound), bounds.upperBound)
            }
        }
        let isElevationCorrectable = variable == .temperature_2m_max || variable == .temperature_2m_min || variable == .temperature_2m_mean
        let modelElevation = referenceWeights.modelElevation
        if isElevationCorrectable && variable.unit == .celsius && !modelElevation.isNaN && !targetElevation.isNaN && targetElevation != modelElevation {
            for i in data.indices {
                // correct temperature by 0.65° per 100 m elevation
                data[i] += (modelElevation - targetElevation) * 0.0065
            }
        }
        return DataAndUnit(data, raw.unit)
    }
    
    func prefetchData(variable: Cmip6Variable, time: TimerangeDt) throws {
        try reader.prefetchData(variable: variable, time: time)
    }
    
    init?(domain: Cmip6Domain, lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode) throws {
        guard let reader = try GenericReader<Cmip6Domain, Cmip6Variable>(domain: domain, lat: lat, lon: lon, elevation: elevation, mode: mode) else {
            throw ForecastapiError.noDataAvilableForThisLocation
        }
        guard let readerEra5Land = try GenericReader<CdsDomain, Era5Variable>(domain: .era5_land, lat: lat, lon: lon, elevation: elevation, mode: mode) else {
            throw ForecastapiError.noDataAvilableForThisLocation
        }
        guard let readerEra5 = try GenericReader<CdsDomain, Era5Variable>(domain: .era5, lat: lat, lon: lon, elevation: elevation, mode: mode) else {
            throw ForecastapiError.noDataAvilableForThisLocation
        }
        self.reader = reader
        /// No data on sea for ERA5-Land
        self.readerEra5Land = readerEra5Land.modelElevation.isSea ? nil : readerEra5Land
        self.readerEra5 = readerEra5
    }
    
    init(domain: Cmip6Domain, position: Range<Int>) {
        fatalError("cmip6 not implemented")
    }
}

struct Cmip6Reader<ReaderNext: GenericReaderMixable>: GenericReaderDerivedSimple, GenericReaderMixable, Cmip6Readerable where ReaderNext.Domain == Cmip6Domain, ReaderNext.MixingVar == Cmip6Variable {

    typealias Derived = Cmip6VariableDerived
    
    var reader: ReaderNext
    
    init(reader: ReaderNext) {
        self.reader = reader
    }

    func get(derived: Cmip6VariableDerived, time: TimerangeDt) throws -> DataAndUnit {
        switch derived {
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
        case .et0_fao_evapotranspiration_sum:
            let tempmax = try get(raw: .temperature_2m_max, time: time).data
            let tempmin = try get(raw: .temperature_2m_min, time: time).data
            let tempmean = try get(raw: .temperature_2m_mean, time: time).data
            let wind = try get(raw: .windspeed_10m_mean, time: time).data
            let radiation = try get(raw: .shortwave_radiation_sum, time: time).data
            let exrad = Zensun.extraTerrestrialRadiationBackwards(latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.with(dtSeconds: 3600)).sum(by: 24)
            let hasRhMinMax = !(domain == .FGOALS_f3_H || domain == .HiRAM_SIT_HR || domain == .MPI_ESM1_2_XR || domain == .FGOALS_f3_H)
            let rhmin = hasRhMinMax ? try get(raw: .relative_humidity_2m_min, time: time).data : nil
            let rhmaxOrMean = hasRhMinMax ? try get(raw: .relative_humidity_2m_max, time: time).data : try get(raw: .relative_humidity_2m_mean, time: time).data
            let elevation = reader.targetElevation.isNaN ? reader.modelElevation.numeric : reader.targetElevation
            
            var et0 = [Float]()
            et0.reserveCapacity(tempmax.count)
            for i in tempmax.indices {
                let rh: Meteorology.MaxAndMinOrMean
                if let rhmin {
                    rh = .maxmin(max: rhmaxOrMean[i], min: rhmin[i])
                } else {
                    rh = .mean(mean: rhmaxOrMean[i])
                }
                et0.append(Meteorology.et0EvapotranspirationDaily(
                    temperature2mCelsiusDailyMax: tempmax[i],
                    temperature2mCelsiusDailyMin: tempmin[i],
                    temperature2mCelsiusDailyMean: tempmean[i],
                    windspeed10mMeterPerSecondMean: wind[i],
                    shortwaveRadiationMJSum: radiation[i],
                    elevation: elevation.isNaN ? 0 : elevation,
                    extraTerrestrialRadiationSum: exrad[i] * 0.0036,
                    relativeHumidity: rh))
            }
            return DataAndUnit(et0, .millimeter)
        case .dewpoint_2m_max:
            let tempMin = try get(raw: .temperature_2m_min, time: time).data
            let tempMax = try get(raw: .temperature_2m_max, time: time).data
            let rhMax = try get(raw: .relative_humidity_2m_max, time: time).data
            return DataAndUnit(zip(zip(tempMax, tempMin), rhMax).map(Meteorology.dewpointDaily), .celsius)
        case .dewpoint_2m_min:
            let tempMin = try get(raw: .temperature_2m_min, time: time).data
            let tempMax = try get(raw: .temperature_2m_max, time: time).data
            let rhMin = try get(raw: .relative_humidity_2m_min, time: time).data
            return DataAndUnit(zip(zip(tempMax, tempMin), rhMin).map(Meteorology.dewpointDaily), .celsius)
        case .dewpoint_2m_mean:
            let tempMin = try get(raw: .temperature_2m_min, time: time).data
            let tempMax = try get(raw: .temperature_2m_max, time: time).data
            let rhMean = try get(raw: .relative_humidity_2m_mean, time: time).data
            return DataAndUnit(zip(zip(tempMax, tempMin), rhMean).map(Meteorology.dewpointDaily), .celsius)
        case .vapor_pressure_deficit_mean:
            let tempmax = try get(raw: .temperature_2m_max, time: time).data
            let tempmin = try get(raw: .temperature_2m_min, time: time).data
            let hasRhMinMax = !(domain == .FGOALS_f3_H || domain == .HiRAM_SIT_HR || domain == .MPI_ESM1_2_XR || domain == .FGOALS_f3_H)
            let rhmin = hasRhMinMax ? try get(raw: .relative_humidity_2m_min, time: time).data : nil
            let rhmaxOrMean = hasRhMinMax ? try get(raw: .relative_humidity_2m_max, time: time).data : try get(raw: .relative_humidity_2m_mean, time: time).data
            
            var vpd = [Float]()
            vpd.reserveCapacity(tempmax.count)
            for i in tempmax.indices {
                let rh: Meteorology.MaxAndMinOrMean
                if let rhmin {
                    rh = .maxmin(max: rhmaxOrMean[i], min: rhmin[i])
                } else {
                    rh = .mean(mean: rhmaxOrMean[i])
                }
                vpd.append(Meteorology.vaporPressureDeficitDaily(
                    temperature2mCelsiusDailyMax: tempmax[i],
                    temperature2mCelsiusDailyMin: tempmin[i],
                    relativeHumidity: rh))
            }
            return DataAndUnit(vpd, .kiloPascal)
        }
    }
    
    func prefetchData(derived: Cmip6VariableDerived, time: TimerangeDt) throws {
        switch derived {
        case .snowfall_sum:
            try prefetchData(raw: .snowfall_water_equivalent_sum, time: time)
        case .rain_sum:
            try prefetchData(raw: .precipitation_sum, time: time)
            try prefetchData(raw: .snowfall_water_equivalent_sum, time: time)
        case .et0_fao_evapotranspiration_sum:
            try prefetchData(raw: .temperature_2m_max, time: time)
            try prefetchData(raw: .temperature_2m_min, time: time)
            try prefetchData(raw: .temperature_2m_mean, time: time)
            try prefetchData(raw: .windspeed_10m_mean, time: time)
            try prefetchData(raw: .shortwave_radiation_sum, time: time)
            let hasRhMinMax = !(domain == .FGOALS_f3_H || domain == .HiRAM_SIT_HR || domain == .MPI_ESM1_2_XR || domain == .FGOALS_f3_H)
            if hasRhMinMax {
                try prefetchData(raw: .relative_humidity_2m_min, time: time)
                try prefetchData(raw: .relative_humidity_2m_max, time: time)
            } else {
                try prefetchData(raw: .relative_humidity_2m_mean, time: time)
            }
        case .dewpoint_2m_max:
            try prefetchData(raw: .temperature_2m_min, time: time)
            try prefetchData(raw: .relative_humidity_2m_max, time: time)
        case .dewpoint_2m_min:
            try prefetchData(raw: .temperature_2m_max, time: time)
            try prefetchData(raw: .relative_humidity_2m_min, time: time)
        case .dewpoint_2m_mean:
            try prefetchData(raw: .temperature_2m_mean, time: time)
            try prefetchData(raw: .relative_humidity_2m_mean, time: time)
        case .vapor_pressure_deficit_mean:
            try prefetchData(raw: .temperature_2m_max, time: time)
            try prefetchData(raw: .temperature_2m_min, time: time)
            let hasRhMinMax = !(domain == .FGOALS_f3_H || domain == .HiRAM_SIT_HR || domain == .MPI_ESM1_2_XR || domain == .FGOALS_f3_H)
            if hasRhMinMax {
                try prefetchData(raw: .relative_humidity_2m_min, time: time)
                try prefetchData(raw: .relative_humidity_2m_max, time: time)
            } else {
                try prefetchData(raw: .relative_humidity_2m_mean, time: time)
            }
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
    let cell_selection: GridSelectionMode?
    let disable_bias_correction: Bool?
    
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
