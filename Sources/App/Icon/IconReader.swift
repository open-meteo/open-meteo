import Foundation

typealias IconReader = GenericReader<IconDomains, IconVariable>

typealias IconMixer = GenericReaderMixerCached<IconDomains, IconVariable>

final class GenericReaderMixerCached<Domain: GenericDomain, Variable: GenericVariableMixing> where Variable: Hashable {
    var cache: [Variable: DataAndUnit]
    let mixer: GenericReaderMixer<Domain, Variable>
    
    public init?(domains: [Domain], lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode, time: TimerangeDt) throws {
        guard let mixer = try GenericReaderMixer<Domain, Variable>(domains: domains, lat: lat, lon: lon, elevation: elevation, mode: mode, time: time) else {
            return nil
        }
        self.mixer = mixer
        self.cache = .init()
    }
    
    func get(variable: Variable) throws -> DataAndUnit {
        if let value = cache[variable] {
            return value
        }
        let data = try mixer.get(variable: variable)
        cache[variable] = data
        return data
    }
}

extension IconMixer {
    func getDaily(variable: DailyWeatherVariable, params: ForecastapiQuery) throws -> DataAndUnit {
        switch variable {
        case .temperature_2m_max:
            let data = try get(variable: .temperature_2m).conertAndRound(params: params)
            return DataAndUnit(data.data.max(by: 24), data.unit)
        case .temperature_2m_min:
            let data = try get(variable: .temperature_2m).conertAndRound(params: params)
            return DataAndUnit(data.data.min(by: 24), data.unit)
        case .apparent_temperature_max:
            let data = try get(variable: .apparent_temperature).conertAndRound(params: params)
            return DataAndUnit(data.data.max(by: 24), data.unit)
        case .apparent_temperature_min:
            let data = try get(variable: .apparent_temperature).conertAndRound(params: params)
            return DataAndUnit(data.data.min(by: 24), data.unit)
        case .precipitation_sum:
            // rounding is required, becuse floating point addition results in uneven numbers
            let data = try get(variable: .precipitation).conertAndRound(params: params)
            return DataAndUnit(data.data.sum(by: 24).round(digits: 2), data.unit)
        case .weathercode:
            // not 100% corrct
            let data = try get(variable: .weathercode).conertAndRound(params: params)
            return DataAndUnit(data.data.max(by: 24), data.unit)
        case .shortwave_radiation_sum:
            let data = try get(variable: .shortwave_radiation).conertAndRound(params: params)
            // 3600s only for hourly data of source
            return DataAndUnit(data.data.map({$0*0.0036}).sum(by: 24).round(digits: 2), .megaJoulesPerSquareMeter)
        case .windspeed_10m_max:
            let data = try get(variable: .windspeed_10m).conertAndRound(params: params)
            return DataAndUnit(data.data.max(by: 24), data.unit)
        case .windgusts_10m_max:
            let data = try get(variable: .windgusts_10m).conertAndRound(params: params)
            return DataAndUnit(data.data.max(by: 24), data.unit)
        case .winddirection_10m_dominant:
            // vector addition
            let u = try get(variable: .u_10m).data.sum(by: 24)
            let v = try get(variable: .v_10m).data.sum(by: 24)
            let direction = Meteorology.windirectionFast(u: u, v: v)
            return DataAndUnit(direction, .degreeDirection)
        //case .sunshine_hours:
            /// TODO need sunrise and set time for correct numbers
            //fatalError()
        case .precipitation_hours:
            let data = try get(variable: .precipitation).conertAndRound(params: params)
            return DataAndUnit(data.data.map({$0 > 0.001 ? 1 : 0}).sum(by: 24), .hours)
        case .sunrise:
            return DataAndUnit([],.hours)
        case .sunset:
            return DataAndUnit([],.hours)
        case .et0_fao_evapotranspiration:
            let data = try get(variable: .et0_fao_evapotranspiration).conertAndRound(params: params)
            return DataAndUnit(data.data.sum(by: 24).round(digits: 2), data.unit)
        case .snowfall_sum:
            let data = try get(variable: .snowfall).conertAndRound(params: params)
            return DataAndUnit(data.data.sum(by: 24).round(digits: 2), data.unit)
        case .rain_sum:
            let data = try get(variable: .rain).conertAndRound(params: params)
            return DataAndUnit(data.data.sum(by: 24).round(digits: 2), data.unit)
        case .showers_sum:
            let data = try get(variable: .showers).conertAndRound(params: params)
            return DataAndUnit(data.data.sum(by: 24).round(digits: 2), data.unit)
        }
    }
    
    func get(variable: WeatherVariable) throws -> DataAndUnit {
        switch variable {
        case .raw(let variable):
            return try get(variable: variable)
        case .derived(let variable):
            return try get(variable: variable)
        }
    }
    
    func prefetchData(variable: Variable) throws {
        try mixer.prefetchData(variable: variable)
    }
    
