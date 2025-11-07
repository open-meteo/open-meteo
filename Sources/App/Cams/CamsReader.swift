

struct CamsReader: GenericReaderDerivedSimple, GenericReaderProtocol {
    typealias MixingVar = VariableOrDerived<CamsVariable, CamsVariableDerived>

    typealias Domain = CamsDomain

    typealias Variable = CamsVariable

    typealias Derived = CamsVariableDerived

    let reader: GenericReaderCached<CamsDomain, CamsVariable>

    func get(derived: CamsVariableDerived, time: TimerangeDtAndSettings) async throws -> DataAndUnit {
        switch derived {
        case .european_aqi:
            let pm2_5 = try await get(derived: .european_aqi_pm2_5, time: time).data
            let pm10 = try await get(derived: .european_aqi_pm10, time: time).data
            let no2 = try await get(derived: .european_aqi_no2, time: time).data
            let o3 = try await get(derived: .european_aqi_o3, time: time).data
            let so2 = try await get(derived: .european_aqi_so2, time: time).data
            let max = pm2_5.indices.map({ i -> Float in
                return Swift.max(Swift.max(Swift.max(Swift.max(pm2_5[i], pm10[i]), no2[i]), o3[i]), so2[i])
            })
            return DataAndUnit(max, .europeanAirQualityIndex)
        case .european_aqi_pm2_5:
            let timeAhead = time.with(start: time.range.lowerBound.add(-24 * 3600))
            let pm2_5 = try await get(raw: .pm2_5, time: timeAhead).data.slidingAverageDroppingFirstDt(dt: 24 * 3600 / time.dtSeconds)
            return DataAndUnit(pm2_5.map(EuropeanAirQuality.indexPm2_5), .europeanAirQualityIndex)
        case .european_aqi_pm10:
            let timeAhead = time.with(start: time.range.lowerBound.add(-24 * 3600))
            let pm10avg = try await get(raw: .pm10, time: timeAhead).data.slidingAverageDroppingFirstDt(dt: 24 * 3600 / time.dtSeconds)
            return DataAndUnit(pm10avg.map(EuropeanAirQuality.indexPm10), .europeanAirQualityIndex)
        case .european_aqi_nitrogen_dioxide, .european_aqi_no2:
            let no2 = try await get(raw: .nitrogen_dioxide, time: time).data
            return DataAndUnit(no2.map(EuropeanAirQuality.indexNo2), .europeanAirQualityIndex)
        case .european_aqi_ozone, .european_aqi_o3:
            let o3 = try await get(raw: .ozone, time: time).data
            return DataAndUnit(o3.map(EuropeanAirQuality.indexO3), .europeanAirQualityIndex)
        case .european_aqi_sulphur_dioxide, .european_aqi_so2:
            let so2 = try await get(raw: .sulphur_dioxide, time: time).data
            return DataAndUnit(so2.map(EuropeanAirQuality.indexSo2), .europeanAirQualityIndex)
        case .us_aqi:
            let pm2_5 = try await get(derived: .us_aqi_pm2_5, time: time).data
            let pm10 = try await get(derived: .us_aqi_pm10, time: time).data
            let no2 = try await get(derived: .us_aqi_no2, time: time).data
            let o3 = try await get(derived: .us_aqi_o3, time: time).data
            let so2 = try await get(derived: .us_aqi_so2, time: time).data
            let co = try await get(derived: .us_aqi_co, time: time).data
            let max = pm2_5.indices.map({ i -> Float in
                return Swift.max(Swift.max(Swift.max(Swift.max(pm2_5[i], Swift.max(pm10[i], co[i])), no2[i]), o3[i]), so2[i])
            })
            return DataAndUnit(max, .usAirQualityIndex)
        case .us_aqi_pm2_5:
            let timeAhead = time.with(start: time.range.lowerBound.add(-24 * 3600))
            let pm2_5 = try await get(raw: .pm2_5, time: timeAhead).data.slidingAverageDroppingFirstDt(dt: 24 * 3600 / time.dtSeconds)
            return DataAndUnit(pm2_5.map(UnitedStatesAirQuality.indexPm2_5), .usAirQualityIndex)
        case .us_aqi_pm10:
            let timeAhead = time.with(start: time.range.lowerBound.add(-24 * 3600))
            let pm10avg = try await get(raw: .pm10, time: timeAhead).data.slidingAverageDroppingFirstDt(dt: 24 * 3600 / time.dtSeconds)
            return DataAndUnit(pm10avg.map(UnitedStatesAirQuality.indexPm10), .usAirQualityIndex)
        case .us_aqi_nitrogen_dioxide, .us_aqi_no2:
            // need to convert from ugm3 to ppb
            let no2 = try await get(raw: .nitrogen_dioxide, time: time).data
            return DataAndUnit(no2.map({ UnitedStatesAirQuality.indexNo2(no2: $0 / 1.88) }), .usAirQualityIndex)
        case .us_aqi_ozone, .us_aqi_o3:
            // need to convert from ugm3 to ppb
            let timeAhead = time.with(start: time.range.lowerBound.add(-8 * 3600))
            let o3 = try await get(raw: .ozone, time: timeAhead).data
            let o3avg = o3.slidingAverageDroppingFirstDt(dt: 8 * 3600 / time.dtSeconds)
            return DataAndUnit(zip(o3.dropFirst(8 * 3600 / time.dtSeconds), o3avg).map({ UnitedStatesAirQuality.indexO3(o3: $0.0 / 1.96, o3_8h_mean: $0.1 / 1.96) }), .usAirQualityIndex)
        case .us_aqi_sulphur_dioxide, .us_aqi_so2:
            // need to convert from ugm3 to ppb
            let timeAhead = time.with(start: time.range.lowerBound.add(-24 * 3600))
            let so2 = try await get(raw: .sulphur_dioxide, time: timeAhead).data
            let so2avg = so2.slidingAverageDroppingFirstDt(dt: 24 * 3600 / time.dtSeconds)
            return DataAndUnit(zip(so2.dropFirst(24 * 3600 / time.dtSeconds), so2avg).map({ UnitedStatesAirQuality.indexSo2(so2: $0.0 / 2.62, so2_24h_mean: $0.1 / 2.62) }), .usAirQualityIndex)
        case .us_aqi_carbon_monoxide, .us_aqi_co:
            // need to convert from ugm3 to ppm
            let timeAhead = time.with(start: time.range.lowerBound.add(-8 * 3600))
            let co = try await get(raw: .carbon_monoxide, time: timeAhead).data.slidingAverageDroppingFirstDt(dt: 8 * 3600 / time.dtSeconds)
            return DataAndUnit(co.map({ UnitedStatesAirQuality.indexCo(co_8h_mean: $0 / 1.15 / 1000) }), .usAirQualityIndex)
        case .is_day:
            return DataAndUnit(Zensun.calculateIsDay(timeRange: time.time, lat: reader.modelLat, lon: reader.modelLon), .dimensionlessInteger)
        }
    }

