import Foundation
import Vapor

typealias GloFasVariableMember = VariableAndMemberAndControl<GloFasVariable>

struct GloFasMixer: GenericReaderMixer {
    var reader: [GloFasReader]
    
    static func makeReader(domain: GloFasReader.Domain, lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode) throws -> GloFasReader? {
        return try GloFasReader(domain: domain, lat: lat, lon: lon, elevation: elevation, mode: mode)
    }
}

enum GlofasDerivedVariable: String, CaseIterable, GenericVariableMixable {
    case river_discharge_mean
    case river_discharge_min
    case river_discharge_max
    case river_discharge_median
    case river_discharge_p25
    case river_discharge_p75
    
    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
}

typealias GloFasVariableOrDerived = VariableOrDerived<GloFasVariable, GlofasDerivedVariable>

struct GloFasReader: GenericReaderDerivedSimple, GenericReaderProtocol {
    var reader: GenericReaderCached<GloFasDomain, GloFasVariableMember>
    
    typealias Domain = GloFasDomain
    
    typealias Variable = GloFasVariableMember
    
    typealias Derived = GlofasDerivedVariable
    
    public init?(domain: Domain, lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode) throws {
        guard let reader = try GenericReader<Domain, Variable>(domain: domain, lat: lat, lon: lon, elevation: elevation, mode: mode) else {
            return nil
        }
        self.reader = GenericReaderCached(reader: reader)
    }
    
    func prefetchData(derived: GlofasDerivedVariable, time: TimerangeDt) throws {
        for member in 0..<51 {
            try reader.prefetchData(variable: .init(.river_discharge, member), time: time)
        }
    }
    
    func get(derived: GlofasDerivedVariable, time: TimerangeDt) throws -> DataAndUnit {
        let data = try (0..<51).map({
            try reader.get(variable: .init(.river_discharge, $0), time: time).data
        })
        if data[0].onlyNaN() {
            return DataAndUnit(data[0], .qubicMeterPerSecond)
        }
        switch derived {
        case .river_discharge_mean:
            return DataAndUnit((0..<time.count).map { t in
                data.reduce(0, {$0 + $1[t]}) / Float(data.count)
            }, .qubicMeterPerSecond)
        case .river_discharge_min:
            return DataAndUnit((0..<time.count).map { t in
                data.reduce(Float.nan, { $0.isNaN || $1[t] < $0 ? $1[t] : $0 })
            }, .qubicMeterPerSecond)
        case .river_discharge_max:
            return DataAndUnit((0..<time.count).map { t in
                data.reduce(Float.nan, { $0.isNaN || $1[t] > $0 ? $1[t] : $0 })
            }, .qubicMeterPerSecond)
        case .river_discharge_median:
            return DataAndUnit((0..<time.count).map { t in
                data.map({$0[t]}).sorted().interpolateLinear(Int(Float(data.count)*0.5), (Float(data.count)*0.5).truncatingRemainder(dividingBy: 1) )
            }, .qubicMeterPerSecond)
        case .river_discharge_p25:
            return DataAndUnit((0..<time.count).map { t in
                data.map({$0[t]}).sorted().interpolateLinear(Int(Float(data.count)*0.25), (Float(data.count)*0.25).truncatingRemainder(dividingBy: 1) )
            }, .qubicMeterPerSecond)
        case .river_discharge_p75:
            return DataAndUnit((0..<time.count).map { t in
                data.map({$0[t]}).sorted().interpolateLinear(Int(Float(data.count)*0.75), (Float(data.count)*0.75).truncatingRemainder(dividingBy: 1) )
            }, .qubicMeterPerSecond)
        }
    }
}

