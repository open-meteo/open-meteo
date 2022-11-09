import Foundation

struct IconReader: GenericReaderDerived, GenericReaderMixable {
    typealias Domain = IconDomains
    typealias Variable = IconVariable
    typealias Derived = IconVariableDerived
    typealias MixingVar = VariableOrDerived<IconVariable, IconVariableDerived>

    var reader: GenericReaderCached<IconDomains, IconVariable>

    func get(raw: IconVariable, time: TimerangeDt) throws -> DataAndUnit {
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
        
        // icon global and EU lack level 975
        if reader.domain != .iconD2, case let .pressure(pressure) = raw, pressure.level == 975  {
            return try self.interpolatePressureLevel(variable: pressure.variable, level: pressure.level, lowerLevel: 950, upperLevel: 1000, time: time)
        }
        
        return try reader.get(variable: raw, time: time)
    }
    
    func prefetchData(raw: IconVariable, time: TimerangeDt) throws {
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
    private func interpolatePressureLevel(variable: IconPressureVariableType, level: Int, lowerLevel: Int, upperLevel: Int, time: TimerangeDt) throws -> DataAndUnit {
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
        case .relativehumidity:
            return DataAndUnit(zip(lower.data, upper.data).map { (l, h) -> Float in
                return (l + h) / 2
            }, lower.unit)
        }
    }
    
    func prefetchData(raw: IconSurfaceVariable, time: TimerangeDt) throws {
        try prefetchData(variable: .raw(.surface(raw)), time: time)
    }
    
    func prefetchData(raw: IconPressureVariable, time: TimerangeDt) throws {
        try prefetchData(variable: .raw(.pressure(raw)), time: time)
    }
    
    func get(raw: IconSurfaceVariable, time: TimerangeDt) throws -> DataAndUnit {
        return try get(variable: .raw(.surface(raw)), time: time)
    }
    
    func get(raw: IconPressureVariable, time: TimerangeDt) throws -> DataAndUnit {
        return try get(variable: .raw(.pressure(raw)), time: time)
    }
    
