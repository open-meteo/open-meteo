import Foundation
import OmFileFormat
import Vapor


struct CmipController {
    func query(_ req: Request) async throws -> Response {
        let host = try await req.ensureSubdomain("climate-api")
        let numberOfLocationsMaximum = host?.starts(with: "customer-") == true ? 10_000 : OpenMeteo.numberOfLocationsMaximum
        let params = req.method == .POST ? try req.content.decode(ApiQueryParameter.self) : try req.query.decode(ApiQueryParameter.self)
        try await req.ensureApiKey("climate-api", apikey: params.apikey)
        
        let currentTime = Timestamp.now()
        let allowedRange = Timestamp(1950, 1, 1) ..< Timestamp(2051, 1, 1)
        
        let prepared = try params.prepareCoordinates(allowTimezones: false)
        guard case .coordinates(let prepared) = prepared else {
            throw ForecastapiError.generic(message: "Bounding box not supported")
        }
        let domains = try Cmip6Domain.load(commaSeparatedOptional: params.models) ?? [.MRI_AGCM3_2_S]
        let paramsDaily = try Cmip6VariableOrDerivedPostBias.load(commaSeparatedOptional: params.daily)
        let nVariables = (paramsDaily?.count ?? 0) * domains.count
        
        let biasCorrection = !(params.disable_bias_correction ?? false)
        
        let locations: [ForecastapiResult<Cmip6Domain>.PerLocation] = try prepared.map { prepared in
            let coordinates = prepared.coordinate
            let timezone = prepared.timezone
            let time = try params.getTimerange2(timezone: timezone, current: currentTime, forecastDaysDefault: 7, forecastDaysMax: 14, startEndDate: prepared.startEndDate, allowedRange: allowedRange, pastDaysMax: 92)
            let timeLocal = TimerangeLocal(range: time.dailyRead.range, utcOffsetSeconds: timezone.utcOffsetSeconds)
            
            let readers: [ForecastapiResult<Cmip6Domain>.PerModel] = try domains.compactMap { domain in
                let reader: any Cmip6Readerable = try {
                    if biasCorrection {
                        guard let reader = try Cmip6BiasCorrectorEra5Seamless(domain: domain, lat: coordinates.latitude, lon: coordinates.longitude, elevation: coordinates.elevation, mode: params.cell_selection ?? .land) else {
                            throw ForecastapiError.noDataAvilableForThisLocation
                        }
                        return Cmip6ReaderPostBiasCorrected(reader: reader, domain: domain)
                    } else {
                        guard let reader = try GenericReader<Cmip6Domain, Cmip6Variable>(domain: domain, lat: coordinates.latitude, lon: coordinates.longitude, elevation: coordinates.elevation, mode: params.cell_selection ?? .land) else {
                            throw ForecastapiError.noDataAvilableForThisLocation
                        }
                        let reader2 = Cmip6ReaderPreBiasCorrection(reader: reader, domain: domain)
                        return Cmip6ReaderPostBiasCorrected(reader: reader2, domain: domain)
                    }
                }()
                return ForecastapiResult<Cmip6Domain>.PerModel(
                    model: domain,
                    latitude: reader.modelLat,
                    longitude: reader.modelLon,
                    elevation: reader.targetElevation,
                    prefetch: {
                        if let dailyVariables = paramsDaily {
                            try reader.prefetchData(variables: dailyVariables, time: time.dailyRead.toSettings())
                        }
                    },
                    current: nil,
                    hourly: nil,
                    daily: paramsDaily.map { paramsDaily in
                        return {
                            return ApiSection(name: "daily", time: time.dailyDisplay, columns: try paramsDaily.map { variable in
                                let d = try reader.get(variable: variable, time: time.dailyRead.toSettings()).convertAndRound(params: params)
                                assert(time.dailyRead.count == d.data.count)
                                return ApiColumn(variable: variable, unit: d.unit, variables: [.float(d.data)])
                            })
                        }
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
        let result = ForecastapiResult<Cmip6Domain>(timeformat: params.timeformatOrDefault, results: locations)
        // Currently the old calculation basically blocks climate data access very early. Adjust weigthing a bit
        await req.incrementRateLimiter(weight: result.calculateQueryWeight(nVariablesModels: nVariables) / 24 / 5)
        return try await result.response(format: params.format ?? .json, numberOfLocationsMaximum: numberOfLocationsMaximum)
    }
}

protocol Cmip6Readerable {
    func prefetchData(variables: [Cmip6VariableOrDerivedPostBias], time: TimerangeDtAndSettings) throws
    func get(variable: Cmip6VariableOrDerivedPostBias, time: TimerangeDtAndSettings) throws -> DataAndUnit
    var modelLat: Float { get }
    var modelLon: Float { get }
    var modelElevation: ElevationOrSea { get }
    var targetElevation: Float { get }
    var modelDtSeconds: Int { get }
}

/// Derived variables that do not need bias correction, but use bias corrected inputs
enum Cmip6VariableDerivedPostBiasCorrection: String, GenericVariableMixable, CaseIterable {
    case snowfall_sum
    case rain_sum
    case dewpoint_2m_max
    case dewpoint_2m_min
    case dewpoint_2m_mean
    case dew_point_2m_max
    case dew_point_2m_min
    case dew_point_2m_mean
    case growing_degree_days_base_0_limit_50
    case soil_moisture_index_0_to_10cm_mean
    case soil_moisture_index_0_to_100cm_mean
    case daylight_duration
    case windspeed_2m_max
    case windspeed_2m_mean
    case wind_speed_2m_max
    case wind_speed_2m_mean
    case windspeed_10m_max
    case windspeed_10m_mean
    case windgusts_10m_mean
    case windgusts_10m_max
    case vapor_pressure_deficit_max
    
    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
}

enum Cmip6VariableDerivedBiasCorrected: String, GenericVariableMixable, CaseIterable, GenericVariableBiasCorrectable {
    case et0_fao_evapotranspiration_sum
    case leaf_wetness_probability_mean
    case soil_moisture_0_to_100cm_mean
    case soil_moisture_0_to_7cm_mean
    case soil_moisture_7_to_28cm_mean
    case soil_moisture_28_to_100cm_mean
    case soil_temperature_0_to_100cm_mean
    case soil_temperature_0_to_7cm_mean
    case soil_temperature_7_to_28cm_mean
    case soil_temperature_28_to_100cm_mean
    case vapour_pressure_deficit_max
    case wind_gusts_10m_mean
    case wind_gusts_10m_max

    
    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
    
    var biasCorrectionType: QuantileDeltaMappingBiasCorrection.ChangeType {
        switch self {
        case .et0_fao_evapotranspiration_sum:
            return .relativeChange(maximum: nil)
        case .vapour_pressure_deficit_max:
            return .relativeChange(maximum: nil)
        case .leaf_wetness_probability_mean:
            return .absoluteChage(bounds: 0...100)
        case .soil_moisture_0_to_100cm_mean:
            return .absoluteChage(bounds: 0...10e9)
        case .soil_moisture_0_to_7cm_mean:
            return .absoluteChage(bounds: 0...10e9)
        case .soil_moisture_7_to_28cm_mean:
            return .absoluteChage(bounds: 0...10e9)
        case .soil_moisture_28_to_100cm_mean:
            return .absoluteChage(bounds: 0...10e9)
        case .soil_temperature_0_to_100cm_mean:
            return .absoluteChage(bounds: nil)
        case .soil_temperature_0_to_7cm_mean:
            return .absoluteChage(bounds: nil)
        case .soil_temperature_7_to_28cm_mean:
            return .absoluteChage(bounds: nil)
        case .soil_temperature_28_to_100cm_mean:
            return .absoluteChage(bounds: nil)
        case .wind_gusts_10m_mean:
            return .relativeChange(maximum: nil)
        case .wind_gusts_10m_max:
            return .relativeChange(maximum: nil)
        }
    }
}

typealias Cmip6VariableOrDerived = VariableOrDerived<Cmip6Variable, Cmip6VariableDerivedBiasCorrected>

typealias Cmip6VariableOrDerivedPostBias = VariableOrDerived<Cmip6VariableOrDerived, Cmip6VariableDerivedPostBiasCorrection>

extension VariableOrDerived: GenericVariableBiasCorrectable where Derived: GenericVariableBiasCorrectable, Raw: GenericVariableBiasCorrectable {
    var biasCorrectionType: QuantileDeltaMappingBiasCorrection.ChangeType {
        switch self {
        case .raw(let raw):
            return raw.biasCorrectionType
        case .derived(let derived):
            return derived.biasCorrectionType
        }
    }
}

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
struct Cmip6BiasCorrectorEra5Seamless: GenericReaderProtocol {
    typealias MixingVar = Cmip6VariableOrDerived
    
    typealias Domain = Cmip6Domain
    
    var modelLat: Float { readerEra5Land?.modelLat ?? readerEra5.modelLat }
    
    var modelLon: Float { readerEra5Land?.modelLon ?? readerEra5.modelLon }
    
    var modelElevation: ElevationOrSea { readerEra5Land?.modelElevation ?? readerEra5.modelElevation }
    
    var targetElevation: Float { reader.targetElevation }
    
    var modelDtSeconds: Int { reader.modelDtSeconds }
    
    var domain: Domain { reader.domain }
    
    /// cmip reader
    let reader: Cmip6ReaderPreBiasCorrection<GenericReader<Cmip6Domain, Cmip6Variable>>
    
    /// era5 reader
    let readerEra5: GenericReader<CdsDomain, Era5Variable>
    
    /// era5 land reader
    let readerEra5Land: GenericReader<CdsDomain, Era5Variable>?
    
    func getStatic(type: ReaderStaticVariable) throws -> Float? {
        return try readerEra5.getStatic(type: type) ?? readerEra5.getStatic(type: type)
    }
    
    /// Get Bias correction field from era5-land or era5
    func getEra5BiasCorrectionWeights(for variable: Cmip6VariableOrDerived) throws -> (weights: BiasCorrectionSeasonalLinear, modelElevation: Float) {
        if let readerEra5Land, let variable = ForecastVariableDaily(rawValue: variable.rawValue), let referenceWeightFile = try readerEra5Land.domain.openBiasCorrectionFile(for: variable.rawValue) {
            let weights = try referenceWeightFile.read(dim0Slow: readerEra5Land.position..<readerEra5Land.position+1, dim1: 0..<referenceWeightFile.dim1)
            if !weights.containsNaN() {
                return (BiasCorrectionSeasonalLinear(meansPerYear: weights), readerEra5Land.modelElevation.numeric)
            }
        }
        guard let variable = ForecastVariableDaily(rawValue: variable.rawValue), let referenceWeightFile = try readerEra5.domain.openBiasCorrectionFile(for: variable.rawValue) else {
            throw ForecastapiError.generic(message: "Could not read reference weight file \(variable) for domain \(readerEra5.domain)")
        }
        let weights = try referenceWeightFile.read(dim0Slow: readerEra5.position..<readerEra5.position+1, dim1: 0..<referenceWeightFile.dim1)
        return (BiasCorrectionSeasonalLinear(meansPerYear: weights), readerEra5.modelElevation.numeric)
    }
    
    
    func get(variable: Cmip6VariableOrDerived, time: TimerangeDtAndSettings) throws -> DataAndUnit {
        let raw = try reader.get(variable: variable, time: time)
        var data = raw.data
        
        guard let controlWeightFile = try reader.domain.openBiasCorrectionFile(for: variable.rawValue) else {
            throw ForecastapiError.generic(message: "Could not read reference weight file \(variable) for domain \(reader.domain)")
        }
        let controlWeights = BiasCorrectionSeasonalLinear(meansPerYear: try controlWeightFile.read(dim0Slow: reader.reader.position..<reader.reader.position+1, dim1: 0..<controlWeightFile.dim1))
        let referenceWeights = try getEra5BiasCorrectionWeights(for: variable)
        referenceWeights.weights.applyOffset(on: &data, otherWeights: controlWeights, time: time.time, type: variable.biasCorrectionType)
        if let bounds = variable.biasCorrectionType.bounds {
            for i in data.indices {
                data[i] = Swift.min(Swift.max(data[i], bounds.lowerBound), bounds.upperBound)
            }
        }
        if case let .raw(raw) = variable {
            let isElevationCorrectable = raw == .temperature_2m_max || raw == .temperature_2m_min || raw == .temperature_2m_mean
            let modelElevation = referenceWeights.modelElevation
            if isElevationCorrectable && raw.unit == .celsius && !modelElevation.isNaN && !targetElevation.isNaN && targetElevation != modelElevation {
                for i in data.indices {
                    // correct temperature by 0.65° per 100 m elevation
                    data[i] += (modelElevation - targetElevation) * 0.0065
                }
            }
        }
        return DataAndUnit(data, raw.unit)
    }
    
    func prefetchData(variable: Cmip6VariableOrDerived, time: TimerangeDtAndSettings) throws {
        try reader.prefetchData(variable: variable, time: time)
    }
    
    func prefetchData(variables: [Cmip6VariableOrDerived], time: TimerangeDtAndSettings) throws {
        for variable in variables {
            try prefetchData(variable: variable, time: time)
        }
    }
    
    init?(domain: Cmip6Domain, lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode) throws {
        guard let reader = try GenericReader<Cmip6Domain, Cmip6Variable>(domain: domain, lat: lat, lon: lon, elevation: elevation, mode: mode) else {
            return nil
        }
        guard let readerEra5Land = try GenericReader<CdsDomain, Era5Variable>(domain: .era5_land_daily, lat: lat, lon: lon, elevation: elevation, mode: mode) else {
            return nil
        }
        guard let readerEra5 = try GenericReader<CdsDomain, Era5Variable>(domain: .era5_daily, lat: lat, lon: lon, elevation: elevation, mode: mode) else {
            return nil
        }
        self.reader = Cmip6ReaderPreBiasCorrection(reader: reader, domain: domain)
        /// No data on sea for ERA5-Land
        self.readerEra5Land = readerEra5Land.modelElevation.isSea ? nil : readerEra5Land
        self.readerEra5 = readerEra5
    }
}

/**
 Perform bias correction using another domain (reference domain). Interpolate weights
 */
final class Cmip6BiasCorrectorInterpolatedWeights: GenericReaderProtocol {
    typealias MixingVar = Cmip6VariableOrDerived
    
    typealias Domain = Cmip6Domain
    
    var modelLat: Float { reader.modelLat }
    
    var modelLon: Float { reader.modelLon }
    
    var modelElevation: ElevationOrSea { reader.modelElevation }
    
    var targetElevation: Float { reader.targetElevation }
    
    var modelDtSeconds: Int { reader.modelDtSeconds }
    
    var domain: Domain { reader.domain }
    
    /// cmip reader
    let reader: Cmip6ReaderPreBiasCorrection<GenericReader<Cmip6Domain, Cmip6Variable>>
    
    /// imerg grid point
    let referencePosition: GridPoint2DFraction
    
    let referenceDomain: GenericDomain
    
    var _referenceElevation: ElevationOrSea? = nil
    
    func getStatic(type: ReaderStaticVariable) throws -> Float? {
        guard let file = referenceDomain.getStaticFile(type: type) else {
            return nil
        }
        return try referenceDomain.grid.readFromStaticFile(gridpoint: referencePosition.gridpoint, file: file)
    }
    
    func getReferenceElevation() throws -> ElevationOrSea {
        if let _referenceElevation {
            return _referenceElevation
        }
        guard let elevationFile = referenceDomain.getStaticFile(type: .elevation) else {
            throw ForecastapiError.generic(message: "Elevation file for domain \(referenceDomain) is missing")
        }
        let referenceElevation = try referenceDomain.grid.readElevationInterpolated(gridpoint: referencePosition, elevationFile: elevationFile)
        self._referenceElevation = referenceElevation
        return referenceElevation
    }
    
    func get(variable: Cmip6VariableOrDerived, time: TimerangeDtAndSettings) throws -> DataAndUnit {
        let raw = try reader.get(variable: variable, time: time)
        var data = raw.data
        
        guard let controlWeightFile = try reader.domain.openBiasCorrectionFile(for: variable.rawValue) else {
            throw ForecastapiError.generic(message: "Could not read reference weight file \(variable) for domain \(reader.domain)")
        }
        let controlWeights = BiasCorrectionSeasonalLinear(meansPerYear: try controlWeightFile.read(dim0Slow: reader.reader.position..<reader.reader.position+1, dim1: 0..<controlWeightFile.dim1))
        
        guard let referenceVariable = ForecastVariableDaily(rawValue: variable.rawValue), let referenceWeightFile = try referenceDomain.openBiasCorrectionFile(for: referenceVariable.rawValue) else {
            throw ForecastapiError.generic(message: "Could not read reference weight file \(variable) for domain \(referenceDomain)")
        }
        let referenceWeights = BiasCorrectionSeasonalLinear(meansPerYear: try referenceWeightFile.readInterpolated(dim0: referencePosition, dim0Nx: referenceDomain.grid.nx, dim1: 0..<referenceWeightFile.dim1))
        
        referenceWeights.applyOffset(on: &data, otherWeights: controlWeights, time: time.time, type: variable.biasCorrectionType)
        if let bounds = variable.biasCorrectionType.bounds {
            for i in data.indices {
                data[i] = Swift.min(Swift.max(data[i], bounds.lowerBound), bounds.upperBound)
            }
        }
        if case let .raw(raw) = variable {
            let isElevationCorrectable = raw == .temperature_2m_max || raw == .temperature_2m_min || raw == .temperature_2m_mean
            
            if isElevationCorrectable && raw.unit == .celsius && !targetElevation.isNaN {
                let modelElevation = try getReferenceElevation().numeric
                if !modelElevation.isNaN && targetElevation != modelElevation {
                    for i in data.indices {
                        // correct temperature by 0.65° per 100 m elevation
                        data[i] += (modelElevation - targetElevation) * 0.0065
                    }
                }
            }
        }
        return DataAndUnit(data, raw.unit)
    }
    
    func prefetchData(variable: Cmip6VariableOrDerived, time: TimerangeDtAndSettings) throws {
        try reader.prefetchData(variable: variable, time: time)
    }
    
    init?(domain: Cmip6Domain, referenceDomain: GenericDomain, lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode) throws {
        guard let reader = try GenericReader<Cmip6Domain, Cmip6Variable>(domain: domain, lat: lat, lon: lon, elevation: elevation, mode: mode) else {
            return nil
        }
        guard let referencePosition = referenceDomain.grid.findPointInterpolated(lat: lat, lon: lon) else {
            return nil
        }
        self.referenceDomain = referenceDomain
        self.referencePosition = referencePosition
        self.reader = Cmip6ReaderPreBiasCorrection(reader: reader, domain: domain)
    }
}


/**
 Perform bias correction using another domain
 */
struct Cmip6BiasCorrectorGenericDomain: GenericReaderProtocol {
    typealias MixingVar = Cmip6VariableOrDerived
    
    typealias Domain = Cmip6Domain
    
    var modelLat: Float { reader.modelLat }
    
    var modelLon: Float { reader.modelLon }
    
    var modelElevation: ElevationOrSea { reader.modelElevation }
    
    var targetElevation: Float { reader.targetElevation }
    
    var modelDtSeconds: Int { reader.modelDtSeconds }
    
    var domain: Domain { reader.domain }
    
    /// cmip reader
    let reader: Cmip6ReaderPreBiasCorrection<GenericReader<Cmip6Domain, Cmip6Variable>>
    
    /// imerg grid point
    let referencePosition: Int
    
    let referenceDomain: GenericDomain
    
    let referenceElevation: ElevationOrSea
    
    func getStatic(type: ReaderStaticVariable) throws -> Float? {
        guard let file = referenceDomain.getStaticFile(type: type) else {
            return nil
        }
        return try referenceDomain.grid.readFromStaticFile(gridpoint: referencePosition, file: file)
    }
    
    func get(variable: Cmip6VariableOrDerived, time: TimerangeDtAndSettings) throws -> DataAndUnit {
        let raw = try reader.get(variable: variable, time: time)
        var data = raw.data
        
        guard let controlWeightFile = try reader.domain.openBiasCorrectionFile(for: variable.rawValue) else {
            throw ForecastapiError.generic(message: "Could not read reference weight file \(variable) for domain \(reader.domain)")
        }
        let controlWeights = BiasCorrectionSeasonalLinear(meansPerYear: try controlWeightFile.read(dim0Slow: reader.reader.position..<reader.reader.position+1, dim1: 0..<controlWeightFile.dim1))
        
        guard let referenceVariable = ForecastVariableDaily(rawValue: variable.rawValue), let referenceWeightFile = try referenceDomain.openBiasCorrectionFile(for: referenceVariable.rawValue) else {
            throw ForecastapiError.generic(message: "Could not read reference weight file \(variable) for domain \(referenceDomain)")
        }
        let referenceWeights = BiasCorrectionSeasonalLinear(meansPerYear: try referenceWeightFile.read(dim0Slow: referencePosition..<referencePosition+1, dim1: 0..<referenceWeightFile.dim1))
        
        referenceWeights.applyOffset(on: &data, otherWeights: controlWeights, time: time.time, type: variable.biasCorrectionType)
        if let bounds = variable.biasCorrectionType.bounds {
            for i in data.indices {
                data[i] = Swift.min(Swift.max(data[i], bounds.lowerBound), bounds.upperBound)
            }
        }
        if case let .raw(raw) = variable {
            let isElevationCorrectable = raw == .temperature_2m_max || raw == .temperature_2m_min || raw == .temperature_2m_mean
            let modelElevation = referenceElevation.numeric
            if isElevationCorrectable && raw.unit == .celsius && !modelElevation.isNaN && !targetElevation.isNaN && targetElevation != modelElevation {
                for i in data.indices {
                    // correct temperature by 0.65° per 100 m elevation
                    data[i] += (modelElevation - targetElevation) * 0.0065
                }
            }
        }
        return DataAndUnit(data, raw.unit)
    }
    
    func prefetchData(variable: Cmip6VariableOrDerived, time: TimerangeDtAndSettings) throws {
        try reader.prefetchData(variable: variable, time: time)
    }
    
    init?(domain: Cmip6Domain, referenceDomain: GenericDomain, lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode) throws {
        guard let reader = try GenericReader<Cmip6Domain, Cmip6Variable>(domain: domain, lat: lat, lon: lon, elevation: elevation, mode: mode) else {
            return nil
        }
        guard let referencePosition = try referenceDomain.grid.findPoint(lat: lat, lon: lon, elevation: elevation, elevationFile: referenceDomain.getStaticFile(type: .elevation), mode: mode) else {
            return nil
        }
        self.referenceDomain = referenceDomain
        self.referenceElevation = referencePosition.gridElevation
        self.referencePosition = referencePosition.gridpoint
        
        self.reader = Cmip6ReaderPreBiasCorrection(reader: reader, domain: domain)
    }
    
    init?(domain: Cmip6Domain, referenceDomain: GenericDomain, referencePosition: Int, referenceElevation: ElevationOrSea) throws {
        
        let (lat, lon) = referenceDomain.grid.getCoordinates(gridpoint: referencePosition)
        guard let reader = try GenericReader<Cmip6Domain, Cmip6Variable>(domain: domain, lat: lat, lon: lon, elevation: referenceElevation.numeric, mode: .nearest) else {
            throw ForecastapiError.noDataAvilableForThisLocation
        }
        self.reader = Cmip6ReaderPreBiasCorrection(reader: reader, domain: domain)
        self.referenceDomain = referenceDomain
        self.referencePosition = referencePosition
        self.referenceElevation = referenceElevation
    }
}

/// There are 2 layers of derived variables
/// "PreBiasCorrected" calculated derived variables before any bias correction
/// "PostBiasCorrected" is done after bias correction
struct Cmip6ReaderPostBiasCorrected<ReaderNext: GenericReaderProtocol>: GenericReaderDerivedSimple, GenericReaderProtocol, Cmip6Readerable where ReaderNext.MixingVar == Cmip6VariableOrDerived {

    typealias Derived = Cmip6VariableDerivedPostBiasCorrection
    
    let reader: ReaderNext
    
    let domain: Cmip6Domain
    
    init(reader: ReaderNext, domain: Cmip6Domain) {
        self.reader = reader
        self.domain = domain
    }

    func get(derived: Cmip6VariableDerivedPostBiasCorrection, time: TimerangeDtAndSettings) throws -> DataAndUnit {
        switch derived {
        case .snowfall_sum:
            let snowwater = try get(raw: .raw(.snowfall_water_equivalent_sum), time: time).data
            let snowfall = snowwater.map { $0 * 0.7 }
            return DataAndUnit(snowfall, .centimetre)
        case .rain_sum:
            let snowwater = try get(raw: .raw(.snowfall_water_equivalent_sum), time: time)
            let precip = try get(raw: .raw(.precipitation_sum), time: time)
            let rain = zip(precip.data, snowwater.data).map({
                return max($0.0-$0.1, 0)
            })
            return DataAndUnit(rain, precip.unit)
        case .dewpoint_2m_max, .dew_point_2m_max:
            let tempMin = try get(raw: .raw(.temperature_2m_min), time: time).data
            let tempMax = try get(raw: .raw(.temperature_2m_max), time: time).data
            let rhMax = try get(raw: .raw(.relative_humidity_2m_max), time: time).data
            return DataAndUnit(zip(zip(tempMax, tempMin), rhMax).map(Meteorology.dewpointDaily), .celsius)
        case .dewpoint_2m_min, .dew_point_2m_min:
            let tempMin = try get(raw: .raw(.temperature_2m_min), time: time).data
            let tempMax = try get(raw: .raw(.temperature_2m_max), time: time).data
            let rhMin = try get(raw: .raw(.relative_humidity_2m_min), time: time).data
            return DataAndUnit(zip(zip(tempMax, tempMin), rhMin).map(Meteorology.dewpointDaily), .celsius)
        case .dewpoint_2m_mean, .dew_point_2m_mean:
            let tempMin = try get(raw: .raw(.temperature_2m_min), time: time).data
            let tempMax = try get(raw: .raw(.temperature_2m_max), time: time).data
            let rhMean = try get(raw: .raw(.relative_humidity_2m_mean), time: time).data
            return DataAndUnit(zip(zip(tempMax, tempMin), rhMean).map(Meteorology.dewpointDaily), .celsius)
        case .growing_degree_days_base_0_limit_50:
            let base: Float = 0
            let limit: Float = 50
            let tempmax = try get(raw: .raw(.temperature_2m_max), time: time).data
            let tempmin = try get(raw: .raw(.temperature_2m_min), time: time).data
            return DataAndUnit(zip(tempmax, tempmin).map({ (tmax, tmin) in
                max(min((tmax + tmin) / 2, limit) - base, 0)
            }), .gddCelsius)
        case .soil_moisture_index_0_to_10cm_mean:
            guard let soilType = try self.getStatic(type: .soilType) else {
                throw ForecastapiError.generic(message: "Could not read soil type")
            }
            guard let type = SoilTypeEra5(rawValue: Int(soilType)) else {
                // 0 = water
                return DataAndUnit([Float](repeating: .nan, count: time.time.count), .fraction)
            }
            let soilMoisture = try get(raw: .raw(.soil_moisture_0_to_10cm_mean), time: time)
            return DataAndUnit(type.calculateSoilMoistureIndex(soilMoisture.data), .fraction)
        case .soil_moisture_index_0_to_100cm_mean:
            guard let soilType = try self.getStatic(type: .soilType) else {
                throw ForecastapiError.generic(message: "Could not read soil type")
            }
            guard let type = SoilTypeEra5(rawValue: Int(soilType)) else {
                return DataAndUnit([Float](repeating: .nan, count: time.time.count), .fraction)
            }
            let soilMoisture = try get(raw: .derived(.soil_moisture_0_to_100cm_mean), time: time)
            return DataAndUnit(type.calculateSoilMoistureIndex(soilMoisture.data), .fraction)
        case .daylight_duration:
            // note: time should align to UTC 0 midnight
            return DataAndUnit(Zensun.calculateDaylightDuration(utcMidnight: time.range, lat: modelLat, lon: modelLon), .seconds)
        case .windspeed_2m_max, .wind_speed_2m_max:
            let wind = try get(raw: .raw(.wind_speed_10m_max), time: time)
            let scale = Meteorology.scaleWindFactor(from: 10, to: 2)
            return DataAndUnit(wind.data.map{$0*scale}, wind.unit)
        case .windspeed_2m_mean, .wind_speed_2m_mean:
            let wind = try get(raw: .raw(.wind_speed_10m_mean), time: time)
            let scale = Meteorology.scaleWindFactor(from: 10, to: 2)
            return DataAndUnit(wind.data.map{$0*scale}, wind.unit)
        case .windgusts_10m_mean:
            return try get(raw: .derived(.wind_gusts_10m_mean), time: time)
        case .windgusts_10m_max:
            return try get(raw: .derived(.wind_gusts_10m_max), time: time)
        case .vapor_pressure_deficit_max:
            return try get(raw: .derived(.vapour_pressure_deficit_max), time: time)
        case .windspeed_10m_max:
            return try get(raw: .raw(.wind_speed_10m_max), time: time)
        case .windspeed_10m_mean:
            return try get(raw: .raw(.wind_speed_10m_mean), time: time)
        }
    }
    
    func prefetchData(derived: Cmip6VariableDerivedPostBiasCorrection, time: TimerangeDtAndSettings) throws {
        switch derived {
        case .snowfall_sum:
            try prefetchData(raw: .raw(.snowfall_water_equivalent_sum), time: time)
        case .rain_sum:
            try prefetchData(raw: .raw(.precipitation_sum), time: time)
            try prefetchData(raw: .raw(.snowfall_water_equivalent_sum), time: time)
        case .dewpoint_2m_max, .dew_point_2m_max:
            try prefetchData(raw: .raw(.temperature_2m_min), time: time)
            try prefetchData(raw: .raw(.relative_humidity_2m_max), time: time)
        case .dewpoint_2m_min, .dew_point_2m_min:
            try prefetchData(raw: .raw(.temperature_2m_max), time: time)
            try prefetchData(raw: .raw(.relative_humidity_2m_min), time: time)
        case .dewpoint_2m_mean, .dew_point_2m_mean:
            try prefetchData(raw: .raw(.temperature_2m_mean), time: time)
            try prefetchData(raw: .raw(.relative_humidity_2m_mean), time: time)
        case .growing_degree_days_base_0_limit_50:
            try prefetchData(raw: .raw(.temperature_2m_max), time: time)
            try prefetchData(raw: .raw(.temperature_2m_min), time: time)
        case .soil_moisture_index_0_to_10cm_mean:
            try prefetchData(raw: .raw(.soil_moisture_0_to_10cm_mean), time: time)
        case .soil_moisture_index_0_to_100cm_mean:
            try prefetchData(raw: .derived(.soil_moisture_0_to_100cm_mean), time: time)
        case .daylight_duration:
            break
        case .windspeed_2m_max, .wind_speed_2m_max:
            try prefetchData(raw: .raw(.wind_speed_10m_max), time: time)
        case .windspeed_2m_mean, .wind_speed_2m_mean:
            try prefetchData(raw: .raw(.wind_speed_10m_mean), time: time)
        case .windgusts_10m_mean:
            try prefetchData(raw: .derived(.wind_gusts_10m_mean), time: time)
        case .windgusts_10m_max:
            try prefetchData(raw: .derived(.wind_gusts_10m_max), time: time)
        case .vapor_pressure_deficit_max:
            try prefetchData(raw: .derived(.vapour_pressure_deficit_max), time: time)
        case .windspeed_10m_max:
            try prefetchData(raw: .raw(.wind_speed_10m_max), time: time)
        case .windspeed_10m_mean:
            try prefetchData(raw: .raw(.wind_speed_10m_mean), time: time)
        }
    }
}

/// Raw input is used and bias correction is performed afterwards
struct Cmip6ReaderPreBiasCorrection<ReaderNext: GenericReaderProtocol>: GenericReaderDerivedSimple, GenericReaderProtocol where ReaderNext.MixingVar == Cmip6Variable {

    typealias Derived = Cmip6VariableDerivedBiasCorrected
    
    let reader: ReaderNext
    
    let domain: Cmip6Domain
    
    init(reader: ReaderNext, domain: Cmip6Domain) {
        self.reader = reader
        self.domain = domain
    }

    func get(derived: Cmip6VariableDerivedBiasCorrected, time: TimerangeDtAndSettings) throws -> DataAndUnit {
        switch derived {
        case .et0_fao_evapotranspiration_sum:
            let tempmax = try get(raw: .temperature_2m_max, time: time).data
            let tempmin = try get(raw: .temperature_2m_min, time: time).data
            let tempmean = try get(raw: .temperature_2m_mean, time: time).data
            let wind = try get(raw: .wind_speed_10m_mean, time: time).data
            let radiation = try get(raw: .shortwave_radiation_sum, time: time).data
            let exrad = Zensun.extraTerrestrialRadiationBackwards(latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time.with(dtSeconds: 3600)).sum(by: 24)
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
            return DataAndUnit(et0, .millimetre)
        case .vapour_pressure_deficit_max:
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
            return DataAndUnit(vpd, .kilopascal)
        case .leaf_wetness_probability_mean:
            let tempmax = try get(raw: .temperature_2m_max, time: time).data
            let tempmin = try get(raw: .temperature_2m_min, time: time).data
            let hasRhMinMax = !(domain == .FGOALS_f3_H || domain == .HiRAM_SIT_HR || domain == .MPI_ESM1_2_XR || domain == .FGOALS_f3_H)
            let rhmin = hasRhMinMax ? try get(raw: .relative_humidity_2m_min, time: time).data : nil
            let rhmaxOrMean = hasRhMinMax ? try get(raw: .relative_humidity_2m_max, time: time).data : try get(raw: .relative_humidity_2m_mean, time: time).data
            let preciptitation = try get(raw: .precipitation_sum, time: time).data
            
            var leafWetness = [Float]()
            leafWetness.reserveCapacity(tempmax.count)
            for i in tempmax.indices {
                let rh: Meteorology.MaxAndMinOrMean
                if let rhmin {
                    rh = .maxmin(max: rhmaxOrMean[i], min: rhmin[i])
                } else {
                    rh = .mean(mean: rhmaxOrMean[i])
                }
                leafWetness.append(Meteorology.leafwetnessPorbabilityDaily(temperature2mCelsiusDaily: (max: tempmax[i], min: tempmin[i]), relativeHumidity: rh, precipitation: preciptitation[i]))
            }
            return DataAndUnit(leafWetness, .percentage)
        case .soil_moisture_0_to_100cm_mean:
            // estimate soil moisture in 0-100 by a moving average over 0-10 cm moisture
            let sm0_10 = try get(raw: .soil_moisture_0_to_10cm_mean, time: time)
            let sm10_28 = sm0_10.data.indices.map { return sm0_10.data[max(0, $0-5) ..< $0+1].mean() }
            let sm28_100 = sm10_28.indices.map { return sm10_28[max(0, $0-51) ..< $0+1].mean() }
            return DataAndUnit(zip(sm0_10.data, zip(sm10_28, sm28_100)).map({
                let (sm0_10, (sm10_28, sm28_100)) = $0
                return sm0_10 * 0.1 + sm10_28 * (0.28 - 0.1) + sm28_100 * (1 - 0.28)
            }), sm0_10.unit)
        case .soil_moisture_0_to_7cm_mean:
            return try get(raw: .soil_moisture_0_to_10cm_mean, time: time)
        case .soil_moisture_7_to_28cm_mean:
            let sm0_10 = try get(raw: .soil_moisture_0_to_10cm_mean, time: time)
            let sm10_28 = sm0_10.data.indices.map { return sm0_10.data[max(0, $0-5) ..< $0+1].mean() }
            return DataAndUnit(sm10_28, sm0_10.unit)
        case .soil_moisture_28_to_100cm_mean:
            let sm0_10 = try get(raw: .soil_moisture_0_to_10cm_mean, time: time)
            let sm10_28 = sm0_10.data.indices.map { return sm0_10.data[max(0, $0-5) ..< $0+1].mean() }
            let sm28_100 = sm10_28.indices.map { return sm10_28[max(0, $0-51) ..< $0+1].mean() }
            return DataAndUnit(sm28_100, sm0_10.unit)
        case .soil_temperature_0_to_100cm_mean:
            let t2m = try get(raw: .temperature_2m_mean, time: time)
            let st0_7 = t2m.data.indices.map { return t2m.data[max(0, $0-3) ..< $0+1].mean() }
            let st7_28 = st0_7.indices.map { return st0_7[max(0, $0-5) ..< $0+1].mean() }
            let st28_100 = st7_28.indices.map { return st7_28[max(0, $0-51) ..< $0+1].mean() }
            return DataAndUnit(zip(st0_7, zip(st7_28, st28_100)).map({
                let (st0_7, (st7_28, st28_100)) = $0
                return st0_7 * 0.07 + st7_28 * (0.28 - 0.07) + st28_100 * (1 - 0.28)
            }), t2m.unit)
        case .soil_temperature_0_to_7cm_mean:
            let t2m = try get(raw: .temperature_2m_mean, time: time)
            let st0_7 = t2m.data.indices.map { return t2m.data[max(0, $0-3) ..< $0+1].mean() }
            return DataAndUnit(st0_7, t2m.unit)
        case .soil_temperature_7_to_28cm_mean:
            let t2m = try get(raw: .temperature_2m_mean, time: time)
            let st0_7 = t2m.data.indices.map { return t2m.data[max(0, $0-3) ..< $0+1].mean() }
            let st7_28 = st0_7.indices.map { return st0_7[max(0, $0-5) ..< $0+1].mean() }
            return DataAndUnit(st7_28, t2m.unit)
        case .soil_temperature_28_to_100cm_mean:
            let t2m = try get(raw: .temperature_2m_mean, time: time)
            let st0_7 = t2m.data.indices.map { return t2m.data[max(0, $0-3) ..< $0+1].mean() }
            let st7_28 = st0_7.indices.map { return st0_7[max(0, $0-5) ..< $0+1].mean() }
            let st28_100 = st7_28.indices.map { return st7_28[max(0, $0-51) ..< $0+1].mean() }
            return DataAndUnit(st28_100, t2m.unit)
        case .wind_gusts_10m_mean:
            return try get(raw: .wind_speed_10m_mean, time: time)
        case .wind_gusts_10m_max:
            return try get(raw: .wind_speed_10m_max, time: time)
        }
    }
    
    func prefetchData(derived: Cmip6VariableDerivedBiasCorrected, time: TimerangeDtAndSettings) throws {
        switch derived {
        case .et0_fao_evapotranspiration_sum:
            try prefetchData(raw: .temperature_2m_max, time: time)
            try prefetchData(raw: .temperature_2m_min, time: time)
            try prefetchData(raw: .temperature_2m_mean, time: time)
            try prefetchData(raw: .wind_speed_10m_mean, time: time)
            try prefetchData(raw: .shortwave_radiation_sum, time: time)
            let hasRhMinMax = !(domain == .FGOALS_f3_H || domain == .HiRAM_SIT_HR || domain == .MPI_ESM1_2_XR || domain == .FGOALS_f3_H)
            if hasRhMinMax {
                try prefetchData(raw: .relative_humidity_2m_min, time: time)
                try prefetchData(raw: .relative_humidity_2m_max, time: time)
            } else {
                try prefetchData(raw: .relative_humidity_2m_mean, time: time)
            }
        case .vapour_pressure_deficit_max:
            try prefetchData(raw: .temperature_2m_max, time: time)
            try prefetchData(raw: .temperature_2m_min, time: time)
            let hasRhMinMax = !(domain == .FGOALS_f3_H || domain == .HiRAM_SIT_HR || domain == .MPI_ESM1_2_XR || domain == .FGOALS_f3_H)
            if hasRhMinMax {
                try prefetchData(raw: .relative_humidity_2m_min, time: time)
                try prefetchData(raw: .relative_humidity_2m_max, time: time)
            } else {
                try prefetchData(raw: .relative_humidity_2m_mean, time: time)
            }
        case .leaf_wetness_probability_mean:
            try prefetchData(raw: .temperature_2m_max, time: time)
            try prefetchData(raw: .temperature_2m_min, time: time)
            try prefetchData(raw: .precipitation_sum, time: time)
            let hasRhMinMax = !(domain == .FGOALS_f3_H || domain == .HiRAM_SIT_HR || domain == .MPI_ESM1_2_XR || domain == .FGOALS_f3_H)
            if hasRhMinMax {
                try prefetchData(raw: .relative_humidity_2m_min, time: time)
                try prefetchData(raw: .relative_humidity_2m_max, time: time)
            } else {
                try prefetchData(raw: .relative_humidity_2m_mean, time: time)
            }
        case .soil_moisture_0_to_100cm_mean:
            try prefetchData(raw: .soil_moisture_0_to_10cm_mean, time: time)
        case .soil_moisture_0_to_7cm_mean:
            try prefetchData(raw: .soil_moisture_0_to_10cm_mean, time: time)
        case .soil_moisture_7_to_28cm_mean:
            try prefetchData(raw: .soil_moisture_0_to_10cm_mean, time: time)
        case .soil_moisture_28_to_100cm_mean:
            try prefetchData(raw: .soil_moisture_0_to_10cm_mean, time: time)
        case .soil_temperature_0_to_100cm_mean:
            try prefetchData(raw: .temperature_2m_mean, time: time)
        case .soil_temperature_0_to_7cm_mean:
            try prefetchData(raw: .temperature_2m_max, time: time)
        case .soil_temperature_7_to_28cm_mean:
            try prefetchData(raw: .temperature_2m_max, time: time)
        case .soil_temperature_28_to_100cm_mean:
            try prefetchData(raw: .temperature_2m_max, time: time)
        case .wind_gusts_10m_mean:
            try prefetchData(raw: .wind_speed_10m_mean, time: time)
        case .wind_gusts_10m_max:
            try prefetchData(raw: .wind_speed_10m_max, time: time)
        }
    }
}