struct GloFasController {
    func query(_ req: Request) throws -> EventLoopFuture<Response> {
        try req.ensureSubdomain("flood-api")
        let generationTimeStart = Date()
        let params = try req.query.decode(GloFasQuery.self)
        try params.validate()
        let currentTime = Timestamp.now()
        
        let allowedRange = Timestamp(1984, 1, 1) ..< currentTime.add(86400 * 230)
        let timezone = try params.resolveTimezone()
        let (utcOffsetSecondsActual, time) = try params.getTimerange(timezone: timezone, current: currentTime, forecastDays: params.forecast_days ?? 92, allowedRange: allowedRange, past_days_max: 360)
        /// For fractional timezones, shift data to show only for full timestamps
        let utcOffsetShift = time.utcOffsetSeconds - utcOffsetSecondsActual
        let dailyTime = time.range.range(dtSeconds: 3600*24)
        
        let domains = try GlofasDomainApi.load(commaSeparatedOptional: params.models) ?? [.seamless_v3]
        
        let readers = try domains.compactMap {
            guard let reader = try $0.getReader(lat: params.latitude, lon: params.longitude, elevation: .nan, mode: params.cell_selection ?? .nearest) else {
                throw ForecastapiError.noDataAvilableForThisLocation
            }
            return reader
        }
        
        guard !readers.isEmpty else {
            throw ForecastapiError.noDataAvilableForThisLocation
        }
        
        // convert variables
        let paramsDaily = try GloFasVariableOrDerived.load(commaSeparated: params.daily)
        let variablesMember: [VariableOrDerived<GloFasReader.Variable, GloFasReader.Derived>] = paramsDaily.map {
            switch $0 {
            case .raw(let raw):
                return .raw(.init(raw, 0))
            case .derived(let derived):
                return .derived(derived)
            }
        }
        /// Variables wih 51 members if requested
        let variables = variablesMember + (params.ensemble ? (1..<51).map({.raw(.init(.river_discharge, $0))}) : [])
        
        
        // Start data prefetch to boooooooost API speed :D
        for reader in readers {
            try reader.prefetchData(variables: variables, time: dailyTime)
        }
        
        let daily = ApiSection(name: "daily", time: dailyTime.add(utcOffsetShift), columns: try variables.flatMap { variable in
            try zip(readers, domains).compactMap { (reader, domain) in
                let name = readers.count > 1 ? "\(variable.rawValue)_\(domain.rawValue)" : variable.rawValue
                let d = try reader.get(variable: variable, time: dailyTime).convertAndRound(temperatureUnit: .celsius, windspeedUnit: .ms, precipitationUnit: .mm).toApi(name: name)
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
            utc_offset_seconds: utcOffsetSecondsActual,
            timezone: timezone,
            current_weather: nil,
            sections: [daily],
            timeformat: params.timeformatOrDefault
        )
        return req.eventLoop.makeSucceededFuture(try out.response(format: params.format ?? .json))
    }
}

enum GlofasDomainApi: String, RawRepresentableString, CaseIterable {
    case seamless_v3
    case forecast_v3
    case consolidated_v3
    
    case consolidated_v4
    
    /// Return the required readers for this domain configuration
    /// Note: last reader has highes resolution data
    func getReader(lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode) throws -> GloFasMixer? {
        switch self {
        case .seamless_v3:
            return try GloFasMixer(domains: [.seasonalv3, .consolidatedv3, .intermediatev3, .forecastv3], lat: lat, lon: lon, elevation: elevation, mode: mode)
        case .forecast_v3:
            return try GloFasMixer(domains: [.seasonalv3, .intermediatev3, .forecastv3], lat: lat, lon: lon, elevation: elevation, mode: mode)
        case .consolidated_v3:
            return try GloFasMixer(domains: [.consolidatedv3], lat: lat, lon: lon, elevation: elevation, mode: mode)
        case .consolidated_v4:
            return try GloFasMixer(domains: [.consolidated], lat: lat, lon: lon, elevation: elevation, mode: mode)
        }
    }
}

struct GloFasQuery: Content, QueryWithStartEndDateTimeZone {
    let latitude: Float
    let longitude: Float
    let daily: [String]
    let timeformat: Timeformat?
    let past_days: Int?
    let forecast_days: Int?
    let format: ForecastResultFormat?
    let timezone: String?
    let models: [String]?
    let ensemble: Bool
    let cell_selection: GridSelectionMode?
    
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
