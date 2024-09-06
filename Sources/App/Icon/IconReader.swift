import Foundation

struct IconReader: GenericReaderDerived, GenericReaderProtocol {
    
    typealias Domain = IconDomains
    typealias Variable = IconVariable
    typealias Derived = IconVariableDerived
    typealias MixingVar = VariableOrDerived<IconVariable, IconVariableDerived>

    let reader: GenericReaderCached<IconDomains, Variable>
    
    let options: GenericReaderOptions
    
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
    
    func get(variable: VariableOrDerived<IconVariable, IconVariableDerived>, time: TimerangeDtAndSettings) throws -> DataAndUnit {
        switch variable {
        case .raw(let raw):
            return try get(raw: raw, time: time)
        case .derived(let derived):
            return try get(derived: derived, time: time)
        }
    }

    func get(raw: IconVariable, time: TimerangeDtAndSettings) throws -> DataAndUnit {
        // icon-d2 has no levels 800, 900, 925
        if reader.domain == .iconD2, case let .pressure(pressure) = raw  {
            let level = pressure.level
            let variable = pressure.variable
            switch level {
            case 800:
                return try self.interpolatePressureLevel(variable: variable, level: level, lowerLevel: 700, upperLevel: 850, time: time)
            case 900:
                return try self.interpolatePressureLevel(variable: variable, level: level, lowerLevel: 850, upperLevel: 950, time: time)
            case 925:
                return try self.interpolatePressureLevel(variable: variable, level: level, lowerLevel: 850, upperLevel: 950, time: time)
            default: break
            }
        }
        if case let .surface(surface) = raw {
            if surface == .direct_radiation {
                // Original ICON direct radiation data may contain small negative values like -0.2.
                // Limit to 0. See https://github.com/open-meteo/open-meteo/issues/932
                let direct = try reader.get(variable: .surface(.direct_radiation), time: time)
                return DataAndUnit(direct.data.map({max($0,0)}), direct.unit)
            }
            
            // ICON-EPS stores total shortwave radiation in diffuse_radiation
            // It would be possible to only use `shortwave_radiation`, but this would invalidate all archives
            if reader.domain == .iconEps,surface == .diffuse_radiation {
                let ghi = try reader.get(variable: raw, time: time)
                let direct = try reader.get(variable: .surface(.direct_radiation), time: time)
                return DataAndUnit(zip(ghi.data, direct.data).map({max($0-$1,0)}), ghi.unit)
            }
            
            // no dedicated rain field in ICON EU EPS
            if reader.domain == .iconEuEps, surface == .rain {
                let precipitation = try get(raw: .precipitation, time: time).data
                let snow_gsp = try get(raw: .snowfall_water_equivalent, time: time).data
                return DataAndUnit(zip(precipitation, snow_gsp).map({$0 - $1}), .millimetre)
            }
            
            // no dedicated rain field in ICON EPS and no snow, use temperautre
            if reader.domain == .iconEps, surface == .rain {
                let precipitation = try get(raw: .precipitation, time: time).data
                let temperature = try get(raw: .temperature_2m, time: time).data
                return DataAndUnit(zip(precipitation, temperature).map({$0 * ($1 <= 0 ? 0 : 1)}), .millimetre)
            }
            
            // EPS models do not have weather codes
            if [.iconEuEps, .iconEps, .iconD2Eps].contains(reader.domain), surface == .weather_code {
                let cloudcover = try get(raw: .cloud_cover, time: time).data
                let precipitation = try get(raw: .precipitation, time: time).data
                let snowfall = try get(variable: .derived(.surface(.snowfall)), time: time).data
                let showers = reader.domain != .iconD2Eps ? nil : try get(raw: .surface(.showers), time: time).data
                let cape = reader.domain == .iconEps ? nil : try get(raw: .surface(.cape), time: time).data
                let gusts = reader.domain == .iconEps ? nil : try get(raw: .surface(.wind_gusts_10m), time: time).data
                return DataAndUnit(WeatherCode.calculate(
                    cloudcover: cloudcover,
                    precipitation: precipitation,
                    convectivePrecipitation: showers,
                    snowfallCentimeters: snowfall,
                    gusts: gusts,
                    cape: cape,
                    liftedIndex: nil,
                    visibilityMeters: nil,
                    categoricalFreezingRain: nil,
                    modelDtSeconds: time.dtSeconds), .wmoCode
                )
            }
            
            // In case elevation correction of more than 100m is necessary, always calculate snow manually with a hard cut at 0°C
            if abs(reader.modelElevation.numeric - reader.targetElevation) > 100 {
                // in case temperature > 0°C, remove snow
                if surface == .snowfall_water_equivalent {
                    let snowfall = try reader.get(variable: .surface(.snowfall_water_equivalent), time: time).data
                    let temperature = try get(raw: .temperature_2m, time: time).data
                    return DataAndUnit(zip(snowfall, temperature).map({$0 * ($1 >= 0 ? 0 : 1)}), .millimetre)
                }
                // in case temperature <0°C, convert add snow to rain
                if surface == .rain {
                    let rain = try reader.get(variable: .surface(.rain), time: time).data
                    let snowfall = try reader.get(variable: .surface(.snowfall_water_equivalent), time: time).data
                    let temperature = try get(raw: .temperature_2m, time: time).data
                    return DataAndUnit(zip(zip(rain, snowfall), temperature).map({$0.0 + max(0, $0.1 * ($1 >= 0 ? 1 : 0))}), .millimetre)
                }
                
                // Correct snow/rain in weather code according to temperature
                if surface == .weather_code {
                    var weatherCode = try reader.get(variable: .surface(.weather_code), time: time).data
                    let temperature = try get(raw: .temperature_2m, time: time).data
                    for i in weatherCode.indices {
                        guard weatherCode[i].isFinite, let weathercode = WeatherCode(rawValue: Int(weatherCode[i])) else {
                            continue
                        }
                        weatherCode[i] = Float(weathercode.correctSnowRainHardCutOff(
                            temperature_2m: temperature[i]
                        ).rawValue)
                    }
                    return DataAndUnit(weatherCode, .wmoCode)
                }
            }
        }
        
        // icon global and EU lack level 975
        if reader.domain != .iconD2, case let .pressure(pressure) = raw, pressure.level == 975  {
            return try self.interpolatePressureLevel(variable: pressure.variable, level: pressure.level, lowerLevel: 950, upperLevel: 1000, time: time)
        }
        
        return try reader.get(variable: raw, time: time)
    }
    
