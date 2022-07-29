import Foundation

final class IconMixer {
    let reader: [IconReader]
    let modelElevation: Float
    let modelLat: Float
    let modelLon: Float
    let time: TimerangeDt
    var cache: [IconVariable: [Float]]
    
    public init(lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode, time: Range<Timestamp>) throws {
        let time = time.range(dtSeconds: 3600)
        reader = try IconDomains.allCases.compactMap {
            try IconReader(domain: $0, lat: lat, lon: lon, elevation: elevation, mode: mode, time: time)
        }
        let highresModel = reader.last!
        self.time = time
        modelElevation = elevation //highresModel.modelElevation
        modelLat = highresModel.modelLat
        modelLon = highresModel.modelLon
        cache = .init()
    }
    
    func get(iconVariable: IconVariable) throws -> DataAndUnit {
        if let value = cache[iconVariable] {
            return DataAndUnit(value, iconVariable.unit)
        }
        
        // Read data from available domains
        let datas = try reader.map {
            try $0.get(iconVariable: iconVariable, targetAsl: modelElevation)
        }
        // icon global
        var first = datas.first!
        
        if iconVariable.requiresOffsetCorrectionForMixing {
            // For soil moisture, we have to correct offsets at model mixing
            // The first value stays the start value, afterwards only deltas are used
            // In the end, the lower-resolution model, just gets corrected by the offset to a higher resolution domain
            // An alternative implementation would be to check exactly at model mixing offsets and correct it there
            for x in (1..<first.count).reversed() {
                first[x] = first[x-1] - first[x]
            }
            // integrate other models, but use convert to delta
            for d in datas.dropFirst() {
                for x in d.indices.reversed() {
                    if d[x].isNaN {
                        continue
                    }
                    if x > 0 {
                        first[x] = d[x-1] - d[x]
                    } else {
                        first[x] = d[x]
                    }
                }
            }
            // undo delta operation
            for x in 1..<first.count {
                first[x] = first[x-1] - first[x]
            }
        } else {
            // default case, just place new data in 1:1
            for d in datas.dropFirst() {
                for x in d.indices {
                    if d[x].isNaN {
                        continue
                    }
                    first[x] = d[x]
                }
            }
        }
        cache[iconVariable] = first
        return DataAndUnit(first, iconVariable.unit)
    }
    
    func getDaily(variable: DailyWeatherVariable, params: ForecastapiQuery) throws -> DataAndUnit {
        switch variable {
        case .temperature_2m_max:
            let data = try get(iconVariable: .temperature_2m).conertAndRound(params: params)
            return DataAndUnit(data.data.max(by: 24), data.unit)
        case .temperature_2m_min:
            let data = try get(iconVariable: .temperature_2m).conertAndRound(params: params)
            return DataAndUnit(data.data.min(by: 24), data.unit)
        case .apparent_temperature_max:
            let data = try get(variable: .apparent_temperature).conertAndRound(params: params)
            return DataAndUnit(data.data.max(by: 24), data.unit)
        case .apparent_temperature_min:
            let data = try get(variable: .apparent_temperature).conertAndRound(params: params)
            return DataAndUnit(data.data.min(by: 24), data.unit)
        case .precipitation_sum:
            // rounding is required, becuse floating point addition results in uneven numbers
            let data = try get(iconVariable: .precipitation).conertAndRound(params: params)
            return DataAndUnit(data.data.sum(by: 24).round(digits: 2), data.unit)
        case .weathercode:
            // not 100% corrct
            let data = try get(iconVariable: .weathercode).conertAndRound(params: params)
            return DataAndUnit(data.data.max(by: 24), data.unit)
        case .shortwave_radiation_sum:
            let data = try get(variable: .shortwave_radiation).conertAndRound(params: params)
            // 3600s only for hourly data of source
            return DataAndUnit(data.data.map({$0*0.0036}).sum(by: 24).round(digits: 2), .megaJoulesPerSquareMeter)
        case .windspeed_10m_max:
            let data = try get(variable: .windspeed_10m).conertAndRound(params: params)
            return DataAndUnit(data.data.max(by: 24), data.unit)
        case .windgusts_10m_max:
            let data = try get(iconVariable: .windgusts_10m).conertAndRound(params: params)
            return DataAndUnit(data.data.max(by: 24), data.unit)
        case .winddirection_10m_dominant:
            // vector addition
            let u = try get(iconVariable: .u_10m).data.sum(by: 24)
            let v = try get(iconVariable: .v_10m).data.sum(by: 24)
            let direction = Meteorology.windirectionFast(u: u, v: v)
            return DataAndUnit(direction, .degreeDirection)
        //case .sunshine_hours:
            /// TODO need sunrise and set time for correct numbers
            //fatalError()
        case .precipitation_hours:
            let data = try get(iconVariable: .precipitation).conertAndRound(params: params)
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
            let data = try get(iconVariable: .rain).conertAndRound(params: params)
            return DataAndUnit(data.data.sum(by: 24).round(digits: 2), data.unit)
        case .showers_sum:
            let data = try get(iconVariable: .showers).conertAndRound(params: params)
            return DataAndUnit(data.data.sum(by: 24).round(digits: 2), data.unit)
        }
    }
    
