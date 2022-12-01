import Foundation
import Vapor
import SwiftEccodes
import SwiftPFor2D


typealias CerraHourlyVariable = VariableOrDerived<CerraVariable, CerraVariableDerived>

enum CerraVariableDerived: String, Codable, RawRepresentableString, GenericVariableMixable {
    case apparent_temperature
    case dewpoint_2m
    //case relativehumidity_2m
    //case windspeed_10m
    //case winddirection_10m
    //case windspeed_100m
    //case winddirection_100m
    case vapor_pressure_deficit
    case diffuse_radiation
    case surface_pressure
    case snowfall
    case rain
    case et0_fao_evapotranspiration
    case cloudcover
    case direct_normal_irradiance
    
    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
}

struct CerraReader: GenericReaderDerivedSimple, GenericReaderMixable {
    var reader: GenericReaderCached<CdsDomain, CerraVariable>
    
    typealias Domain = CdsDomain
    
    typealias Variable = CerraVariable
    
    typealias Derived = CerraVariableDerived
    
    func prefetchData(variables: [CerraHourlyVariable], time: TimerangeDt) throws {
        for variable in variables {
            switch variable {
            case .raw(let v):
                try prefetchData(raw: v, time: time)
            case .derived(let v):
                try prefetchData(derived: v, time: time)
            }
        }
    }
    
    func prefetchData(derived: CerraVariableDerived, time: TimerangeDt) throws {
        switch derived {
        //case .windspeed_10m:
        //    try prefetchData(variable: .wind_u_component_10m, time: time)
        //    try prefetchData(variable: .wind_v_component_10m, time: time)
        case .apparent_temperature:
            try prefetchData(raw: .temperature_2m, time: time)
            try prefetchData(raw: .windspeed_10m, time: time)
            try prefetchData(raw: .relativehumidity_2m, time: time)
            try prefetchData(raw: .direct_radiation, time: time)
            try prefetchData(raw: .shortwave_radiation, time: time)
        case .dewpoint_2m:
            try prefetchData(raw: .temperature_2m, time: time)
            try prefetchData(raw: .relativehumidity_2m, time: time)
            /*case .relativehumidity_2m:
            try prefetchData(variable: .temperature_2m, time: time)
            try prefetchData(variable: .dewpoint_2m, time: time)
        case .winddirection_10m:
            try prefetchData(variable: .wind_u_component_10m, time: time)
            try prefetchData(variable: .wind_v_component_10m, time: time)
        case .windspeed_100m:
            try prefetchData(variable: .wind_u_component_100m, time: time)
            try prefetchData(variable: .wind_v_component_100m, time: time)
        case .winddirection_100m:
            try prefetchData(variable: .wind_u_component_100m, time: time)
            try prefetchData(variable: .wind_v_component_100m, time: time)*/
        case .vapor_pressure_deficit:
            try prefetchData(raw: .temperature_2m, time: time)
            try prefetchData(raw: .relativehumidity_2m, time: time)
        case .diffuse_radiation:
            try prefetchData(raw: .shortwave_radiation, time: time)
            try prefetchData(raw: .direct_radiation, time: time)
        case .et0_fao_evapotranspiration:
            try prefetchData(raw: .direct_radiation, time: time)
            try prefetchData(derived: .diffuse_radiation, time: time)
            try prefetchData(raw: .temperature_2m, time: time)
            try prefetchData(raw: .relativehumidity_2m, time: time)
            try prefetchData(raw: .windspeed_10m, time: time)
        case .surface_pressure:
            try prefetchData(raw: .pressure_msl, time: time)
        case .snowfall:
            try prefetchData(raw: .snowfall_water_equivalent, time: time)
        case .cloudcover:
            try prefetchData(raw: .cloudcover_low, time: time)
            try prefetchData(raw: .cloudcover_mid, time: time)
            try prefetchData(raw: .cloudcover_high, time: time)
        case .direct_normal_irradiance:
            try prefetchData(raw: .direct_radiation, time: time)
        case .rain:
            try prefetchData(raw: .precipitation, time: time)
            try prefetchData(raw: .snowfall_water_equivalent, time: time)
        }
    }
    