    func prefetchData(raw: IconVariable, time: TimerangeDtAndSettings) throws {
        // icon-d2 has no levels 800, 900, 925
        if reader.domain == .iconD2, case let .pressure(pressure) = raw  {
            let level = pressure.level
            let variable = pressure.variable
            switch level {
            case 800:
                try reader.prefetchData(variable: .pressure(IconPressureVariable(variable: variable, level: 700)), time: time)
                try reader.prefetchData(variable: .pressure(IconPressureVariable(variable: variable, level: 850)), time: time)
                return
            case 900: fallthrough
            case 925:
                try reader.prefetchData(variable: .pressure(IconPressureVariable(variable: variable, level: 850)), time: time)
                try reader.prefetchData(variable: .pressure(IconPressureVariable(variable: variable, level: 950)), time: time)
                return
            default: break
            }
        }
        
        if case let .surface(surface) = raw {
            // ICON-EPS stores total shortwave radiation in diffuse_radiation
            if reader.domain == .iconEps, surface == .diffuse_radiation {
                try reader.prefetchData(variable: raw, time: time)
                try reader.prefetchData(variable: .surface(.direct_radiation), time: time)
                return
            }
            
            // no dedicated rain field in ICON EU EPS
            if reader.domain == .iconEuEps, surface == .rain {
                try reader.prefetchData(variable: .surface(.precipitation), time: time)
                try reader.prefetchData(variable: .surface(.snowfall_water_equivalent), time: time)
                return
            }
            
            // no dedicated rain field in ICON EPS and no snow, use temperautre
            if reader.domain == .iconEps, surface == .rain {
                try reader.prefetchData(variable: .surface(.precipitation), time: time)
                try reader.prefetchData(variable: .surface(.temperature_2m), time: time)
                return
            }
            
            // EPS models do not have weather codes
            if [.iconEuEps, .iconEps, .iconD2Eps].contains(reader.domain), surface == .weather_code {
                try reader.prefetchData(variable: .surface(.precipitation), time: time)
                try reader.prefetchData(variable: .surface(.cloud_cover), time: time)
                if reader.domain != .iconEuEps {
                    try reader.prefetchData(variable: .surface(.snowfall_water_equivalent), time: time)
                    try reader.prefetchData(variable: .surface(.wind_gusts_10m), time: time)
                    try reader.prefetchData(variable: .surface(.cape), time: time)
                }
                if reader.domain == .iconEps {
                    // use temperature for snowfall
                    try reader.prefetchData(variable: .surface(.temperature_2m), time: time)
                }
                if reader.domain == .iconD2Eps {
                    try reader.prefetchData(variable: .surface(.showers), time: time)
                }
                return
            }
            
            // In case elevation correction of more than 100m is necessary, always calculate snow manually with a hard cut at 0°C
            if abs(reader.modelElevation.numeric - reader.targetElevation) > 100 {
                // in case temperature > 0°C, remove snow
                if surface == .snowfall_water_equivalent {
                    try reader.prefetchData(variable: .surface(.snowfall_water_equivalent), time: time)
                    try reader.prefetchData(variable: .surface(.temperature_2m), time: time)
                    return
                }
                // in case temperature < 0°C, convert add snow to rain
                if surface == .rain {
                    try reader.prefetchData(variable: .surface(.snowfall_water_equivalent), time: time)
                    try reader.prefetchData(variable: .surface(.rain), time: time)
                    try reader.prefetchData(variable: .surface(.temperature_2m), time: time)
                    return
                }
                
                // Correct snow/rain in weather code according to temperature
                if surface == .weather_code {
                    try reader.prefetchData(variable: .surface(.weather_code), time: time)
                    try reader.prefetchData(variable: .surface(.temperature_2m), time: time)
                    return
                }
            }
        }
        
        // icon global and EU lack level 975
        if reader.domain != .iconD2, case let .pressure(pressure) = raw, pressure.level == 975  {
            let variable = pressure.variable
            try reader.prefetchData(variable: .pressure(IconPressureVariable(variable: variable, level: 950)), time: time)
            try reader.prefetchData(variable: .pressure(IconPressureVariable(variable: variable, level: 1000)), time: time)
            return
        }
        
        return try reader.prefetchData(variable: raw, time: time)
    }
     
