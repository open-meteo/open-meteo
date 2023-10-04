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
        if raw.variable == .surface_air_pressure {
            let pressure = try reader.get(variable: raw, time: time)
            let factor = Meteorology.sealevelPressureFactor(temperature: 20, elevation: reader.modelElevation.numeric) / Meteorology.sealevelPressureFactor(temperature: 20, elevation: reader.targetElevation)
            return DataAndUnit(pressure.data.map({$0*factor}), pressure.unit)
        }
        return try reader.get(variable: raw, time: time)
    }
    
    func get(derived: Derived, time: TimerangeDt) throws -> DataAndUnit {
        let member = derived.member
        switch derived.variable {
        case .windspeed_10m:
            let v = try get(raw: .init(.northward_wind_10m, member), time: time)
            let u = try get(raw: .init(.eastward_wind_10m, member), time: time)
            let speed = zip(u.data,v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .ms)
        case .winddirection_10m:
            let v = try get(raw: .init(.northward_wind_10m, member), time: time)
            let u = try get(raw: .init(.eastward_wind_10m, member), time: time)
            let direction = Meteorology.windirectionFast(u: u.data, v: v.data)
            return DataAndUnit(direction, .degreeDirection)
        case .windspeed_1000hPa:
            let v = try get(raw: .init(.northward_wind_1000hPa, member), time: time)
            let u = try get(raw: .init(.eastward_wind_1000hPa, member), time: time)
            let speed = zip(u.data,v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .ms)
        case .windspeed_925hPa:
            let v = try get(raw: .init(.northward_wind_925hPa, member), time: time)
            let u = try get(raw: .init(.eastward_wind_925hPa, member), time: time)
            let speed = zip(u.data,v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .ms)
        case .windspeed_850hPa:
            let v = try get(raw: .init(.northward_wind_850hPa, member), time: time)
            let u = try get(raw: .init(.eastward_wind_850hPa, member), time: time)
            let speed = zip(u.data,v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .ms)
        case .windspeed_700hPa:
            let v = try get(raw: .init(.northward_wind_700hPa, member), time: time)
            let u = try get(raw: .init(.eastward_wind_700hPa, member), time: time)
            let speed = zip(u.data,v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .ms)
        case .windspeed_500hPa:
            let v = try get(raw: .init(.northward_wind_500hPa, member), time: time)
            let u = try get(raw: .init(.eastward_wind_500hPa, member), time: time)
            let speed = zip(u.data,v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .ms)
        case .windspeed_300hPa:
            let v = try get(raw: .init(.northward_wind_300hPa, member), time: time)
            let u = try get(raw: .init(.eastward_wind_300hPa, member), time: time)
            let speed = zip(u.data,v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .ms)
        case .windspeed_250hPa:
            let v = try get(raw: .init(.northward_wind_250hPa, member), time: time)
            let u = try get(raw: .init(.eastward_wind_250hPa, member), time: time)
            let speed = zip(u.data,v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .ms)
        case .windspeed_200hPa:
            let v = try get(raw: .init(.northward_wind_200hPa, member), time: time)
            let u = try get(raw: .init(.eastward_wind_200hPa, member), time: time)
            let speed = zip(u.data,v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .ms)
        case .windspeed_50hPa:
            let v = try get(raw: .init(.northward_wind_50hPa, member), time: time)
            let u = try get(raw: .init(.eastward_wind_50hPa, member), time: time)
            let speed = zip(u.data,v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .ms)
        case .winddirection_1000hPa:
            let v = try get(raw: .init(.northward_wind_1000hPa, member), time: time)
            let u = try get(raw: .init(.eastward_wind_1000hPa, member), time: time)
            let direction = Meteorology.windirectionFast(u: u.data, v: v.data)
            return DataAndUnit(direction, .degreeDirection)
        case .winddirection_925hPa:
            let v = try get(raw: .init(.northward_wind_925hPa, member), time: time)
            let u = try get(raw: .init(.eastward_wind_925hPa, member), time: time)
            let direction = Meteorology.windirectionFast(u: u.data, v: v.data)
            return DataAndUnit(direction, .degreeDirection)
        case .winddirection_850hPa:
            let v = try get(raw: .init(.northward_wind_850hPa, member), time: time)
            let u = try get(raw: .init(.eastward_wind_850hPa, member), time: time)
            let direction = Meteorology.windirectionFast(u: u.data, v: v.data)
            return DataAndUnit(direction, .degreeDirection)
        case .winddirection_700hPa:
            let v = try get(raw: .init(.northward_wind_700hPa, member), time: time)
            let u = try get(raw: .init(.eastward_wind_700hPa, member), time: time)
            let direction = Meteorology.windirectionFast(u: u.data, v: v.data)
            return DataAndUnit(direction, .degreeDirection)
        case .winddirection_500hPa:
            let v = try get(raw: .init(.northward_wind_500hPa, member), time: time)
            let u = try get(raw: .init(.eastward_wind_500hPa, member), time: time)
            let direction = Meteorology.windirectionFast(u: u.data, v: v.data)
            return DataAndUnit(direction, .degreeDirection)
        case .winddirection_300hPa:
            let v = try get(raw: .init(.northward_wind_300hPa, member), time: time)
            let u = try get(raw: .init(.eastward_wind_300hPa, member), time: time)
            let direction = Meteorology.windirectionFast(u: u.data, v: v.data)
            return DataAndUnit(direction, .degreeDirection)
        case .winddirection_250hPa:
            let v = try get(raw: .init(.northward_wind_250hPa, member), time: time)
            let u = try get(raw: .init(.eastward_wind_250hPa, member), time: time)
            let direction = Meteorology.windirectionFast(u: u.data, v: v.data)
            return DataAndUnit(direction, .degreeDirection)
        case .winddirection_200hPa:
            let v = try get(raw: .init(.northward_wind_200hPa, member), time: time)
            let u = try get(raw: .init(.eastward_wind_200hPa, member), time: time)
            let direction = Meteorology.windirectionFast(u: u.data, v: v.data)
            return DataAndUnit(direction, .degreeDirection)
        case .winddirection_50hPa:
            let v = try get(raw: .init(.northward_wind_50hPa, member), time: time)
            let u = try get(raw: .init(.eastward_wind_50hPa, member), time: time)
            let direction = Meteorology.windirectionFast(u: u.data, v: v.data)
            return DataAndUnit(direction, .degreeDirection)
        case .soil_temperature_0_to_10cm:
            fallthrough
        case .soil_temperature_0_10cm:
            fallthrough
        case .soil_temperature_0_7cm:
            return try get(raw: .init(.soil_temperature_0_to_7cm, member), time: time)
        case .weathercode:
            let cloudcover = try get(raw: .init(.cloudcover, member), time: time).data
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
        case .cloudcover_1000hPa:
            let rh = try get(raw: .init(.relative_humidity_1000hPa, member), time: time)
            return DataAndUnit(rh.data.map({Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0, pressureHPa: 1000)}), .percent)
        case .cloudcover_925hPa:
            let rh = try get(raw: .init(.relative_humidity_925hPa, member), time: time)
            return DataAndUnit(rh.data.map({Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0, pressureHPa: 925)}), .percent)
        case .cloudcover_850hPa:
            let rh = try get(raw: .init(.relative_humidity_850hPa, member), time: time)
            return DataAndUnit(rh.data.map({Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0, pressureHPa: 850)}), .percent)
        case .cloudcover_700hPa:
            let rh = try get(raw: .init(.relative_humidity_700hPa, member), time: time)
            return DataAndUnit(rh.data.map({Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0, pressureHPa: 700)}), .percent)
        case .cloudcover_500hPa:
            let rh = try get(raw: .init(.relative_humidity_500hPa, member), time: time)
            return DataAndUnit(rh.data.map({Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0, pressureHPa: 500)}), .percent)
        case .cloudcover_300hPa:
            let rh = try get(raw: .init(.relative_humidity_300hPa, member), time: time)
            return DataAndUnit(rh.data.map({Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0, pressureHPa: 300)}), .percent)
        case .cloudcover_250hPa:
            let rh = try get(raw: .init(.relative_humidity_250hPa, member), time: time)
            return DataAndUnit(rh.data.map({Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0, pressureHPa: 250)}), .percent)
        case .cloudcover_200hPa:
            let rh = try get(raw: .init(.relative_humidity_200hPa, member), time: time)
            return DataAndUnit(rh.data.map({Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0, pressureHPa: 200)}), .percent)
        case .cloudcover_50hPa:
            let rh = try get(raw: .init(.relative_humidity_50hPa, member), time: time)
            return DataAndUnit(rh.data.map({Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0, pressureHPa: 50)}), .percent)
        case .snowfall:
            let temperature = try get(raw: .init(.temperature_2m, member), time: time)
            let precipitation = try get(raw: .init(.precipitation, member), time: time)
            return DataAndUnit(zip(temperature.data, precipitation.data).map({ $1 * ($0 >= 0 ? 0 : 0.7) }), .centimeter)
        case .rain:
            let temperature = try get(raw: .init(.temperature_2m, member), time: time)
            let precipitation = try get(raw: .init(.precipitation, member), time: time)
            return DataAndUnit(zip(temperature.data, precipitation.data).map({ $0 >= 0 ? $1 : 0 }), .millimeter)
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
        case .dewpoint_1000hPa:
            let temperature = try get(raw: .init(.temperature_1000hPa, member), time: time)
            let rh = try get(raw: .init(.relative_humidity_1000hPa, member), time: time)
            return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.dewpoint), temperature.unit)
        case .dewpoint_925hPa:
            let temperature = try get(raw: .init(.temperature_925hPa, member), time: time)
            let rh = try get(raw: .init(.relative_humidity_925hPa, member), time: time)
            return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.dewpoint), temperature.unit)
        case .dewpoint_850hPa:
            let temperature = try get(raw: .init(.temperature_850hPa, member), time: time)
            let rh = try get(raw: .init(.relative_humidity_850hPa, member), time: time)
            return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.dewpoint), temperature.unit)
        case .dewpoint_700hPa:
            let temperature = try get(raw: .init(.temperature_700hPa, member), time: time)
            let rh = try get(raw: .init(.relative_humidity_700hPa, member), time: time)
            return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.dewpoint), temperature.unit)
        case .dewpoint_500hPa:
            let temperature = try get(raw: .init(.temperature_500hPa, member), time: time)
            let rh = try get(raw: .init(.relative_humidity_500hPa, member), time: time)
            return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.dewpoint), temperature.unit)
        case .dewpoint_300hPa:
            let temperature = try get(raw: .init(.temperature_300hPa, member), time: time)
            let rh = try get(raw: .init(.relative_humidity_300hPa, member), time: time)
            return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.dewpoint), temperature.unit)
        case .dewpoint_250hPa:
            let temperature = try get(raw: .init(.temperature_250hPa, member), time: time)
            let rh = try get(raw: .init(.relative_humidity_250hPa, member), time: time)
            return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.dewpoint), temperature.unit)
        case .dewpoint_200hPa:
            let temperature = try get(raw: .init(.temperature_200hPa, member), time: time)
            let rh = try get(raw: .init(.relative_humidity_200hPa, member), time: time)
            return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.dewpoint), temperature.unit)
        case .dewpoint_50hPa:
            let temperature = try get(raw: .init(.temperature_50hPa, member), time: time)
            let rh = try get(raw: .init(.relative_humidity_50hPa, member), time: time)
            return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.dewpoint), temperature.unit)
        case .soil_temperature_0cm:
            fallthrough
        case .surface_temperature:
            return try get(raw: .init(.skin_temperature, member), time: time)
        case .surface_pressure:
            return try get(raw: .init(.surface_air_pressure, member), time: time)
        case .relativehumidity_2m:
            return try get(raw: .init(.relative_humidity_1000hPa, member), time: time)
        case .dewpoint_2m:
            let temperature = try get(raw: .init(.temperature_2m, member), time: time)
            let rh = try get(derived: .init(.relativehumidity_2m, member), time: time)
            return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.dewpoint), temperature.unit)
        case .apparent_temperature:
            let windspeed = try get(derived: .init(.windspeed_10m, member), time: time).data
            let temperature = try get(raw: .init(.temperature_2m, member), time: time).data
            let relhum = try get(derived: .init(.relativehumidity_2m, member), time: time).data
            return DataAndUnit(Meteorology.apparentTemperature(temperature_2m: temperature, relativehumidity_2m: relhum, windspeed_10m: windspeed, shortware_radiation: nil), .celsius)
        case .vapor_pressure_deficit:
            let temperature = try get(raw: .init(.temperature_2m, member), time: time).data
            let rh = try get(derived: .init(.relativehumidity_2m, member), time: time).data
            let dewpoint = zip(temperature,rh).map(Meteorology.dewpoint)
            return DataAndUnit(zip(temperature,dewpoint).map(Meteorology.vaporPressureDeficit), .kiloPascal)
        case .wet_bulb_temperature_2m:
            let temperature = try get(raw: .init(.temperature_2m, member), time: time)
            let rh = try get(derived: .init(.relativehumidity_2m, member), time: time)
            return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.wetBulbTemperature), temperature.unit)
        }
    }
    
    func prefetchData(derived: Derived, time: TimerangeDt) throws {
        let member = derived.member
        switch derived.variable {
        case .windspeed_10m:
            try prefetchData(raw: .init(.northward_wind_10m, member), time: time)
            try prefetchData(raw: .init(.eastward_wind_10m, member), time: time)
        case .windspeed_1000hPa:
            try prefetchData(raw: .init(.northward_wind_1000hPa, member), time: time)
            try prefetchData(raw: .init(.eastward_wind_1000hPa, member), time: time)
        case .windspeed_925hPa:
            try prefetchData(raw: .init(.northward_wind_925hPa, member), time: time)
            try prefetchData(raw: .init(.eastward_wind_925hPa, member), time: time)
        case .windspeed_850hPa:
            try prefetchData(raw: .init(.northward_wind_850hPa, member), time: time)
            try prefetchData(raw: .init(.eastward_wind_850hPa, member), time: time)
        case .windspeed_700hPa:
            try prefetchData(raw: .init(.northward_wind_700hPa, member), time: time)
            try prefetchData(raw: .init(.eastward_wind_700hPa, member), time: time)
        case .windspeed_500hPa:
            try prefetchData(raw: .init(.northward_wind_500hPa, member), time: time)
            try prefetchData(raw: .init(.eastward_wind_500hPa, member), time: time)
        case .windspeed_300hPa:
            try prefetchData(raw: .init(.northward_wind_300hPa, member), time: time)
            try prefetchData(raw: .init(.eastward_wind_300hPa, member), time: time)
        case .windspeed_250hPa:
            try prefetchData(raw: .init(.northward_wind_250hPa, member), time: time)
            try prefetchData(raw: .init(.eastward_wind_250hPa, member), time: time)
        case .windspeed_200hPa:
            try prefetchData(raw: .init(.northward_wind_200hPa, member), time: time)
            try prefetchData(raw: .init(.eastward_wind_200hPa, member), time: time)
        case .windspeed_50hPa:
            try prefetchData(raw: .init(.northward_wind_50hPa, member), time: time)
            try prefetchData(raw: .init(.eastward_wind_50hPa, member), time: time)
        case .winddirection_10m:
            try prefetchData(raw: .init(.northward_wind_10m, member), time: time)
            try prefetchData(raw: .init(.eastward_wind_10m, member), time: time)
        case .winddirection_1000hPa:
            try prefetchData(raw: .init(.northward_wind_1000hPa, member), time: time)
            try prefetchData(raw: .init(.eastward_wind_1000hPa, member), time: time)
        case .winddirection_925hPa:
            try prefetchData(raw: .init(.northward_wind_925hPa, member), time: time)
            try prefetchData(raw: .init(.eastward_wind_925hPa, member), time: time)
        case .winddirection_850hPa:
            try prefetchData(raw: .init(.northward_wind_850hPa, member), time: time)
            try prefetchData(raw: .init(.eastward_wind_850hPa, member), time: time)
        case .winddirection_700hPa:
            try prefetchData(raw: .init(.northward_wind_700hPa, member), time: time)
            try prefetchData(raw: .init(.eastward_wind_700hPa, member), time: time)
        case .winddirection_500hPa:
            try prefetchData(raw: .init(.northward_wind_500hPa, member), time: time)
            try prefetchData(raw: .init(.eastward_wind_500hPa, member), time: time)
        case .winddirection_300hPa:
            try prefetchData(raw: .init(.northward_wind_300hPa, member), time: time)
            try prefetchData(raw: .init(.eastward_wind_300hPa, member), time: time)
        case .winddirection_250hPa:
            try prefetchData(raw: .init(.northward_wind_250hPa, member), time: time)
            try prefetchData(raw: .init(.eastward_wind_250hPa, member), time: time)
        case .winddirection_200hPa:
            try prefetchData(raw: .init(.northward_wind_200hPa, member), time: time)
            try prefetchData(raw: .init(.eastward_wind_200hPa, member), time: time)
        case .winddirection_50hPa:
            try prefetchData(raw: .init(.northward_wind_50hPa, member), time: time)
            try prefetchData(raw: .init(.eastward_wind_50hPa, member), time: time)
        case .soil_temperature_0_to_10cm:
            fallthrough
        case .soil_temperature_0_10cm:
            fallthrough
        case .soil_temperature_0_7cm:
            try prefetchData(raw: .init(.soil_temperature_0_to_7cm, member), time: time)
        case .cloudcover_1000hPa:
            try prefetchData(raw: .init(.relative_humidity_1000hPa, member), time: time)
        case .cloudcover_925hPa:
            try prefetchData(raw: .init(.relative_humidity_925hPa, member), time: time)
        case .cloudcover_850hPa:
            try prefetchData(raw: .init(.relative_humidity_850hPa, member), time: time)
        case .cloudcover_700hPa:
            try prefetchData(raw: .init(.relative_humidity_700hPa, member), time: time)
        case .cloudcover_500hPa:
            try prefetchData(raw: .init(.relative_humidity_500hPa, member), time: time)
        case .cloudcover_300hPa:
            try prefetchData(raw: .init(.relative_humidity_300hPa, member), time: time)
        case .cloudcover_250hPa:
            try prefetchData(raw: .init(.relative_humidity_250hPa, member), time: time)
        case .cloudcover_200hPa:
            try prefetchData(raw: .init(.relative_humidity_200hPa, member), time: time)
        case .cloudcover_50hPa:
            try prefetchData(raw: .init(.relative_humidity_50hPa, member), time: time)
        case .weathercode:
            try prefetchData(raw: .init(.cloudcover, member), time: time)
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
        case .dewpoint_1000hPa:
            try prefetchData(raw: .init(.temperature_1000hPa, member), time: time)
            try prefetchData(raw: .init(.relative_humidity_1000hPa, member), time: time)
        case .dewpoint_925hPa:
            try prefetchData(raw: .init(.temperature_925hPa, member), time: time)
            try prefetchData(raw: .init(.relative_humidity_925hPa, member), time: time)
        case .dewpoint_850hPa:
            try prefetchData(raw: .init(.temperature_850hPa, member), time: time)
            try prefetchData(raw: .init(.relative_humidity_850hPa, member), time: time)
        case .dewpoint_700hPa:
            try prefetchData(raw: .init(.temperature_700hPa, member), time: time)
            try prefetchData(raw: .init(.relative_humidity_700hPa, member), time: time)
        case .dewpoint_500hPa:
            try prefetchData(raw: .init(.temperature_500hPa, member), time: time)
            try prefetchData(raw: .init(.relative_humidity_500hPa, member), time: time)
        case .dewpoint_300hPa:
            try prefetchData(raw: .init(.temperature_300hPa, member), time: time)
            try prefetchData(raw: .init(.relative_humidity_300hPa, member), time: time)
        case .dewpoint_250hPa:
            try prefetchData(raw: .init(.temperature_250hPa, member), time: time)
            try prefetchData(raw: .init(.relative_humidity_250hPa, member), time: time)
        case .dewpoint_200hPa:
            try prefetchData(raw: .init(.temperature_200hPa, member), time: time)
            try prefetchData(raw: .init(.relative_humidity_200hPa, member), time: time)
        case .dewpoint_50hPa:
            try prefetchData(raw: .init(.temperature_50hPa, member), time: time)
            try prefetchData(raw: .init(.relative_humidity_50hPa, member), time: time)
        case .surface_temperature:
            fallthrough
        case .soil_temperature_0cm:
            try prefetchData(raw: .init(.skin_temperature, member), time: time)
        case .surface_pressure:
            try prefetchData(raw: .init(.surface_air_pressure, member), time: time)
        case .relativehumidity_2m:
            try prefetchData(raw: .init(.relative_humidity_1000hPa, member), time: time)
        case .dewpoint_2m:
            try prefetchData(raw: .init(.relative_humidity_1000hPa, member), time: time)
            try prefetchData(raw: .init(.temperature_2m, member), time: time)
        case .apparent_temperature:
            try prefetchData(derived: .init(.relativehumidity_2m, member), time: time)
            try prefetchData(raw: .init(.temperature_2m, member), time: time)
            try prefetchData(derived: .init(.windspeed_10m, member), time: time)
        case .vapor_pressure_deficit:
            try prefetchData(derived: .init(.relativehumidity_2m, member), time: time)
            try prefetchData(raw: .init(.temperature_2m, member), time: time)
        case .wet_bulb_temperature_2m:
            try prefetchData(raw: .init(.relative_humidity_1000hPa, member), time: time)
            try prefetchData(raw: .init(.temperature_2m, member), time: time)
        }
    }
}