    func get(variable: WeatherVariable) throws -> DataAndUnit {
        switch variable {
        case .raw(let variable):
            return try get(iconVariable: variable)
        case .derived(let variable):
            return try get(variable: variable)
        }
    }
    
    func prefetchData(iconVariable: IconVariable) throws {
        for reader in reader {
            try reader.prefetchData(iconVariable: iconVariable)
        }
    }
    
    func prefetchData(variables: [DailyWeatherVariable]) throws {
        for variable in variables {
            switch variable {
            case .temperature_2m_max:
                fallthrough
            case .temperature_2m_min:
                try prefetchData(iconVariable: .temperature_2m)
            case .apparent_temperature_max:
                fallthrough
            case .apparent_temperature_min:
                try prefetchData(iconVariable: .temperature_2m)
                try prefetchData(iconVariable: .u_10m)
                try prefetchData(iconVariable: .v_10m)
                try prefetchData(iconVariable: .relativehumidity_2m)
                try prefetchData(iconVariable: .direct_radiation)
                try prefetchData(iconVariable: .diffuse_radiation)
            case .precipitation_sum:
                try prefetchData(iconVariable: .precipitation)
            case .weathercode:
                try prefetchData(iconVariable: .weathercode)
            case .shortwave_radiation_sum:
                try prefetchData(iconVariable: .direct_radiation)
                try prefetchData(iconVariable: .diffuse_radiation)
            case .windspeed_10m_max:
                try prefetchData(iconVariable: .u_10m)
                try prefetchData(iconVariable: .v_10m)
            case .windgusts_10m_max:
                try prefetchData(iconVariable: .windgusts_10m)
            case .winddirection_10m_dominant:
                try prefetchData(iconVariable: .u_10m)
                try prefetchData(iconVariable: .v_10m)
            case .precipitation_hours:
                try prefetchData(iconVariable: .precipitation)
            case .sunrise:
                break
            case .sunset:
                break
            case .et0_fao_evapotranspiration:
                try prefetchData(iconVariable: .direct_radiation)
                try prefetchData(iconVariable: .diffuse_radiation)
                try prefetchData(iconVariable: .temperature_2m)
                try prefetchData(iconVariable: .relativehumidity_2m)
                try prefetchData(iconVariable: .u_10m)
                try prefetchData(iconVariable: .v_10m)
            case .snowfall_sum:
                try prefetchData(iconVariable: .precipitation)
                try prefetchData(iconVariable: .showers)
                try prefetchData(iconVariable: .rain)
            case .rain_sum:
                try prefetchData(iconVariable: .rain)
            case .showers_sum:
                try prefetchData(iconVariable: .showers)
            }
        }
    }
    