    func prefetchData(variables: [DailyWeatherVariable]) throws {
        for variable in variables {
            switch variable {
            case .temperature_2m_max:
                fallthrough
            case .temperature_2m_min:
                try prefetchData(variable: .temperature_2m)
            case .apparent_temperature_max:
                fallthrough
            case .apparent_temperature_min:
                try prefetchData(variable: .temperature_2m)
                try prefetchData(variable: .u_10m)
                try prefetchData(variable: .v_10m)
                try prefetchData(variable: .relativehumidity_2m)
                try prefetchData(variable: .direct_radiation)
                try prefetchData(variable: .diffuse_radiation)
            case .precipitation_sum:
                try prefetchData(variable: .precipitation)
            case .weathercode:
                try prefetchData(variable: .weathercode)
            case .shortwave_radiation_sum:
                try prefetchData(variable: .direct_radiation)
                try prefetchData(variable: .diffuse_radiation)
            case .windspeed_10m_max:
                try prefetchData(variable: .u_10m)
                try prefetchData(variable: .v_10m)
            case .windgusts_10m_max:
                try prefetchData(variable: .windgusts_10m)
            case .winddirection_10m_dominant:
                try prefetchData(variable: .u_10m)
                try prefetchData(variable: .v_10m)
            case .precipitation_hours:
                try prefetchData(variable: .precipitation)
            case .sunrise:
                break
            case .sunset:
                break
            case .et0_fao_evapotranspiration:
                try prefetchData(variable: .direct_radiation)
                try prefetchData(variable: .diffuse_radiation)
                try prefetchData(variable: .temperature_2m)
                try prefetchData(variable: .relativehumidity_2m)
                try prefetchData(variable: .u_10m)
                try prefetchData(variable: .v_10m)
            case .snowfall_sum:
                try prefetchData(variable: .precipitation)
                try prefetchData(variable: .showers)
                try prefetchData(variable: .rain)
            case .rain_sum:
                try prefetchData(variable: .rain)
            case .showers_sum:
                try prefetchData(variable: .showers)
            }
        }
    }
    
