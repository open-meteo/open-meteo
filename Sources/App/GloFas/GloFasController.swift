import Foundation
import Vapor

typealias GloFasVariableMember = VariableAndMemberAndControlSplitFiles<GloFasVariable>

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
        let params = try req.query.decode(ApiQueryParameter.self)
        let currentTime = Timestamp.now()
        let allowedRange = Timestamp(1984, 1, 1) ..< currentTime.add(86400 * 230)
        
        let prepared = try params.prepareCoordinates(allowTimezones: true)
        let domains = try GlofasDomainApi.load(commaSeparatedOptional: params.models) ?? [.best_match]
        guard let paramsDaily = try GloFasVariableOrDerived.load(commaSeparatedOptional: params.daily) else {
            throw ForecastapiError.generic(message: "Parameter 'daily' required")
        }
        let nVariables = (params.ensemble ? 51 : 1) * domains.count
        
        let result = ForecastapiResultSet(timeformat: params.timeformatOrDefault, results: try prepared.map { prepared in
            let coordinates = prepared.coordinate
            let timezone = prepared.timezone
            let time = try params.getTimerange(timezone: timezone, current: currentTime, forecastDays: params.forecast_days ?? 92, forecastDaysMax: 366, startEndDate: prepared.startEndDate, allowedRange: allowedRange, pastDaysMax: 92)
            /// For fractional timezones, shift data to show only for full timestamps
            let utcOffsetShift = time.utcOffsetSeconds - timezone.utcOffsetSeconds
            
            let dailyTime = time.range.range(dtSeconds: 3600*24)
            
            let readers = try domains.compactMap {
                guard let reader = try $0.getReader(lat: coordinates.latitude, lon: coordinates.longitude, elevation: .nan, mode: params.cell_selection ?? .nearest) else {
                    throw ForecastapiError.noDataAvilableForThisLocation
                }
                return reader
            }
            
            guard !readers.isEmpty else {
                throw ForecastapiError.noDataAvilableForThisLocation
            }
            
            // convert variables
            
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
            
            return ForecastapiResult(
                latitude: readers[0].modelLat,
                longitude: readers[0].modelLon,
                elevation: nil,
                timezone: timezone,
                time: time,
                prefetch: {
                    for reader in readers {
                        try reader.prefetchData(variables: variables, time: dailyTime)
                    }
                },
                current_weather: nil,
                current: nil,
                hourly: nil,
                daily: {
                    ApiSection(name: "daily", time: dailyTime.add(utcOffsetShift), columns: try variables.flatMap { variable in
                        try zip(readers, domains).compactMap { (reader, domain) in
                            let name = readers.count > 1 ? "\(variable.rawValue)_\(domain.rawValue)" : variable.rawValue
                            let units = ApiUnits(temperature_unit: .celsius, windspeed_unit: .ms, precipitation_unit: .mm, length_unit: .metric)
                            let d = try reader.get(variable: variable, time: dailyTime).convertAndRound(params: units).toApi(name: name)
                            assert(dailyTime.count == d.data.count, "days \(dailyTime.count), values \(d.data.count)")
                            return d
                        }
                    })
                },
                sixHourly: nil,
                minutely15: nil
            )
        })
        req.incrementRateLimiter(weight: result.calculateQueryWeight(nVariablesModels: nVariables))
        return result.response(format: params.format ?? .json)
    }
}

enum GlofasDomainApi: String, RawRepresentableString, CaseIterable {
    case best_match
    
    case seamless_v3
    case forecast_v3
    case consolidated_v3
    
    case seamless_v4
    case forecast_v4
    case consolidated_v4
    
    /// Return the required readers for this domain configuration
    /// Note: last reader has highes resolution data
    func getReader(lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode) throws -> GloFasMixer? {
        switch self {
        case .best_match:
            return try GloFasMixer(domains: [.seasonalv3, .consolidatedv3, .intermediatev3, .forecastv3, .seasonal, .consolidated, .intermediate, .forecast], lat: lat, lon: lon, elevation: elevation, mode: mode)
        case .seamless_v3:
            return try GloFasMixer(domains: [.seasonalv3, .consolidatedv3, .intermediatev3, .forecastv3], lat: lat, lon: lon, elevation: elevation, mode: mode)
        case .forecast_v3:
            return try GloFasMixer(domains: [.seasonalv3, .intermediatev3, .forecastv3], lat: lat, lon: lon, elevation: elevation, mode: mode)
        case .seamless_v4:
            return try GloFasMixer(domains: [.seasonal, .consolidated, .intermediate, .forecast], lat: lat, lon: lon, elevation: elevation, mode: mode)
        case .forecast_v4:
            return try GloFasMixer(domains: [.seasonal, .intermediate, .forecast], lat: lat, lon: lon, elevation: elevation, mode: mode)
        case .consolidated_v3:
            return try GloFasMixer(domains: [.consolidatedv3], lat: lat, lon: lon, elevation: elevation, mode: mode)
        case .consolidated_v4:
            return try GloFasMixer(domains: [.consolidated], lat: lat, lon: lon, elevation: elevation, mode: mode)
        }
    }
}