    func get(variable: CerraHourlyVariable, time: TimerangeDt) throws -> DataAndUnit {
        switch variable {
        case .raw(let variable):
            return try get(raw: variable, time: time)
        case .derived(let variable):
            return try get(derived: variable, time: time)
        }
    }
    
    
    func get(derived: CerraVariableDerived, time: TimerangeDt) throws -> DataAndUnit {
        switch derived {
        /*case .windspeed_10m:
            let u = try get(variable: .wind_u_component_10m, time: time)
            let v = try get(variable: .wind_v_component_10m, time: time)
            let speed = zip(u.data,v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .ms)*/
        case .dewpoint_2m:
            let relhum = try get(raw: .relativehumidity_2m, time: time)
            let temperature = try get(raw: .temperature_2m, time: time)
            return DataAndUnit(zip(temperature.data,relhum.data).map(Meteorology.dewpoint), temperature.unit)
        case .apparent_temperature:
            let windspeed = try get(raw: .windspeed_10m, time: time).data
            let temperature = try get(raw: .temperature_2m, time: time).data
            let relhum = try get(raw: .relativehumidity_2m, time: time).data
            let radiation = try get(raw: .shortwave_radiation, time: time).data
            return DataAndUnit(Meteorology.apparentTemperature(temperature_2m: temperature, relativehumidity_2m: relhum, windspeed_10m: windspeed, shortware_radiation: radiation), .celsius)
            /*case .relativehumidity_2m:
            let temperature = try get(variable: .temperature_2m, time: time).data
            let dew = try get(variable: .dewpoint_2m, time: time).data
            let relativeHumidity = zip(temperature, dew).map(Meteorology.relativeHumidity)
            return DataAndUnit(relativeHumidity, .percent)
        case .winddirection_10m:
            let u = try get(variable: .wind_u_component_10m, time: time).data
            let v = try get(variable: .wind_v_component_10m, time: time).data
            let direction = Meteorology.windirectionFast(u: u, v: v)
            return DataAndUnit(direction, .degreeDirection)
        case .windspeed_100m:
            let u = try get(variable: .wind_u_component_100m, time: time)
            let v = try get(variable: .wind_v_component_100m, time: time)
            let speed = zip(u.data,v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .ms)
        case .winddirection_100m:
            let u = try get(variable: .wind_u_component_100m, time: time).data
            let v = try get(variable: .wind_v_component_100m, time: time).data
            let direction = Meteorology.windirectionFast(u: u, v: v)
            return DataAndUnit(direction, .degreeDirection)*/
        case .vapor_pressure_deficit:
            let temperature = try get(raw: .temperature_2m, time: time).data
            let dewpoint = try get(derived: .dewpoint_2m, time: time).data
            return DataAndUnit(zip(temperature,dewpoint).map(Meteorology.vaporPressureDeficit), .kiloPascal)
        case .et0_fao_evapotranspiration:
            let exrad = Zensun.extraTerrestrialRadiationBackwards(latitude: modelLat, longitude: modelLon, timerange: time)
            let swrad = try get(raw: .shortwave_radiation, time: time).data
            let temperature = try get(raw: .temperature_2m, time: time).data
            let windspeed = try get(raw: .windspeed_10m, time: time).data
            let dewpoint = try get(derived: .dewpoint_2m, time: time).data
            
            let et0 = swrad.indices.map { i in
                return Meteorology.et0Evapotranspiration(temperature2mCelsius: temperature[i], windspeed10mMeterPerSecond: windspeed[i], dewpointCelsius: dewpoint[i], shortwaveRadiationWatts: swrad[i], elevation: self.modelElevation, extraTerrestrialRadiation: exrad[i], dtSeconds: 3600)
            }
            return DataAndUnit(et0, .millimeter)
        case .diffuse_radiation:
            let swrad = try get(raw: .shortwave_radiation, time: time).data
            let direct = try get(raw: .direct_radiation, time: time).data
            let diff = zip(swrad,direct).map(-)
            return DataAndUnit(diff, .wattPerSquareMeter)
        case .surface_pressure:
            let temperature = try get(raw: .temperature_2m, time: time).data
            let pressure = try get(raw: .pressure_msl, time: time)
            return DataAndUnit(Meteorology.surfacePressure(temperature: temperature, pressure: pressure.data, elevation: modelElevation), pressure.unit)
        case .cloudcover:
            let low = try get(raw: .cloudcover_low, time: time).data
            let mid = try get(raw: .cloudcover_mid, time: time).data
            let high = try get(raw: .cloudcover_high, time: time).data
            return DataAndUnit(Meteorology.cloudCoverTotal(low: low, mid: mid, high: high), .percent)
        case .snowfall:
            let snowwater = try get(raw: .snowfall_water_equivalent, time: time).data
            let snowfall = snowwater.map { $0 * 0.7 }
            return DataAndUnit(snowfall, .centimeter)
        case .direct_normal_irradiance:
            let dhi = try get(raw: .direct_radiation, time: time).data
            let dni = Zensun.calculateBackwardsDNI(directRadiation: dhi, latitude: modelLat, longitude: modelLon, timerange: time)
            return DataAndUnit(dni, .wattPerSquareMeter)
        case .rain:
            let snowwater = try get(raw: .snowfall_water_equivalent, time: time)
            let precip = try get(raw: .precipitation, time: time)
            let rain = zip(precip.data, snowwater.data).map({
                return max($0.0-$0.1, 0)
            })
            return DataAndUnit(rain, precip.unit)
        }
    }
}


