import Foundation

struct EcmwfReader: GenericReaderDerived, GenericReaderProtocol {
    let reader: GenericReaderCached<EcmwfDomain, Variable>

    let options: GenericReaderOptions

    typealias Domain = EcmwfDomain

    typealias Variable = EcmwfVariable

    typealias Derived = EcmwfVariableDerived

    public init?(domain: Domain, lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode, options: GenericReaderOptions) throws {
        guard let reader = try GenericReader<Domain, Variable>(domain: domain, lat: lat, lon: lon, elevation: elevation, mode: mode) else {
            return nil
        }
        self.reader = GenericReaderCached(reader: reader)
        self.options = options
    }

    public init(domain: Domain, gridpoint: Int, options: GenericReaderOptions) throws {
        let reader = try GenericReader<Domain, Variable>(domain: domain, position: gridpoint)
        self.reader = GenericReaderCached(reader: reader)
        self.options = options
    }

    func prefetchData(raw: EcmwfVariable, time: TimerangeDtAndSettings) throws {
        try reader.prefetchData(variable: raw, time: time)
    }

    func get(raw: EcmwfVariable, time: TimerangeDtAndSettings) throws -> DataAndUnit {
        return try reader.get(variable: raw, time: time)
    }

    func get(derived: Derived, time: TimerangeDtAndSettings) throws -> DataAndUnit {
        switch derived {
        case .wind_speed_10m, .windspeed_10m:
            let v = try get(raw: .wind_v_component_10m, time: time)
            let u = try get(raw: .wind_u_component_10m, time: time)
            let speed = zip(u.data, v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .metrePerSecond)
        case .wind_direction_10m, .winddirection_10m:
            let v = try get(raw: .wind_v_component_10m, time: time)
            let u = try get(raw: .wind_u_component_10m, time: time)
            let direction = Meteorology.windirectionFast(u: u.data, v: v.data)
            return DataAndUnit(direction, .degreeDirection)
        case .wind_speed_100m, .windspeed_100m:
            let v = try get(raw: .wind_v_component_100m, time: time)
            let u = try get(raw: .wind_u_component_100m, time: time)
            let speed = zip(u.data, v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .metrePerSecond)
        case .wind_direction_100m, .winddirection_100m:
            let v = try get(raw: .wind_v_component_100m, time: time)
            let u = try get(raw: .wind_u_component_100m, time: time)
            let direction = Meteorology.windirectionFast(u: u.data, v: v.data)
            return DataAndUnit(direction, .degreeDirection)
        case .wind_speed_1000hPa, .windspeed_1000hPa:
            let v = try get(raw: .wind_v_component_1000hPa, time: time)
            let u = try get(raw: .wind_u_component_1000hPa, time: time)
            let speed = zip(u.data, v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .metrePerSecond)
        case .wind_speed_925hPa, .windspeed_925hPa:
            let v = try get(raw: .wind_v_component_925hPa, time: time)
            let u = try get(raw: .wind_u_component_925hPa, time: time)
            let speed = zip(u.data, v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .metrePerSecond)
        case .wind_speed_850hPa, .windspeed_850hPa:
            let v = try get(raw: .wind_v_component_850hPa, time: time)
            let u = try get(raw: .wind_u_component_850hPa, time: time)
            let speed = zip(u.data, v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .metrePerSecond)
        case .wind_speed_700hPa, .windspeed_700hPa:
            let v = try get(raw: .wind_v_component_700hPa, time: time)
            let u = try get(raw: .wind_u_component_700hPa, time: time)
            let speed = zip(u.data, v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .metrePerSecond)
        case .wind_speed_600hPa, .windspeed_600hPa:
            let v = try get(raw: .wind_v_component_600hPa, time: time)
            let u = try get(raw: .wind_u_component_600hPa, time: time)
            let speed = zip(u.data, v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .metrePerSecond)
        case .wind_speed_500hPa, .windspeed_500hPa:
            let v = try get(raw: .wind_v_component_500hPa, time: time)
            let u = try get(raw: .wind_u_component_500hPa, time: time)
            let speed = zip(u.data, v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .metrePerSecond)
        case .wind_speed_400hPa, .windspeed_400hPa:
            let v = try get(raw: .wind_v_component_400hPa, time: time)
            let u = try get(raw: .wind_u_component_400hPa, time: time)
            let speed = zip(u.data, v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .metrePerSecond)
        case .wind_speed_300hPa, .windspeed_300hPa:
            let v = try get(raw: .wind_v_component_300hPa, time: time)
            let u = try get(raw: .wind_u_component_300hPa, time: time)
            let speed = zip(u.data, v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .metrePerSecond)
        case .wind_speed_250hPa, .windspeed_250hPa:
            let v = try get(raw: .wind_v_component_250hPa, time: time)
            let u = try get(raw: .wind_u_component_250hPa, time: time)
            let speed = zip(u.data, v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .metrePerSecond)
        case .wind_speed_200hPa, .windspeed_200hPa:
            let v = try get(raw: .wind_v_component_200hPa, time: time)
            let u = try get(raw: .wind_u_component_200hPa, time: time)
            let speed = zip(u.data, v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .metrePerSecond)
        case .wind_speed_100hPa, .windspeed_100hPa:
            let v = try get(raw: .wind_v_component_100hPa, time: time)
            let u = try get(raw: .wind_u_component_100hPa, time: time)
            let speed = zip(u.data, v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .metrePerSecond)
        case .wind_speed_50hPa, .windspeed_50hPa:
            let v = try get(raw: .wind_v_component_50hPa, time: time)
            let u = try get(raw: .wind_u_component_50hPa, time: time)
            let speed = zip(u.data, v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .metrePerSecond)
        case .wind_direction_1000hPa, .winddirection_1000hPa:
            let v = try get(raw: .wind_v_component_1000hPa, time: time)
            let u = try get(raw: .wind_u_component_1000hPa, time: time)
            let direction = Meteorology.windirectionFast(u: u.data, v: v.data)
            return DataAndUnit(direction, .degreeDirection)
        case .wind_direction_925hPa, .winddirection_925hPa:
            let v = try get(raw: .wind_v_component_925hPa, time: time)
            let u = try get(raw: .wind_u_component_925hPa, time: time)
            let direction = Meteorology.windirectionFast(u: u.data, v: v.data)
            return DataAndUnit(direction, .degreeDirection)
        case .wind_direction_850hPa, .winddirection_850hPa:
            let v = try get(raw: .wind_v_component_850hPa, time: time)
            let u = try get(raw: .wind_u_component_850hPa, time: time)
            let direction = Meteorology.windirectionFast(u: u.data, v: v.data)
            return DataAndUnit(direction, .degreeDirection)
        case .wind_direction_700hPa, .winddirection_700hPa:
            let v = try get(raw: .wind_v_component_700hPa, time: time)
            let u = try get(raw: .wind_u_component_700hPa, time: time)
            let direction = Meteorology.windirectionFast(u: u.data, v: v.data)
            return DataAndUnit(direction, .degreeDirection)
        case .wind_direction_600hPa, .winddirection_600hPa:
            let v = try get(raw: .wind_v_component_600hPa, time: time)
            let u = try get(raw: .wind_u_component_600hPa, time: time)
            let direction = Meteorology.windirectionFast(u: u.data, v: v.data)
            return DataAndUnit(direction, .degreeDirection)
        case .wind_direction_500hPa, .winddirection_500hPa:
            let v = try get(raw: .wind_v_component_500hPa, time: time)
            let u = try get(raw: .wind_u_component_500hPa, time: time)
            let direction = Meteorology.windirectionFast(u: u.data, v: v.data)
            return DataAndUnit(direction, .degreeDirection)
        case .wind_direction_400hPa, .winddirection_400hPa:
            let v = try get(raw: .wind_v_component_400hPa, time: time)
            let u = try get(raw: .wind_u_component_400hPa, time: time)
            let direction = Meteorology.windirectionFast(u: u.data, v: v.data)
            return DataAndUnit(direction, .degreeDirection)
        case .wind_direction_300hPa, .winddirection_300hPa:
            let v = try get(raw: .wind_v_component_300hPa, time: time)
            let u = try get(raw: .wind_u_component_300hPa, time: time)
            let direction = Meteorology.windirectionFast(u: u.data, v: v.data)
            return DataAndUnit(direction, .degreeDirection)
        case .wind_direction_250hPa, .winddirection_250hPa:
            let v = try get(raw: .wind_v_component_250hPa, time: time)
            let u = try get(raw: .wind_u_component_250hPa, time: time)
            let direction = Meteorology.windirectionFast(u: u.data, v: v.data)
            return DataAndUnit(direction, .degreeDirection)
        case .wind_direction_200hPa, .winddirection_200hPa:
            let v = try get(raw: .wind_v_component_200hPa, time: time)
            let u = try get(raw: .wind_u_component_200hPa, time: time)
            let direction = Meteorology.windirectionFast(u: u.data, v: v.data)
            return DataAndUnit(direction, .degreeDirection)
        case .wind_direction_100hPa, .winddirection_100hPa:
            let v = try get(raw: .wind_v_component_100hPa, time: time)
            let u = try get(raw: .wind_u_component_100hPa, time: time)
            let direction = Meteorology.windirectionFast(u: u.data, v: v.data)
            return DataAndUnit(direction, .degreeDirection)
        case .wind_direction_50hPa, .winddirection_50hPa:
            let v = try get(raw: .wind_v_component_50hPa, time: time)
            let u = try get(raw: .wind_u_component_50hPa, time: time)
            let direction = Meteorology.windirectionFast(u: u.data, v: v.data)
            return DataAndUnit(direction, .degreeDirection)
        case .soil_temperature_0_to_10cm, .soil_temperature_0_10cm, .soil_temperature_0_7cm:
            return try get(raw: .soil_temperature_0_to_7cm, time: time)
        case .weather_code, .weathercode:
            let cloudcover = try get(raw: .cloud_cover, time: time).data
            let precipitation = try get(raw: .precipitation, time: time).data
            let snowfall = try get(derived: .snowfall, time: time).data
            let cape = try get(raw: .cape, time: time).data
            return DataAndUnit(WeatherCode.calculate(
                cloudcover: cloudcover,
                precipitation: precipitation,
                convectivePrecipitation: nil,
                snowfallCentimeters: snowfall,
                gusts: nil,
                cape: cape,
                liftedIndex: nil,
                visibilityMeters: nil,
                categoricalFreezingRain: nil,
                modelDtSeconds: time.dtSeconds), .wmoCode
            )
        case .cloud_cover_1000hPa, .cloudcover_1000hPa:
            let rh = try get(raw: .relative_humidity_1000hPa, time: time)
            return DataAndUnit(rh.data.map({ Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0, pressureHPa: 1000) }), .percentage)
        case .cloud_cover_925hPa, .cloudcover_925hPa:
            let rh = try get(raw: .relative_humidity_925hPa, time: time)
            return DataAndUnit(rh.data.map({ Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0, pressureHPa: 925) }), .percentage)
        case .cloud_cover_850hPa, .cloudcover_850hPa:
            let rh = try get(raw: .relative_humidity_850hPa, time: time)
            return DataAndUnit(rh.data.map({ Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0, pressureHPa: 850) }), .percentage)
        case .cloud_cover_700hPa, .cloudcover_700hPa:
            let rh = try get(raw: .relative_humidity_700hPa, time: time)
            return DataAndUnit(rh.data.map({ Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0, pressureHPa: 700) }), .percentage)
        case .cloud_cover_600hPa, .cloudcover_600hPa:
            let rh = try get(raw: .relative_humidity_600hPa, time: time)
            return DataAndUnit(rh.data.map({ Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0, pressureHPa: 600) }), .percentage)
        case .cloud_cover_500hPa, .cloudcover_500hPa:
            let rh = try get(raw: .relative_humidity_500hPa, time: time)
            return DataAndUnit(rh.data.map({ Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0, pressureHPa: 500) }), .percentage)
        case .cloud_cover_400hPa, .cloudcover_400hPa:
            let rh = try get(raw: .relative_humidity_400hPa, time: time)
            return DataAndUnit(rh.data.map({ Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0, pressureHPa: 400) }), .percentage)
        case .cloud_cover_300hPa, .cloudcover_300hPa:
            let rh = try get(raw: .relative_humidity_300hPa, time: time)
            return DataAndUnit(rh.data.map({ Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0, pressureHPa: 300) }), .percentage)
        case .cloud_cover_250hPa, .cloudcover_250hPa:
            let rh = try get(raw: .relative_humidity_250hPa, time: time)
            return DataAndUnit(rh.data.map({ Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0, pressureHPa: 250) }), .percentage)
        case .cloud_cover_200hPa, .cloudcover_200hPa:
            let rh = try get(raw: .relative_humidity_200hPa, time: time)
            return DataAndUnit(rh.data.map({ Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0, pressureHPa: 200) }), .percentage)
        case .cloud_cover_100hPa, .cloudcover_100hPa:
            let rh = try get(raw: .relative_humidity_100hPa, time: time)
            return DataAndUnit(rh.data.map({ Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0, pressureHPa: 100) }), .percentage)
        case .cloudcover_50hPa, .cloud_cover_50hPa:
            let rh = try get(raw: .relative_humidity_50hPa, time: time)
            return DataAndUnit(rh.data.map({ Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0, pressureHPa: 50) }), .percentage)
        case .snowfall:
            if reader.domain == .aifs025_single {
                let snow = try get(raw: .snowfall_water_equivalent, time: time).data.map({ $0 * 0.7 })
                return DataAndUnit(snow, .centimetre)
            }
            let temperature = try get(raw: .temperature_2m, time: time)
            let precipitation = try get(raw: .precipitation, time: time)
            let precipitationType = try get(raw: .precipitation_type, time: time)
            return DataAndUnit(zip(zip(temperature.data, precipitationType.data), precipitation.data).map({
                let ptype = $0.1
                let temp = $0.0
                let precip = $1
                if ptype.isNaN {
                    return precip * (temp >= 0 ? 0 : 0.7)
                }
                // freezing rain, snow, wet snow, ice pellets, freezing drizzle
                let isSnow = ptype == 3 || ptype == 5 || ptype == 8 || ptype == 12
                // mixed, wet snow
                let isMixed = ptype == 7 || ptype == 6
                return precip * (isMixed ? 0.7 / 2 : isSnow ? 0.7 : 0)
            }), .centimetre)
        case .rain:
            let precipitation = try get(raw: .precipitation, time: time)
            if reader.domain == .aifs025_single {
                let snow = try get(raw: .snowfall_water_equivalent, time: time).data
                let showers = try get(raw: .showers, time: time).data
                return DataAndUnit(zip(precipitation.data, zip(snow, showers)).map { max($0 - $1.0 - $1.1, 0) }, .millimetre)
            }
            let temperature = try get(raw: .temperature_2m, time: time)
            let precipitationType = try get(raw: .precipitation_type, time: time)
            return DataAndUnit(zip(zip(temperature.data, precipitationType.data), precipitation.data).map({
                let ptype = $0.1
                let temp = $0.0
                let precip = $1
                if ptype.isNaN {
                    return precip * (temp >= 0 ? 1 : 0)
                }
                // freezing rain, snow, wet snow, ice pellets, freezing drizzle
                let isSnow = ptype == 3 || ptype == 5 || ptype == 8 || ptype == 12
                // mixed, wet snow
                let isMixed = ptype == 7 || ptype == 6
                return precip * (isMixed ? 1 / 2 : isSnow ? 0 : 1)
            }), .millimetre)
        case .showers:
            if reader.domain == .aifs025_single {
                return try get(raw: .showers, time: time)
            }
            let precipitation = try get(raw: .precipitation, time: time)
            return DataAndUnit(precipitation.data.map({ min($0, 0) }), precipitation.unit)
        case .is_day:
            return DataAndUnit(Zensun.calculateIsDay(timeRange: time.time, lat: reader.modelLat, lon: reader.modelLon), .dimensionlessInteger)
        case .relativehumidity_1000hPa:
            return try get(raw: .relative_humidity_1000hPa, time: time)
        case .relativehumidity_925hPa:
            return try get(raw: .relative_humidity_925hPa, time: time)
        case .relativehumidity_850hPa:
            return try get(raw: .relative_humidity_850hPa, time: time)
        case .relativehumidity_700hPa:
            return try get(raw: .relative_humidity_700hPa, time: time)
        case .relativehumidity_600hPa:
            return try get(raw: .relative_humidity_300hPa, time: time)
        case .relativehumidity_500hPa:
            return try get(raw: .relative_humidity_500hPa, time: time)
        case .relativehumidity_400hPa:
            return try get(raw: .relative_humidity_300hPa, time: time)
        case .relativehumidity_300hPa:
            return try get(raw: .relative_humidity_300hPa, time: time)
        case .relativehumidity_250hPa:
            return try get(raw: .relative_humidity_250hPa, time: time)
        case .relativehumidity_200hPa:
            return try get(raw: .relative_humidity_200hPa, time: time)
        case .relativehumidity_100hPa:
            return try get(raw: .relative_humidity_300hPa, time: time)
        case .relativehumidity_50hPa:
            return try get(raw: .relative_humidity_50hPa, time: time)
        case .dew_point_1000hPa, .dewpoint_1000hPa:
            let temperature = try get(raw: .temperature_1000hPa, time: time)
            let rh = try get(raw: .relative_humidity_1000hPa, time: time)
            return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.dewpoint), temperature.unit)
        case .dew_point_925hPa, .dewpoint_925hPa:
            let temperature = try get(raw: .temperature_925hPa, time: time)
            let rh = try get(raw: .relative_humidity_925hPa, time: time)
            return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.dewpoint), temperature.unit)
        case .dew_point_850hPa, .dewpoint_850hPa:
            let temperature = try get(raw: .temperature_850hPa, time: time)
            let rh = try get(raw: .relative_humidity_850hPa, time: time)
            return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.dewpoint), temperature.unit)
        case .dew_point_700hPa, .dewpoint_700hPa:
            let temperature = try get(raw: .temperature_700hPa, time: time)
            let rh = try get(raw: .relative_humidity_700hPa, time: time)
            return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.dewpoint), temperature.unit)
        case .dew_point_600hPa, .dewpoint_600hPa:
            let temperature = try get(raw: .temperature_600hPa, time: time)
            let rh = try get(raw: .relative_humidity_600hPa, time: time)
            return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.dewpoint), temperature.unit)
        case .dew_point_500hPa, .dewpoint_500hPa:
            let temperature = try get(raw: .temperature_500hPa, time: time)
            let rh = try get(raw: .relative_humidity_500hPa, time: time)
            return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.dewpoint), temperature.unit)
        case .dew_point_400hPa, .dewpoint_400hPa:
            let temperature = try get(raw: .temperature_400hPa, time: time)
            let rh = try get(raw: .relative_humidity_400hPa, time: time)
            return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.dewpoint), temperature.unit)
        case .dew_point_300hPa, .dewpoint_300hPa:
            let temperature = try get(raw: .temperature_300hPa, time: time)
            let rh = try get(raw: .relative_humidity_300hPa, time: time)
            return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.dewpoint), temperature.unit)
        case .dew_point_250hPa, .dewpoint_250hPa:
            let temperature = try get(raw: .temperature_250hPa, time: time)
            let rh = try get(raw: .relative_humidity_250hPa, time: time)
            return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.dewpoint), temperature.unit)
        case .dew_point_200hPa, .dewpoint_200hPa:
            let temperature = try get(raw: .temperature_200hPa, time: time)
            let rh = try get(raw: .relative_humidity_200hPa, time: time)
            return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.dewpoint), temperature.unit)
        case .dew_point_100hPa, .dewpoint_100hPa:
            let temperature = try get(raw: .temperature_100hPa, time: time)
            let rh = try get(raw: .relative_humidity_100hPa, time: time)
            return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.dewpoint), temperature.unit)
        case .dew_point_50hPa, .dewpoint_50hPa:
            let temperature = try get(raw: .temperature_50hPa, time: time)
            let rh = try get(raw: .relative_humidity_50hPa, time: time)
            return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.dewpoint), temperature.unit)
        case .soil_temperature_0cm, .skin_temperature:
            return try get(raw: .surface_temperature, time: time)
        case .surface_air_pressure, .surface_pressure:
            let temperature = try get(raw: .temperature_2m, time: time).data
            let pressure = try get(raw: .pressure_msl, time: time)
            return DataAndUnit(Meteorology.surfacePressure(temperature: temperature, pressure: pressure.data, elevation: reader.targetElevation), pressure.unit)
        case .relativehumidity_2m:
            return try get(raw: .relative_humidity_2m, time: time)
        case .dew_point_2m, .dewpoint_2m:
            let temperature = try get(raw: .temperature_2m, time: time)
            let rh = try get(raw: .relative_humidity_2m, time: time)
            return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.dewpoint), temperature.unit)
        case .apparent_temperature:
            let windspeed = try get(derived: .windspeed_10m, time: time).data
            let temperature = try get(raw: .temperature_2m, time: time).data
            let relhum = try get(derived: .relativehumidity_2m, time: time).data
            let swrad = try get(raw: .shortwave_radiation, time: time).data
            return DataAndUnit(Meteorology.apparentTemperature(temperature_2m: temperature, relativehumidity_2m: relhum, windspeed_10m: windspeed, shortwave_radiation: swrad), .celsius)
        case .vapour_pressure_deficit, .vapor_pressure_deficit:
            let temperature = try get(raw: .temperature_2m, time: time).data
            let rh = try get(derived: .relativehumidity_2m, time: time).data
            let dewpoint = zip(temperature, rh).map(Meteorology.dewpoint)
            return DataAndUnit(zip(temperature, dewpoint).map(Meteorology.vaporPressureDeficit), .kilopascal)
        case .wet_bulb_temperature_2m:
            let temperature = try get(raw: .temperature_2m, time: time)
            let rh = try get(derived: .relativehumidity_2m, time: time)
            return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.wetBulbTemperature), temperature.unit)
        case .cloudcover:
            return try get(raw: .cloud_cover, time: time)
        case .cloudcover_low:
            return try get(raw: .cloud_cover_low, time: time)
        case .cloudcover_mid:
            return try get(raw: .cloud_cover_mid, time: time)
        case .cloudcover_high:
            return try get(raw: .cloud_cover_high, time: time)
        case .terrestrial_radiation:
            /// Use center averaged
            let solar = Zensun.extraTerrestrialRadiationBackwards(latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time)
            return DataAndUnit(solar, .wattPerSquareMetre)
        case .terrestrial_radiation_instant:
            /// Use center averaged
            let solar = Zensun.extraTerrestrialRadiationInstant(latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time)
            return DataAndUnit(solar, .wattPerSquareMetre)
        case .shortwave_radiation_instant:
            let sw = try get(raw: .shortwave_radiation, time: time)
            let factor = Zensun.backwardsAveragedToInstantFactor(time: time.time, latitude: reader.modelLat, longitude: reader.modelLon)
            return DataAndUnit(zip(sw.data, factor).map(*), sw.unit)
        case .direct_normal_irradiance:
            let dhi = try get(derived: .direct_radiation, time: time).data
            let dni = Zensun.calculateBackwardsDNI(directRadiation: dhi, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time)
            return DataAndUnit(dni, .wattPerSquareMetre)
        case .direct_normal_irradiance_instant:
            let direct = try get(derived: .direct_radiation, time: time)
            let dni = Zensun.calculateBackwardsDNI(directRadiation: direct.data, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time, convertToInstant: true)
            return DataAndUnit(dni, direct.unit)
        case .diffuse_radiation:
            let swrad = try get(raw: .shortwave_radiation, time: time)
            let diffuse = Zensun.calculateDiffuseRadiationBackwards(shortwaveRadiation: swrad.data, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time)
            return DataAndUnit(diffuse, swrad.unit)
        case .direct_radiation:
            let swrad = try get(raw: .shortwave_radiation, time: time)
            let diffuse = Zensun.calculateDiffuseRadiationBackwards(shortwaveRadiation: swrad.data, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time)
            return DataAndUnit(zip(swrad.data, diffuse).map(-), swrad.unit)
        case .direct_radiation_instant:
            let direct = try get(derived: .direct_radiation, time: time)
            let factor = Zensun.backwardsAveragedToInstantFactor(time: time.time, latitude: reader.modelLat, longitude: reader.modelLon)
            return DataAndUnit(zip(direct.data, factor).map(*), direct.unit)
        case .diffuse_radiation_instant:
            let diff = try get(derived: .diffuse_radiation, time: time)
            let factor = Zensun.backwardsAveragedToInstantFactor(time: time.time, latitude: reader.modelLat, longitude: reader.modelLon)
            return DataAndUnit(zip(diff.data, factor).map(*), diff.unit)
        case .global_tilted_irradiance:
            let directRadiation = try get(derived: .direct_radiation, time: time).data
            let diffuseRadiation = try get(derived: .diffuse_radiation, time: time).data
            let gti = Zensun.calculateTiltedIrradiance(directRadiation: directRadiation, diffuseRadiation: diffuseRadiation, tilt: try options.getTilt(), azimuth: try options.getAzimuth(), latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time, convertBackwardsToInstant: false)
            return DataAndUnit(gti, .wattPerSquareMetre)
        case .global_tilted_irradiance_instant:
            let directRadiation = try get(derived: .direct_radiation, time: time).data
            let diffuseRadiation = try get(derived: .diffuse_radiation, time: time).data
            let gti = Zensun.calculateTiltedIrradiance(directRadiation: directRadiation, diffuseRadiation: diffuseRadiation, tilt: try options.getTilt(), azimuth: try options.getAzimuth(), latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time, convertBackwardsToInstant: true)
            return DataAndUnit(gti, .wattPerSquareMetre)
        case .et0_fao_evapotranspiration:
            let exrad = Zensun.extraTerrestrialRadiationBackwards(latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time)
            let swrad = try get(raw: .shortwave_radiation, time: time).data
            let temperature = try get(raw: .temperature_2m, time: time).data
            let windspeed = try get(derived: .windspeed_10m, time: time).data
            let rh = try get(raw: .relative_humidity_2m, time: time).data
            let dewpoint = zip(temperature, rh).map(Meteorology.dewpoint)

            let et0 = swrad.indices.map { i in
                return Meteorology.et0Evapotranspiration(temperature2mCelsius: temperature[i], windspeed10mMeterPerSecond: windspeed[i], dewpointCelsius: dewpoint[i], shortwaveRadiationWatts: swrad[i], elevation: reader.targetElevation, extraTerrestrialRadiation: exrad[i], dtSeconds: time.dtSeconds)
            }
            return DataAndUnit(et0, .millimetre)
        }
    }

    func prefetchData(derived: Derived, time: TimerangeDtAndSettings) throws {
        switch derived {
        case .terrestrial_radiation, .terrestrial_radiation_instant:
            break
        case .diffuse_radiation, .diffuse_radiation_instant, .direct_normal_irradiance, .direct_normal_irradiance_instant, .direct_radiation, .direct_radiation_instant, .shortwave_radiation_instant, .global_tilted_irradiance, .global_tilted_irradiance_instant:
            try prefetchData(raw: .shortwave_radiation, time: time)
        case .windspeed_100m, .wind_speed_100m, .winddirection_100m, .wind_direction_100m:
            try prefetchData(raw: .wind_u_component_100m, time: time)
            try prefetchData(raw: .wind_v_component_100m, time: time)
        case .windspeed_10m, .wind_speed_10m:
            try prefetchData(raw: .wind_u_component_10m, time: time)
            try prefetchData(raw: .wind_v_component_10m, time: time)
        case .wind_speed_1000hPa, .windspeed_1000hPa:
            try prefetchData(raw: .wind_v_component_1000hPa, time: time)
            try prefetchData(raw: .wind_u_component_1000hPa, time: time)
        case .wind_speed_925hPa, .windspeed_925hPa:
            try prefetchData(raw: .wind_v_component_925hPa, time: time)
            try prefetchData(raw: .wind_u_component_925hPa, time: time)
        case .wind_speed_850hPa, .windspeed_850hPa:
            try prefetchData(raw: .wind_v_component_850hPa, time: time)
            try prefetchData(raw: .wind_u_component_850hPa, time: time)
        case .wind_speed_700hPa, .windspeed_700hPa:
            try prefetchData(raw: .wind_v_component_700hPa, time: time)
            try prefetchData(raw: .wind_u_component_700hPa, time: time)
        case .wind_speed_600hPa, .windspeed_600hPa:
            try prefetchData(raw: .wind_v_component_600hPa, time: time)
            try prefetchData(raw: .wind_u_component_600hPa, time: time)
        case .wind_speed_500hPa, .windspeed_500hPa:
            try prefetchData(raw: .wind_v_component_500hPa, time: time)
            try prefetchData(raw: .wind_u_component_500hPa, time: time)
        case .wind_speed_400hPa, .windspeed_400hPa:
            try prefetchData(raw: .wind_v_component_400hPa, time: time)
            try prefetchData(raw: .wind_u_component_400hPa, time: time)
        case .wind_speed_300hPa, .windspeed_300hPa:
            try prefetchData(raw: .wind_v_component_300hPa, time: time)
            try prefetchData(raw: .wind_u_component_300hPa, time: time)
        case .wind_speed_250hPa, .windspeed_250hPa:
            try prefetchData(raw: .wind_v_component_250hPa, time: time)
            try prefetchData(raw: .wind_u_component_250hPa, time: time)
        case .wind_speed_200hPa, .windspeed_200hPa:
            try prefetchData(raw: .wind_v_component_200hPa, time: time)
            try prefetchData(raw: .wind_u_component_200hPa, time: time)
        case .wind_speed_100hPa, .windspeed_100hPa:
            try prefetchData(raw: .wind_v_component_100hPa, time: time)
            try prefetchData(raw: .wind_u_component_100hPa, time: time)
        case .wind_speed_50hPa, .windspeed_50hPa:
            try prefetchData(raw: .wind_v_component_50hPa, time: time)
            try prefetchData(raw: .wind_u_component_50hPa, time: time)
        case .wind_direction_10m, .winddirection_10m:
            try prefetchData(raw: .wind_u_component_10m, time: time)
            try prefetchData(raw: .wind_v_component_10m, time: time)
        case .wind_direction_1000hPa, .winddirection_1000hPa:
            try prefetchData(raw: .wind_v_component_1000hPa, time: time)
            try prefetchData(raw: .wind_u_component_1000hPa, time: time)
        case .wind_direction_925hPa, .winddirection_925hPa:
            try prefetchData(raw: .wind_v_component_925hPa, time: time)
            try prefetchData(raw: .wind_u_component_925hPa, time: time)
        case .wind_direction_850hPa, .winddirection_850hPa:
            try prefetchData(raw: .wind_v_component_850hPa, time: time)
            try prefetchData(raw: .wind_u_component_850hPa, time: time)
        case .wind_direction_700hPa, .winddirection_700hPa:
            try prefetchData(raw: .wind_v_component_700hPa, time: time)
            try prefetchData(raw: .wind_u_component_700hPa, time: time)
        case .wind_direction_600hPa, .winddirection_600hPa:
            try prefetchData(raw: .wind_v_component_600hPa, time: time)
            try prefetchData(raw: .wind_u_component_600hPa, time: time)
        case .wind_direction_500hPa, .winddirection_500hPa:
            try prefetchData(raw: .wind_v_component_500hPa, time: time)
            try prefetchData(raw: .wind_u_component_500hPa, time: time)
        case .wind_direction_400hPa, .winddirection_400hPa:
            try prefetchData(raw: .wind_v_component_400hPa, time: time)
            try prefetchData(raw: .wind_u_component_400hPa, time: time)
        case .wind_direction_300hPa, .winddirection_300hPa:
            try prefetchData(raw: .wind_v_component_300hPa, time: time)
            try prefetchData(raw: .wind_u_component_300hPa, time: time)
        case .wind_direction_250hPa, .winddirection_250hPa:
            try prefetchData(raw: .wind_v_component_250hPa, time: time)
            try prefetchData(raw: .wind_u_component_250hPa, time: time)
        case .wind_direction_200hPa, .winddirection_200hPa:
            try prefetchData(raw: .wind_v_component_200hPa, time: time)
            try prefetchData(raw: .wind_u_component_200hPa, time: time)
        case .wind_direction_100hPa, .winddirection_100hPa:
            try prefetchData(raw: .wind_v_component_100hPa, time: time)
            try prefetchData(raw: .wind_u_component_100hPa, time: time)
        case .wind_direction_50hPa, .winddirection_50hPa:
            try prefetchData(raw: .wind_v_component_50hPa, time: time)
            try prefetchData(raw: .wind_u_component_50hPa, time: time)
        case .soil_temperature_0_to_10cm, .soil_temperature_0_10cm, .soil_temperature_0_7cm:
            try prefetchData(raw: .soil_temperature_0_to_7cm, time: time)
        case .cloud_cover_1000hPa, .cloudcover_1000hPa:
            try prefetchData(raw: .relative_humidity_1000hPa, time: time)
        case .cloud_cover_925hPa, .cloudcover_925hPa:
            try prefetchData(raw: .relative_humidity_925hPa, time: time)
        case .cloud_cover_850hPa, .cloudcover_850hPa:
            try prefetchData(raw: .relative_humidity_850hPa, time: time)
        case .cloud_cover_700hPa, .cloudcover_700hPa:
            try prefetchData(raw: .relative_humidity_700hPa, time: time)
        case .cloud_cover_600hPa, .cloudcover_600hPa:
            try prefetchData(raw: .relative_humidity_600hPa, time: time)
        case .cloud_cover_500hPa, .cloudcover_500hPa:
            try prefetchData(raw: .relative_humidity_500hPa, time: time)
        case .cloud_cover_400hPa, .cloudcover_400hPa:
            try prefetchData(raw: .relative_humidity_400hPa, time: time)
        case .cloud_cover_300hPa, .cloudcover_300hPa:
            try prefetchData(raw: .relative_humidity_300hPa, time: time)
        case .cloud_cover_250hPa, .cloudcover_250hPa:
            try prefetchData(raw: .relative_humidity_250hPa, time: time)
        case .cloud_cover_200hPa, .cloudcover_200hPa:
            try prefetchData(raw: .relative_humidity_200hPa, time: time)
        case .cloud_cover_100hPa, .cloudcover_100hPa:
            try prefetchData(raw: .relative_humidity_100hPa, time: time)
        case .cloud_cover_50hPa, .cloudcover_50hPa:
            try prefetchData(raw: .relative_humidity_50hPa, time: time)
        case .weather_code, .weathercode:
            try prefetchData(raw: .cloud_cover, time: time)
            try prefetchData(derived: .snowfall, time: time)
            try prefetchData(raw: .precipitation, time: time)
            try prefetchData(raw: .cape, time: time)
        case .rain:
            try prefetchData(raw: .precipitation, time: time)
            if reader.domain == .aifs025_single {
                try prefetchData(raw: .snowfall_water_equivalent, time: time)
                try prefetchData(raw: .showers, time: time)
            } else {
                try prefetchData(raw: .temperature_2m, time: time)
                try prefetchData(raw: .precipitation_type, time: time)
            }
        case .snowfall:
            if reader.domain == .aifs025_single {
                try prefetchData(raw: .snowfall_water_equivalent, time: time)
            } else {
                try prefetchData(raw: .precipitation, time: time)
                try prefetchData(raw: .temperature_2m, time: time)
                try prefetchData(raw: .precipitation_type, time: time)
            }
        case .showers:
            if reader.domain == .aifs025_single {
                try prefetchData(raw: .showers, time: time)
            } else {
                try prefetchData(raw: .precipitation, time: time)
            }
        case .is_day:
            break
        case .relativehumidity_1000hPa:
            try prefetchData(raw: .relative_humidity_1000hPa, time: time)
        case .relativehumidity_925hPa:
            try prefetchData(raw: .relative_humidity_925hPa, time: time)
        case .relativehumidity_850hPa:
            try prefetchData(raw: .relative_humidity_850hPa, time: time)
        case .relativehumidity_700hPa:
            try prefetchData(raw: .relative_humidity_700hPa, time: time)
        case .relativehumidity_600hPa:
            try prefetchData(raw: .relative_humidity_600hPa, time: time)
        case .relativehumidity_500hPa:
            try prefetchData(raw: .relative_humidity_500hPa, time: time)
        case .relativehumidity_400hPa:
            try prefetchData(raw: .relative_humidity_400hPa, time: time)
        case .relativehumidity_300hPa:
            try prefetchData(raw: .relative_humidity_300hPa, time: time)
        case .relativehumidity_250hPa:
            try prefetchData(raw: .relative_humidity_250hPa, time: time)
        case .relativehumidity_200hPa:
            try prefetchData(raw: .relative_humidity_200hPa, time: time)
        case .relativehumidity_100hPa:
            try prefetchData(raw: .relative_humidity_100hPa, time: time)
        case .relativehumidity_50hPa:
            try prefetchData(raw: .relative_humidity_50hPa, time: time)
        case .dew_point_1000hPa, .dewpoint_1000hPa:
            try prefetchData(raw: .temperature_1000hPa, time: time)
            try prefetchData(raw: .relative_humidity_1000hPa, time: time)
        case .dew_point_925hPa, .dewpoint_925hPa:
            try prefetchData(raw: .temperature_925hPa, time: time)
            try prefetchData(raw: .relative_humidity_925hPa, time: time)
        case .dew_point_850hPa, .dewpoint_850hPa:
            try prefetchData(raw: .temperature_850hPa, time: time)
            try prefetchData(raw: .relative_humidity_850hPa, time: time)
        case .dew_point_700hPa, .dewpoint_700hPa:
            try prefetchData(raw: .temperature_700hPa, time: time)
            try prefetchData(raw: .relative_humidity_700hPa, time: time)
        case .dew_point_600hPa, .dewpoint_600hPa:
            try prefetchData(raw: .temperature_600hPa, time: time)
            try prefetchData(raw: .relative_humidity_600hPa, time: time)
        case .dew_point_500hPa, .dewpoint_500hPa:
            try prefetchData(raw: .temperature_500hPa, time: time)
            try prefetchData(raw: .relative_humidity_500hPa, time: time)
        case .dew_point_400hPa, .dewpoint_400hPa:
            try prefetchData(raw: .temperature_400hPa, time: time)
            try prefetchData(raw: .relative_humidity_400hPa, time: time)
        case .dew_point_300hPa, .dewpoint_300hPa:
            try prefetchData(raw: .temperature_300hPa, time: time)
            try prefetchData(raw: .relative_humidity_300hPa, time: time)
        case .dew_point_250hPa, .dewpoint_250hPa:
            try prefetchData(raw: .temperature_250hPa, time: time)
            try prefetchData(raw: .relative_humidity_250hPa, time: time)
        case .dew_point_200hPa, .dewpoint_200hPa:
            try prefetchData(raw: .temperature_200hPa, time: time)
            try prefetchData(raw: .relative_humidity_200hPa, time: time)
        case .dew_point_100hPa, .dewpoint_100hPa:
            try prefetchData(raw: .temperature_100hPa, time: time)
            try prefetchData(raw: .relative_humidity_100hPa, time: time)
        case .dew_point_50hPa, .dewpoint_50hPa:
            try prefetchData(raw: .temperature_50hPa, time: time)
            try prefetchData(raw: .relative_humidity_50hPa, time: time)
        case .skin_temperature, .soil_temperature_0cm:
            try prefetchData(raw: .surface_temperature, time: time)
        case .surface_air_pressure, .surface_pressure:
            try prefetchData(raw: .pressure_msl, time: time)
            try prefetchData(raw: .temperature_2m, time: time)
        case .relativehumidity_2m:
            try prefetchData(raw: .relative_humidity_2m, time: time)
        case .dew_point_2m, .dewpoint_2m:
            try prefetchData(raw: .relative_humidity_2m, time: time)
            try prefetchData(raw: .temperature_2m, time: time)
        case .apparent_temperature:
            try prefetchData(derived: .relativehumidity_2m, time: time)
            try prefetchData(raw: .temperature_2m, time: time)
            try prefetchData(derived: .windspeed_10m, time: time)
            try prefetchData(raw: .shortwave_radiation, time: time)
        case .vapour_pressure_deficit, .vapor_pressure_deficit:
            try prefetchData(derived: .relativehumidity_2m, time: time)
            try prefetchData(raw: .temperature_2m, time: time)
        case .wet_bulb_temperature_2m:
            try prefetchData(raw: .relative_humidity_1000hPa, time: time)
            try prefetchData(raw: .temperature_2m, time: time)
        case .cloudcover:
            try prefetchData(raw: .cloud_cover, time: time)
        case .cloudcover_low:
            try prefetchData(raw: .cloud_cover_low, time: time)
        case .cloudcover_mid:
            try prefetchData(raw: .cloud_cover_mid, time: time)
        case .cloudcover_high:
            try prefetchData(raw: .cloud_cover_high, time: time)
        case .et0_fao_evapotranspiration:
            try prefetchData(raw: .shortwave_radiation, time: time)
            try prefetchData(raw: .temperature_2m, time: time)
            try prefetchData(raw: .relative_humidity_2m, time: time)
            try prefetchData(derived: .wind_speed_10m, time: time)
        }
    }
}
