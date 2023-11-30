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
typealias GloFasVariableOrDerivedMember = VariableOrDerived<GloFasVariableMember, GloFasReader.Derived>

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
            return DataAndUnit(data[0], .cubicMetrePerSecond)
        }
        switch derived {
        case .river_discharge_mean:
            return DataAndUnit((0..<time.count).map { t in
                data.reduce(0, {$0 + $1[t]}) / Float(data.count)
            }, .cubicMetrePerSecond)
        case .river_discharge_min:
            return DataAndUnit((0..<time.count).map { t in
                data.reduce(Float.nan, { $0.isNaN || $1[t] < $0 ? $1[t] : $0 })
            }, .cubicMetrePerSecond)
        case .river_discharge_max:
            return DataAndUnit((0..<time.count).map { t in
                data.reduce(Float.nan, { $0.isNaN || $1[t] > $0 ? $1[t] : $0 })
            }, .cubicMetrePerSecond)
        case .river_discharge_median:
            return DataAndUnit((0..<time.count).map { t in
                data.map({$0[t]}).sorted().interpolateLinear(Int(Float(data.count)*0.5), (Float(data.count)*0.5).truncatingRemainder(dividingBy: 1) )
            }, .cubicMetrePerSecond)
        case .river_discharge_p25:
            return DataAndUnit((0..<time.count).map { t in
                data.map({$0[t]}).sorted().interpolateLinear(Int(Float(data.count)*0.25), (Float(data.count)*0.25).truncatingRemainder(dividingBy: 1) )
            }, .cubicMetrePerSecond)
        case .river_discharge_p75:
            return DataAndUnit((0..<time.count).map { t in
                data.map({$0[t]}).sorted().interpolateLinear(Int(Float(data.count)*0.75), (Float(data.count)*0.75).truncatingRemainder(dividingBy: 1) )
            }, .cubicMetrePerSecond)
        }
    }
}

struct GloFasController {
    func query(_ req: Request) throws -> EventLoopFuture<Response> {
        try req.ensureSubdomain("flood-api")
        let params = try req.query.decode(ApiQueryParameter.self)
        let currentTime = Timestamp.now()
        let allowedRange = Timestamp(1984, 1, 1) ..< currentTime.add(86400 * 230)
        
        let prepared = try params.prepareCoordinates(allowTimezones: false)
        let domains = try GlofasDomainApi.load(commaSeparatedOptional: params.models) ?? [.best_match]
        guard let paramsDaily = try GloFasVariableOrDerived.load(commaSeparatedOptional: params.daily) else {
            throw ForecastapiError.generic(message: "Parameter 'daily' required")
        }
        let nVariables = (params.ensemble ? 51 : 1) * domains.count
        
        let locations: [ForecastapiResult<GlofasDomainApi>.PerLocation] = try prepared.map { prepared in
            let coordinates = prepared.coordinate
            let timezone = prepared.timezone
            let time = try params.getTimerange2(timezone: timezone, current: currentTime, forecastDaysDefault: 92, forecastDaysMax: 366, startEndDate: prepared.startEndDate, allowedRange: allowedRange, pastDaysMax: 92)
            let timeLocal = TimerangeLocal(range: time.dailyRead.range, utcOffsetSeconds: timezone.utcOffsetSeconds)
            
            let readers: [ForecastapiResult<GlofasDomainApi>.PerModel] = try domains.compactMap { domain in
                guard let reader = try domain.getReader(lat: coordinates.latitude, lon: coordinates.longitude, elevation: .nan, mode: params.cell_selection ?? .nearest) else {
                    return nil
                }
                return ForecastapiResult<GlofasDomainApi>.PerModel(
                    model: domain,
                    latitude: reader.modelLat,
                    longitude: reader.modelLon,
                    elevation: reader.targetElevation,
                    prefetch: {
                        // convert variables
                        let variablesMember: [GloFasVariableOrDerivedMember] = paramsDaily.map {
                            switch $0 {
                            case .raw(let raw):
                                return .raw(.init(raw, 0))
                            case .derived(let derived):
                                return .derived(derived)
                            }
                        }
                        /// Variables wih 51 members if requested
                        let variables = variablesMember + (params.ensemble ? (1..<51).map({.raw(.init(.river_discharge, $0))}) : [])
                        try reader.prefetchData(variables: variables, time: time.dailyRead)
                    },
                    current: nil,
                    hourly: nil,
                    daily: {
                        return ApiSection<GloFasVariableOrDerived>(name: "daily", time: time.dailyDisplay, columns: try paramsDaily.map { variable in
                            switch variable {
                            case .raw(_):
                                let d = try (params.ensemble ? (0..<51) : (0..<1)).map { member -> ApiArray in
                                    let d = try reader.get(variable: .raw(.init(.river_discharge, member)), time: time.dailyRead).convertAndRound(params: params)
                                    assert(time.dailyRead.count == d.data.count, "days \(time.dailyRead.count), values \(d.data.count)")
                                    return ApiArray.float(d.data)
                                }
                                return ApiColumn<GloFasVariableOrDerived>(variable: variable, unit: .cubicMetrePerSecond, variables: d)
                            case .derived(let derived):
                                let d = try reader.get(variable: .derived(derived), time: time.dailyRead).convertAndRound(params: params)
                                assert(time.dailyRead.count == d.data.count, "days \(time.dailyRead.count), values \(d.data.count)")
                                return ApiColumn<GloFasVariableOrDerived>(variable: variable, unit: .cubicMetrePerSecond, variables: [.float(d.data)])
                            }
                        })
                    },
                    sixHourly: nil,
                    minutely15: nil
                )
            }
            guard !readers.isEmpty else {
                throw ForecastapiError.noDataAvilableForThisLocation
            }
            return .init(timezone: timezone, time: timeLocal, locationId: coordinates.locationId, results: readers)
        }
        let result = ForecastapiResult<GlofasDomainApi>(timeformat: params.timeformatOrDefault, results: locations)
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