    func prefetchData(variables: [WeatherVariable]) throws {
        for variable in variables {
            switch variable {
            case .raw(let variable):
                try prefetchData(iconVariable: variable)
            case .derived(let variable):
                switch variable {
                case .apparent_temperature:
                    try prefetchData(iconVariable: .temperature_2m)
                    try prefetchData(iconVariable: .u_10m)
                    try prefetchData(iconVariable: .v_10m)
                    try prefetchData(iconVariable: .relativehumidity_2m)
                    try prefetchData(iconVariable: .direct_radiation)
                    try prefetchData(iconVariable: .diffuse_radiation)
                case .relativehumitidy_2m:
                    try prefetchData(iconVariable: .relativehumidity_2m)
                case .windspeed_10m:
                    try prefetchData(iconVariable: .u_10m)
                    try prefetchData(iconVariable: .v_10m)
                case .winddirection_10m:
                    try prefetchData(iconVariable: .u_10m)
                    try prefetchData(iconVariable: .v_10m)
                case .windspeed_80m:
                    try prefetchData(iconVariable: .u_80m)
                    try prefetchData(iconVariable: .v_80m)
                case .winddirection_80m:
                    try prefetchData(iconVariable: .u_80m)
                    try prefetchData(iconVariable: .v_80m)
                case .windspeed_120m:
                    try prefetchData(iconVariable: .u_120m)
                    try prefetchData(iconVariable: .v_120m)
                case .winddirection_120m:
                    try prefetchData(iconVariable: .u_120m)
                    try prefetchData(iconVariable: .v_120m)
                case .windspeed_180m:
                    try prefetchData(iconVariable: .u_180m)
                    try prefetchData(iconVariable: .v_180m)
                case .winddirection_180m:
                    try prefetchData(iconVariable: .u_180m)
                    try prefetchData(iconVariable: .v_180m)
                case .snow_height:
                    try prefetchData(iconVariable: .snow_depth)
                case .shortwave_radiation:
                    try prefetchData(iconVariable: .direct_radiation)
                    try prefetchData(iconVariable: .diffuse_radiation)
                case .direct_normal_irradiance:
                    try prefetchData(iconVariable: .direct_radiation)
                case .evapotranspiration:
                    try prefetchData(iconVariable: .latent_heatflux)
                case .vapor_pressure_deficit:
                    try prefetchData(iconVariable: .temperature_2m)
                    try prefetchData(iconVariable: .dewpoint_2m)
                case .et0_fao_evapotranspiration:
                    try prefetchData(iconVariable: .direct_radiation)
                    try prefetchData(iconVariable: .diffuse_radiation)
                    try prefetchData(iconVariable: .temperature_2m)
                    try prefetchData(iconVariable: .dewpoint_2m)
                    try prefetchData(iconVariable: .u_10m)
                    try prefetchData(iconVariable: .v_10m)
                case .snowfall:
                    try prefetchData(iconVariable: .snowfall_water_equivalent)
                    try prefetchData(iconVariable: .snowfall_convective_water_equivalent)
                case .surface_pressure:
                    try prefetchData(iconVariable: .pressure_msl)
                    try prefetchData(iconVariable: .temperature_2m)
                }
            }
        }
    }
    
    
    func get(variable: IconVariableDerived) throws -> DataAndUnit {
        // NOTE caching U/V or temp/rh variables might be required
        
        switch variable {
        case .windspeed_10m:
            let u = try get(iconVariable: .u_10m).data
            let v = try get(iconVariable: .v_10m).data
            let speed = zip(u,v).map(Meteorology.windspeed)
            return DataAndUnit(speed, .ms)
        case .winddirection_10m:
            let u = try get(iconVariable: .u_10m).data
            let v = try get(iconVariable: .v_10m).data
            let direction = Meteorology.windirectionFast(u: u, v: v)
            return DataAndUnit(direction, .degreeDirection)
        case .windspeed_80m:
            let u = try get(iconVariable: .u_80m).data
            let v = try get(iconVariable: .v_80m).data
            let speed = zip(u,v).map(Meteorology.windspeed)
            return DataAndUnit(speed, .ms)
        case .winddirection_80m:
            let u = try get(iconVariable: .u_80m).data
            let v = try get(iconVariable: .v_80m).data
            let direction = Meteorology.windirectionFast(u: u, v: v)
            return DataAndUnit(direction, .degreeDirection)
        case .windspeed_120m:
            let u = try get(iconVariable: .u_120m).data
            let v = try get(iconVariable: .v_120m).data
            let speed = zip(u,v).map(Meteorology.windspeed)
            return DataAndUnit(speed, .ms)
        case .winddirection_120m:
            let u = try get(iconVariable: .u_120m).data
            let v = try get(iconVariable: .v_120m).data
            let direction = Meteorology.windirectionFast(u: u, v: v)
            return DataAndUnit(direction, .degreeDirection)
        case .windspeed_180m:
            let u = try get(iconVariable: .u_180m).data
            let v = try get(iconVariable: .v_180m).data
            let speed = zip(u,v).map(Meteorology.windspeed)
            return DataAndUnit(speed, .ms)
        case .winddirection_180m:
            let u = try get(iconVariable: .u_180m).data
            let v = try get(iconVariable: .v_180m).data
            let direction = Meteorology.windirectionFast(u: u, v: v)
            return DataAndUnit(direction, .degreeDirection)
        case .snow_height:
            return try get(iconVariable: .snow_depth)
        case .apparent_temperature:
            let windspeed = try get(variable: .windspeed_10m).data
            let temperature = try get(iconVariable: .temperature_2m).data
            let relhum = try get(iconVariable: .relativehumidity_2m).data
            let radiation = try get(variable: .shortwave_radiation).data
            return DataAndUnit(Meteorology.apparentTemperature(temperature_2m: temperature, relativehumidity_2m: relhum, windspeed_10m: windspeed, shortware_radiation: radiation), .celsius)
        case .shortwave_radiation:
            let direct = try get(iconVariable: .direct_radiation).data
            let diffuse = try get(iconVariable: .diffuse_radiation).data
            let total = zip(direct, diffuse).map(+)
            return DataAndUnit(total, .wattPerSquareMeter)
        case .evapotranspiration:
            let latent = try get(iconVariable: .latent_heatflux).data
            let evapotranspiration = latent.map(Meteorology.evapotranspiration)
            return DataAndUnit(evapotranspiration, .millimeter)
        case .vapor_pressure_deficit:
            let temperature = try get(iconVariable: .temperature_2m).data
            let dewpoint = try get(iconVariable: .dewpoint_2m).data
            return DataAndUnit(zip(temperature,dewpoint).map(Meteorology.vaporPressureDeficit), .kiloPascal)
        case .direct_normal_irradiance:
            let dhi = try get(iconVariable: .direct_radiation).data
            let dni = Zensun.caluclateBackwardsDNI(directRadiation: dhi, latitude: modelLat, longitude: modelLon, startTime: time.range.lowerBound, dtSeconds: time.dtSeconds)
            return DataAndUnit(dni, .wattPerSquareMeter)
        case .et0_fao_evapotranspiration:
            let exrad = Meteorology.extraTerrestrialRadiationBackwards(latitude: modelLat, longitude: modelLon, timerange: time)
            let swrad = try get(variable: .shortwave_radiation).data
            let temperature = try get(iconVariable: .temperature_2m).data
            let windspeed = try get(variable: .windspeed_10m).data
            let dewpoint = try get(iconVariable: .dewpoint_2m).data
            
            let et0 = swrad.indices.map { i in
                return Meteorology.et0Evapotranspiration(temperature2mCelsius: temperature[i], windspeed10mMeterPerSecond: windspeed[i], dewpointCelsius: dewpoint[i], shortwaveRadiationWatts: swrad[i], elevation: self.modelElevation, extraTerrestrialRadiation: exrad[i], dtSeconds: 3600)
            }
            return DataAndUnit(et0, .millimeter)
        case .snowfall:
            let snow_gsp = try get(iconVariable: .snowfall_water_equivalent).data
            let snow_con = try get(iconVariable: .snowfall_convective_water_equivalent).data
            let snowfall = zip(snow_gsp, snow_con).map({
                ($0 + $1) * 0.7
            })
            return DataAndUnit(snowfall, SiUnit.centimeter)
        case .relativehumitidy_2m:
            return try get(iconVariable: .relativehumidity_2m)
        case .surface_pressure:
            let temperature = try get(iconVariable: .temperature_2m).data
            let pressure = try get(iconVariable: .pressure_msl)
            return DataAndUnit(Meteorology.surfacePressure(temperature: temperature, pressure: pressure.data, elevation: modelElevation), pressure.unit)
        }
    }
}