    /// TODO: duplicated code in meteofrance controller
    private func interpolatePressureLevel(variable: IconPressureVariableType, level: Int, lowerLevel: Int, upperLevel: Int, time: TimerangeDtAndSettings) throws -> DataAndUnit {
        let lower = try get(raw: .pressure(IconPressureVariable(variable: variable, level: lowerLevel)), time: time)
        let upper = try get(raw: .pressure(IconPressureVariable(variable: variable, level: upperLevel)), time: time)
        
        switch variable {
        case .temperature:
            // temperature/pressure is linear, therefore
            // perform linear interpolation between 2 points
            return DataAndUnit(zip(lower.data, upper.data).map { (l, h) -> Float in
                return l + Float(level - lowerLevel) * (h - l) / Float(upperLevel - lowerLevel)
            }, lower.unit)
        case .wind_u_component:
            fallthrough
        case .wind_v_component:
            return DataAndUnit(zip(lower.data, upper.data).map { (l, h) -> Float in
                return l + Float(level - lowerLevel) * (h - l) / Float(upperLevel - lowerLevel)
            }, lower.unit)
        case .geopotential_height:
            return DataAndUnit(zip(lower.data, upper.data).map { (l, h) -> Float in
                let lP = Meteorology.pressureLevelHpA(altitudeAboveSeaLevelMeters: l)
                let hP = Meteorology.pressureLevelHpA(altitudeAboveSeaLevelMeters: h)
                let adjPressure = lP + Float(level - lowerLevel) * (hP - lP) / Float(upperLevel - lowerLevel)
                return Meteorology.altitudeAboveSeaLevelMeters(pressureLevelHpA: adjPressure)
            }, lower.unit)
        case .relative_humidity:
            return DataAndUnit(zip(lower.data, upper.data).map { (l, h) -> Float in
                return (l + h) / 2
            }, lower.unit)
        }
    }
    
    func prefetchData(raw: IconSurfaceVariable, time: TimerangeDtAndSettings) throws {
        try prefetchData(variable: .raw(.surface(raw)), time: time)
    }
    
