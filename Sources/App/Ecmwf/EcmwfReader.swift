import Foundation


struct EcmwfReader: GenericReaderDerived, GenericReaderProtocol {
    var reader: GenericReaderCached<EcmwfDomain, Variable>
    
    typealias Domain = EcmwfDomain
    
    typealias Variable = VariableAndMemberAndControl<EcmwfVariable>
    
    typealias Derived = VariableAndMemberAndControl<EcmwfVariableDerived>
    
    public init?(domain: Domain, lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode) throws {
        guard let reader = try GenericReader<Domain, Variable>(domain: domain, lat: lat, lon: lon, elevation: elevation, mode: mode) else {
            return nil
        }
        self.reader = GenericReaderCached(reader: reader)
    }
    
    func prefetchData(raw: VariableAndMemberAndControl<EcmwfVariable>, time: TimerangeDt) throws {
        try reader.prefetchData(variable: raw, time: time)
    }
    
    func get(raw: VariableAndMemberAndControl<EcmwfVariable>, time: TimerangeDt) throws -> DataAndUnit {
        /// Adjust surface pressure to target elevation. Surface pressure is stored for `modelElevation`, but we want to get the pressure on `targetElevation`
        if raw.variable == .surface_pressure {
            let pressure = try reader.get(variable: raw, time: time)
            let factor = Meteorology.sealevelPressureFactor(temperature: 20, elevation: reader.modelElevation.numeric) / Meteorology.sealevelPressureFactor(temperature: 20, elevation: reader.targetElevation)
            return DataAndUnit(pressure.data.map({$0*factor}), pressure.unit)
        }
        return try reader.get(variable: raw, time: time)
    }
    