struct IconReader {
    let domain: IconDomain
    
    /// Grid index in data files
    let position: Int
    //let timeIndices: Range<Int>
    let time: TimerangeDt
    
    /// Elevstion of the grid point
    let modelElevation: Float
    let modelLat: Float
    let modelLon: Float
    
    /// If set, use new data files
    let omFileSplitter: OmFileSplitter
    
    /// Will shrink time according to ring time
    public init?(domain: IconDomains, lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode, time: TimerangeDt) throws {
        // check if coordinates are in domain, otherwise return nil
        guard let gridpoint = try domain.grid.findPoint(lat: lat, lon: lon, elevation: elevation, elevationFile: domain.instance.elevationFile, mode: mode) else {
            return nil
        }
        self.domain = domain.instance
        self.position = gridpoint.gridpoint
        //let runTime = self.domain.getRun()
        //let commonTime = time.range.clamped(to: runTime)
        self.time = time
        
        // sea grid points are set to -999
        self.modelElevation = gridpoint.gridElevation
        
        omFileSplitter = OmFileSplitter(basePath: domain.omfileDirectory, nLocations: domain.grid.count, nTimePerFile: domain.omFileLength, yearlyArchivePath: nil)
        
        (modelLat, modelLon) = domain.grid.getCoordinates(gridpoint: gridpoint.gridpoint)
    }
    
    func prefetchData(iconVariable: IconVariable) throws {
        try omFileSplitter.willNeed(variable: iconVariable.dwdVariableName, location: position, time: time)
    }
    
    func get(iconVariable: IconVariable, targetAsl: Float) throws -> [Float] {
        // TODO this float array could be reused... e.g. allocate one array per instance
        // OR use one array to merge all domains already into the same array
        var data = try omFileSplitter.read(variable: iconVariable.dwdVariableName, location: position, time: time)
        
        if iconVariable == .temperature_2m || iconVariable == .dewpoint_2m {
            for i in data.indices {
                // correct temperature by 0.65° per 100 m elevation
                data[i] += (modelElevation - targetAsl) * 0.0065
            }
        }
        return data
    }
}