    func prefetchData(derived: IconVariableDerived, time: TimerangeDt) throws {
        switch derived {
        case .surface(let variable):
            switch variable {
            case .apparent_temperature:
                try prefetchData(raw: .temperature_2m, time: time)
                try prefetchData(raw: .wind_u_component_10m, time: time)
                try prefetchData(raw: .wind_v_component_10m, time: time)
                try prefetchData(raw: .relativehumidity_2m, time: time)
                try prefetchData(raw: .direct_radiation, time: time)
                try prefetchData(raw: .diffuse_radiation, time: time)
            case .relativehumitidy_2m:
                try prefetchData(raw: .relativehumidity_2m, time: time)
            case .windspeed_10m:
                try prefetchData(raw: .wind_u_component_10m, time: time)
                try prefetchData(raw: .wind_v_component_10m, time: time)
            case .winddirection_10m:
                try prefetchData(raw: .wind_u_component_10m, time: time)
                try prefetchData(raw: .wind_v_component_10m, time: time)
            case .windspeed_80m:
                try prefetchData(raw: .wind_u_component_80m, time: time)
                try prefetchData(raw: .wind_v_component_80m, time: time)
            case .winddirection_80m:
                try prefetchData(raw: .wind_u_component_80m, time: time)
                try prefetchData(raw: .wind_v_component_80m, time: time)
            case .windspeed_120m:
                try prefetchData(raw: .wind_u_component_120m, time: time)
                try prefetchData(raw: .wind_v_component_120m, time: time)
            case .winddirection_120m:
                try prefetchData(raw: .wind_u_component_120m, time: time)
                try prefetchData(raw: .wind_v_component_120m, time: time)
            case .windspeed_180m:
                try prefetchData(raw: .wind_u_component_180m, time: time)
                try prefetchData(raw: .wind_v_component_180m, time: time)
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
                try prefetchData(raw: .latent_heatflux, time: time)
            case .vapor_pressure_deficit:
                try prefetchData(raw: .temperature_2m, time: time)
                try prefetchData(raw: .dewpoint_2m, time: time)
            case .et0_fao_evapotranspiration:
                try prefetchData(raw: .direct_radiation, time: time)
                try prefetchData(raw: .diffuse_radiation, time: time)
                try prefetchData(raw: .temperature_2m, time: time)
                try prefetchData(raw: .dewpoint_2m, time: time)
                try prefetchData(raw: .wind_u_component_10m, time: time)
                try prefetchData(raw: .wind_v_component_10m, time: time)
            case .snowfall:
                try prefetchData(raw: .snowfall_water_equivalent, time: time)
                try prefetchData(raw: .snowfall_convective_water_equivalent, time: time)
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
            }
        case .pressure(let variable):
            let level = variable.level
            switch variable.variable {
            case .windspeed:
                fallthrough
            case .winddirection:
                try prefetchData(raw: IconPressureVariable(variable: .wind_u_component, level: level), time: time)
                try prefetchData(raw: IconPressureVariable(variable: .wind_v_component, level: level), time: time)
            case .dewpoint:
                try prefetchData(raw: IconPressureVariable(variable: .temperature, level: level), time: time)
                try prefetchData(raw: IconPressureVariable(variable: .relativehumidity, level: level), time: time)
            case .cloudcover:
                try prefetchData(raw: IconPressureVariable(variable: .relativehumidity, level: level), time: time)
            }
        }
    }
    
    
    func get(derived: IconVariableDerived, time: TimerangeDt) throws -> DataAndUnit {
        switch derived {
        case .surface(let variable):
            switch variable {
            case .windspeed_10m:
                let u = try get(raw: .wind_u_component_10m, time: time).data
                let v = try get(raw: .wind_v_component_10m, time: time).data
                let speed = zip(u,v).map(Meteorology.windspeed)
                return DataAndUnit(speed, .ms)
            case .winddirection_10m:
                let u = try get(raw: .wind_u_component_10m, time: time).data
                let v = try get(raw: .wind_v_component_10m, time: time).data
                let direction = Meteorology.windirectionFast(u: u, v: v)
                return DataAndUnit(direction, .degreeDirection)
            case .windspeed_80m:
                let u = try get(raw: .wind_u_component_80m, time: time).data
                let v = try get(raw: .wind_v_component_80m, time: time).data
                let speed = zip(u,v).map(Meteorology.windspeed)
                return DataAndUnit(speed, .ms)
            case .winddirection_80m:
                let u = try get(raw: .wind_u_component_80m, time: time).data
                let v = try get(raw: .wind_v_component_80m, time: time).data
                let direction = Meteorology.windirectionFast(u: u, v: v)
                return DataAndUnit(direction, .degreeDirection)
            case .windspeed_120m:
                let u = try get(raw: .wind_u_component_120m, time: time).data
                let v = try get(raw: .wind_v_component_120m, time: time).data
                let speed = zip(u,v).map(Meteorology.windspeed)
                return DataAndUnit(speed, .ms)
            case .winddirection_120m:
                let u = try get(raw: .wind_u_component_120m, time: time).data
                let v = try get(raw: .wind_v_component_120m, time: time).data
                let direction = Meteorology.windirectionFast(u: u, v: v)
                return DataAndUnit(direction, .degreeDirection)
            case .windspeed_180m:
                let u = try get(raw: .wind_u_component_180m, time: time).data
                let v = try get(raw: .wind_v_component_180m, time: time).data
                let speed = zip(u,v).map(Meteorology.windspeed)
                return DataAndUnit(speed, .ms)
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
                let relhum = try get(raw: .relativehumidity_2m, time: time).data
                let radiation = try get(derived:  .surface(.shortwave_radiation), time: time).data
                return DataAndUnit(Meteorology.apparentTemperature(temperature_2m: temperature, relativehumidity_2m: relhum, windspeed_10m: windspeed, shortware_radiation: radiation), .celsius)
            case .shortwave_radiation:
                let direct = try get(raw: .direct_radiation, time: time).data
                let diffuse = try get(raw: .diffuse_radiation, time: time).data
                let total = zip(direct, diffuse).map(+)
                return DataAndUnit(total, .wattPerSquareMeter)
            case .evapotranspiration:
                let latent = try get(raw: .latent_heatflux, time: time).data
                let evapotranspiration = latent.map(Meteorology.evapotranspiration)
                return DataAndUnit(evapotranspiration, .millimeter)
            case .vapor_pressure_deficit:
                let temperature = try get(raw: .temperature_2m, time: time).data
                let dewpoint = try get(raw: .dewpoint_2m, time: time).data
                return DataAndUnit(zip(temperature,dewpoint).map(Meteorology.vaporPressureDeficit), .kiloPascal)
            case .direct_normal_irradiance:
                let dhi = try get(raw: .direct_radiation, time: time).data
                let dni = Zensun.calculateBackwardsDNI(directRadiation: dhi, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time)
                return DataAndUnit(dni, .wattPerSquareMeter)
            case .et0_fao_evapotranspiration:
                let exrad = Zensun.extraTerrestrialRadiationBackwards(latitude: reader.modelLat, longitude: reader.modelLon, timerange: time)
                let swrad = try get(derived: .surface(.shortwave_radiation), time: time).data
                let temperature = try get(raw: .temperature_2m, time: time).data
                let windspeed = try get(derived: .surface(.windspeed_10m), time: time).data
                let dewpoint = try get(raw: .dewpoint_2m, time: time).data
                
                let et0 = swrad.indices.map { i in
                    return Meteorology.et0Evapotranspiration(temperature2mCelsius: temperature[i], windspeed10mMeterPerSecond: windspeed[i], dewpointCelsius: dewpoint[i], shortwaveRadiationWatts: swrad[i], elevation: reader.targetElevation, extraTerrestrialRadiation: exrad[i], dtSeconds: 3600)
                }
                return DataAndUnit(et0, .millimeter)
            case .snowfall:
                let snow_gsp = try get(raw: .snowfall_water_equivalent, time: time).data
                let snow_con = try get(raw: .snowfall_convective_water_equivalent, time: time).data
                let snowfall = zip(snow_gsp, snow_con).map({
                    ($0 + $1) * 0.7
                })
                return DataAndUnit(snowfall, SiUnit.centimeter)
            case .relativehumitidy_2m:
                return try get(raw: .relativehumidity_2m, time: time)
            case .surface_pressure:
                let temperature = try get(raw: .temperature_2m, time: time).data
                let pressure = try get(raw: .pressure_msl, time: time)
                return DataAndUnit(Meteorology.surfacePressure(temperature: temperature, pressure: pressure.data, elevation: reader.targetElevation), pressure.unit)
            case .terrestrial_radiation:
                /// Use center averaged
                let solar = Zensun.extraTerrestrialRadiationBackwards(latitude: reader.modelLat, longitude: reader.modelLon, timerange: time)
                return DataAndUnit(solar, .wattPerSquareMeter)
            case .terrestrial_radiation_instant:
                /// Use center averaged
                let solar = Zensun.extraTerrestrialRadiationInstant(latitude: reader.modelLat, longitude: reader.modelLon, timerange: time)
                return DataAndUnit(solar, .wattPerSquareMeter)
            case .shortwave_radiation_instant:
                let sw = try get(derived: .surface(.shortwave_radiation), time: time)
                let factor = Zensun.backwardsAveragedToInstantFactor(time: time, latitude: reader.modelLat, longitude: reader.modelLon)
                return DataAndUnit(zip(sw.data, factor).map(*), sw.unit)
            case .diffuse_radiation_instant:
                let diff = try get(raw: .diffuse_radiation, time: time)
                let factor = Zensun.backwardsAveragedToInstantFactor(time: time, latitude: reader.modelLat, longitude: reader.modelLon)
                return DataAndUnit(zip(diff.data, factor).map(*), diff.unit)
            case .direct_radiation_instant:
                let direct = try get(raw: .direct_radiation, time: time)
                let factor = Zensun.backwardsAveragedToInstantFactor(time: time, latitude: reader.modelLat, longitude: reader.modelLon)
                return DataAndUnit(zip(direct.data, factor).map(*), direct.unit)
            case .direct_normal_irradiance_instant:
                let direct = try get(derived: .surface(.direct_radiation_instant), time: time)
                let dni = Zensun.calculateInstantDNI(directRadiation: direct.data, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time)
                return DataAndUnit(dni, direct.unit)
                
                // because DNI is divided by cos(zenith), the approach below was not work
                //let dni = try get(variable: .direct_normal_irradiance)
                //let factor = Zensun.backwardsAveragedToInstantFactor(time: mixer.time, latitude: mixer.modelLat, longitude: mixer.modelLon)
                //return DataAndUnit(zip(dni.data, factor).map(*), dni.unit)
            }
        case .pressure(let variable):
            let level = variable.level
            switch variable.variable {
            case .windspeed:
                let u = try get(raw: IconPressureVariable(variable: .wind_u_component, level: level), time: time)
                let v = try get(raw: IconPressureVariable(variable: .wind_v_component, level: level), time: time)
                let speed = zip(u.data,v.data).map(Meteorology.windspeed)
                return DataAndUnit(speed, u.unit)
            case .winddirection:
                let u = try get(raw: IconPressureVariable(variable: .wind_u_component, level: level), time: time).data
                let v = try get(raw: IconPressureVariable(variable: .wind_v_component, level: level), time: time).data
                let direction = Meteorology.windirectionFast(u: u, v: v)
                return DataAndUnit(direction, .degreeDirection)
            case .dewpoint:
                let temperature = try get(raw: IconPressureVariable(variable: .temperature, level: level), time: time)
                let rh = try get(raw: IconPressureVariable(variable: .relativehumidity, level: level), time: time)
                return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.dewpoint), temperature.unit)
            case .cloudcover:
                let rh = try get(raw: IconPressureVariable(variable: .relativehumidity, level: level), time: time)
                return DataAndUnit(rh.data.map(Meteorology.relativeHumidityToCloudCover), .percent)
            }
        }
    }
}

