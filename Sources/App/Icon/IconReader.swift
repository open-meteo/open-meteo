import Foundation

typealias IconReader = GenericReader<IconDomains, IconVariable>

typealias IconMixer = GenericReaderMixerCached<IconDomains, IconVariable>

final class GenericReaderMixerCached<Domain: GenericDomain, Variable: GenericVariableMixing> where Variable: Hashable {
    var cache: [Variable: DataAndUnit]
    let mixer: GenericReaderMixer<Domain, Variable>
    
    public init?(domains: [Domain], lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode) throws {
        guard let mixer = try GenericReaderMixer<Domain, Variable>(domains: domains, lat: lat, lon: lon, elevation: elevation, mode: mode) else {
            return nil
        }
        self.mixer = mixer
        self.cache = .init()
    }
    
    func get(variable: Variable, time: TimerangeDt) throws -> DataAndUnit {
        if let value = cache[variable] {
            return value
        }
        let data = try mixer.get(variable: variable, time: time)
        cache[variable] = data
        return data
    }
}

extension IconMixer {
    func getDaily(variable: DailyWeatherVariable, params: ForecastapiQuery, time timeDaily: TimerangeDt) throws -> DataAndUnit {
        let time = timeDaily.with(dtSeconds: mixer.reader.first!.domain.dtSeconds)
        switch variable {
        case .temperature_2m_max:
            let data = try get(variable: .temperature_2m, time: time).conertAndRound(params: params)
            return DataAndUnit(data.data.max(by: 24), data.unit)
        case .temperature_2m_min:
            let data = try get(variable: .temperature_2m, time: time).conertAndRound(params: params)
            return DataAndUnit(data.data.min(by: 24), data.unit)
        case .apparent_temperature_max:
            let data = try get(variable: .apparent_temperature, time: time).conertAndRound(params: params)
            return DataAndUnit(data.data.max(by: 24), data.unit)
        case .apparent_temperature_min:
            let data = try get(variable: .apparent_temperature, time: time).conertAndRound(params: params)
            return DataAndUnit(data.data.min(by: 24), data.unit)
        case .precipitation_sum:
            // rounding is required, becuse floating point addition results in uneven numbers
            let data = try get(variable: .precipitation, time: time).conertAndRound(params: params)
            return DataAndUnit(data.data.sum(by: 24).round(digits: 2), data.unit)
        case .weathercode:
            // not 100% corrct
            let data = try get(variable: .weathercode, time: time).conertAndRound(params: params)
            return DataAndUnit(data.data.max(by: 24), data.unit)
        case .shortwave_radiation_sum:
            let data = try get(variable: .shortwave_radiation, time: time).conertAndRound(params: params)
            // 3600s only for hourly data of source
            return DataAndUnit(data.data.map({$0*0.0036}).sum(by: 24).round(digits: 2), .megaJoulesPerSquareMeter)
        case .windspeed_10m_max:
            let data = try get(variable: .windspeed_10m, time: time).conertAndRound(params: params)
            return DataAndUnit(data.data.max(by: 24), data.unit)
        case .windgusts_10m_max:
            let data = try get(variable: .windgusts_10m, time: time).conertAndRound(params: params)
            return DataAndUnit(data.data.max(by: 24), data.unit)
        case .winddirection_10m_dominant:
            // vector addition
            let u = try get(variable: .u_10m, time: time).data.sum(by: 24)
            let v = try get(variable: .v_10m, time: time).data.sum(by: 24)
            let direction = Meteorology.windirectionFast(u: u, v: v)
            return DataAndUnit(direction, .degreeDirection)
        //case .sunshine_hours:
            /// TODO need sunrise and set time for correct numbers
            //fatalError()
        case .precipitation_hours:
            let data = try get(variable: .precipitation, time: time).conertAndRound(params: params)
            return DataAndUnit(data.data.map({$0 > 0.001 ? 1 : 0}).sum(by: 24), .hours)
        case .sunrise:
            return DataAndUnit([],.hours)
        case .sunset:
            return DataAndUnit([],.hours)
        case .et0_fao_evapotranspiration:
            let data = try get(variable: .et0_fao_evapotranspiration, time: time).conertAndRound(params: params)
            return DataAndUnit(data.data.sum(by: 24).round(digits: 2), data.unit)
        case .snowfall_sum:
            let data = try get(variable: .snowfall, time: time).conertAndRound(params: params)
            return DataAndUnit(data.data.sum(by: 24).round(digits: 2), data.unit)
        case .rain_sum:
            let data = try get(variable: .rain, time: time).conertAndRound(params: params)
            return DataAndUnit(data.data.sum(by: 24).round(digits: 2), data.unit)
        case .showers_sum:
            let data = try get(variable: .showers, time: time).conertAndRound(params: params)
            return DataAndUnit(data.data.sum(by: 24).round(digits: 2), data.unit)
        }
    }
    