    func prefetchData(derived: CamsVariableDerived, time: TimerangeDtAndSettings) async throws {
        switch derived {
        case .european_aqi:
            try await prefetchData(derived: .european_aqi_pm2_5, time: time)
            try await prefetchData(derived: .european_aqi_pm10, time: time)
            try await prefetchData(derived: .european_aqi_no2, time: time)
            try await prefetchData(derived: .european_aqi_o3, time: time)
            try await prefetchData(derived: .european_aqi_so2, time: time)
        case .european_aqi_pm2_5:
            try await prefetchData(raw: .pm2_5, time: time.with(start: time.range.lowerBound.add(-24 * 3600)))
        case .european_aqi_pm10:
            try await prefetchData(raw: .pm10, time: time.with(start: time.range.lowerBound.add(-24 * 3600)))
        case .european_aqi_nitrogen_dioxide, .european_aqi_no2:
            try await prefetchData(raw: .nitrogen_dioxide, time: time)
        case .european_aqi_ozone, .european_aqi_o3:
            try await prefetchData(raw: .ozone, time: time)
        case .european_aqi_sulphur_dioxide, .european_aqi_so2:
            try await prefetchData(raw: .sulphur_dioxide, time: time)
        case .us_aqi:
            try await prefetchData(derived: .us_aqi_pm2_5, time: time)
            try await prefetchData(derived: .us_aqi_pm10, time: time)
            try await prefetchData(derived: .us_aqi_no2, time: time)
            try await prefetchData(derived: .us_aqi_o3, time: time)
            try await prefetchData(derived: .us_aqi_so2, time: time)
            try await prefetchData(derived: .us_aqi_co, time: time)
        case .us_aqi_pm2_5:
            try await prefetchData(raw: .pm2_5, time: time.with(start: time.range.lowerBound.add(-24 * 3600)))
        case .us_aqi_pm10:
            try await prefetchData(raw: .pm10, time: time.with(start: time.range.lowerBound.add(-24 * 3600)))
        case .us_aqi_nitrogen_dioxide, .us_aqi_no2:
            try await prefetchData(raw: .nitrogen_dioxide, time: time)
        case .us_aqi_ozone, .us_aqi_o3:
            try await prefetchData(raw: .ozone, time: time.with(start: time.range.lowerBound.add(-8 * 3600)))
        case .us_aqi_sulphur_dioxide, .us_aqi_so2:
            try await prefetchData(raw: .ozone, time: time.with(start: time.range.lowerBound.add(-24 * 3600)))
        case .us_aqi_carbon_monoxide, .us_aqi_co:
            try await prefetchData(raw: .ozone, time: time.with(start: time.range.lowerBound.add(-8 * 3600)))
        case .is_day:
            break
        }
    }
}