    func prefetchData(variables: [WeatherVariable]) throws {
        for variable in variables {
            switch variable {
            case .raw(let variable):
                try prefetchData(variable: variable)
            case .derived(let variable):
                switch variable {
                case .apparent_temperature:
                    try prefetchData(variable: .temperature_2m)
                    try prefetchData(variable: .u_10m)
                    try prefetchData(variable: .v_10m)
                    try prefetchData(variable: .relativehumidity_2m)
                    try prefetchData(variable: .direct_radiation)
                    try prefetchData(variable: .diffuse_radiation)
                case .relativehumitidy_2m:
                    try prefetchData(variable: .relativehumidity_2m)
                case .windspeed_10m:
                    try prefetchData(variable: .u_10m)
                    try prefetchData(variable: .v_10m)
                case .winddirection_10m:
                    try prefetchData(variable: .u_10m)
                    try prefetchData(variable: .v_10m)
                case .windspeed_80m:
                    try prefetchData(variable: .u_80m)
                    try prefetchData(variable: .v_80m)
                case .winddirection_80m:
                    try prefetchData(variable: .u_80m)
                    try prefetchData(variable: .v_80m)
                case .windspeed_120m:
                    try prefetchData(variable: .u_120m)
                    try prefetchData(variable: .v_120m)
                case .winddirection_120m:
                    try prefetchData(variable: .u_120m)
                    try prefetchData(variable: .v_120m)
                case .windspeed_180m:
                    try prefetchData(variable: .u_180m)
                    try prefetchData(variable: .v_180m)
                case .winddirection_180m:
                    try prefetchData(variable: .u_180m)
                    try prefetchData(variable: .v_180m)
                case .snow_height:
                    try prefetchData(variable: .snow_depth)
                case .shortwave_radiation:
                    try prefetchData(variable: .direct_radiation)
                    try prefetchData(variable: .diffuse_radiation)
                case .direct_normal_irradiance:
                    try prefetchData(variable: .direct_radiation)
                case .evapotranspiration:
                    try prefetchData(variable: .latent_heatflux)
                case .vapor_pressure_deficit:
                    try prefetchData(variable: .temperature_2m)
                    try prefetchData(variable: .dewpoint_2m)
                case .et0_fao_evapotranspiration:
                    try prefetchData(variable: .direct_radiation)
                    try prefetchData(variable: .diffuse_radiation)
                    try prefetchData(variable: .temperature_2m)
                    try prefetchData(variable: .dewpoint_2m)
                    try prefetchData(variable: .u_10m)
                    try prefetchData(variable: .v_10m)
                case .snowfall:
                    try prefetchData(variable: .snowfall_water_equivalent)
                    try prefetchData(variable: .snowfall_convective_water_equivalent)
                case .surface_pressure:
                    try prefetchData(variable: .pressure_msl)
                    try prefetchData(variable: .temperature_2m)
                }
            }
        }
    }
    
    
    func get(variable: IconVariableDerived) throws -> DataAndUnit {
        // NOTE caching U/V or temp/rh variables might be required
        
        switch variable {
        case .windspeed_10m:
            let u = try get(variable: .u_10m).data
            let v = try get(variable: .v_10m).data
            let speed = zip(u,v).map(Meteorology.windspeed)
            return DataAndUnit(speed, .ms)
        case .winddirection_10m:
            let u = try get(variable: .u_10m).data
            let v = try get(variable: .v_10m).data
            let direction = Meteorology.windirectionFast(u: u, v: v)
            return DataAndUnit(direction, .degreeDirection)
        case .windspeed_80m:
            let u = try get(variable: .u_80m).data
            let v = try get(variable: .v_80m).data
            let speed = zip(u,v).map(Meteorology.windspeed)
            return DataAndUnit(speed, .ms)
        case .winddirection_80m:
            let u = try get(variable: .u_80m).data
            let v = try get(variable: .v_80m).data
            let direction = Meteorology.windirectionFast(u: u, v: v)
            return DataAndUnit(direction, .degreeDirection)
        case .windspeed_120m:
            let u = try get(variable: .u_120m).data
            let v = try get(variable: .v_120m).data
            let speed = zip(u,v).map(Meteorology.windspeed)
            return DataAndUnit(speed, .ms)
        case .winddirection_120m:
            let u = try get(variable: .u_120m).data
            let v = try get(variable: .v_120m).data
            let direction = Meteorology.windirectionFast(u: u, v: v)
            return DataAndUnit(direction, .degreeDirection)
        case .windspeed_180m:
            let u = try get(variable: .u_180m).data
            let v = try get(variable: .v_180m).data
            let speed = zip(u,v).map(Meteorology.windspeed)
            return DataAndUnit(speed, .ms)
        case .winddirection_180m:
            let u = try get(variable: .u_180m).data
            let v = try get(variable: .v_180m).data
            let direction = Meteorology.windirectionFast(u: u, v: v)
            return DataAndUnit(direction, .degreeDirection)
        case .snow_height:
            return try get(variable: .snow_depth)
        case .apparent_temperature:
            let windspeed = try get(variable: .windspeed_10m).data
            let temperature = try get(variable: .temperature_2m).data
            let relhum = try get(variable: .relativehumidity_2m).data
            let radiation = try get(variable: .shortwave_radiation).data
            return DataAndUnit(Meteorology.apparentTemperature(temperature_2m: temperature, relativehumidity_2m: relhum, windspeed_10m: windspeed, shortware_radiation: radiation), .celsius)
        case .shortwave_radiation:
            let direct = try get(variable: .direct_radiation).data
            let diffuse = try get(variable: .diffuse_radiation).data
            let total = zip(direct, diffuse).map(+)
            return DataAndUnit(total, .wattPerSquareMeter)
        case .evapotranspiration:
            let latent = try get(variable: .latent_heatflux).data
            let evapotranspiration = latent.map(Meteorology.evapotranspiration)
            return DataAndUnit(evapotranspiration, .millimeter)
        case .vapor_pressure_deficit:
            let temperature = try get(variable: .temperature_2m).data
            let dewpoint = try get(variable: .dewpoint_2m).data
            return DataAndUnit(zip(temperature,dewpoint).map(Meteorology.vaporPressureDeficit), .kiloPascal)
        case .direct_normal_irradiance:
            let dhi = try get(variable: .direct_radiation).data
            let dni = Zensun.caluclateBackwardsDNI(directRadiation: dhi, latitude: mixer.modelLat, longitude: mixer.modelLon, startTime: mixer.time.range.lowerBound, dtSeconds: mixer.time.dtSeconds)
            return DataAndUnit(dni, .wattPerSquareMeter)
        case .et0_fao_evapotranspiration:
            let exrad = Meteorology.extraTerrestrialRadiationBackwards(latitude: mixer.modelLat, longitude: mixer.modelLon, timerange: mixer.time)
            let swrad = try get(variable: .shortwave_radiation).data
            let temperature = try get(variable: .temperature_2m).data
            let windspeed = try get(variable: .windspeed_10m).data
            let dewpoint = try get(variable: .dewpoint_2m).data
            
            let et0 = swrad.indices.map { i in
                return Meteorology.et0Evapotranspiration(temperature2mCelsius: temperature[i], windspeed10mMeterPerSecond: windspeed[i], dewpointCelsius: dewpoint[i], shortwaveRadiationWatts: swrad[i], elevation: mixer.targetElevation, extraTerrestrialRadiation: exrad[i], dtSeconds: 3600)
            }
            return DataAndUnit(et0, .millimeter)
        case .snowfall:
            let snow_gsp = try get(variable: .snowfall_water_equivalent).data
            let snow_con = try get(variable: .snowfall_convective_water_equivalent).data
            let snowfall = zip(snow_gsp, snow_con).map({
                ($0 + $1) * 0.7
            })
            return DataAndUnit(snowfall, SiUnit.centimeter)
        case .relativehumitidy_2m:
            return try get(variable: .relativehumidity_2m)
        case .surface_pressure:
            let temperature = try get(variable: .temperature_2m).data
            let pressure = try get(variable: .pressure_msl)
            return DataAndUnit(Meteorology.surfacePressure(temperature: temperature, pressure: pressure.data, elevation: mixer.targetElevation), pressure.unit)
        }
    }
}