    func get(variable: WeatherVariable, time: TimerangeDt) throws -> DataAndUnit {
        switch variable {
        case .raw(let variable):
            return try get(variable: variable, time: time)
        case .derived(let variable):
            return try get(variable: variable, time: time)
        }
    }
    
    func prefetchData(variable: Variable, time: TimerangeDt) throws {
        try mixer.prefetchData(variable: variable, time: time)
    }
    
    func prefetchData(variables: [DailyWeatherVariable], time timeDaily: TimerangeDt) throws {
        let time = timeDaily.with(dtSeconds: mixer.reader.first!.domain.dtSeconds)
        for variable in variables {
            switch variable {
            case .temperature_2m_max:
                fallthrough
            case .temperature_2m_min:
                try prefetchData(variable: .temperature_2m, time: time)
            case .apparent_temperature_max:
                fallthrough
            case .apparent_temperature_min:
                try prefetchData(variable: .temperature_2m, time: time)
                try prefetchData(variable: .u_10m, time: time)
                try prefetchData(variable: .v_10m, time: time)
                try prefetchData(variable: .relativehumidity_2m, time: time)
                try prefetchData(variable: .direct_radiation, time: time)
                try prefetchData(variable: .diffuse_radiation, time: time)
            case .precipitation_sum:
                try prefetchData(variable: .precipitation, time: time)
            case .weathercode:
                try prefetchData(variable: .weathercode, time: time)
            case .shortwave_radiation_sum:
                try prefetchData(variable: .direct_radiation, time: time)
                try prefetchData(variable: .diffuse_radiation, time: time)
            case .windspeed_10m_max:
                try prefetchData(variable: .u_10m, time: time)
                try prefetchData(variable: .v_10m, time: time)
            case .windgusts_10m_max:
                try prefetchData(variable: .windgusts_10m, time: time)
            case .winddirection_10m_dominant:
                try prefetchData(variable: .u_10m, time: time)
                try prefetchData(variable: .v_10m, time: time)
            case .precipitation_hours:
                try prefetchData(variable: .precipitation, time: time)
            case .sunrise:
                break
            case .sunset:
                break
            case .et0_fao_evapotranspiration:
                try prefetchData(variable: .direct_radiation, time: time)
                try prefetchData(variable: .diffuse_radiation, time: time)
                try prefetchData(variable: .temperature_2m, time: time)
                try prefetchData(variable: .relativehumidity_2m, time: time)
                try prefetchData(variable: .u_10m, time: time)
                try prefetchData(variable: .v_10m, time: time)
            case .snowfall_sum:
                try prefetchData(variable: .precipitation, time: time)
                try prefetchData(variable: .showers, time: time)
                try prefetchData(variable: .rain, time: time)
            case .rain_sum:
                try prefetchData(variable: .rain, time: time)
            case .showers_sum:
                try prefetchData(variable: .showers, time: time)
            }
        }
    }
    