/// Might be used to decode API queries later
enum CerraVariable: String, CaseIterable, Codable, GenericVariable {
    case temperature_2m
    case windspeed_10m
    case winddirection_10m
    case windspeed_100m
    case winddirection_100m
    case windgusts_10m
    case relativehumidity_2m
    case cloudcover_low
    case cloudcover_mid
    case cloudcover_high
    case pressure_msl
    case snowfall_water_equivalent
    /*case soil_temperature_0_to_7cm  // special dataset now, with very fine grained spacing ~1-4cm
    case soil_temperature_7_to_28cm
    case soil_temperature_28_to_100cm
    case soil_temperature_100_to_255cm
    case soil_moisture_0_to_7cm
    case soil_moisture_7_to_28cm
    case soil_moisture_28_to_100cm
    case soil_moisture_100_to_255cm*/
    case shortwave_radiation
    case precipitation
    case direct_radiation
    
    var isElevationCorrectable: Bool {
        return self == .temperature_2m
    }
    
    var omFileName: String {
        return rawValue
    }
    
    var interpolation: ReaderInterpolation {
        fatalError("Interpolation not required for cerra")
    }
    
    var requiresOffsetCorrectionForMixing: Bool {
         return false
    }
    
    /// Name used to query the ECMWF CDS API via python
    var cdsApiName: String {
        switch self {
        case .windgusts_10m: return "10m_wind_gust_since_previous_post_processing"
        case .relativehumidity_2m: return "2m_relative_humidity"
        case .temperature_2m: return "2m_temperature"
        case .cloudcover_low: return "low_cloud_cover"
        case .cloudcover_mid: return "medium_cloud_cover"
        case .cloudcover_high: return "high_cloud_cover"
        case .pressure_msl: return "mean_sea_level_pressure"
        case .snowfall_water_equivalent: return "snow_fall_water_equivalent"
        case .shortwave_radiation: return "surface_solar_radiation_downwards"
        case .precipitation: return "total_precipitation"
        case .direct_radiation: return "time_integrated_surface_direct_short_wave_radiation_flux"
        case .windspeed_10m: return "10m_wind_speed"
        case .winddirection_10m: return "10m_wind_direction"
        case .windspeed_100m: return "wind_speed"
        case .winddirection_100m: return "wind_direction"
        }
    }
    
    var isAccumulatedSinceModelStart: Bool {
        switch self {
        case .shortwave_radiation:
            fallthrough
        case .direct_radiation:
            fallthrough
        case .precipitation:
            fallthrough
        case .snowfall_water_equivalent:
            return true
        default:
            return false
        }
    }
    
    var hasAnalysis: Bool {
        switch self {
        case .temperature_2m:
            return true
        case .windspeed_10m:
            return true
        case .winddirection_10m:
            return true
        case .windspeed_100m:
            return true
        case .winddirection_100m:
            return true
        case .relativehumidity_2m:
            return true
        case .cloudcover_low:
            return true
        case .cloudcover_mid:
            return true
        case .cloudcover_high:
            return true
        case .pressure_msl:
            return true
        default:
            return false
        }
    }
    
    var isHeightLevel: Bool {
        switch self {
        case .windspeed_100m: fallthrough
        case .winddirection_100m: return true
        default: return false
        }
    }
    
    /// Applied to the netcdf file after reading
    var netCdfScaling: (offest: Double, scalefactor: Double)? {
        switch self {
        case .temperature_2m: return (-273.15, 1) // kelvin to celsius
        case .shortwave_radiation: fallthrough // joules to watt
        case .direct_radiation: return (0, 1/3600)
        default: return nil
        }
    }
    
    /// shortName attribute in GRIB
    var gribShortName: [String] {
        switch self {
        case .windspeed_10m: return ["10si"]
        case .winddirection_10m: return ["10wdir"]
        case .windspeed_100m: return ["ws"]
        case .winddirection_100m: return ["wdir"]
        case .windgusts_10m: return ["10fg", "gust"] // or "gust" on ubuntu 22.04
        case .relativehumidity_2m: return ["2r"]
        case .temperature_2m: return ["2t"]
        case .cloudcover_low: return ["lcc"]
        case .cloudcover_mid: return ["mcc"]
        case .cloudcover_high: return ["hcc"]
        case .pressure_msl: return ["msl"]
        case .snowfall_water_equivalent: return ["sf"]
        case .shortwave_radiation: return ["ssrd"]
        case .precipitation: return ["tp"]
        case .direct_radiation: return ["tidirswrf"]
        }
    }
    