    func prefetchData(raw: IconPressureVariable, time: TimerangeDtAndSettings) throws {
        try prefetchData(variable: .raw(.pressure(raw)), time: time)
    }
    
    func get(raw: IconSurfaceVariable, time: TimerangeDtAndSettings) throws -> DataAndUnit {
        return try get(variable: .raw(.surface(raw)), time: time)
    }
    
    func get(raw: IconPressureVariable, time: TimerangeDtAndSettings) throws -> DataAndUnit {
        return try get(variable: .raw(.pressure(raw)), time: time)
    }
    
    func prefetchData(derived: IconVariableDerived, time: TimerangeDtAndSettings) throws {
        switch derived {
        case .surface(let variable):
            switch variable {
            case .apparent_temperature:
                try prefetchData(raw: .temperature_2m, time: time)
                try prefetchData(raw: .wind_u_component_10m, time: time)
                try prefetchData(raw: .wind_v_component_10m, time: time)
                try prefetchData(raw: .relative_humidity_2m, time: time)
                try prefetchData(raw: .direct_radiation, time: time)
                try prefetchData(raw: .diffuse_radiation, time: time)
            case .relativehumidity_2m:
                try prefetchData(raw: .relative_humidity_2m, time: time)
            case .dew_point_2m:
                fallthrough
            case .dewpoint_2m:
                try prefetchData(raw: .relative_humidity_2m, time: time)
                try prefetchData(raw: .temperature_2m, time: time)
            case .wind_speed_10m:
                fallthrough
            case .windspeed_10m:
                fallthrough
            case .wind_direction_10m:
                fallthrough
            case .winddirection_10m:
                try prefetchData(raw: .wind_u_component_10m, time: time)
                try prefetchData(raw: .wind_v_component_10m, time: time)
            case .wind_speed_80m:
                fallthrough
            case .windspeed_80m:
                fallthrough
            case .wind_direction_80m:
                fallthrough
            case .winddirection_80m:
                try prefetchData(raw: .wind_u_component_80m, time: time)
                try prefetchData(raw: .wind_v_component_80m, time: time)
            case .wind_speed_120m:
                fallthrough
            case .windspeed_120m:
                fallthrough
            case .wind_direction_120m:
                fallthrough
            case .winddirection_120m:
                try prefetchData(raw: .wind_u_component_120m, time: time)
                try prefetchData(raw: .wind_v_component_120m, time: time)
            case .wind_speed_180m:
                fallthrough
            case .windspeed_180m:
                fallthrough
            case .wind_direction_180m:
                fallthrough
            case .winddirection_180m:
                try prefetchData(raw: .wind_u_component_180m, time: time)
                try prefetchData(raw: .wind_v_component_180m, time: time)
            case .snow_height:
                try prefetchData(raw: .snow_depth, time: time)
            case .shortwave_radiation:
                try prefetchData(raw: .direct_radiation, time: time)
                try prefetchData(raw: .diffuse_radiation, time: time)
            case .direct_normal_irradiance:
                try prefetchData(raw: .direct_radiation, time: time)
            case .evapotranspiration:
                try prefetchData(raw: .latent_heat_flux, time: time)
            case .vapour_pressure_deficit:
                fallthrough
            case .vapor_pressure_deficit:
                try prefetchData(raw: .temperature_2m, time: time)
                try prefetchData(raw: .relative_humidity_2m, time: time)
            case .et0_fao_evapotranspiration:
                try prefetchData(raw: .direct_radiation, time: time)
                try prefetchData(raw: .diffuse_radiation, time: time)
                try prefetchData(raw: .temperature_2m, time: time)
                try prefetchData(raw: .relative_humidity_2m, time: time)
                try prefetchData(raw: .wind_u_component_10m, time: time)
                try prefetchData(raw: .wind_v_component_10m, time: time)
            case .snowfall:
                if reader.domain == .iconEps {
                    try prefetchData(raw: .precipitation, time: time)
                    try prefetchData(raw: .temperature_2m, time: time)
                } else {
                    try prefetchData(raw: .snowfall_water_equivalent, time: time)
                }
            case .surface_pressure:
                try prefetchData(raw: .pressure_msl, time: time)
                try prefetchData(raw: .temperature_2m, time: time)
            case .terrestrial_radiation:
                break
            case .terrestrial_radiation_instant:
                break
            case .shortwave_radiation_instant:
                try prefetchData(raw: .direct_radiation, time: time)
                try prefetchData(raw: .diffuse_radiation, time: time)
            case .diffuse_radiation_instant:
                try prefetchData(raw: .diffuse_radiation, time: time)
            case .direct_radiation_instant:
                try prefetchData(raw: .direct_radiation, time: time)
            case .direct_normal_irradiance_instant:
                try prefetchData(raw: .direct_radiation, time: time)
            case .is_day:
                break
            case .soil_moisture_0_1cm:
                try prefetchData(raw: .soil_moisture_0_to_1cm, time: time)
            case .soil_moisture_1_3cm:
                try prefetchData(raw: .soil_moisture_1_to_3cm, time: time)
            case .soil_moisture_3_9cm:
                try prefetchData(raw: .soil_moisture_3_to_9cm, time: time)
            case .soil_moisture_9_27cm:
                try prefetchData(raw: .soil_moisture_9_to_27cm, time: time)
            case .soil_moisture_27_81cm:
                try prefetchData(raw: .soil_moisture_27_to_81cm, time: time)
            case .wet_bulb_temperature_2m:
                try prefetchData(raw: .temperature_2m, time: time)
                try prefetchData(raw: .relative_humidity_2m, time: time)
            case .cloudcover:
                try prefetchData(raw: .cloud_cover, time: time)
            case .cloudcover_low:
                try prefetchData(raw: .cloud_cover_low, time: time)
            case .cloudcover_mid:
                try prefetchData(raw: .cloud_cover_mid, time: time)
            case .cloudcover_high:
                try prefetchData(raw: .cloud_cover_high, time: time)
            case .weathercode:
                try prefetchData(raw: .weather_code, time: time)
            case .sensible_heatflux:
                try prefetchData(raw: .sensible_heat_flux, time: time)
            case .latent_heatflux:
                try prefetchData(raw: .latent_heat_flux, time: time)
            case .windgusts_10m:
                try prefetchData(raw: .wind_gusts_10m, time: time)
            case .freezinglevel_height:
                try prefetchData(raw: .freezing_level_height, time: time)
            case .sunshine_duration:
                try prefetchData(raw: .direct_radiation, time: time)
            case .global_tilted_irradiance, .global_tilted_irradiance_instant:
                try prefetchData(raw: .direct_radiation, time: time)
                try prefetchData(raw: .diffuse_radiation, time: time)
            }
        case .pressure(let variable):
            let level = variable.level
            switch variable.variable {
            case .wind_speed:
                fallthrough
            case .windspeed:
                fallthrough
            case .wind_direction:
                fallthrough
            case .winddirection:
                try prefetchData(raw: IconPressureVariable(variable: .wind_u_component, level: level), time: time)
                try prefetchData(raw: IconPressureVariable(variable: .wind_v_component, level: level), time: time)
            case .dew_point:
                fallthrough
            case .dewpoint:
                try prefetchData(raw: IconPressureVariable(variable: .temperature, level: level), time: time)
                try prefetchData(raw: IconPressureVariable(variable: .relative_humidity, level: level), time: time)
            case .cloud_cover:
                fallthrough
            case .cloudcover:
                try prefetchData(raw: IconPressureVariable(variable: .relative_humidity, level: level), time: time)
            case .relativehumidity:
                try prefetchData(raw: IconPressureVariable(variable: .relative_humidity, level: level), time: time)
            }
        }
    }
    
    
    func get(derived: IconVariableDerived, time: TimerangeDtAndSettings) throws -> DataAndUnit {
        switch derived {
        case .surface(let variable):
            switch variable {
            case .wind_speed_10m:
                fallthrough
            case .windspeed_10m:
                let u = try get(raw: .wind_u_component_10m, time: time).data
                let v = try get(raw: .wind_v_component_10m, time: time).data
                let speed = zip(u,v).map(Meteorology.windspeed)
                return DataAndUnit(speed, .metrePerSecond)
            case .wind_direction_10m:
                fallthrough
            case .winddirection_10m:
                let u = try get(raw: .wind_u_component_10m, time: time).data
                let v = try get(raw: .wind_v_component_10m, time: time).data
                let direction = Meteorology.windirectionFast(u: u, v: v)
                return DataAndUnit(direction, .degreeDirection)
            case .wind_speed_80m:
                fallthrough
            case .windspeed_80m:
                let u = try get(raw: .wind_u_component_80m, time: time).data
                let v = try get(raw: .wind_v_component_80m, time: time).data
                let speed = zip(u,v).map(Meteorology.windspeed)
                return DataAndUnit(speed, .metrePerSecond)
            case .wind_direction_80m:
                fallthrough
            case .winddirection_80m:
                let u = try get(raw: .wind_u_component_80m, time: time).data
                let v = try get(raw: .wind_v_component_80m, time: time).data
                let direction = Meteorology.windirectionFast(u: u, v: v)
                return DataAndUnit(direction, .degreeDirection)
            case .wind_speed_120m:
                fallthrough
            case .windspeed_120m:
                let u = try get(raw: .wind_u_component_120m, time: time).data
                let v = try get(raw: .wind_v_component_120m, time: time).data
                let speed = zip(u,v).map(Meteorology.windspeed)
                return DataAndUnit(speed, .metrePerSecond)
            case .wind_direction_120m:
                fallthrough
            case .winddirection_120m:
                let u = try get(raw: .wind_u_component_120m, time: time).data
                let v = try get(raw: .wind_v_component_120m, time: time).data
                let direction = Meteorology.windirectionFast(u: u, v: v)
                return DataAndUnit(direction, .degreeDirection)
            case .wind_speed_180m:
                fallthrough
            case .windspeed_180m:
                let u = try get(raw: .wind_u_component_180m, time: time).data
                let v = try get(raw: .wind_v_component_180m, time: time).data
                let speed = zip(u,v).map(Meteorology.windspeed)
                return DataAndUnit(speed, .metrePerSecond)
            case .wind_direction_180m:
                fallthrough
            case .winddirection_180m:
                let u = try get(raw: .wind_u_component_180m, time: time).data
                let v = try get(raw: .wind_v_component_180m, time: time).data
                let direction = Meteorology.windirectionFast(u: u, v: v)
                return DataAndUnit(direction, .degreeDirection)
            case .snow_height:
                return try get(raw: .snow_depth, time: time)
            case .apparent_temperature:
                let windspeed = try get(derived: .surface(.windspeed_10m), time: time).data
                let temperature = try get(raw: .temperature_2m, time: time).data
                let relhum = try get(derived: .surface(.relativehumidity_2m), time: time).data
                let radiation = try get(derived: .surface(.shortwave_radiation), time: time).data
                return DataAndUnit(Meteorology.apparentTemperature(temperature_2m: temperature, relativehumidity_2m: relhum, windspeed_10m: windspeed, shortwave_radiation: radiation), .celsius)
            case .shortwave_radiation:
                let direct = try get(raw: .direct_radiation, time: time).data
                let diffuse = try get(raw: .diffuse_radiation, time: time).data
                let total = zip(direct, diffuse).map(+)
                return DataAndUnit(total, .wattPerSquareMetre)
            case .evapotranspiration:
                let latent = try get(raw: .latent_heat_flux, time: time).data
                let evapotranspiration = latent.map(Meteorology.evapotranspiration)
                return DataAndUnit(evapotranspiration, .millimetre)
            case .vapour_pressure_deficit:
                fallthrough
            case .vapor_pressure_deficit:
                let temperature = try get(raw: .temperature_2m, time: time).data
                let rh = try get(raw: .relative_humidity_2m, time: time).data
                let dewpoint = zip(temperature,rh).map(Meteorology.dewpoint)
                return DataAndUnit(zip(temperature,dewpoint).map(Meteorology.vaporPressureDeficit), .kilopascal)
            case .direct_normal_irradiance:
                let dhi = try get(raw: .direct_radiation, time: time).data
                let dni = Zensun.calculateBackwardsDNI(directRadiation: dhi, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time)
                return DataAndUnit(dni, .wattPerSquareMetre)
            case .et0_fao_evapotranspiration:
                let exrad = Zensun.extraTerrestrialRadiationBackwards(latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time)
                let swrad = try get(derived: .surface(.shortwave_radiation), time: time).data
                let temperature = try get(raw: .temperature_2m, time: time).data
                let windspeed = try get(derived: .surface(.windspeed_10m), time: time).data
                let rh = try get(raw: .relative_humidity_2m, time: time).data
                let dewpoint = zip(temperature,rh).map(Meteorology.dewpoint)
                
                let et0 = swrad.indices.map { i in
                    return Meteorology.et0Evapotranspiration(temperature2mCelsius: temperature[i], windspeed10mMeterPerSecond: windspeed[i], dewpointCelsius: dewpoint[i], shortwaveRadiationWatts: swrad[i], elevation: reader.targetElevation, extraTerrestrialRadiation: exrad[i], dtSeconds: 3600)
                }
                return DataAndUnit(et0, .millimetre)
            case .snowfall:
                if reader.domain == .iconEps {
                    let precipitation = try get(raw: .precipitation, time: time).data
                    let temperature = try get(raw: .temperature_2m, time: time).data
                    // snowfall if temperature below 0°C
                    let snowfall = zip(precipitation, temperature).map({
                        $0 * ($1 < 0 ? 0.7 : 0)
                    })
                    return DataAndUnit(snowfall, SiUnit.centimetre)
                }
                let snow_gsp = try get(raw: .snowfall_water_equivalent, time: time).data
                let snowfall = snow_gsp.map({$0 * 0.7})
                return DataAndUnit(snowfall, SiUnit.centimetre)
            case .relativehumidity_2m:
                return try get(raw: .relative_humidity_2m, time: time)
            case .dew_point_2m:
                fallthrough
            case .dewpoint_2m:
                let temperature = try get(raw: .temperature_2m, time: time)
                let rh = try get(raw: .relative_humidity_2m, time: time)
                return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.dewpoint), temperature.unit)
            case .surface_pressure:
                let temperature = try get(raw: .temperature_2m, time: time).data
                let pressure = try get(raw: .pressure_msl, time: time)
                return DataAndUnit(Meteorology.surfacePressure(temperature: temperature, pressure: pressure.data, elevation: reader.targetElevation), pressure.unit)
            case .terrestrial_radiation:
                /// Use center averaged
                let solar = Zensun.extraTerrestrialRadiationBackwards(latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time)
                return DataAndUnit(solar, .wattPerSquareMetre)
            case .terrestrial_radiation_instant:
                /// Use center averaged
                let solar = Zensun.extraTerrestrialRadiationInstant(latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time)
                return DataAndUnit(solar, .wattPerSquareMetre)
            case .shortwave_radiation_instant:
                let sw = try get(derived: .surface(.shortwave_radiation), time: time)
                let factor = Zensun.backwardsAveragedToInstantFactor(time: time.time, latitude: reader.modelLat, longitude: reader.modelLon)
                return DataAndUnit(zip(sw.data, factor).map(*), sw.unit)
            case .diffuse_radiation_instant:
                let diff = try get(raw: .diffuse_radiation, time: time)
                let factor = Zensun.backwardsAveragedToInstantFactor(time: time.time, latitude: reader.modelLat, longitude: reader.modelLon)
                return DataAndUnit(zip(diff.data, factor).map(*), diff.unit)
            case .direct_radiation_instant:
                let direct = try get(raw: .direct_radiation, time: time)
                let factor = Zensun.backwardsAveragedToInstantFactor(time: time.time, latitude: reader.modelLat, longitude: reader.modelLon)
                return DataAndUnit(zip(direct.data, factor).map(*), direct.unit)
            case .direct_normal_irradiance_instant:
                let direct = try get(derived: .surface(.direct_radiation_instant), time: time)
                let dni = Zensun.calculateInstantDNI(directRadiation: direct.data, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time)
                return DataAndUnit(dni, direct.unit)
            case .is_day:
                return DataAndUnit(Zensun.calculateIsDay(timeRange: time.time, lat: reader.modelLat, lon: reader.modelLon), .dimensionlessInteger)
            case .soil_moisture_0_1cm:
                return try get(raw: .soil_moisture_0_to_1cm, time: time)
            case .soil_moisture_1_3cm:
                return try get(raw: .soil_moisture_1_to_3cm, time: time)
            case .soil_moisture_3_9cm:
                return try get(raw: .soil_moisture_3_to_9cm, time: time)
            case .soil_moisture_9_27cm:
                return try get(raw: .soil_moisture_9_to_27cm, time: time)
            case .soil_moisture_27_81cm:
                return try get(raw: .soil_moisture_27_to_81cm, time: time)
            case .wet_bulb_temperature_2m:
                let temperature = try get(raw: .temperature_2m, time: time)
                let rh = try get(raw: .relative_humidity_2m, time: time).data
                return DataAndUnit(zip(temperature.data, rh).map(Meteorology.wetBulbTemperature), temperature.unit)
            case .cloudcover:
                return try get(raw: .cloud_cover, time: time)
            case .cloudcover_low:
                return try get(raw: .cloud_cover_low, time: time)
            case .cloudcover_mid:
                return try get(raw: .cloud_cover_mid, time: time)
            case .cloudcover_high:
                return try get(raw: .cloud_cover_high, time: time)
            case .weathercode:
                return try get(raw: .weather_code, time: time)
            case .sensible_heatflux:
                return try get(raw: .sensible_heat_flux, time: time)
            case .latent_heatflux:
                return try get(raw: .latent_heat_flux, time: time)
            case .windgusts_10m:
                return try get(raw: .wind_gusts_10m, time: time)
            case .freezinglevel_height:
                return try get(raw: .freezing_level_height, time: time)
            case .sunshine_duration:
                let directRadiation = try get(raw: .direct_radiation, time: time)
                let duration = Zensun.calculateBackwardsSunshineDuration(directRadiation: directRadiation.data, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time)
                return DataAndUnit(duration, .seconds)
            case .global_tilted_irradiance:
                let directRadiation = try get(raw: .direct_radiation, time: time).data
                let diffuseRadiation = try get(raw: .diffuse_radiation, time: time).data
                let gti = Zensun.calculateTiltedIrradiance(directRadiation: directRadiation, diffuseRadiation: diffuseRadiation, tilt: try options.getTilt(), azimuth: try options.getAzimuth(), latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time, convertBackwardsToInstant: false)
                return DataAndUnit(gti, .wattPerSquareMetre)
            case .global_tilted_irradiance_instant:
                let directRadiation = try get(raw: .direct_radiation, time: time).data
                let diffuseRadiation = try get(raw: .diffuse_radiation, time: time).data
                let gti = Zensun.calculateTiltedIrradiance(directRadiation: directRadiation, diffuseRadiation: diffuseRadiation, tilt: try options.getTilt(), azimuth: try options.getAzimuth(), latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time, convertBackwardsToInstant: true)
                return DataAndUnit(gti, .wattPerSquareMetre)
                
            }
        case .pressure(let variable):
            let level = variable.level
            switch variable.variable {
            case .wind_speed:
                fallthrough
            case .windspeed:
                let u = try get(raw: IconPressureVariable(variable: .wind_u_component, level: level), time: time)
                let v = try get(raw: IconPressureVariable(variable: .wind_v_component, level: level), time: time)
                let speed = zip(u.data,v.data).map(Meteorology.windspeed)
                return DataAndUnit(speed, u.unit)
            case .wind_direction:
                fallthrough
            case .winddirection:
                let u = try get(raw: IconPressureVariable(variable: .wind_u_component, level: level), time: time).data
                let v = try get(raw: IconPressureVariable(variable: .wind_v_component, level: level), time: time).data
                let direction = Meteorology.windirectionFast(u: u, v: v)
                return DataAndUnit(direction, .degreeDirection)
            case .dew_point:
                fallthrough
            case .dewpoint:
                let temperature = try get(raw: IconPressureVariable(variable: .temperature, level: level), time: time)
                let rh = try get(raw: IconPressureVariable(variable: .relative_humidity, level: level), time: time)
                return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.dewpoint), temperature.unit)
            case .cloud_cover:
                fallthrough
            case .cloudcover:
                let rh = try get(raw: IconPressureVariable(variable: .relative_humidity, level: level), time: time)
                return DataAndUnit(rh.data.map({Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0, pressureHPa: Float(level))}), .percentage)
            case .relativehumidity:
                return try get(raw: IconPressureVariable(variable: .relative_humidity, level: level), time: time)
            }
        }
    }
}

struct IconMixer: GenericReaderMixer {
    let reader: [IconReader]
    
    static func makeReader(domain: IconReader.Domain, lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode, options: GenericReaderOptions) throws -> IconReader? {
        return try IconReader(domain: domain, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
    }
}
