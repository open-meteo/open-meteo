//enum EcmwfSeasVariable24HourlySingleLevelDerived: String, RawRepresentableString, GenericVariableMixable {
//    case temperature_2m_max
//    case temperature_2m_min
//    case temperature_2m_mean
//}
//
///// Available daily aggregations
//enum EcmwfSeasVariableDailyComputed: String, DailyVariableCalculatable, RawRepresentableString, FlatBuffersVariable {
//    case apparent_temperature_max
//    case apparent_temperature_mean
//    case apparent_temperature_min
//    case cloud_cover_max
//    case cloud_cover_mean
//    case cloud_cover_min
//    case dew_point_2m_max
//    case dew_point_2m_mean
//    case dew_point_2m_min
//    case et0_fao_evapotranspiration
//    case et0_fao_evapotranspiration_sum
//    case pressure_msl_max
//    case pressure_msl_mean
//    case pressure_msl_min
//    case precipitation_sum
//    case rain_sum
//    case relative_humidity_2m_max
//    case relative_humidity_2m_mean
//    case relative_humidity_2m_min
//    case shortwave_radiation_sum
//    case snowfall_sum
//    case snowfall_water_equivalent_sum
//
//    case sunrise
//    case sunset
//    case daylight_duration
//
//    case surface_pressure_max
//    case surface_pressure_mean
//    case surface_pressure_min
//
//    case vapor_pressure_deficit_max
//    case vapour_pressure_deficit_max
//
//    case weathercode
//    case weather_code
//    
//    case wind_direction_10m_dominant
//    case wind_speed_10m_max
//    case wind_speed_10m_mean
//    case wind_speed_10m_min
//    case wet_bulb_temperature_2m_max
//    case wet_bulb_temperature_2m_mean
//    case wet_bulb_temperature_2m_min
//    
//    case sea_surface_temperature_min
//    case sea_surface_temperature_max
//    case sea_surface_temperature_mean
//    
//    case soil_temperature_0_to_7cm_mean
//
//    var aggregation: DailyAggregation<SeasonalVariableHourly> {
//        switch self {
//        case .apparent_temperature_max:
//            return .max(.apparent_temperature)
//        case .apparent_temperature_mean:
//            return .mean(.apparent_temperature)
//        case .apparent_temperature_min:
//            return .min(.apparent_temperature)
//        case .cloud_cover_max:
//            return .max(.cloud_cover)
//        case .cloud_cover_mean:
//            return .mean(.cloud_cover)
//        case .cloud_cover_min:
//            return .min(.cloud_cover)
//        case .dew_point_2m_max:
//            return .max(.dew_point_2m)
//        case .dew_point_2m_mean:
//            return .mean(.dew_point_2m)
//        case .dew_point_2m_min:
//            return .min(.dew_point_2m)
//        case .et0_fao_evapotranspiration, .et0_fao_evapotranspiration_sum:
//            return .sum(.et0_fao_evapotranspiration)
//        case .pressure_msl_max:
//            return .max(.pressure_msl)
//        case .pressure_msl_mean:
//            return .mean(.pressure_msl)
//        case .pressure_msl_min:
//            return .min(.pressure_msl)
//        case .rain_sum:
//            return .sum(.rain)
//        case .relative_humidity_2m_max:
//            return .max(.relative_humidity_2m)
//        case .relative_humidity_2m_mean:
//            return .mean(.relative_humidity_2m)
//        case .relative_humidity_2m_min:
//            return .min(.relative_humidity_2m)
//        case .shortwave_radiation_sum:
//            return .radiationSum(.shortwave_radiation)
//        case .snowfall_sum:
//            return .sum(.snowfall)
//        case .snowfall_water_equivalent_sum:
//            return .sum(.snowfall_water_equivalent)
//        case .sunrise:
//            return .none
//        case .sunset:
//            return .none
//        case .daylight_duration:
//            return .none
//        case .surface_pressure_max:
//            return .max(.surface_pressure)
//        case .surface_pressure_mean:
//            return .mean(.surface_pressure)
//        case .surface_pressure_min:
//            return .min(.surface_pressure)
//        case .vapor_pressure_deficit_max, .vapour_pressure_deficit_max:
//            return .max(.vapor_pressure_deficit)
//        case .weathercode, .weather_code:
//            return .max(.weathercode)
//        case .wind_direction_10m_dominant:
//            return .dominantDirectionComponents(u: .wind_u_component_10m, v: .wind_v_component_10m)
//        case .wind_speed_10m_max:
//            return .max(.wind_speed_10m)
//        case .wind_speed_10m_mean:
//            return .mean(.wind_speed_10m)
//        case .wind_speed_10m_min:
//            return .min(.wind_speed_10m)
//        case .wet_bulb_temperature_2m_max:
//            return .max(.wet_bulb_temperature_2m)
//        case .wet_bulb_temperature_2m_mean:
//            return .mean(.wet_bulb_temperature_2m)
//        case .wet_bulb_temperature_2m_min:
//            return .min(.wet_bulb_temperature_2m)
//        case .precipitation_sum:
//            return .sum(.precipitation)
//        case .sea_surface_temperature_min:
//            return .min(.sea_surface_temperature)
//        case .sea_surface_temperature_max:
//            return .max(.sea_surface_temperature)
//        case .sea_surface_temperature_mean:
//            return .mean(.sea_surface_temperature)
//        case .soil_temperature_0_to_7cm_mean:
//            return .mean(.soil_temperature_0_to_7cm)
//        }
//    }
//    
//    func getFlatBuffersMeta() -> FlatBufferVariableMeta {
//        switch self {
//        case .apparent_temperature_max:
//            return .init(variable: .apparentTemperature, aggregation: .maximum)
//        case .apparent_temperature_mean:
//            return .init(variable: .apparentTemperature, aggregation: .mean)
//        case .apparent_temperature_min:
//            return .init(variable: .apparentTemperature, aggregation: .minimum)
//        case .cloud_cover_max:
//            return .init(variable: .cloudCover, aggregation: .maximum)
//        case .cloud_cover_mean:
//            return .init(variable: .cloudCover, aggregation: .mean)
//        case .cloud_cover_min:
//            return .init(variable: .cloudCover, aggregation: .minimum)
//        case .dew_point_2m_max:
//            return .init(variable: .dewPoint, aggregation: .maximum, altitude: 2)
//        case .dew_point_2m_mean:
//            return .init(variable: .dewPoint, aggregation: .mean, altitude: 2)
//        case .dew_point_2m_min:
//            return .init(variable: .dewPoint, aggregation: .minimum, altitude: 2)
//        case .et0_fao_evapotranspiration, .et0_fao_evapotranspiration_sum:
//            return .init(variable: .et0FaoEvapotranspiration, aggregation: .sum)
//        case .pressure_msl_max:
//            return .init(variable: .pressureMsl, aggregation: .maximum)
//        case .pressure_msl_mean:
//            return .init(variable: .pressureMsl, aggregation: .mean)
//        case .pressure_msl_min:
//            return .init(variable: .pressureMsl, aggregation: .minimum)
//        case .precipitation_sum:
//            return .init(variable: .precipitation, aggregation: .sum)
//        case .rain_sum:
//            return .init(variable: .rain, aggregation: .sum)
//        case .relative_humidity_2m_max:
//            return .init(variable: .relativeHumidity, aggregation: .maximum, altitude: 2)
//        case .relative_humidity_2m_mean:
//            return .init(variable: .relativeHumidity, aggregation: .mean, altitude: 2)
//        case .relative_humidity_2m_min:
//            return .init(variable: .relativeHumidity, aggregation: .minimum, altitude: 2)
//        case .shortwave_radiation_sum:
//            return .init(variable: .shortwaveRadiation, aggregation: .sum)
//        case .snowfall_sum:
//            return .init(variable: .snowfall, aggregation: .sum)
//        case .snowfall_water_equivalent_sum:
//            return .init(variable: .snowfallWaterEquivalent, aggregation: .sum)
//        case .sunrise:
//            return .init(variable: .sunrise)
//        case .sunset:
//            return .init(variable: .sunset)
//        case .daylight_duration:
//            return .init(variable: .daylightDuration)
//        case .surface_pressure_max:
//            return .init(variable: .surfacePressure, aggregation: .maximum)
//        case .surface_pressure_mean:
//            return .init(variable: .surfacePressure, aggregation: .mean)
//        case .surface_pressure_min:
//            return .init(variable: .surfacePressure, aggregation: .minimum)
//        case .vapor_pressure_deficit_max, .vapour_pressure_deficit_max:
//            return .init(variable: .vapourPressureDeficit, aggregation: .maximum)
//        case .weathercode, .weather_code:
//            return .init(variable: .weatherCode)
//        case .wind_direction_10m_dominant:
//            return .init(variable: .windDirection, aggregation: .dominant, altitude: 10)
//        case .wind_speed_10m_max:
//            return .init(variable: .windSpeed, aggregation: .maximum, altitude: 10)
//        case .wind_speed_10m_mean:
//            return .init(variable: .windSpeed, aggregation: .mean, altitude: 10)
//        case .wind_speed_10m_min:
//            return .init(variable: .windSpeed, aggregation: .minimum, altitude: 10)
//        case .wet_bulb_temperature_2m_max:
//            return .init(variable: .wetBulbTemperature, aggregation: .maximum, altitude: 2)
//        case .wet_bulb_temperature_2m_mean:
//            return .init(variable: .wetBulbTemperature, aggregation: .mean, altitude: 2)
//        case .wet_bulb_temperature_2m_min:
//            return .init(variable: .wetBulbTemperature, aggregation: .minimum, altitude: 2)
//        case .sea_surface_temperature_min:
//            return .init(variable: .seaSurfaceTemperature, aggregation: .minimum)
//        case .sea_surface_temperature_max:
//            return .init(variable: .seaSurfaceTemperature, aggregation: .maximum)
//        case .sea_surface_temperature_mean:
//            return .init(variable: .seaSurfaceTemperature, aggregation: .mean)
//        case .soil_temperature_0_to_7cm_mean:
//            return .init(variable: .soilTemperature, aggregation: .mean, depth: 0, depthTo: 7)
//        }
//    }
//}
//
//
//struct EcmwfSeas5Controller24Hourly: GenericReaderDerivedSimple, GenericReaderProtocol {
//    let reader: GenericReaderCached<EcmwfSeasDomain, EcmwfSeasVariable24HourlySingleLevel>
//
//    let options: GenericReaderOptions
//
//    typealias Domain = EcmwfSeasDomain
//
//    typealias Variable = VariableOrDerived<EcmwfSeasVariable24HourlySingleLevel, EcmwfSeasVariable24HourlySingleLevelDerived>
//
//    typealias Derived = EcmwfSeasVariable24HourlySingleLevelDerived
//
//    public init?(lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode, options: GenericReaderOptions) async throws {
//        guard let reader = try await GenericReader<Domain, EcmwfSeasVariable24HourlySingleLevel>(domain: .seas5_24hourly, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options) else {
//            return nil
//        }
//        self.reader = GenericReaderCached(reader: reader)
//        self.options = options
//    }
//    
//    public init(gridpoint: Int, options: GenericReaderOptions) async throws {
//        let reader = try await GenericReader<Domain, EcmwfSeasVariable24HourlySingleLevel>(domain: .seas5_24hourly, position: gridpoint, options: options)
//        self.reader = GenericReaderCached(reader: reader)
//        self.options = options
//    }
//
//    func prefetchData(variables: [Variable], time: TimerangeDtAndSettings) async throws {
//        for variable in variables {
//            switch variable {
//            case .raw(let v):
//                try await prefetchData(raw: v, time: time)
//            case .derived(let v):
//                try await prefetchData(derived: v, time: time)
//            }
//        }
//    }
//
//    func prefetchData(derived: EcmwfSeasVariable24HourlySingleLevelDerived, time: TimerangeDtAndSettings) async throws {
//        let time24hAgo = time.with(time: time.time.add(-86400))
//        switch derived {
//        case .temperature_2m_max:
//            try await prefetchData(raw: .temperature_max24h_2m, time: time24hAgo)
//        case .temperature_2m_min:
//            try await prefetchData(raw: .temperature_min24h_2m, time: time24hAgo)
//        case .temperature_2m_mean:
//            try await prefetchData(raw: .temperature_mean24h_2m, time: time24hAgo)
//        }
//    }
//
//    func get(variable: Variable, time: TimerangeDtAndSettings) async throws -> DataAndUnit {
//        switch variable {
//        case .raw(let variable):
//            return try await get(raw: variable, time: time)
//        case .derived(let variable):
//            return try await get(derived: variable, time: time)
//        }
//    }
//
//    func get(derived: EcmwfSeasVariable24HourlySingleLevelDerived, time: TimerangeDtAndSettings) async throws -> DataAndUnit {
//        let time24hAgo = time.with(time: time.time.add(-86400))
//        switch derived {
//        case .temperature_2m_max:
//            return try await get(raw: .temperature_max24h_2m, time: time24hAgo)
//        case .temperature_2m_min:
//            return try await get(raw: .temperature_min24h_2m, time: time24hAgo)
//        case .temperature_2m_mean:
//            return try await get(raw: .temperature_mean24h_2m, time: time24hAgo)
//        }
//    }
//}