    func get(derived: Derived, time: TimerangeDt) throws -> DataAndUnit {
        let member = derived.member
        switch derived.variable {
        case .wind_speed_10m:
            fallthrough
        case .windspeed_10m:
            let v = try get(raw: .init(.wind_v_component_10m, member), time: time)
            let u = try get(raw: .init(.wind_u_component_10m, member), time: time)
            let speed = zip(u.data,v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .metrePerSecond)
        case .wind_direction_10m:
            fallthrough
        case .winddirection_10m:
            let v = try get(raw: .init(.wind_v_component_10m, member), time: time)
            let u = try get(raw: .init(.wind_u_component_10m, member), time: time)
            let direction = Meteorology.windirectionFast(u: u.data, v: v.data)
            return DataAndUnit(direction, .degreeDirection)
        case .wind_speed_1000hPa:
            fallthrough
        case .windspeed_1000hPa:
            let v = try get(raw: .init(.wind_v_component_1000hPa, member), time: time)
            let u = try get(raw: .init(.wind_u_component_1000hPa, member), time: time)
            let speed = zip(u.data,v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .metrePerSecond)
        case .wind_speed_925hPa:
            fallthrough
        case .windspeed_925hPa:
            let v = try get(raw: .init(.wind_v_component_925hPa, member), time: time)
            let u = try get(raw: .init(.wind_u_component_925hPa, member), time: time)
            let speed = zip(u.data,v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .metrePerSecond)
        case .wind_speed_850hPa:
            fallthrough
        case .windspeed_850hPa:
            let v = try get(raw: .init(.wind_v_component_850hPa, member), time: time)
            let u = try get(raw: .init(.wind_u_component_850hPa, member), time: time)
            let speed = zip(u.data,v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .metrePerSecond)
        case .wind_speed_700hPa:
            fallthrough
        case .windspeed_700hPa:
            let v = try get(raw: .init(.wind_v_component_700hPa, member), time: time)
            let u = try get(raw: .init(.wind_u_component_700hPa, member), time: time)
            let speed = zip(u.data,v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .metrePerSecond)
        case .wind_speed_500hPa:
            fallthrough
        case .windspeed_500hPa:
            let v = try get(raw: .init(.wind_v_component_500hPa, member), time: time)
            let u = try get(raw: .init(.wind_u_component_500hPa, member), time: time)
            let speed = zip(u.data,v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .metrePerSecond)
        case .wind_speed_300hPa:
            fallthrough
        case .windspeed_300hPa:
            let v = try get(raw: .init(.wind_v_component_300hPa, member), time: time)
            let u = try get(raw: .init(.wind_u_component_300hPa, member), time: time)
            let speed = zip(u.data,v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .metrePerSecond)
        case .wind_speed_250hPa:
            fallthrough
        case .windspeed_250hPa:
            let v = try get(raw: .init(.wind_v_component_250hPa, member), time: time)
            let u = try get(raw: .init(.wind_u_component_250hPa, member), time: time)
            let speed = zip(u.data,v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .metrePerSecond)
        case .wind_speed_200hPa:
            fallthrough
        case .windspeed_200hPa:
            let v = try get(raw: .init(.wind_v_component_200hPa, member), time: time)
            let u = try get(raw: .init(.wind_u_component_200hPa, member), time: time)
            let speed = zip(u.data,v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .metrePerSecond)
        case .wind_speed_50hPa:
            fallthrough
        case .windspeed_50hPa:
            let v = try get(raw: .init(.wind_v_component_50hPa, member), time: time)
            let u = try get(raw: .init(.wind_u_component_50hPa, member), time: time)
            let speed = zip(u.data,v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .metrePerSecond)
        case .wind_direction_1000hPa:
            fallthrough
        case .winddirection_1000hPa:
            let v = try get(raw: .init(.wind_v_component_1000hPa, member), time: time)
            let u = try get(raw: .init(.wind_u_component_1000hPa, member), time: time)
            let direction = Meteorology.windirectionFast(u: u.data, v: v.data)
            return DataAndUnit(direction, .degreeDirection)
        case .wind_direction_925hPa:
            fallthrough
        case .winddirection_925hPa:
            let v = try get(raw: .init(.wind_v_component_925hPa, member), time: time)
            let u = try get(raw: .init(.wind_u_component_925hPa, member), time: time)
            let direction = Meteorology.windirectionFast(u: u.data, v: v.data)
            return DataAndUnit(direction, .degreeDirection)
        case .wind_direction_850hPa:
            fallthrough
        case .winddirection_850hPa:
            let v = try get(raw: .init(.wind_v_component_850hPa, member), time: time)
            let u = try get(raw: .init(.wind_u_component_850hPa, member), time: time)
            let direction = Meteorology.windirectionFast(u: u.data, v: v.data)
            return DataAndUnit(direction, .degreeDirection)
        case .wind_direction_700hPa:
            fallthrough
        case .winddirection_700hPa:
            let v = try get(raw: .init(.wind_v_component_700hPa, member), time: time)
            let u = try get(raw: .init(.wind_u_component_700hPa, member), time: time)
            let direction = Meteorology.windirectionFast(u: u.data, v: v.data)
            return DataAndUnit(direction, .degreeDirection)
        case .wind_direction_500hPa:
            fallthrough
        case .winddirection_500hPa:
            let v = try get(raw: .init(.wind_v_component_500hPa, member), time: time)
            let u = try get(raw: .init(.wind_u_component_500hPa, member), time: time)
            let direction = Meteorology.windirectionFast(u: u.data, v: v.data)
            return DataAndUnit(direction, .degreeDirection)
        case .wind_direction_300hPa:
            fallthrough
        case .winddirection_300hPa:
            let v = try get(raw: .init(.wind_v_component_300hPa, member), time: time)
            let u = try get(raw: .init(.wind_u_component_300hPa, member), time: time)
            let direction = Meteorology.windirectionFast(u: u.data, v: v.data)
            return DataAndUnit(direction, .degreeDirection)
        case .wind_direction_250hPa:
            fallthrough
        case .winddirection_250hPa:
            let v = try get(raw: .init(.wind_v_component_250hPa, member), time: time)
            let u = try get(raw: .init(.wind_u_component_250hPa, member), time: time)
            let direction = Meteorology.windirectionFast(u: u.data, v: v.data)
            return DataAndUnit(direction, .degreeDirection)
        case .wind_direction_200hPa:
            fallthrough
        case .winddirection_200hPa:
            let v = try get(raw: .init(.wind_v_component_200hPa, member), time: time)
            let u = try get(raw: .init(.wind_u_component_200hPa, member), time: time)
            let direction = Meteorology.windirectionFast(u: u.data, v: v.data)
            return DataAndUnit(direction, .degreeDirection)
        case .wind_direction_50hPa:
            fallthrough
        case .winddirection_50hPa:
            let v = try get(raw: .init(.wind_v_component_50hPa, member), time: time)
            let u = try get(raw: .init(.wind_u_component_50hPa, member), time: time)
            let direction = Meteorology.windirectionFast(u: u.data, v: v.data)
            return DataAndUnit(direction, .degreeDirection)
        case .soil_temperature_0_to_10cm:
            fallthrough
        case .soil_temperature_0_10cm:
            fallthrough
        case .soil_temperature_0_7cm:
            return try get(raw: .init(.soil_temperature_0_to_7cm, member), time: time)
        case .weather_code:
            fallthrough
        case .weathercode:
            let cloudcover = try get(raw: .init(.cloud_cover, member), time: time).data
            let precipitation = try get(raw: .init(.precipitation, member), time: time).data
            let snowfall = try get(derived: .init(.snowfall, member), time: time).data
            return DataAndUnit(WeatherCode.calculate(
                cloudcover: cloudcover,
                precipitation: precipitation,
                convectivePrecipitation: nil,
                snowfallCentimeters: snowfall,
                gusts: nil,
                cape: nil,
                liftedIndex: nil,
                visibilityMeters: nil,
                categoricalFreezingRain: nil,
                modelDtSeconds: time.dtSeconds), .wmoCode
            )
        case .cloud_cover_1000hPa:
            fallthrough
        case .cloudcover_1000hPa:
            let rh = try get(raw: .init(.relative_humidity_1000hPa, member), time: time)
            return DataAndUnit(rh.data.map({Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0, pressureHPa: 1000)}), .percentage)
        case .cloud_cover_925hPa:
            fallthrough
        case .cloudcover_925hPa:
            let rh = try get(raw: .init(.relative_humidity_925hPa, member), time: time)
            return DataAndUnit(rh.data.map({Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0, pressureHPa: 925)}), .percentage)
        case .cloud_cover_850hPa:
            fallthrough
        case .cloudcover_850hPa:
            let rh = try get(raw: .init(.relative_humidity_850hPa, member), time: time)
            return DataAndUnit(rh.data.map({Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0, pressureHPa: 850)}), .percentage)
        case .cloud_cover_700hPa:
            fallthrough
        case .cloudcover_700hPa:
            let rh = try get(raw: .init(.relative_humidity_700hPa, member), time: time)
            return DataAndUnit(rh.data.map({Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0, pressureHPa: 700)}), .percentage)
        case .cloud_cover_500hPa:
            fallthrough
        case .cloudcover_500hPa:
            let rh = try get(raw: .init(.relative_humidity_500hPa, member), time: time)
            return DataAndUnit(rh.data.map({Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0, pressureHPa: 500)}), .percentage)
        case .cloud_cover_300hPa:
            fallthrough
        case .cloudcover_300hPa:
            let rh = try get(raw: .init(.relative_humidity_300hPa, member), time: time)
            return DataAndUnit(rh.data.map({Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0, pressureHPa: 300)}), .percentage)
        case .cloud_cover_250hPa:
            fallthrough
        case .cloudcover_250hPa:
            let rh = try get(raw: .init(.relative_humidity_250hPa, member), time: time)
            return DataAndUnit(rh.data.map({Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0, pressureHPa: 250)}), .percentage)
        case .cloud_cover_200hPa:
            fallthrough
        case .cloudcover_200hPa:
            let rh = try get(raw: .init(.relative_humidity_200hPa, member), time: time)
            return DataAndUnit(rh.data.map({Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0, pressureHPa: 200)}), .percentage)
        case .cloudcover_50hPa:
            fallthrough
        case .cloud_cover_50hPa:
            let rh = try get(raw: .init(.relative_humidity_50hPa, member), time: time)
            return DataAndUnit(rh.data.map({Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0, pressureHPa: 50)}), .percentage)
        case .snowfall:
            let temperature = try get(raw: .init(.temperature_2m, member), time: time)
            let precipitation = try get(raw: .init(.precipitation, member), time: time)
            return DataAndUnit(zip(temperature.data, precipitation.data).map({ $1 * ($0 >= 0 ? 0 : 0.7) }), .centimetre)
        case .rain:
            let temperature = try get(raw: .init(.temperature_2m, member), time: time)
            let precipitation = try get(raw: .init(.precipitation, member), time: time)
            return DataAndUnit(zip(temperature.data, precipitation.data).map({ $1 * ($0 >= 0 ? 1 : 0) }), .millimetre)
        case .is_day:
            return DataAndUnit(Zensun.calculateIsDay(timeRange: time, lat: reader.modelLat, lon: reader.modelLon), .dimensionlessInteger)
        case .relativehumidity_1000hPa:
            return try get(raw: .init(.relative_humidity_1000hPa, member), time: time)
        case .relativehumidity_925hPa:
            return try get(raw: .init(.relative_humidity_925hPa, member), time: time)
        case .relativehumidity_850hPa:
            return try get(raw: .init(.relative_humidity_850hPa, member), time: time)
        case .relativehumidity_700hPa:
            return try get(raw: .init(.relative_humidity_700hPa, member), time: time)
        case .relativehumidity_500hPa:
            return try get(raw: .init(.relative_humidity_500hPa, member), time: time)
        case .relativehumidity_300hPa:
            return try get(raw: .init(.relative_humidity_300hPa, member), time: time)
        case .relativehumidity_250hPa:
            return try get(raw: .init(.relative_humidity_250hPa, member), time: time)
        case .relativehumidity_200hPa:
            return try get(raw: .init(.relative_humidity_200hPa, member), time: time)
        case .relativehumidity_50hPa:
            return try get(raw: .init(.relative_humidity_50hPa, member), time: time)
        case .dew_point_1000hPa:
            fallthrough
        case .dewpoint_1000hPa:
            let temperature = try get(raw: .init(.temperature_1000hPa, member), time: time)
            let rh = try get(raw: .init(.relative_humidity_1000hPa, member), time: time)
            return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.dewpoint), temperature.unit)
        case .dew_point_925hPa:
            fallthrough
        case .dewpoint_925hPa:
            let temperature = try get(raw: .init(.temperature_925hPa, member), time: time)
            let rh = try get(raw: .init(.relative_humidity_925hPa, member), time: time)
            return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.dewpoint), temperature.unit)
        case .dew_point_850hPa:
            fallthrough
        case .dewpoint_850hPa:
            let temperature = try get(raw: .init(.temperature_850hPa, member), time: time)
            let rh = try get(raw: .init(.relative_humidity_850hPa, member), time: time)
            return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.dewpoint), temperature.unit)
        case .dew_point_700hPa:
            fallthrough
        case .dewpoint_700hPa:
            let temperature = try get(raw: .init(.temperature_700hPa, member), time: time)
            let rh = try get(raw: .init(.relative_humidity_700hPa, member), time: time)
            return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.dewpoint), temperature.unit)
        case .dew_point_500hPa:
            fallthrough
        case .dewpoint_500hPa:
            let temperature = try get(raw: .init(.temperature_500hPa, member), time: time)
            let rh = try get(raw: .init(.relative_humidity_500hPa, member), time: time)
            return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.dewpoint), temperature.unit)
        case .dew_point_300hPa:
            fallthrough
        case .dewpoint_300hPa:
            let temperature = try get(raw: .init(.temperature_300hPa, member), time: time)
            let rh = try get(raw: .init(.relative_humidity_300hPa, member), time: time)
            return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.dewpoint), temperature.unit)
        case .dew_point_250hPa:
            fallthrough
        case .dewpoint_250hPa:
            let temperature = try get(raw: .init(.temperature_250hPa, member), time: time)
            let rh = try get(raw: .init(.relative_humidity_250hPa, member), time: time)
            return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.dewpoint), temperature.unit)
        case .dew_point_200hPa:
            fallthrough
        case .dewpoint_200hPa:
            let temperature = try get(raw: .init(.temperature_200hPa, member), time: time)
            let rh = try get(raw: .init(.relative_humidity_200hPa, member), time: time)
            return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.dewpoint), temperature.unit)
        case .dew_point_50hPa:
            fallthrough
        case .dewpoint_50hPa:
            let temperature = try get(raw: .init(.temperature_50hPa, member), time: time)
            let rh = try get(raw: .init(.relative_humidity_50hPa, member), time: time)
            return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.dewpoint), temperature.unit)
        case .soil_temperature_0cm:
            fallthrough
        case .skin_temperature:
            return try get(raw: .init(.surface_temperature, member), time: time)
        case .surface_air_pressure:
            return try get(raw: .init(.surface_pressure, member), time: time)
        case .relative_humidity_2m:
            fallthrough
        case .relativehumidity_2m:
            return try get(raw: .init(.relative_humidity_1000hPa, member), time: time)
        case .dew_point_2m:
            fallthrough
        case .dewpoint_2m:
            let temperature = try get(raw: .init(.temperature_2m, member), time: time)
            let rh = try get(derived: .init(.relativehumidity_2m, member), time: time)
            return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.dewpoint), temperature.unit)
        case .apparent_temperature:
            let windspeed = try get(derived: .init(.windspeed_10m, member), time: time).data
            let temperature = try get(raw: .init(.temperature_2m, member), time: time).data
            let relhum = try get(derived: .init(.relativehumidity_2m, member), time: time).data
            return DataAndUnit(Meteorology.apparentTemperature(temperature_2m: temperature, relativehumidity_2m: relhum, windspeed_10m: windspeed, shortware_radiation: nil), .celsius)
        case .vapour_pressure_deficit:
            fallthrough
        case .vapor_pressure_deficit:
            let temperature = try get(raw: .init(.temperature_2m, member), time: time).data
            let rh = try get(derived: .init(.relativehumidity_2m, member), time: time).data
            let dewpoint = zip(temperature,rh).map(Meteorology.dewpoint)
            return DataAndUnit(zip(temperature,dewpoint).map(Meteorology.vaporPressureDeficit), .kilopascal)
        case .wet_bulb_temperature_2m:
            let temperature = try get(raw: .init(.temperature_2m, member), time: time)
            let rh = try get(derived: .init(.relativehumidity_2m, member), time: time)
            return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.wetBulbTemperature), temperature.unit)
        case .cloudcover:
            return try get(raw: .init(.cloud_cover, member), time: time)
        case .cloudcover_low:
            return try get(raw: .init(.cloud_cover_low, member), time: time)
        case .cloudcover_mid:
            return try get(raw: .init(.cloud_cover_mid, member), time: time)
        case .cloudcover_high:
            return try get(raw: .init(.cloud_cover_high, member), time: time)
        }
    }
    
    func prefetchData(derived: Derived, time: TimerangeDt) throws {
        let member = derived.member
        switch derived.variable {
        case .wind_speed_10m:
            fallthrough
        case .windspeed_10m:
            try prefetchData(raw: .init(.wind_u_component_10m, member), time: time)
            try prefetchData(raw: .init(.wind_v_component_10m, member), time: time)
        case .wind_speed_1000hPa:
            fallthrough
        case .windspeed_1000hPa:
            try prefetchData(raw: .init(.wind_v_component_1000hPa, member), time: time)
            try prefetchData(raw: .init(.wind_u_component_1000hPa, member), time: time)
        case .wind_speed_925hPa:
            fallthrough
        case .windspeed_925hPa:
            try prefetchData(raw: .init(.wind_v_component_925hPa, member), time: time)
            try prefetchData(raw: .init(.wind_u_component_925hPa, member), time: time)
        case .wind_speed_850hPa:
            fallthrough
        case .windspeed_850hPa:
            try prefetchData(raw: .init(.wind_v_component_850hPa, member), time: time)
            try prefetchData(raw: .init(.wind_u_component_850hPa, member), time: time)
        case .wind_speed_700hPa:
            fallthrough
        case .windspeed_700hPa:
            try prefetchData(raw: .init(.wind_v_component_700hPa, member), time: time)
            try prefetchData(raw: .init(.wind_u_component_700hPa, member), time: time)
        case .wind_speed_500hPa:
            fallthrough
        case .windspeed_500hPa:
            try prefetchData(raw: .init(.wind_v_component_500hPa, member), time: time)
            try prefetchData(raw: .init(.wind_u_component_500hPa, member), time: time)
        case .wind_speed_300hPa:
            fallthrough
        case .windspeed_300hPa:
            try prefetchData(raw: .init(.wind_v_component_300hPa, member), time: time)
            try prefetchData(raw: .init(.wind_u_component_300hPa, member), time: time)
        case .wind_speed_250hPa:
            fallthrough
        case .windspeed_250hPa:
            try prefetchData(raw: .init(.wind_v_component_250hPa, member), time: time)
            try prefetchData(raw: .init(.wind_u_component_250hPa, member), time: time)
        case .wind_speed_200hPa:
            fallthrough
        case .windspeed_200hPa:
            try prefetchData(raw: .init(.wind_v_component_200hPa, member), time: time)
            try prefetchData(raw: .init(.wind_u_component_200hPa, member), time: time)
        case .wind_speed_50hPa:
            fallthrough
        case .windspeed_50hPa:
            try prefetchData(raw: .init(.wind_v_component_50hPa, member), time: time)
            try prefetchData(raw: .init(.wind_u_component_50hPa, member), time: time)
        case .wind_direction_10m:
            fallthrough
        case .winddirection_10m:
            try prefetchData(raw: .init(.wind_u_component_10m, member), time: time)
            try prefetchData(raw: .init(.wind_v_component_10m, member), time: time)
        case .wind_direction_1000hPa:
            fallthrough
        case .winddirection_1000hPa:
            try prefetchData(raw: .init(.wind_v_component_1000hPa, member), time: time)
            try prefetchData(raw: .init(.wind_u_component_1000hPa, member), time: time)
        case .wind_direction_925hPa:
            fallthrough
        case .winddirection_925hPa:
            try prefetchData(raw: .init(.wind_v_component_925hPa, member), time: time)
            try prefetchData(raw: .init(.wind_u_component_925hPa, member), time: time)
        case .wind_direction_850hPa:
            fallthrough
        case .winddirection_850hPa:
            try prefetchData(raw: .init(.wind_v_component_850hPa, member), time: time)
            try prefetchData(raw: .init(.wind_u_component_850hPa, member), time: time)
        case .wind_direction_700hPa:
            fallthrough
        case .winddirection_700hPa:
            try prefetchData(raw: .init(.wind_v_component_700hPa, member), time: time)
            try prefetchData(raw: .init(.wind_u_component_700hPa, member), time: time)
        case .wind_direction_500hPa:
            fallthrough
        case .winddirection_500hPa:
            try prefetchData(raw: .init(.wind_v_component_500hPa, member), time: time)
            try prefetchData(raw: .init(.wind_u_component_500hPa, member), time: time)
        case .wind_direction_300hPa:
            fallthrough
        case .winddirection_300hPa:
            try prefetchData(raw: .init(.wind_v_component_300hPa, member), time: time)
            try prefetchData(raw: .init(.wind_u_component_300hPa, member), time: time)
        case .wind_direction_250hPa:
            fallthrough
        case .winddirection_250hPa:
            try prefetchData(raw: .init(.wind_v_component_250hPa, member), time: time)
            try prefetchData(raw: .init(.wind_u_component_250hPa, member), time: time)
        case .wind_direction_200hPa:
            fallthrough
        case .winddirection_200hPa:
            try prefetchData(raw: .init(.wind_v_component_200hPa, member), time: time)
            try prefetchData(raw: .init(.wind_u_component_200hPa, member), time: time)
        case .wind_direction_50hPa:
            fallthrough
        case .winddirection_50hPa:
            try prefetchData(raw: .init(.wind_v_component_50hPa, member), time: time)
            try prefetchData(raw: .init(.wind_u_component_50hPa, member), time: time)
        case .soil_temperature_0_to_10cm:
            fallthrough
        case .soil_temperature_0_10cm:
            fallthrough
        case .soil_temperature_0_7cm:
            try prefetchData(raw: .init(.soil_temperature_0_to_7cm, member), time: time)
        case .cloud_cover_1000hPa:
            fallthrough
        case .cloudcover_1000hPa:
            try prefetchData(raw: .init(.relative_humidity_1000hPa, member), time: time)
        case .cloud_cover_925hPa:
            fallthrough
        case .cloudcover_925hPa:
            try prefetchData(raw: .init(.relative_humidity_925hPa, member), time: time)
        case .cloud_cover_850hPa:
            fallthrough
        case .cloudcover_850hPa:
            try prefetchData(raw: .init(.relative_humidity_850hPa, member), time: time)
        case .cloud_cover_700hPa:
            fallthrough
        case .cloudcover_700hPa:
            try prefetchData(raw: .init(.relative_humidity_700hPa, member), time: time)
        case .cloud_cover_500hPa:
            fallthrough
        case .cloudcover_500hPa:
            try prefetchData(raw: .init(.relative_humidity_500hPa, member), time: time)
        case .cloud_cover_300hPa:
            fallthrough
        case .cloudcover_300hPa:
            try prefetchData(raw: .init(.relative_humidity_300hPa, member), time: time)
        case .cloud_cover_250hPa:
            fallthrough
        case .cloudcover_250hPa:
            try prefetchData(raw: .init(.relative_humidity_250hPa, member), time: time)
        case .cloud_cover_200hPa:
            fallthrough
        case .cloudcover_200hPa:
            try prefetchData(raw: .init(.relative_humidity_200hPa, member), time: time)
        case .cloud_cover_50hPa:
            fallthrough
        case .cloudcover_50hPa:
            try prefetchData(raw: .init(.relative_humidity_50hPa, member), time: time)
        case .weather_code:
            fallthrough
        case .weathercode:
            try prefetchData(raw: .init(.cloud_cover, member), time: time)
            try prefetchData(derived: .init(.snowfall, member), time: time)
            try prefetchData(raw: .init(.precipitation, member), time: time)
        case .rain:
            fallthrough
        case .snowfall:
            try prefetchData(raw: .init(.temperature_2m, member), time: time)
            try prefetchData(raw: .init(.precipitation, member), time: time)
        case .is_day:
            break
        case .relativehumidity_1000hPa:
            try prefetchData(raw: .init(.relative_humidity_1000hPa, member), time: time)
        case .relativehumidity_925hPa:
            try prefetchData(raw: .init(.relative_humidity_925hPa, member), time: time)
        case .relativehumidity_850hPa:
            try prefetchData(raw: .init(.relative_humidity_850hPa, member), time: time)
        case .relativehumidity_700hPa:
            try prefetchData(raw: .init(.relative_humidity_700hPa, member), time: time)
        case .relativehumidity_500hPa:
            try prefetchData(raw: .init(.relative_humidity_500hPa, member), time: time)
        case .relativehumidity_300hPa:
            try prefetchData(raw: .init(.relative_humidity_300hPa, member), time: time)
        case .relativehumidity_250hPa:
            try prefetchData(raw: .init(.relative_humidity_250hPa, member), time: time)
        case .relativehumidity_200hPa:
            try prefetchData(raw: .init(.relative_humidity_200hPa, member), time: time)
        case .relativehumidity_50hPa:
            try prefetchData(raw: .init(.relative_humidity_50hPa, member), time: time)
        case .dew_point_1000hPa:
            fallthrough
        case .dewpoint_1000hPa:
            try prefetchData(raw: .init(.temperature_1000hPa, member), time: time)
            try prefetchData(raw: .init(.relative_humidity_1000hPa, member), time: time)
        case .dew_point_925hPa:
            fallthrough
        case .dewpoint_925hPa:
            try prefetchData(raw: .init(.temperature_925hPa, member), time: time)
            try prefetchData(raw: .init(.relative_humidity_925hPa, member), time: time)
        case .dew_point_850hPa:
            fallthrough
        case .dewpoint_850hPa:
            try prefetchData(raw: .init(.temperature_850hPa, member), time: time)
            try prefetchData(raw: .init(.relative_humidity_850hPa, member), time: time)
        case .dew_point_700hPa:
            fallthrough
        case .dewpoint_700hPa:
            try prefetchData(raw: .init(.temperature_700hPa, member), time: time)
            try prefetchData(raw: .init(.relative_humidity_700hPa, member), time: time)
        case .dew_point_500hPa:
            fallthrough
        case .dewpoint_500hPa:
            try prefetchData(raw: .init(.temperature_500hPa, member), time: time)
            try prefetchData(raw: .init(.relative_humidity_500hPa, member), time: time)
        case .dew_point_300hPa:
            fallthrough
        case .dewpoint_300hPa:
            try prefetchData(raw: .init(.temperature_300hPa, member), time: time)
            try prefetchData(raw: .init(.relative_humidity_300hPa, member), time: time)
        case .dew_point_250hPa:
            fallthrough
        case .dewpoint_250hPa:
            try prefetchData(raw: .init(.temperature_250hPa, member), time: time)
            try prefetchData(raw: .init(.relative_humidity_250hPa, member), time: time)
        case .dew_point_200hPa:
            fallthrough
        case .dewpoint_200hPa:
            try prefetchData(raw: .init(.temperature_200hPa, member), time: time)
            try prefetchData(raw: .init(.relative_humidity_200hPa, member), time: time)
        case .dew_point_50hPa:
            fallthrough
        case .dewpoint_50hPa:
            try prefetchData(raw: .init(.temperature_50hPa, member), time: time)
            try prefetchData(raw: .init(.relative_humidity_50hPa, member), time: time)
        case .skin_temperature:
            fallthrough
        case .soil_temperature_0cm:
            try prefetchData(raw: .init(.surface_temperature, member), time: time)
        case .surface_air_pressure:
            try prefetchData(raw: .init(.surface_pressure, member), time: time)
        case .relative_humidity_2m:
            fallthrough
        case .relativehumidity_2m:
            try prefetchData(raw: .init(.relative_humidity_1000hPa, member), time: time)
        case .dew_point_2m:
            fallthrough
        case .dewpoint_2m:
            try prefetchData(raw: .init(.relative_humidity_1000hPa, member), time: time)
            try prefetchData(raw: .init(.temperature_2m, member), time: time)
        case .apparent_temperature:
            try prefetchData(derived: .init(.relativehumidity_2m, member), time: time)
            try prefetchData(raw: .init(.temperature_2m, member), time: time)
            try prefetchData(derived: .init(.windspeed_10m, member), time: time)
        case .vapour_pressure_deficit:
            fallthrough
        case .vapor_pressure_deficit:
            try prefetchData(derived: .init(.relativehumidity_2m, member), time: time)
            try prefetchData(raw: .init(.temperature_2m, member), time: time)
        case .wet_bulb_temperature_2m:
            try prefetchData(raw: .init(.relative_humidity_1000hPa, member), time: time)
            try prefetchData(raw: .init(.temperature_2m, member), time: time)
        case .cloudcover:
            try prefetchData(raw: .init(.cloud_cover, member), time: time)
        case .cloudcover_low:
            try prefetchData(raw: .init(.cloud_cover_low, member), time: time)
        case .cloudcover_mid:
            try prefetchData(raw: .init(.cloud_cover_mid, member), time: time)
        case .cloudcover_high:
            try prefetchData(raw: .init(.cloud_cover_high, member), time: time)
        }
    }
}