struct IconMixer: GenericReaderMixer {
    let reader: [IconReader]
}

extension IconMixer {
    func get(raw: IconSurfaceVariable, time: TimerangeDt) throws -> DataAndUnit {
        return try get(variable: .raw(.surface(raw)), time: time)
    }
    func get(derived: IconSurfaceVariableDerived, time: TimerangeDt) throws -> DataAndUnit {
        return try get(variable: .derived(.surface(derived)), time: time)
    }
    
    func getDaily(variable: DailyWeatherVariable, params: IconApiQuery, time timeDaily: TimerangeDt) throws -> DataAndUnit {
        let time = timeDaily.with(dtSeconds: modelDtSeconds)
        switch variable {
        case .temperature_2m_max:
            let data = try get(raw: .temperature_2m, time: time).conertAndRound(params: params)
            return DataAndUnit(data.data.max(by: 24), data.unit)
        case .temperature_2m_min:
            let data = try get(raw: .temperature_2m, time: time).conertAndRound(params: params)
            return DataAndUnit(data.data.min(by: 24), data.unit)
        case .apparent_temperature_max:
            let data = try get(derived: .apparent_temperature, time: time).conertAndRound(params: params)
            return DataAndUnit(data.data.max(by: 24), data.unit)
        case .apparent_temperature_min:
            let data = try get(derived: .apparent_temperature, time: time).conertAndRound(params: params)
            return DataAndUnit(data.data.min(by: 24), data.unit)
        case .precipitation_sum:
            // rounding is required, becuse floating point addition results in uneven numbers
            let data = try get(raw: .precipitation, time: time).conertAndRound(params: params)
            return DataAndUnit(data.data.sum(by: 24).round(digits: 2), data.unit)
        case .weathercode:
            // not 100% corrct
            let data = try get(raw: .weathercode, time: time).conertAndRound(params: params)
            return DataAndUnit(data.data.max(by: 24), data.unit)
        case .shortwave_radiation_sum:
            let data = try get(derived: .shortwave_radiation, time: time).conertAndRound(params: params)
            // 3600s only for hourly data of source
            return DataAndUnit(data.data.map({$0*0.0036}).sum(by: 24).round(digits: 2), .megaJoulesPerSquareMeter)
        case .windspeed_10m_max:
            let data = try get(derived: .windspeed_10m, time: time).conertAndRound(params: params)
            return DataAndUnit(data.data.max(by: 24), data.unit)
        case .windgusts_10m_max:
            let data = try get(raw: .windgusts_10m, time: time).conertAndRound(params: params)
            return DataAndUnit(data.data.max(by: 24), data.unit)
        case .winddirection_10m_dominant:
            // vector addition
            let u = try get(raw: .wind_u_component_10m, time: time).data.sum(by: 24)
            let v = try get(raw: .wind_v_component_10m, time: time).data.sum(by: 24)
            let direction = Meteorology.windirectionFast(u: u, v: v)
            return DataAndUnit(direction, .degreeDirection)
        //case .sunshine_hours:
            /// TODO need sunrise and set time for correct numbers
            //fatalError()
        case .precipitation_hours:
            let data = try get(raw: .precipitation, time: time).conertAndRound(params: params)
            return DataAndUnit(data.data.map({$0 > 0.001 ? 1 : 0}).sum(by: 24), .hours)
        case .sunrise:
            return DataAndUnit([],.hours)
        case .sunset:
            return DataAndUnit([],.hours)
        case .et0_fao_evapotranspiration:
            let data = try get(derived: .et0_fao_evapotranspiration, time: time).conertAndRound(params: params)
            return DataAndUnit(data.data.sum(by: 24).round(digits: 2), data.unit)
        case .snowfall_sum:
            let data = try get(derived: .snowfall, time: time).conertAndRound(params: params)
            return DataAndUnit(data.data.sum(by: 24).round(digits: 2), data.unit)
        case .rain_sum:
            let data = try get(raw: .rain, time: time).conertAndRound(params: params)
            return DataAndUnit(data.data.sum(by: 24).round(digits: 2), data.unit)
        case .showers_sum:
            let data = try get(raw: .showers, time: time).conertAndRound(params: params)
            return DataAndUnit(data.data.sum(by: 24).round(digits: 2), data.unit)
        }
    }
    