    /// Scalefactor to compress data
    var scalefactor: Float {
        switch self {
        case .cloudcover_low: return 1
        case .cloudcover_mid: return 1
        case .cloudcover_high: return 1
        case .windgusts_10m: return 10
        case .relativehumidity_2m: return 1
        case .temperature_2m: return 20
        case .pressure_msl: return 0.1
        case .snowfall_water_equivalent: return 10
        case .shortwave_radiation: return 1
        case .precipitation: return 10
        case .direct_radiation: return 1
        case .windspeed_10m: return 10
        case .winddirection_10m: return 0.5
        case .windspeed_100m: return 10
        case .winddirection_100m: return 0.5
        }
    }
    
    var unit: SiUnit {
        switch self {
        case .windspeed_10m: fallthrough
        case .windspeed_100m: fallthrough
        case .windgusts_10m: return .ms
        case .winddirection_10m: return .degreeDirection
        case .winddirection_100m: return .degreeDirection
        case .relativehumidity_2m: return .percent
        case .temperature_2m: return .celsius
        case .cloudcover_low: return .percent
        case .cloudcover_mid: return .percent
        case .cloudcover_high: return .percent
        case .pressure_msl: return .pascal
        case .snowfall_water_equivalent: return .millimeter
        case .shortwave_radiation: return .wattPerSquareMeter
        case .precipitation: return .millimeter
        case .direct_radiation: return .wattPerSquareMeter
        }
    }
}

/**
Sources:
 - https://cds.climate.copernicus.eu/cdsapp#!/dataset/reanalysis-cerra-land?tab=form
 - https://cds.climate.copernicus.eu/cdsapp#!/dataset/reanalysis-cerra-single-levels?tab=form
 - https://cds.climate.copernicus.eu/cdsapp#!/dataset/reanalysis-cerra-height-levels?tab=overview
 */
struct DownloadCerraCommand: Command {
    struct Signature: CommandSignature {
        @Option(name: "timeinterval", short: "t", help: "Timeinterval to download with format 20220101-20220131")
        var timeinterval: String?
        
        @Option(name: "year", short: "y", help: "Download one year")
        var year: String?
        
        @Option(name: "stripseaYear", short: "s", help: "strip sea of converted files")
        var stripseaYear: String?
        
        @Option(name: "cdskey", short: "k", help: "CDS API user and key like: 123456:8ec08f...")
        var cdskey: String?
        
        //@Flag(name: "force", short: "f", help: "Force to update given timeinterval, regardless if files could be downloaded")
        //var force: Bool
        
        //@Flag(name: "hourlyfiles", help: "Download hourly files instead of daily files")
        //var hourlyFiles: Bool
        
        /// Get the specified timerange in the command, or use the last 7 days as range
        /*func getTimeinterval() -> TimerangeDt {
            let dt = hourlyFiles ? 3600 : 86400
            if let timeinterval = timeinterval {
                guard timeinterval.count == 17, timeinterval.contains("-") else {
                    fatalError("format looks wrong")
                }
                let start = Timestamp(Int(timeinterval[0..<4])!, Int(timeinterval[4..<6])!, Int(timeinterval[6..<8])!)
                let end = Timestamp(Int(timeinterval[9..<13])!, Int(timeinterval[13..<15])!, Int(timeinterval[15..<17])!).add(86400)
                return TimerangeDt(start: start, to: end, dtSeconds: dt)
            }
            // Cerra has a typical delay of 5 days
            // Per default, check last 14 days for new data. If data is already downloaded, downloading is skipped
            let lastDays = 14
            let time0z = Timestamp.now().with(hour: 0)
            return TimerangeDt(start: time0z.add(lastDays * -86400), to: time0z, dtSeconds: dt)
        }*/
    }

    var help: String {
        "Download CERRA from the ECMWF climate data store and convert"
    }
    
    func stripSea(logger: Logger, readFilePath: String, writeFilePath: String, elevation: [Float]) throws {
        let domain = CdsDomain.cerra
        if FileManager.default.fileExists(atPath: writeFilePath) {
            return
        }
        let read = try OmFileReader(file: readFilePath)
        
        var percent = 0
        try OmFileWriter(dim0: read.dim0, dim1: read.dim1, chunk0: read.chunk0, chunk1: read.chunk1).write(file: writeFilePath, compressionType: .p4nzdec256, scalefactor: read.scalefactor) { dim0 in
            let ratio = Int(Float(dim0) / (Float(read.dim0)) * 100)
            if percent != ratio {
                logger.info("\(ratio) %")
                percent = ratio
            }
            
            let nLocations = 1000 * read.chunk0
            let locationRange = dim0..<min(dim0+nLocations, read.dim0)
            
            try read.willNeed(dim0Slow: locationRange, dim1: 0..<read.dim1)
            var data = try read.read(dim0Slow: locationRange, dim1: nil)
            for loc in locationRange {
                let (lat,lon) = domain.grid.getCoordinates(gridpoint: loc)
                let isNorthRussia = lon >= 43 && lat > 63
                let isNorthCanadaGreenlandAlaska = lat > 66 && lon < -26
                let isAntarctica = lat < -56
                
                if elevation[loc] <= -999 || lat > 72 || isNorthRussia || isNorthCanadaGreenlandAlaska || isAntarctica {
                    for t in 0..<read.dim1 {
                        data[(loc-dim0) * read.dim1 + t] = .nan
                    }
                }
            }
            return ArraySlice(data)
        }
    }
    
