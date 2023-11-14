import Foundation

struct IconReader: GenericReaderDerived, GenericReaderProtocol {
    
    typealias Domain = IconDomains
    typealias Variable = VariableAndMemberAndControl<IconVariable>
    typealias Derived = VariableAndMemberAndControl<IconVariableDerived>
    typealias MixingVar = VariableOrDerived<VariableAndMemberAndControl<IconVariable>, VariableAndMemberAndControl<IconVariableDerived>>

    var reader: GenericReaderCached<IconDomains, Variable>
    
    public init?(domain: Domain, lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode) throws {
        guard let reader = try GenericReader<Domain, Variable>(domain: domain, lat: lat, lon: lon, elevation: elevation, mode: mode) else {
            return nil
        }
        self.reader = GenericReaderCached(reader: reader)
    }
    
    func get(variable: VariableOrDerived<IconVariable, IconVariableDerived>, member: Int, time: TimerangeDt) throws -> DataAndUnit {
        switch variable {
        case .raw(let raw):
            return try get(raw: .init(raw, member), time: time)
        case .derived(let derived):
            return try get(derived: .init(derived, member), time: time)
        }
    }

    func get(raw: VariableAndMemberAndControl<IconVariable>, time: TimerangeDt) throws -> DataAndUnit {
        let member = raw.member
        // icon-d2 has no levels 800, 900, 925
        if reader.domain == .iconD2, case let .pressure(pressure) = raw.variable  {
            let level = pressure.level
            let variable = pressure.variable
            switch level {
            case 800:
                return try self.interpolatePressureLevel(variable: variable, level: level, member: member, lowerLevel: 700, upperLevel: 850, time: time)
            case 900:
                return try self.interpolatePressureLevel(variable: variable, level: level, member: member, lowerLevel: 850, upperLevel: 950, time: time)
            case 925:
                return try self.interpolatePressureLevel(variable: variable, level: level, member: member, lowerLevel: 850, upperLevel: 950, time: time)
            default: break
            }
        }
        if case let .surface(surface) = raw.variable {
            // ICON-EPS stores total shortwave radiation in diffuse_radiation
            // It would be possible to only use `shortwave_radiation`, but this would invalidate all archives
            if reader.domain == .iconEps,surface == .diffuse_radiation {
                let ghi = try reader.get(variable: raw, time: time)
                let direct = try reader.get(variable: .init(.surface(.direct_radiation), member), time: time)
                return DataAndUnit(zip(ghi.data, direct.data).map({max($0-$1,0)}), ghi.unit)
            }
            
            // no dedicated rain field in ICON EU EPS
            if reader.domain == .iconEuEps, surface == .rain {
                let precipitation = try get(raw: .precipitation, member: member, time: time).data
                let snow_gsp = try get(raw: .snowfall_water_equivalent, member: member, time: time).data
                let snow_con = try get(raw: .snowfall_convective_water_equivalent, member: member, time: time).data
                return DataAndUnit(zip(precipitation, zip(snow_con, snow_gsp)).map({$0 - $1.0 - $1.1}), .millimetre)
            }
            
            // no dedicated rain field in ICON EPS and no snow, use temperautre
            if reader.domain == .iconEps, surface == .rain {
                let precipitation = try get(raw: .precipitation, member: member, time: time).data
                let temperature = try get(raw: .temperature_2m, member: member, time: time).data
                return DataAndUnit(zip(precipitation, temperature).map({$0 * ($1 <= 0 ? 0 : 1)}), .millimetre)
            }
            
            // EPS models do not have weather codes
            if [.iconEuEps, .iconEps, .iconD2Eps].contains(reader.domain), surface == .weathercode {
                let cloudcover = try get(raw: .cloudcover, member: member, time: time).data
                let precipitation = try get(raw: .precipitation, member: member, time: time).data
                let snowfall = try get(variable: .derived(.surface(.snowfall)), member: member, time: time).data
                let showers = reader.domain != .iconD2Eps ? nil : try get(raw: .init(.surface(.showers), member), time: time).data
                let cape = reader.domain == .iconEps ? nil : try get(raw: .init(.surface(.cape), member), time: time).data
                let gusts = reader.domain == .iconEps ? nil : try get(raw: .init(.surface(.windgusts_10m), member), time: time).data
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
        }
        
        // icon global and EU lack level 975
        if reader.domain != .iconD2, case let .pressure(pressure) = raw.variable, pressure.level == 975  {
            return try self.interpolatePressureLevel(variable: pressure.variable, level: pressure.level, member: member, lowerLevel: 950, upperLevel: 1000, time: time)
        }
        
        return try reader.get(variable: raw, time: time)
    }
    
    func prefetchData(raw: VariableAndMemberAndControl<IconVariable>, time: TimerangeDt) throws {
        let member = raw.member
        // icon-d2 has no levels 800, 900, 925
        if reader.domain == .iconD2, case let .pressure(pressure) = raw.variable  {
            let level = pressure.level
            let variable = pressure.variable
            switch level {
            case 800:
                try reader.prefetchData(variable: .init(.pressure(IconPressureVariable(variable: variable, level: 700)), member), time: time)
                try reader.prefetchData(variable: .init(.pressure(IconPressureVariable(variable: variable, level: 850)), member), time: time)
                return
            case 900: fallthrough
            case 925:
                try reader.prefetchData(variable: .init(.pressure(IconPressureVariable(variable: variable, level: 850)), member), time: time)
                try reader.prefetchData(variable: .init(.pressure(IconPressureVariable(variable: variable, level: 950)), member), time: time)
                return
            default: break
            }
        }
        
        if case let .surface(surface) = raw.variable {
            // ICON-EPS stores total shortwave radiation in diffuse_radiation
            if reader.domain == .iconEps, surface == .diffuse_radiation {
                try reader.prefetchData(variable: raw, time: time)
                try reader.prefetchData(variable: .init(.surface(.direct_radiation), member), time: time)
                return
            }
            
            // no dedicated rain field in ICON EU EPS
            if reader.domain == .iconEuEps, surface == .rain {
                try reader.prefetchData(variable: .init(.surface(.precipitation), member), time: time)
                try reader.prefetchData(variable: .init(.surface(.snowfall_water_equivalent), member), time: time)
                try reader.prefetchData(variable: .init(.surface(.snowfall_convective_water_equivalent), member), time: time)
                return
            }
            
            // no dedicated rain field in ICON EPS and no snow, use temperautre
            if reader.domain == .iconEps, surface == .rain {
                try reader.prefetchData(variable: .init(.surface(.precipitation), member), time: time)
                try reader.prefetchData(variable: .init(.surface(.temperature_2m), member), time: time)
                return
            }
            
            // EPS models do not have weather codes
            if [.iconEuEps, .iconEps, .iconD2Eps].contains(reader.domain), surface == .weathercode {
                try reader.prefetchData(variable: .init(.surface(.precipitation), member), time: time)
                try reader.prefetchData(variable: .init(.surface(.cloudcover), member), time: time)
                if reader.domain != .iconEuEps {
                    try reader.prefetchData(variable: .init(.surface(.snowfall_water_equivalent), member), time: time)
                    try reader.prefetchData(variable: .init(.surface(.snowfall_convective_water_equivalent), member), time: time)
                    try reader.prefetchData(variable: .init(.surface(.windgusts_10m), member), time: time)
                    try reader.prefetchData(variable: .init(.surface(.cape), member), time: time)
                }
                if reader.domain == .iconEps {
                    // use temperature for snowfall
                    try reader.prefetchData(variable: .init(.surface(.temperature_2m), member), time: time)
                }
                if reader.domain == .iconD2Eps {
                    try reader.prefetchData(variable: .init(.surface(.showers), member), time: time)
                }
                return
            }
        }
        
        // icon global and EU lack level 975
        if reader.domain != .iconD2, case let .pressure(pressure) = raw.variable, pressure.level == 975  {
            let variable = pressure.variable
            try reader.prefetchData(variable: .init(.pressure(IconPressureVariable(variable: variable, level: 950)), member), time: time)
            try reader.prefetchData(variable: .init(.pressure(IconPressureVariable(variable: variable, level: 1000)), member), time: time)
            return
        }
        
        return try reader.prefetchData(variable: raw, time: time)
    }
     
    /// TODO: duplicated code in meteofrance controller
    private func interpolatePressureLevel(variable: IconPressureVariableType, level: Int, member: Int, lowerLevel: Int, upperLevel: Int, time: TimerangeDt) throws -> DataAndUnit {
        let lower = try get(raw: .init(.pressure(IconPressureVariable(variable: variable, level: lowerLevel)), member), time: time)
        let upper = try get(raw: .init(.pressure(IconPressureVariable(variable: variable, level: upperLevel)), member), time: time)
        
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
        case .relativehumidity:
            return DataAndUnit(zip(lower.data, upper.data).map { (l, h) -> Float in
                return (l + h) / 2
            }, lower.unit)
        }
    }
    