enum CamsVariableDerived: String, GenericVariableMixable {
    case european_aqi
    case european_aqi_pm2_5
    case european_aqi_pm10
    case european_aqi_no2
    case european_aqi_o3
    case european_aqi_so2
    case european_aqi_nitrogen_dioxide
    case european_aqi_ozone
    case european_aqi_sulphur_dioxide

    case us_aqi
    case us_aqi_pm2_5
    case us_aqi_pm10
    case us_aqi_no2
    case us_aqi_o3
    case us_aqi_so2
    case us_aqi_co
    case us_aqi_nitrogen_dioxide
    case us_aqi_ozone
    case us_aqi_sulphur_dioxide
    case us_aqi_carbon_monoxide

    case is_day
}

extension TimerangeDt {
    func with(start: Timestamp) -> TimerangeDt {
        TimerangeDt(start: start, to: range.upperBound, dtSeconds: dtSeconds)
    }
}

extension Array where Element == Float {
    /// Resulting array will be `dt` elements shorter
    func slidingAverageDroppingFirstDt(dt: Int) -> [Float] {
        return (0 ..< Swift.max(self.count - dt, 0)).map { i in
            return self[i..<Swift.min(i + dt, self.count)].reduce(0, +) / Float(dt)
        }
    }
}

struct CamsMixer: GenericReaderMixer {
    let reader: [CamsReader]

    static func makeReader(domain: CamsDomain, lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode, options: GenericReaderOptions) async throws -> CamsReader? {
        guard let reader = try await GenericReader<CamsDomain, CamsVariable>(domain: domain, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options) else {
            return nil
        }
        return CamsReader(reader: GenericReaderCached(reader: reader))
    }
}

struct CamsQuery {
}

extension CamsQuery {
    enum Domain: String, Codable, Sendable, RawRepresentableString {
        case auto
        case cams_global
        case cams_europe
        
        var multiDomain: MultiDomains {
            switch self {
            case .auto:
                return .air_quality_best_match
            case .cams_global:
                return .cams_global
            case .cams_europe:
                return .cams_europe
            }
        }
    }
}