    func runStripSea(logger: Logger, year: Int) throws {
        let domain = CdsDomain.cerra
        try FileManager.default.createDirectory(atPath: "\(OpenMeteo.dataDictionary)cerra-no-sea", withIntermediateDirectories: true)
        logger.info("Read elevation")
        let elevation = try OmFileReader(file: domain.surfaceElevationFileOm).readAll()
        
        for variable in CerraVariable.allCases {
            logger.info("Converting variable \(variable)")
            let fullFile = "\(domain.omfileArchive!)\(variable)_\(year).om"
            let strippedFile = "\(OpenMeteo.dataDictionary)cerra-no-sea/\(variable)_\(year).om"
            try stripSea(logger: logger, readFilePath: fullFile, writeFilePath: strippedFile, elevation: elevation)
        }
    }
    
    // Data is stored in one file per hour
    func runYear(logger: Logger, year: Int, cdskey: String) throws {
        let domain = CdsDomain.cerra
        let timeintervalHourly = TimerangeDt(start: Timestamp(year,1,1), to: Timestamp(year+1,1,1), dtSeconds: 3600)
        let timeintervalDaily = TimerangeDt(start: Timestamp(year,1,1), to: Timestamp(year+1,1,1), dtSeconds: 24*3600)
        try downloadDailyFilesCerra(logger: logger, cdskey: cdskey, timeinterval: timeintervalDaily)
        
        let nx = domain.grid.nx // 721
        let ny = domain.grid.ny // 1440
        let nt = timeintervalHourly.count // 8784
        
        try FileManager.default.createDirectory(atPath: domain.omfileArchive!, withIntermediateDirectories: true)
        
        // convert to yearly file
        for variable in CerraVariable.allCases {
            logger.info("Converting variable \(variable)")
            let writeFile = "\(domain.omfileArchive!)\(variable)_\(year).om"
            if FileManager.default.fileExists(atPath: writeFile) {
                continue
            }
            let omFiles = try timeintervalHourly.map { timeinterval -> OmFileReader? in
                let timestampDir = "\(domain.downloadDirectory)\(timeinterval.format_YYYYMMdd)"
                let omFile = "\(timestampDir)/\(variable.rawValue)_\(timeinterval.format_YYYYMMddHH).om"
                if !FileManager.default.fileExists(atPath: omFile) {
                    return nil
                }
                return try OmFileReader(file: omFile)
            }
            var percent = 0
            var looptime = DispatchTime.now()
            // chunk1 must be multiple of 24 hours for deaccumulation
            try OmFileWriter(dim0: ny*nx, dim1: nt, chunk0: 6, chunk1: 45*24).write(file: writeFile, compressionType: .p4nzdec256, scalefactor: variable.scalefactor) { dim0 in
                let ratio = Int(Float(dim0) / (Float(nx*ny)) * 100)
                if percent != ratio {
                    /// time ~4.5 seconds
                    logger.info("\(ratio) %, time per step \(looptime.timeElapsedPretty())")
                    looptime = DispatchTime.now()
                    percent = ratio
                }
                
                /// Process around 20 MB memory at once
                let nLoc = 6 * 100
                let locationRange = dim0..<min(dim0+nLoc, nx*ny)
                
                var fasttime = Array2DFastTime(data: [Float](repeating: .nan, count: nt * locationRange.count), nLocations: locationRange.count, nTime: nt)
                
                for (i, omfile) in omFiles.enumerated() {
                    guard let omfile else {
                        continue
                    }
                    try omfile.willNeed(dim0Slow: 0..<1, dim1: locationRange)
                    let read = try omfile.read(dim0Slow: 0..<1, dim1: locationRange)
                    for l in 0..<locationRange.count {
                        fasttime[l, i] = read[l]
                    }
                }
                if variable.isAccumulatedSinceModelStart {
                    fasttime.deaccumulateOverTime(slidingWidth: 3, slidingOffset: variable.hasAnalysis ? 0 : 1)
                }
                return ArraySlice(fasttime.data)
            }
        }
    }
    