    func prefetchData(raw: IconSurfaceVariable, member: Int, time: TimerangeDt) throws {
        try prefetchData(variable: .raw(.init(.surface(raw), member)), time: time)
    }
    
    func prefetchData(raw: IconPressureVariable, member: Int, time: TimerangeDt) throws {
        try prefetchData(variable: .raw(.init(.pressure(raw), member)), time: time)
    }
    
    func get(raw: IconSurfaceVariable, member: Int, time: TimerangeDt) throws -> DataAndUnit {
        return try get(variable: .raw(.init(.surface(raw), member)), time: time)
    }
    
    func get(raw: IconPressureVariable, member: Int, time: TimerangeDt) throws -> DataAndUnit {
        return try get(variable: .raw(.init(.pressure(raw), member)), time: time)
    }
    
    func prefetchData(derived: VariableAndMemberAndControl<IconVariableDerived>, time: TimerangeDt) throws {
        let member = derived.member
        switch derived.variable {
        case .surface(let variable):
            switch variable {
            case .apparent_temperature:
                try prefetchData(raw: .temperature_2m, member: member, time: time)
                try prefetchData(raw: .wind_u_component_10m, member: member, time: time)
                try prefetchData(raw: .wind_v_component_10m, member: member, time: time)
                try prefetchData(raw: .relativehumidity_2m, member: member, time: time)
                try prefetchData(raw: .direct_radiation, member: member, time: time)
                try prefetchData(raw: .diffuse_radiation, member: member, time: time)
            case .relative_humidity_2m:
                try prefetchData(raw: .relativehumidity_2m, member: member, time: time)
            case .dew_point_2m:
                fallthrough
            case .dewpoint_2m:
                try prefetchData(raw: .relativehumidity_2m, member: member, time: time)
                try prefetchData(raw: .temperature_2m, member: member, time: time)
            case .wind_speed_10m:
                fallthrough
            case .windspeed_10m:
                fallthrough
            case .wind_direction_10m:
                fallthrough
            case .winddirection_10m:
                try prefetchData(raw: .wind_u_component_10m, member: member, time: time)
                try prefetchData(raw: .wind_v_component_10m, member: member, time: time)
            case .wind_speed_80m:
                fallthrough
            case .windspeed_80m:
                fallthrough
            case .wind_direction_80m:
                fallthrough
            case .winddirection_80m:
                try prefetchData(raw: .wind_u_component_80m, member: member, time: time)
                try prefetchData(raw: .wind_v_component_80m, member: member, time: time)
            case .wind_speed_120m:
                fallthrough
            case .windspeed_120m:
                fallthrough
            case .wind_direction_120m:
                fallthrough
            case .winddirection_120m:
                try prefetchData(raw: .wind_u_component_120m, member: member, time: time)
                try prefetchData(raw: .wind_v_component_120m, member: member, time: time)
            case .wind_speed_180m:
                fallthrough
            case .windspeed_180m:
                fallthrough
            case .wind_direction_180m:
                fallthrough
            case .winddirection_180m:
                try prefetchData(raw: .wind_u_component_180m, member: member, time: time)
                try prefetchData(raw: .wind_v_component_180m, member: member, time: time)
            case .snow_height:
                try prefetchData(raw: .snow_depth, member: member, time: time)
            case .shortwave_radiation:
                try prefetchData(raw: .direct_radiation, member: member, time: time)
                try prefetchData(raw: .diffuse_radiation, member: member, time: time)
            case .direct_normal_irradiance:
                try prefetchData(raw: .direct_radiation, member: member, time: time)
            case .evapotranspiration:
                try prefetchData(raw: .latent_heatflux, member: member, time: time)
            case .vapour_pressure_deficit:
                fallthrough
            case .vapor_pressure_deficit:
                try prefetchData(raw: .temperature_2m, member: member, time: time)
                try prefetchData(raw: .relativehumidity_2m, member: member, time: time)
            case .et0_fao_evapotranspiration:
                try prefetchData(raw: .direct_radiation, member: member, time: time)
                try prefetchData(raw: .diffuse_radiation, member: member, time: time)
                try prefetchData(raw: .temperature_2m, member: member, time: time)
                try prefetchData(raw: .relativehumidity_2m, member: member, time: time)
                try prefetchData(raw: .wind_u_component_10m, member: member, time: time)
                try prefetchData(raw: .wind_v_component_10m, member: member, time: time)
            case .snowfall:
                if reader.domain == .iconEps {
                    try prefetchData(raw: .precipitation, member: member, time: time)
                    try prefetchData(raw: .temperature_2m, member: member, time: time)
                } else {
                    try prefetchData(raw: .snowfall_water_equivalent, member: member, time: time)
                    try prefetchData(raw: .snowfall_convective_water_equivalent, member: member, time: time)
                }
            case .surface_pressure:
                try prefetchData(raw: .pressure_msl, member: member, time: time)
                try prefetchData(raw: .temperature_2m, member: member, time: time)
            case .terrestrial_radiation:
                break
            case .terrestrial_radiation_instant:
                break
            case .shortwave_radiation_instant:
                try prefetchData(raw: .direct_radiation, member: member, time: time)
                try prefetchData(raw: .diffuse_radiation, member: member, time: time)
            case .diffuse_radiation_instant:
                try prefetchData(raw: .diffuse_radiation, member: member, time: time)
            case .direct_radiation_instant:
                try prefetchData(raw: .direct_radiation, member: member, time: time)
            case .direct_normal_irradiance_instant:
                try prefetchData(raw: .direct_radiation, member: member, time: time)
            case .is_day:
                break
            case .soil_moisture_0_to_1cm:
                try prefetchData(raw: .soil_moisture_0_1cm, member: member, time: time)
            case .soil_moisture_1_to_3cm:
                try prefetchData(raw: .soil_moisture_1_3cm, member: member, time: time)
            case .soil_moisture_3_to_9cm:
                try prefetchData(raw: .soil_moisture_3_9cm, member: member, time: time)
            case .soil_moisture_9_to_27cm:
                try prefetchData(raw: .soil_moisture_9_27cm, member: member, time: time)
            case .soil_moisture_27_to_81cm:
                try prefetchData(raw: .soil_moisture_27_81cm, member: member, time: time)
            case .wet_bulb_temperature_2m:
                try prefetchData(raw: .temperature_2m, member: member, time: time)
                try prefetchData(raw: .relativehumidity_2m, member: member, time: time)
            case .cloud_cover:
                try prefetchData(raw: .cloudcover, member: member, time: time)
            case .cloud_cover_low:
                try prefetchData(raw: .cloudcover_low, member: member, time: time)
            case .cloud_cover_mid:
                try prefetchData(raw: .cloudcover_mid, member: member, time: time)
            case .cloud_cover_high:
                try prefetchData(raw: .cloudcover_high, member: member, time: time)
            case .weather_code:
                try prefetchData(raw: .weathercode, member: member, time: time)
            case .sensible_heat_flux:
                try prefetchData(raw: .sensible_heatflux, member: member, time: time)
            case .latent_heat_flux:
                try prefetchData(raw: .latent_heatflux, member: member, time: time)
            case .wind_gusts_10m:
                try prefetchData(raw: .windgusts_10m, member: member, time: time)
            case .freezing_level_height:
                try prefetchData(raw: .freezinglevel_height, member: member, time: time)
            case .sunshine_duration:
                try prefetchData(raw: .direct_radiation, member: member, time: time)            }
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
                try prefetchData(raw: IconPressureVariable(variable: .wind_u_component, level: level), member: member, time: time)
                try prefetchData(raw: IconPressureVariable(variable: .wind_v_component, level: level), member: member, time: time)
            case .dew_point:
                fallthrough
            case .dewpoint:
                try prefetchData(raw: IconPressureVariable(variable: .temperature, level: level), member: member, time: time)
                try prefetchData(raw: IconPressureVariable(variable: .relativehumidity, level: level), member: member, time: time)
            case .cloud_cover:
                fallthrough
            case .cloudcover:
                try prefetchData(raw: IconPressureVariable(variable: .relativehumidity, level: level), member: member, time: time)
            case .relative_humidity:
                try prefetchData(raw: IconPressureVariable(variable: .relativehumidity, level: level), member: member, time: time)
            }
        }
    }
    
    
    func get(derived: VariableAndMemberAndControl<IconVariableDerived>, time: TimerangeDt) throws -> DataAndUnit {
        let member = derived.member
        switch derived.variable {
        case .surface(let variable):
            switch variable {
            case .wind_speed_10m:
                fallthrough
            case .windspeed_10m:
                let u = try get(raw: .wind_u_component_10m, member: member, time: time).data
                let v = try get(raw: .wind_v_component_10m, member: member, time: time).data
                let speed = zip(u,v).map(Meteorology.windspeed)
                return DataAndUnit(speed, .metrePerSecond)
            case .wind_direction_10m:
                fallthrough
            case .winddirection_10m:
                let u = try get(raw: .wind_u_component_10m, member: member, time: time).data
                let v = try get(raw: .wind_v_component_10m, member: member, time: time).data
                let direction = Meteorology.windirectionFast(u: u, v: v)
                return DataAndUnit(direction, .degreeDirection)
            case .wind_speed_80m:
                fallthrough
            case .windspeed_80m:
                let u = try get(raw: .wind_u_component_80m, member: member, time: time).data
                let v = try get(raw: .wind_v_component_80m, member: member, time: time).data
                let speed = zip(u,v).map(Meteorology.windspeed)
                return DataAndUnit(speed, .metrePerSecond)
            case .wind_direction_80m:
                fallthrough
            case .winddirection_80m:
                let u = try get(raw: .wind_u_component_80m, member: member, time: time).data
                let v = try get(raw: .wind_v_component_80m, member: member, time: time).data
                let direction = Meteorology.windirectionFast(u: u, v: v)
                return DataAndUnit(direction, .degreeDirection)
            case .wind_speed_120m:
                fallthrough
            case .windspeed_120m:
                let u = try get(raw: .wind_u_component_120m, member: member, time: time).data
                let v = try get(raw: .wind_v_component_120m, member: member, time: time).data
                let speed = zip(u,v).map(Meteorology.windspeed)
                return DataAndUnit(speed, .metrePerSecond)
            case .wind_direction_120m:
                fallthrough
            case .winddirection_120m:
                let u = try get(raw: .wind_u_component_120m, member: member, time: time).data
                let v = try get(raw: .wind_v_component_120m, member: member, time: time).data
                let direction = Meteorology.windirectionFast(u: u, v: v)
                return DataAndUnit(direction, .degreeDirection)
            case .wind_speed_180m:
                fallthrough
            case .windspeed_180m:
                let u = try get(raw: .wind_u_component_180m, member: member, time: time).data
                let v = try get(raw: .wind_v_component_180m, member: member, time: time).data
                let speed = zip(u,v).map(Meteorology.windspeed)
                return DataAndUnit(speed, .metrePerSecond)
            case .wind_direction_180m:
                fallthrough
            case .winddirection_180m:
                let u = try get(raw: .wind_u_component_180m, member: member, time: time).data
                let v = try get(raw: .wind_v_component_180m, member: member, time: time).data
                let direction = Meteorology.windirectionFast(u: u, v: v)
                return DataAndUnit(direction, .degreeDirection)
            case .snow_height:
                return try get(raw: .snow_depth, member: member, time: time)
            case .apparent_temperature:
                let windspeed = try get(derived: .init(.surface(.windspeed_10m), member), time: time).data
                let temperature = try get(raw: .temperature_2m, member: member, time: time).data
                let relhum = try get(derived: .init(.surface(.relative_humidity_2m), member), time: time).data
                let radiation = try get(derived: .init(.surface(.shortwave_radiation), member), time: time).data
                return DataAndUnit(Meteorology.apparentTemperature(temperature_2m: temperature, relativehumidity_2m: relhum, windspeed_10m: windspeed, shortware_radiation: radiation), .celsius)
            case .shortwave_radiation:
                let direct = try get(raw: .direct_radiation, member: member, time: time).data
                let diffuse = try get(raw: .diffuse_radiation, member: member, time: time).data
                let total = zip(direct, diffuse).map(+)
                return DataAndUnit(total, .wattPerSquareMetre)
            case .evapotranspiration:
                let latent = try get(raw: .latent_heatflux, member: member, time: time).data
                let evapotranspiration = latent.map(Meteorology.evapotranspiration)
                return DataAndUnit(evapotranspiration, .millimetre)
            case .vapour_pressure_deficit:
                fallthrough
            case .vapor_pressure_deficit:
                let temperature = try get(raw: .temperature_2m, member: member, time: time).data
                let rh = try get(raw: .relativehumidity_2m, member: member, time: time).data
                let dewpoint = zip(temperature,rh).map(Meteorology.dewpoint)
                return DataAndUnit(zip(temperature,dewpoint).map(Meteorology.vaporPressureDeficit), .kilopascal)
            case .direct_normal_irradiance:
                let dhi = try get(raw: .direct_radiation, member: member, time: time).data
                let dni = Zensun.calculateBackwardsDNI(directRadiation: dhi, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time)
                return DataAndUnit(dni, .wattPerSquareMetre)
            case .et0_fao_evapotranspiration:
                let exrad = Zensun.extraTerrestrialRadiationBackwards(latitude: reader.modelLat, longitude: reader.modelLon, timerange: time)
                let swrad = try get(derived: .init(.surface(.shortwave_radiation),  member), time: time).data
                let temperature = try get(raw: .temperature_2m, member: member, time: time).data
                let windspeed = try get(derived: .init(.surface(.windspeed_10m), member), time: time).data
                let rh = try get(raw: .relativehumidity_2m, member: member, time: time).data
                let dewpoint = zip(temperature,rh).map(Meteorology.dewpoint)
                
                let et0 = swrad.indices.map { i in
                    return Meteorology.et0Evapotranspiration(temperature2mCelsius: temperature[i], windspeed10mMeterPerSecond: windspeed[i], dewpointCelsius: dewpoint[i], shortwaveRadiationWatts: swrad[i], elevation: reader.targetElevation, extraTerrestrialRadiation: exrad[i], dtSeconds: 3600)
                }
                return DataAndUnit(et0, .millimetre)
            case .snowfall:
                if reader.domain == .iconEps {
                    let precipitation = try get(raw: .precipitation, member: member, time: time).data
                    let temperature = try get(raw: .temperature_2m, member: member, time: time).data
                    // snowfall if temperature below 0°C
                    let snowfall = zip(precipitation, temperature).map({
                        $0 * ($1 < 0 ? 0.7 : 0)
                    })
                    return DataAndUnit(snowfall, SiUnit.centimetre)
                }
                let snow_gsp = try get(raw: .snowfall_water_equivalent, member: member, time: time).data
                let snow_con = try get(raw: .snowfall_convective_water_equivalent, member: member, time: time).data
                let snowfall = zip(snow_gsp, snow_con).map({
                    ($0 + $1) * 0.7
                })
                return DataAndUnit(snowfall, SiUnit.centimetre)
            case .relative_humidity_2m:
                return try get(raw: .relativehumidity_2m, member: member, time: time)
            case .dew_point_2m:
                fallthrough
            case .dewpoint_2m:
                let temperature = try get(raw: .temperature_2m, member: member, time: time)
                let rh = try get(raw: .relativehumidity_2m, member: member, time: time)
                return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.dewpoint), temperature.unit)
            case .surface_pressure:
                let temperature = try get(raw: .temperature_2m, member: member, time: time).data
                let pressure = try get(raw: .pressure_msl, member: member, time: time)
                return DataAndUnit(Meteorology.surfacePressure(temperature: temperature, pressure: pressure.data, elevation: reader.targetElevation), pressure.unit)
            case .terrestrial_radiation:
                /// Use center averaged
                let solar = Zensun.extraTerrestrialRadiationBackwards(latitude: reader.modelLat, longitude: reader.modelLon, timerange: time)
                return DataAndUnit(solar, .wattPerSquareMetre)
            case .terrestrial_radiation_instant:
                /// Use center averaged
                let solar = Zensun.extraTerrestrialRadiationInstant(latitude: reader.modelLat, longitude: reader.modelLon, timerange: time)
                return DataAndUnit(solar, .wattPerSquareMetre)
            case .shortwave_radiation_instant:
                let sw = try get(derived: .init(.surface(.shortwave_radiation), member), time: time)
                let factor = Zensun.backwardsAveragedToInstantFactor(time: time, latitude: reader.modelLat, longitude: reader.modelLon)
                return DataAndUnit(zip(sw.data, factor).map(*), sw.unit)
            case .diffuse_radiation_instant:
                let diff = try get(raw: .diffuse_radiation, member: member, time: time)
                let factor = Zensun.backwardsAveragedToInstantFactor(time: time, latitude: reader.modelLat, longitude: reader.modelLon)
                return DataAndUnit(zip(diff.data, factor).map(*), diff.unit)
            case .direct_radiation_instant:
                let direct = try get(raw: .direct_radiation, member: member, time: time)
                let factor = Zensun.backwardsAveragedToInstantFactor(time: time, latitude: reader.modelLat, longitude: reader.modelLon)
                return DataAndUnit(zip(direct.data, factor).map(*), direct.unit)
            case .direct_normal_irradiance_instant:
                let direct = try get(derived: .init(.surface(.direct_radiation_instant), member), time: time)
                let dni = Zensun.calculateInstantDNI(directRadiation: direct.data, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time)
                return DataAndUnit(dni, direct.unit)
            case .is_day:
                return DataAndUnit(Zensun.calculateIsDay(timeRange: time, lat: reader.modelLat, lon: reader.modelLon), .dimensionlessInteger)
            case .soil_moisture_0_to_1cm:
                return try get(raw: .soil_moisture_0_1cm, member: member, time: time)
            case .soil_moisture_1_to_3cm:
                return try get(raw: .soil_moisture_1_3cm, member: member, time: time)
            case .soil_moisture_3_to_9cm:
                return try get(raw: .soil_moisture_3_9cm, member: member, time: time)
            case .soil_moisture_9_to_27cm:
                return try get(raw: .soil_moisture_9_27cm, member: member, time: time)
            case .soil_moisture_27_to_81cm:
                return try get(raw: .soil_moisture_27_81cm, member: member, time: time)
            case .wet_bulb_temperature_2m:
                let temperature = try get(raw: .temperature_2m, member: member, time: time)
                let rh = try get(raw: .relativehumidity_2m, member: member, time: time).data
                return DataAndUnit(zip(temperature.data, rh).map(Meteorology.wetBulbTemperature), temperature.unit)
            case .cloud_cover:
                return try get(raw: .cloudcover, member: member, time: time)
            case .cloud_cover_low:
                return try get(raw: .cloudcover_low, member: member, time: time)
            case .cloud_cover_mid:
                return try get(raw: .cloudcover_mid, member: member, time: time)
            case .cloud_cover_high:
                return try get(raw: .cloudcover_high, member: member, time: time)
            case .weather_code:
                return try get(raw: .weathercode, member: member, time: time)
            case .sensible_heat_flux:
                return try get(raw: .sensible_heatflux, member: member, time: time)
            case .latent_heat_flux:
                return try get(raw: .latent_heatflux, member: member, time: time)
            case .wind_gusts_10m:
                return try get(raw: .windgusts_10m, member: member, time: time)
            case .freezing_level_height:
                return try get(raw: .freezinglevel_height, member: member, time: time)
            case .sunshine_duration:
                let directRadiation = try get(raw: .direct_radiation, member: member, time: time)
                let duration = Zensun.calculateBackwardsSunshineDuration(directRadiation: directRadiation.data, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time)
                return DataAndUnit(duration, .seconds)
            }
        case .pressure(let variable):
            let level = variable.level
            switch variable.variable {
            case .wind_speed:
                fallthrough
            case .windspeed:
                let u = try get(raw: IconPressureVariable(variable: .wind_u_component, level: level), member: member, time: time)
                let v = try get(raw: IconPressureVariable(variable: .wind_v_component, level: level), member: member, time: time)
                let speed = zip(u.data,v.data).map(Meteorology.windspeed)
                return DataAndUnit(speed, u.unit)
            case .wind_direction:
                fallthrough
            case .winddirection:
                let u = try get(raw: IconPressureVariable(variable: .wind_u_component, level: level), member: member, time: time).data
                let v = try get(raw: IconPressureVariable(variable: .wind_v_component, level: level), member: member, time: time).data
                let direction = Meteorology.windirectionFast(u: u, v: v)
                return DataAndUnit(direction, .degreeDirection)
            case .dew_point:
                fallthrough
            case .dewpoint:
                let temperature = try get(raw: IconPressureVariable(variable: .temperature, level: level), member: member, time: time)
                let rh = try get(raw: IconPressureVariable(variable: .relativehumidity, level: level), member: member, time: time)
                return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.dewpoint), temperature.unit)
            case .cloud_cover:
                fallthrough
            case .cloudcover:
                let rh = try get(raw: IconPressureVariable(variable: .relativehumidity, level: level), member: member, time: time)
                return DataAndUnit(rh.data.map({Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0, pressureHPa: Float(level))}), .percentage)
            case .relative_humidity:
                return try get(raw: IconPressureVariable(variable: .relativehumidity, level: level), member: member, time: time)
            }
        }
    }
}

struct IconMixer: GenericReaderMixer {
    let reader: [IconReader]
    
    static func makeReader(domain: IconReader.Domain, lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode) throws -> IconReader? {
        return try IconReader(domain: domain, lat: lat, lon: lon, elevation: elevation, mode: mode)
    }
}