    func prefetchData(variables: [WeatherVariable], time: TimerangeDt) throws {
        for variable in variables {
            switch variable {
            case .raw(let variable):
                try prefetchData(variable: variable, time: time)
            case .derived(let variable):
                switch variable {
                case .apparent_temperature:
                    try prefetchData(variable: .temperature_2m, time: time)
                    try prefetchData(variable: .u_10m, time: time)
                    try prefetchData(variable: .v_10m, time: time)
                    try prefetchData(variable: .relativehumidity_2m, time: time)
                    try prefetchData(variable: .direct_radiation, time: time)
                    try prefetchData(variable: .diffuse_radiation, time: time)
                case .relativehumitidy_2m:
                    try prefetchData(variable: .relativehumidity_2m, time: time)
                case .windspeed_10m:
                    try prefetchData(variable: .u_10m, time: time)
                    try prefetchData(variable: .v_10m, time: time)
                case .winddirection_10m:
                    try prefetchData(variable: .u_10m, time: time)
                    try prefetchData(variable: .v_10m, time: time)
                case .windspeed_80m:
                    try prefetchData(variable: .u_80m, time: time)
                    try prefetchData(variable: .v_80m, time: time)
                case .winddirection_80m:
                    try prefetchData(variable: .u_80m, time: time)
                    try prefetchData(variable: .v_80m, time: time)
                case .windspeed_120m:
                    try prefetchData(variable: .u_120m, time: time)
                    try prefetchData(variable: .v_120m, time: time)
                case .winddirection_120m:
                    try prefetchData(variable: .u_120m, time: time)
                    try prefetchData(variable: .v_120m, time: time)
                case .windspeed_180m:
                    try prefetchData(variable: .u_180m, time: time)
                    try prefetchData(variable: .v_180m, time: time)
                case .winddirection_180m:
                    try prefetchData(variable: .u_180m, time: time)
                    try prefetchData(variable: .v_180m, time: time)
                case .snow_height:
                    try prefetchData(variable: .snow_depth, time: time)
                case .shortwave_radiation:
                    try prefetchData(variable: .direct_radiation, time: time)
                    try prefetchData(variable: .diffuse_radiation, time: time)
                case .direct_normal_irradiance:
                    try prefetchData(variable: .direct_radiation, time: time)
                case .evapotranspiration:
                    try prefetchData(variable: .latent_heatflux, time: time)
                case .vapor_pressure_deficit:
                    try prefetchData(variable: .temperature_2m, time: time)
                    try prefetchData(variable: .dewpoint_2m, time: time)
                case .et0_fao_evapotranspiration:
                    try prefetchData(variable: .direct_radiation, time: time)
                    try prefetchData(variable: .diffuse_radiation, time: time)
                    try prefetchData(variable: .temperature_2m, time: time)
                    try prefetchData(variable: .dewpoint_2m, time: time)
                    try prefetchData(variable: .u_10m, time: time)
                    try prefetchData(variable: .v_10m, time: time)
                case .snowfall:
                    try prefetchData(variable: .snowfall_water_equivalent, time: time)
                    try prefetchData(variable: .snowfall_convective_water_equivalent, time: time)
                case .surface_pressure:
                    try prefetchData(variable: .pressure_msl, time: time)
                    try prefetchData(variable: .temperature_2m, time: time)
                case .terrestrial_radiation:
                    break
                case .terrestrial_radiation_instant:
                    break
                case .shortwave_radiation_instant:
                    try prefetchData(variable: .direct_radiation, time: time)
                    try prefetchData(variable: .diffuse_radiation, time: time)
                case .diffuse_radiation_instant:
                    try prefetchData(variable: .diffuse_radiation, time: time)
                case .direct_radiation_instant:
                    try prefetchData(variable: .direct_radiation, time: time)
                case .direct_normal_irradiance_instant:
                    try prefetchData(variable: .direct_radiation, time: time)
                }
            }
        }
    }
    
    
    func get(variable: IconVariableDerived, time: TimerangeDt) throws -> DataAndUnit {
        // NOTE caching U/V or temp/rh variables might be required
        
        switch variable {
        case .windspeed_10m:
            let u = try get(variable: .u_10m, time: time).data
            let v = try get(variable: .v_10m, time: time).data
            let speed = zip(u,v).map(Meteorology.windspeed)
            return DataAndUnit(speed, .ms)
        case .winddirection_10m:
            let u = try get(variable: .u_10m, time: time).data
            let v = try get(variable: .v_10m, time: time).data
            let direction = Meteorology.windirectionFast(u: u, v: v)
            return DataAndUnit(direction, .degreeDirection)
        case .windspeed_80m:
            let u = try get(variable: .u_80m, time: time).data
            let v = try get(variable: .v_80m, time: time).data
            let speed = zip(u,v).map(Meteorology.windspeed)
            return DataAndUnit(speed, .ms)
        case .winddirection_80m:
            let u = try get(variable: .u_80m, time: time).data
            let v = try get(variable: .v_80m, time: time).data
            let direction = Meteorology.windirectionFast(u: u, v: v)
            return DataAndUnit(direction, .degreeDirection)
        case .windspeed_120m:
            let u = try get(variable: .u_120m, time: time).data
            let v = try get(variable: .v_120m, time: time).data
            let speed = zip(u,v).map(Meteorology.windspeed)
            return DataAndUnit(speed, .ms)
        case .winddirection_120m:
            let u = try get(variable: .u_120m, time: time).data
            let v = try get(variable: .v_120m, time: time).data
            let direction = Meteorology.windirectionFast(u: u, v: v)
            return DataAndUnit(direction, .degreeDirection)
        case .windspeed_180m:
            let u = try get(variable: .u_180m, time: time).data
            let v = try get(variable: .v_180m, time: time).data
            let speed = zip(u,v).map(Meteorology.windspeed)
            return DataAndUnit(speed, .ms)
        case .winddirection_180m:
            let u = try get(variable: .u_180m, time: time).data
            let v = try get(variable: .v_180m, time: time).data
            let direction = Meteorology.windirectionFast(u: u, v: v)
            return DataAndUnit(direction, .degreeDirection)
        case .snow_height:
            return try get(variable: .snow_depth, time: time)
        case .apparent_temperature:
            let windspeed = try get(variable: .windspeed_10m, time: time).data
            let temperature = try get(variable: .temperature_2m, time: time).data
            let relhum = try get(variable: .relativehumidity_2m, time: time).data
            let radiation = try get(variable: .shortwave_radiation, time: time).data
            return DataAndUnit(Meteorology.apparentTemperature(temperature_2m: temperature, relativehumidity_2m: relhum, windspeed_10m: windspeed, shortware_radiation: radiation), .celsius)
        case .shortwave_radiation:
            let direct = try get(variable: .direct_radiation, time: time).data
            let diffuse = try get(variable: .diffuse_radiation, time: time).data
            let total = zip(direct, diffuse).map(+)
            return DataAndUnit(total, .wattPerSquareMeter)
        case .evapotranspiration:
            let latent = try get(variable: .latent_heatflux, time: time).data
            let evapotranspiration = latent.map(Meteorology.evapotranspiration)
            return DataAndUnit(evapotranspiration, .millimeter)
        case .vapor_pressure_deficit:
            let temperature = try get(variable: .temperature_2m, time: time).data
            let dewpoint = try get(variable: .dewpoint_2m, time: time).data
            return DataAndUnit(zip(temperature,dewpoint).map(Meteorology.vaporPressureDeficit), .kiloPascal)
        case .direct_normal_irradiance:
            let dhi = try get(variable: .direct_radiation, time: time).data
            let dni = Zensun.calculateBackwardsDNI(directRadiation: dhi, latitude: mixer.modelLat, longitude: mixer.modelLon, timerange: time)
            return DataAndUnit(dni, .wattPerSquareMeter)
        case .et0_fao_evapotranspiration:
            let exrad = Zensun.extraTerrestrialRadiationBackwards(latitude: mixer.modelLat, longitude: mixer.modelLon, timerange: time)
            let swrad = try get(variable: .shortwave_radiation, time: time).data
            let temperature = try get(variable: .temperature_2m, time: time).data
            let windspeed = try get(variable: .windspeed_10m, time: time).data
            let dewpoint = try get(variable: .dewpoint_2m, time: time).data
            
            let et0 = swrad.indices.map { i in
                return Meteorology.et0Evapotranspiration(temperature2mCelsius: temperature[i], windspeed10mMeterPerSecond: windspeed[i], dewpointCelsius: dewpoint[i], shortwaveRadiationWatts: swrad[i], elevation: mixer.targetElevation, extraTerrestrialRadiation: exrad[i], dtSeconds: 3600)
            }
            return DataAndUnit(et0, .millimeter)
        case .snowfall:
            let snow_gsp = try get(variable: .snowfall_water_equivalent, time: time).data
            let snow_con = try get(variable: .snowfall_convective_water_equivalent, time: time).data
            let snowfall = zip(snow_gsp, snow_con).map({
                ($0 + $1) * 0.7
            })
            return DataAndUnit(snowfall, SiUnit.centimeter)
        case .relativehumitidy_2m:
            return try get(variable: .relativehumidity_2m, time: time)
        case .surface_pressure:
            let temperature = try get(variable: .temperature_2m, time: time).data
            let pressure = try get(variable: .pressure_msl, time: time)
            return DataAndUnit(Meteorology.surfacePressure(temperature: temperature, pressure: pressure.data, elevation: mixer.targetElevation), pressure.unit)
        case .terrestrial_radiation:
            /// Use center averaged
            let solar = Zensun.extraTerrestrialRadiationBackwards(latitude: mixer.modelLat, longitude: mixer.modelLon, timerange: time)
            return DataAndUnit(solar, .wattPerSquareMeter)
        case .terrestrial_radiation_instant:
            /// Use center averaged
            let solar = Zensun.extraTerrestrialRadiationInstant(latitude: mixer.modelLat, longitude: mixer.modelLon, timerange: time)
            return DataAndUnit(solar, .wattPerSquareMeter)
        case .shortwave_radiation_instant:
            let sw = try get(variable: .shortwave_radiation, time: time)
            let factor = Zensun.backwardsAveragedToInstantFactor(time: time, latitude: mixer.modelLat, longitude: mixer.modelLon)
            return DataAndUnit(zip(sw.data, factor).map(*), sw.unit)
        case .diffuse_radiation_instant:
            let diff = try get(variable: .diffuse_radiation, time: time)
            let factor = Zensun.backwardsAveragedToInstantFactor(time: time, latitude: mixer.modelLat, longitude: mixer.modelLon)
            return DataAndUnit(zip(diff.data, factor).map(*), diff.unit)
        case .direct_radiation_instant:
            let direct = try get(variable: .direct_radiation, time: time)
            let factor = Zensun.backwardsAveragedToInstantFactor(time: time, latitude: mixer.modelLat, longitude: mixer.modelLon)
            return DataAndUnit(zip(direct.data, factor).map(*), direct.unit)
        case .direct_normal_irradiance_instant:
            let direct = try get(variable: .direct_radiation_instant, time: time)
            let dni = Zensun.calculateInstantDNI(directRadiation: direct.data, latitude: mixer.modelLat, longitude: mixer.modelLon, timerange: time)
            return DataAndUnit(dni, direct.unit)
            
            // because DNI is divided by cos(zenith), the approach below was not work
            //let dni = try get(variable: .direct_normal_irradiance)
            //let factor = Zensun.backwardsAveragedToInstantFactor(time: mixer.time, latitude: mixer.modelLat, longitude: mixer.modelLon)
            //return DataAndUnit(zip(dni.data, factor).map(*), dni.unit)
        }
    }
}