    struct CdsQuery: Encodable {
        let product_type: [String]
        let format = "grib"
        let level_type: String?
        let data_type = "reanalysis"
        let height_level: String?
        let year: String
        let month: String
        let day: [String]
        let leadtime_hour: [String]
        let time: [String] = ["00:00", "03:00", "06:00", "09:00", "12:00", "15:00", "18:00", "21:00"]
        let variable: [String]
    }
    
    /// Dowload CERRA data, use analysis if available, otherwise use forecast
    func downloadDailyFilesCerra(logger: Logger, cdskey: String, timeinterval: TimerangeDt) throws {
        let domain = CdsDomain.cerra
        logger.info("Downloading timerange \(timeinterval.prettyString())")
        
        /// Directory dir, where to place temporary downloaded files
        let downloadDir = domain.downloadDirectory
        try FileManager.default.createDirectory(atPath: downloadDir, withIntermediateDirectories: true)
                
        let variables = CerraVariable.allCases
        
        /// loop over each day, download data and convert it
        let pid = ProcessInfo.processInfo.processIdentifier
        let tempDownloadGribFile = "\(downloadDir)cerradownload_\(pid).grib"
        let tempPythonFile = "\(downloadDir)cerradownload_\(pid).py"
        
        var grib2d = GribArray2D(nx: domain.grid.nx, ny: domain.grid.ny)
        
        let writer = OmFileWriter(dim0: 1, dim1: domain.grid.count, chunk0: 1, chunk1: 600)
        
        func downloadAndConvert(datasetName: String, productType: [String], variables: [CerraVariable], height_level: String?, level_type: String?, year: Int, month: Int, day: Int?, leadtime_hours: [Int]) throws {
            let lastDayInMonth = Timestamp(year, month % 12 + 1, 1).add(-86400).toComponents().day
            let days = day.map{[$0.zeroPadded(len: 2)]} ?? (1...lastDayInMonth).map{$0.zeroPadded(len: 2)}
            
            let YYYYMMdd = "\(year)\(month.zeroPadded(len: 2))\(days[0])"
            if FileManager.default.fileExists(atPath: "\(downloadDir)\(YYYYMMdd)/\(variables[0].rawValue)_\(YYYYMMdd)01.om") {
                logger.info("Already exists \(YYYYMMdd) variable \(variables[0]). Skipping.")
                return
            }
            
            let query = CdsQuery(
                product_type: productType,
                level_type: level_type,
                height_level: height_level,
                year: year.zeroPadded(len: 2),
                month: month.zeroPadded(len: 2),
                day: days,
                leadtime_hour: leadtime_hours.map(String.init),
                variable: variables.map {$0.cdsApiName}
            )
            
            let queryEncoded = String(data: try JSONEncoder().encode(query), encoding: .utf8)!
            
            let json = """
                import cdsapi

                c = cdsapi.Client(url="https://cds.climate.copernicus.eu/api/v2", key="\(cdskey)", verify=True)
                c.retrieve('\(datasetName)',\(queryEncoded),'\(tempDownloadGribFile)')
                """
            
            try json.write(toFile: tempPythonFile, atomically: true, encoding: .utf8)
            try Process.spawn(cmd: "python3", args: [tempPythonFile])
            try SwiftEccodes.iterateMessages(fileName: tempDownloadGribFile, multiSupport: true) { message in
                let shortName = message.get(attribute: "shortName")!
                guard let variable = variables.first(where: {$0.gribShortName.contains(shortName)}) else {
                    fatalError("Could not find \(shortName) in grib")
                }
                
                /// (key: "validityTime", value: "1700")
                let hour = Int(message.get(attribute: "validityTime")!)!/100
                let date = message.get(attribute: "validityDate")!
                logger.info("Converting variable \(variable) \(date) \(hour) \(message.get(attribute: "name")!)")
                //try message.debugGrid(grid: domain.grid)
                
                try grib2d.load(message: message)
                if let scaling = variable.netCdfScaling {
                    grib2d.array.data.multiplyAdd(multiply: Float(scaling.scalefactor), add: Float(scaling.offest))
                }
                
                try FileManager.default.createDirectory(atPath: "\(domain.downloadDirectory)\(date)", withIntermediateDirectories: true)
                let omFile = "\(domain.downloadDirectory)\(date)/\(variable.rawValue)_\(date)\(hour.zeroPadded(len: 2)).om"
                try FileManager.default.removeItemIfExists(at: omFile)
                try writer.write(file: omFile, compressionType: .p4nzdec256, scalefactor: variable.scalefactor, all: grib2d.array.data)
            }
        }
        
        func downloadAndConvertAll(datasetName: String, productType: [String], height_level: String?, year: Int, month: Int, day: Int?, leadtime_hours: [Int]) throws {
         
            // download analysis + forecast hour 1,2
            let variablesAnalysis = variables.filter { $0.hasAnalysis && !$0.isHeightLevel }
            try downloadAndConvert(datasetName: domain.cdsDatasetName, productType: ["analysis", "forecast"], variables: variablesAnalysis, height_level: nil, level_type: "surface_or_atmosphere", year: year, month: month, day: day, leadtime_hours: [1,2])
            
            // download forecast hour 1,2,3 for variables without analysis
            let variablesForecastHour3 = variables.filter { !$0.hasAnalysis && !$0.isHeightLevel }
            try downloadAndConvert(datasetName: domain.cdsDatasetName, productType: ["forecast"], variables: variablesForecastHour3, height_level: nil, level_type: "surface_or_atmosphere", year: year, month: month, day: day, leadtime_hours: [1,2,3])
            
            // download analysis + 2 forecast steps from level 100m
            let variablesHeightLevel = variables.filter { $0.isHeightLevel }
            try downloadAndConvert(datasetName: "reanalysis-cerra-height-levels", productType: ["forecast", "analysis"], variables: variablesHeightLevel, height_level: "100_m", level_type: nil, year: year, month: month, day: day, leadtime_hours: [1,2])
        }
        
        let months = timeinterval.toYearMonth()
        if months.count >= 6 {
            /// Download one month at once
            for date in months {
                logger.info("Downloading year \(date.year) month \(date.month)")
                try downloadAndConvertAll(datasetName: domain.cdsDatasetName, productType: ["analysis", "forecast"], height_level: nil, year: date.year, month: date.month, day: nil, leadtime_hours: [1,2])
            }
        } else {
            for timestamp in timeinterval {
                logger.info("Downloading day \(timestamp.format_YYYYMMdd)")
                let date = timestamp.toComponents()
                try downloadAndConvertAll(datasetName: domain.cdsDatasetName, productType: ["analysis", "forecast"], height_level: nil, year: date.year, month: date.month, day: date.day, leadtime_hours: [1,2])
            }
        }
            
        try FileManager.default.removeItemIfExists(at: tempDownloadGribFile)
        try FileManager.default.removeItemIfExists(at: tempPythonFile)
    }
    