    func prefetchData(derived: IconSurfaceVariableDerived, time: TimerangeDt) throws {
        try prefetchData(variable: .derived(.surface(derived)), time: time)
    }
    
    func prefetchData(raw: IconSurfaceVariable, time: TimerangeDt) throws {
        try prefetchData(variable: .raw(.surface(raw)), time: time)
    }
    
    func prefetchData(variables: [DailyWeatherVariable], time timeDaily: TimerangeDt) throws {
        let time = timeDaily.with(dtSeconds: modelDtSeconds)
        for variable in variables {
            switch variable {
            case .temperature_2m_max:
                fallthrough
            case .temperature_2m_min:
                try prefetchData(raw: .temperature_2m, time: time)
            case .apparent_temperature_max:
                fallthrough
            case .apparent_temperature_min:
                try prefetchData(raw: .temperature_2m, time: time)
                try prefetchData(raw: .wind_u_component_10m, time: time)
                try prefetchData(raw: .wind_v_component_10m, time: time)
                try prefetchData(raw: .relativehumidity_2m, time: time)
                try prefetchData(raw: .direct_radiation, time: time)
                try prefetchData(raw: .diffuse_radiation, time: time)
            case .precipitation_sum:
                try prefetchData(raw: .precipitation, time: time)
            case .weathercode:
                try prefetchData(raw: .weathercode, time: time)
            case .shortwave_radiation_sum:
                try prefetchData(raw: .direct_radiation, time: time)
                try prefetchData(raw: .diffuse_radiation, time: time)
            case .windspeed_10m_max:
                try prefetchData(raw: .wind_u_component_10m, time: time)
                try prefetchData(raw: .wind_v_component_10m, time: time)
            case .windgusts_10m_max:
                try prefetchData(raw: .windgusts_10m, time: time)
            case .winddirection_10m_dominant:
                try prefetchData(raw: .wind_u_component_10m, time: time)
                try prefetchData(raw: .wind_v_component_10m, time: time)
            case .precipitation_hours:
                try prefetchData(raw: .precipitation, time: time)
            case .sunrise:
                break
            case .sunset:
                break
            case .et0_fao_evapotranspiration:
                try prefetchData(raw: .direct_radiation, time: time)
                try prefetchData(raw: .diffuse_radiation, time: time)
                try prefetchData(raw: .temperature_2m, time: time)
                try prefetchData(raw: .relativehumidity_2m, time: time)
                try prefetchData(raw: .wind_u_component_10m, time: time)
                try prefetchData(raw: .wind_v_component_10m, time: time)
            case .snowfall_sum:
                try prefetchData(raw: .precipitation, time: time)
                try prefetchData(raw: .showers, time: time)
                try prefetchData(raw: .rain, time: time)
            case .rain_sum:
                try prefetchData(raw: .rain, time: time)
            case .showers_sum:
                try prefetchData(raw: .showers, time: time)
            }
        }
    }
}