    /// Convert daily compressed files to longer compressed files specified by `Cerra.omFileLength`. E.g. 14 days in one file.
    /*func convertDailyFiles(logger: Logger, timeinterval: TimerangeDt) throws {
        let domain = CdsDomain.cerra
        if timeinterval.count == 0 {
            logger.info("No new timesteps could be downloaded. Nothing to do. Existing")
            return
        }
        
        logger.info("Converting timerange \(timeinterval.prettyString())")
       
        /// Directory dir, where to place temporary downloaded files
        let downloadDir = domain.downloadDirectory
        try FileManager.default.createDirectory(atPath: downloadDir, withIntermediateDirectories: true)
        
        let om = OmFileSplitter(basePath: domain.omfileDirectory, nLocations: domain.grid.count, nTimePerFile: domain.omFileLength, yearlyArchivePath: nil)
        
        let variables = CerraVariable.allCases // [CerraVariable.wind_u_component_10m, .wind_v_component_10m, .wind_u_component_100m, .wind_v_component_100m]
        
        let ntPerFile = timeinterval.dtSeconds == 3600 ? 1 : 24
        
        /// loop over each day convert it
        for variable in variables {
            logger.info("Converting variable \(variable)")
            
            let nt = timeinterval.count * ntPerFile
            let nLoc = domain.grid.count
            
            var fasttime = Array2DFastTime(data: [Float](repeating: .nan, count: nt*nLoc), nLocations: nLoc, nTime: nt)
            
            for (i,timestamp) in timeinterval.enumerated() {
                let timestampDailyHourly = timeinterval.dtSeconds == 3600 ? timestamp.format_YYYYMMddHH : timestamp.format_YYYYMMdd
                logger.info("Reading timestamp \(timestampDailyHourly)")
                let timestampDir = "\(domain.downloadDirectory)\(timestamp.format_YYYYMMdd)"
                let omFile =  "\(timestampDir)/\(variable.rawValue)_\(timestampDailyHourly).om"
                
                guard FileManager.default.fileExists(atPath: omFile) else {
                    continue
                }
                let data = try OmFileReader(file: omFile).readAll()
                let read2d = Array2DFastTime(data: data, nLocations: nLoc, nTime: ntPerFile)
                for l in 0..<nLoc {
                    fasttime[l, i*ntPerFile ..< (i+1)*ntPerFile] = read2d[l, 0..<ntPerFile]
                }
            }
            
            logger.info("Writing \(variable)")
            let ringtime = timeinterval.range.lowerBound.timeIntervalSince1970 / 3600 ..< timeinterval.range.upperBound.timeIntervalSince1970 / 3600
            try om.updateFromTimeOriented(variable: variable.rawValue, array2d: fasttime, ringtime: ringtime, skipFirst: 0, smooth: 0, skipLast: 0, scalefactor: variable.scalefactor)
        }
    }*/
    
    func downloadElevation(logger: Logger, cdskey: String, domain: CdsDomain) throws {
        if FileManager.default.fileExists(atPath: domain.surfaceElevationFileOm) {
            return
        }
        
        let downloadDir = domain.downloadDirectory
        try FileManager.default.createDirectory(atPath: downloadDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(atPath: domain.omfileDirectory, withIntermediateDirectories: true)
        let tempDownloadGribFile = "\(downloadDir)elevation.grib"
                
        if !FileManager.default.fileExists(atPath: tempDownloadGribFile) {
            logger.info("Downloading elevation and sea mask")
            let pyCode = """
                import cdsapi
                c = cdsapi.Client(url="https://cds.climate.copernicus.eu/api/v2", key="\(cdskey)", verify=True)

                c.retrieve(
                    '\(domain.cdsDatasetName)',
                    {
                        'format': 'grib',
                        'variable': [
                            'land_sea_mask', 'orography',
                        ],
                        'data_type': 'reanalysis',
                        'product_type': 'analysis',
                        'level_type': 'surface_or_atmosphere',
                        'year': '2019',
                        'month': '12',
                        'day': '23',
                        'time': '00:00',
                    },
                    '\(tempDownloadGribFile)')
                """
            let tempPythonFile = "\(downloadDir)elevation.py"

            try pyCode.write(toFile: tempPythonFile, atomically: true, encoding: .utf8)
            try Process.spawn(cmd: "python3", args: [tempPythonFile])
        }
        
        logger.info("Converting elevation and sea mask")
        var landmask: [Float]? = nil
        var elevation: [Float]? = nil
        try SwiftEccodes.iterateMessages(fileName: tempDownloadGribFile, multiSupport: true) { message in
            let shortName = message.get(attribute: "shortName")!
            let data = try message.getDouble().map(Float.init)
            switch shortName {
            case "orog":
                elevation = data
            case "lsm":
                landmask = data
            default:
                fatalError("Found \(shortName) in grib")
            }
        }
    
        guard var elevation, let landmask else {
            fatalError("missing elevation in grib")
        }
        
        /*let a1 = Array2DFastSpace(data: elevation, nLocations: domain.grid.count, nTime: 1)
        try a1.writeNetcdf(filename: "\(downloadDir)/elevation_converted.nc", nx: domain.grid.nx, ny: domain.grid.ny)
        let a2 = Array2DFastSpace(data: landmask, nLocations: domain.grid.count, nTime: 1)
        try a2.writeNetcdf(filename: "\(downloadDir)/landmask_converted.nc", nx: domain.grid.nx, ny: domain.grid.ny)*/
        
        // Set all sea grid points to -999
        precondition(elevation.count == landmask.count)
        for i in elevation.indices {
            if landmask[i] < 0.5 {
                elevation[i] = -999
            }
        }
        
        try OmFileWriter(dim0: domain.grid.ny, dim1: domain.grid.nx, chunk0: 20, chunk1: 20).write(file: domain.surfaceElevationFileOm, compressionType: .p4nzdec256, scalefactor: 1, all: elevation)
    }
    
    func run(using context: CommandContext, signature: Signature) throws {
        let logger = context.application.logger
        if let stripseaYear = signature.stripseaYear {
            try runStripSea(logger: logger, year: Int(stripseaYear)!)
            return
        }
        guard let cdskey = signature.cdskey else {
            fatalError("cds key is required")
        }
        //let domain = CdsDomain.cerra
        try downloadElevation(logger: logger, cdskey: cdskey, domain: .cerra)
        
        /// Only download one specified year
        if let yearStr = signature.year {
            if yearStr.contains("-") {
                let split = yearStr.split(separator: "-")
                guard split.count == 2 else {
                    fatalError("year invalid")
                }
                for year in Int(split[0])! ... Int(split[1])! {
                    try runYear(logger: logger, year: year, cdskey: cdskey)
                }
            } else {
                guard let year = Int(yearStr) else {
                    fatalError("Could not convert year to integer")
                }
                try runYear(logger: logger, year: year, cdskey: cdskey)
            }
            return
        }
        
        fatalError("only yearlt download supported")
        
        /// Select the desired timerange, or use last 14 day
        //let timeinterval = signature.getTimeinterval()
        //try downloadDailyFilesCerra(logger: logger, cdskey: cdskey, timeinterval: timeinterval)
        //try convertDailyFiles(logger: logger, timeinterval: timeinterval)
    }
}

