import Foundation
import SwiftEccodes
import Vapor
import SwiftNetCDF
import SwiftPFor2D


enum CdsDomain: String, GenericDomain {
    case era5
    case era5_land
    case cerra
    
    var dtSeconds: Int {
        return 3600
    }
    
    var elevationFile: OmFileReader<MmapFile>? {
        switch self {
        case .era5:
            return Self.era5ElevationFile
        case .era5_land:
            return Self.era5LandElevationFile
        case .cerra:
            return Self.cerraElevationFile
        }
        
    }
    
    var cdsDatasetName: String {
        switch self {
        case .era5:
            return "reanalysis-era5-single-levels"
        case .era5_land:
            return "reanalysis-era5-land"
        case .cerra:
            return "reanalysis-cerra-single-levels"
        }
    }
    
    private static var era5ElevationFile = try? OmFileReader(file: Self.era5.surfaceElevationFileOm)
    private static var era5LandElevationFile = try? OmFileReader(file: Self.era5_land.surfaceElevationFileOm)
    private static var cerraElevationFile = try? OmFileReader(file: Self.cerra.surfaceElevationFileOm)
    
    /// Filename of the surface elevation file
    var surfaceElevationFileOm: String {
        "\(omfileDirectory)HSURF.om"
    }
    
    var downloadDirectory: String {
        return "\(OpenMeteo.dataDictionary)download-\(rawValue)/"
    }
    
    var omfileDirectory: String {
        return "\(OpenMeteo.dataDictionary)omfile-\(rawValue)//"
    }
    
    var omfileArchive: String? {
        return "\(OpenMeteo.dataDictionary)yearly-\(rawValue)//"
    }
    
    /// Use store 14 days per om file
    var omFileLength: Int {
        // 24 hours over 21 days = 504 timesteps per file
        // Afterwards the om compressor will combine 6 locations to one chunks
        // 6 * 504 = 3024 values per compressed chunk
        // In case for a 1 year API call, around 51 kb will have to be decompressed with 34 IO operations
        return 24 * 21
    }
    
    var grid: Gridable {
        switch self {
        case .era5:
            return RegularGrid(nx: 1440, ny: 721, latMin: -90, lonMin: -180, dx: 0.25, dy: 0.25)
        case .era5_land:
            return RegularGrid(nx: 3600, ny: 1801, latMin: -90, lonMin: -180, dx: 0.1, dy: 0.1)
        case .cerra:
            return ProjectionGrid(nx: 1069, ny: 1069, latitude: 20.29228...63.769516, longitude: -17.485962...74.10509, projection: LambertConformalConicProjection(λ0: 8, ϕ0: 50, ϕ1: 50, ϕ2: 50))
        }
    }
}

protocol CdsVariableDownloadable: GenericVariable {
    var isAccumulatedSinceModelStart: Bool { get }
    var hasAnalysis: Bool { get }
}

/// Might be used to decode API queries later
enum Era5Variable: String, CaseIterable, Codable, CdsVariableDownloadable {
    case temperature_2m
    case wind_u_component_100m
    case wind_v_component_100m
    case wind_u_component_10m
    case wind_v_component_10m
    case windgusts_10m
    case dewpoint_2m
    case cloudcover_low
    case cloudcover_mid
    case cloudcover_high
    case pressure_msl
    case snowfall_water_equivalent
    case soil_temperature_0_to_7cm
    case soil_temperature_7_to_28cm
    case soil_temperature_28_to_100cm
    case soil_temperature_100_to_255cm
    case soil_moisture_0_to_7cm
    case soil_moisture_7_to_28cm
    case soil_moisture_28_to_100cm
    case soil_moisture_100_to_255cm
    case shortwave_radiation
    case precipitation
    case direct_radiation
    
    var isElevationCorrectable: Bool {
        return self == .temperature_2m || self == .dewpoint_2m
    }
    
    var omFileName: String {
        return rawValue
    }
    
    var requiresOffsetCorrectionForMixing: Bool {
         return false
    }
    
    var interpolation: ReaderInterpolation {
        fatalError("Interpolation not required for era5")
    }
    
    func availableForDomain(domain: CdsDomain) -> Bool {
        // Note: ERA5-Land wind, pressure, snowfall, radiation and precipitation are only linearly interpolated from ERA5
        if domain == .era5_land {
            switch self {
            case .temperature_2m:
                fallthrough
            case .dewpoint_2m:
                fallthrough
            case .soil_temperature_0_to_7cm:
                fallthrough
            case .soil_temperature_7_to_28cm:
                fallthrough
            case .soil_temperature_28_to_100cm:
                fallthrough
            case .soil_temperature_100_to_255cm:
                fallthrough
            case .soil_moisture_0_to_7cm:
                fallthrough
            case .soil_moisture_7_to_28cm:
                fallthrough
            case .soil_moisture_28_to_100cm:
                fallthrough
            case .soil_moisture_100_to_255cm:
                return true
            default: return false
            }
        }
        return true
    }
    
    var isAccumulatedSinceModelStart: Bool {
        return false
    }
    
    var hasAnalysis: Bool {
        return false
    }
    
    /// Name used to query the ECMWF CDS API via python
    var cdsApiName: String {
        switch self {
        case .wind_u_component_100m: return "100m_u_component_of_wind"
        case .wind_v_component_100m: return "100m_v_component_of_wind"
        case .wind_u_component_10m: return "10m_u_component_of_wind"
        case .wind_v_component_10m: return "10m_v_component_of_wind"
        case .windgusts_10m: return "instantaneous_10m_wind_gust"
        case .dewpoint_2m: return "2m_dewpoint_temperature"
        case .temperature_2m: return "2m_temperature"
        case .cloudcover_low: return "low_cloud_cover"
        case .cloudcover_mid: return "medium_cloud_cover"
        case .cloudcover_high: return "high_cloud_cover"
        case .pressure_msl: return "mean_sea_level_pressure"
        case .snowfall_water_equivalent: return "snowfall"
        case .soil_temperature_0_to_7cm: return "soil_temperature_level_1"
        case .soil_temperature_7_to_28cm: return "soil_temperature_level_2"
        case .soil_temperature_28_to_100cm: return "soil_temperature_level_3"
        case .soil_temperature_100_to_255cm: return "soil_temperature_level_4"
        case .shortwave_radiation: return "surface_solar_radiation_downwards"
        case .precipitation: return "total_precipitation"
        case .direct_radiation: return "total_sky_direct_solar_radiation_at_surface"
        case .soil_moisture_0_to_7cm: return "volumetric_soil_water_layer_1"
        case .soil_moisture_7_to_28cm: return "volumetric_soil_water_layer_2"
        case .soil_moisture_28_to_100cm: return "volumetric_soil_water_layer_3"
        case .soil_moisture_100_to_255cm: return "volumetric_soil_water_layer_4"
        }
    }
    
    /// Applied to the netcdf file after reading
    var netCdfScaling: (offest: Double, scalefactor: Double)? {
        switch self {
        case .temperature_2m: return (-273.15, 1) // kelvin to celsius
        case .dewpoint_2m: return (-273.15, 1)
        case .cloudcover_low: return (0, 100) // fraction to percent
        case .cloudcover_mid: return (0, 100)
        case .cloudcover_high: return (0, 100)
        case .pressure_msl: return (0, 1) // keep in Pa (not hPa)
        case .snowfall_water_equivalent: return (0, 1000) // meter to millimeter
        case .soil_temperature_0_to_7cm: return (-273.15, 1) // kelvin to celsius
        case .soil_temperature_7_to_28cm: return (-273.15, 1)
        case .soil_temperature_28_to_100cm: return (-273.15, 1)
        case .soil_temperature_100_to_255cm: return (-273.15, 1)
        case .shortwave_radiation: return (0, 1/3600) // joules to watt
        case .precipitation: return (0, 1000) // meter to millimeter
        case .direct_radiation: return (0, 1/3600)
        default: return nil
        }
    }
    
    /// shortName attribute in GRIB
    var gribShortName: [String] {
        switch self {
        case .windgusts_10m: return ["10fg", "gust"] // or "gust" on ubuntu 22.04
        case .temperature_2m: return ["2t"]
        case .cloudcover_low: return ["lcc"]
        case .cloudcover_mid: return ["mcc"]
        case .cloudcover_high: return ["hcc"]
        case .pressure_msl: return ["msl"]
        case .snowfall_water_equivalent: return ["sf"]
        case .shortwave_radiation: return ["ssrd"]
        case .precipitation: return ["tp"]
        case .direct_radiation: return ["tidirswrf"]
        case .wind_u_component_100m: return ["100u"]
        case .wind_v_component_100m: return ["100v"]
        case .wind_u_component_10m: return ["10u"]
        case .wind_v_component_10m: return ["10v"]
        case .dewpoint_2m: return ["2d"]
        case .soil_temperature_0_to_7cm: return ["stl1"]
        case .soil_temperature_7_to_28cm: return ["stl2"]
        case .soil_temperature_28_to_100cm: return ["stl3"]
        case .soil_temperature_100_to_255cm: return ["stl4"]
        case .soil_moisture_0_to_7cm: return ["swvl1"]
        case .soil_moisture_7_to_28cm: return ["swvl2"]
        case .soil_moisture_28_to_100cm: return ["swvl3"]
        case .soil_moisture_100_to_255cm: return ["swvl4"]
        }
    }
    
    /// Name in the resulting netCdf file from CDS API
    var netCdfName: String {
        switch self {
        case .wind_u_component_100m: return "v100"
        case .wind_v_component_100m: return "u100"
        case .wind_u_component_10m: return "v10"
        case .wind_v_component_10m: return "u10"
        case .windgusts_10m: return "i10fg"
        case .dewpoint_2m: return "d2m"
        case .temperature_2m: return "t2m"
        case .cloudcover_low: return "lcc"
        case .cloudcover_mid: return "mcc"
        case .cloudcover_high: return "hcc"
        case .pressure_msl: return "msl"
        case .snowfall_water_equivalent: return "sf"
        case .soil_temperature_0_to_7cm: return "stl1"
        case .soil_temperature_7_to_28cm: return "stl2"
        case .soil_temperature_28_to_100cm: return "stl3"
        case .soil_temperature_100_to_255cm: return "stl4"
        case .shortwave_radiation: return "ssrd"
        case .precipitation: return "tp"
        case .direct_radiation: return "fdir"
        case .soil_moisture_0_to_7cm: return "swvl1"
        case .soil_moisture_7_to_28cm: return "swvl2"
        case .soil_moisture_28_to_100cm: return "swvl3"
        case .soil_moisture_100_to_255cm: return "swvl4"
        }
    }
    
    /// Scalefactor to compress data
    var scalefactor: Float {
        switch self {
        case .wind_u_component_100m: return 10
        case .wind_v_component_100m: return 10
        case .wind_u_component_10m: return 10
        case .wind_v_component_10m: return 10
        case .cloudcover_low: return 1
        case .cloudcover_mid: return 1
        case .cloudcover_high: return 1
        case .windgusts_10m: return 10
        case .dewpoint_2m: return 20
        case .temperature_2m: return 20
        case .pressure_msl: return 0.1
        case .snowfall_water_equivalent: return 10
        case .soil_temperature_0_to_7cm: return 20
        case .soil_temperature_7_to_28cm: return 20
        case .soil_temperature_28_to_100cm: return 20
        case .soil_temperature_100_to_255cm: return 20
        case .shortwave_radiation: return 1
        case .precipitation: return 10
        case .direct_radiation: return 1
        case .soil_moisture_0_to_7cm: return 1000
        case .soil_moisture_7_to_28cm: return 1000
        case .soil_moisture_28_to_100cm: return 1000
        case .soil_moisture_100_to_255cm: return 1000
        }
    }
    
    var unit: SiUnit {
        switch self {
        case .wind_u_component_100m: fallthrough
        case .wind_v_component_100m: fallthrough
        case .wind_u_component_10m: fallthrough
        case .wind_v_component_10m: fallthrough
        case .windgusts_10m: return .ms
        case .dewpoint_2m: return .celsius
        case .temperature_2m: return .celsius
        case .cloudcover_low: return .percent
        case .cloudcover_mid: return .percent
        case .cloudcover_high: return .percent
        case .pressure_msl: return .pascal
        case .snowfall_water_equivalent: return .millimeter
        case .soil_temperature_0_to_7cm: return .celsius
        case .soil_temperature_7_to_28cm: return .celsius
        case .soil_temperature_28_to_100cm: return .celsius
        case .soil_temperature_100_to_255cm: return .celsius
        case .shortwave_radiation: return .wattPerSquareMeter
        case .precipitation: return .millimeter
        case .direct_radiation: return .wattPerSquareMeter
        case .soil_moisture_0_to_7cm: return .qubicMeterPerQubicMeter
        case .soil_moisture_7_to_28cm: return .qubicMeterPerQubicMeter
        case .soil_moisture_28_to_100cm: return .qubicMeterPerQubicMeter
        case .soil_moisture_100_to_255cm: return .qubicMeterPerQubicMeter
        }
    }
}

struct DownloadEra5Command: Command {
    struct Signature: CommandSignature {
        @Option(name: "timeinterval", short: "t", help: "Timeinterval to download with format 20220101-20220131")
        var timeinterval: String?
        
        @Option(name: "year", short: "y", help: "Download one year")
        var year: String?
        
        @Option(name: "domain", short: "d", help: "Which domain to use")
        var domain: String?
        
        @Option(name: "stripseaYear", short: "s", help: "strip sea of converted files")
        var stripseaYear: String?
        
        @Option(name: "cdskey", short: "k", help: "CDS API user and key like: 123456:8ec08f...")
        var cdskey: String?
        
        @Flag(name: "force", short: "f", help: "Force to update given timeinterval, regardless if files could be downloaded")
        var force: Bool
        
        @Flag(name: "hourlyfiles", help: "Download hourly files instead of daily files")
        var hourlyFiles: Bool
        
        /// Get the specified timerange in the command, or use the last 7 days as range
        func getTimeinterval() -> TimerangeDt {
            let dt = hourlyFiles ? 3600 : 86400
            if let timeinterval = timeinterval {
                guard timeinterval.count == 17, timeinterval.contains("-") else {
                    fatalError("format looks wrong")
                }
                let start = Timestamp(Int(timeinterval[0..<4])!, Int(timeinterval[4..<6])!, Int(timeinterval[6..<8])!)
                let end = Timestamp(Int(timeinterval[9..<13])!, Int(timeinterval[13..<15])!, Int(timeinterval[15..<17])!).add(86400)
                return TimerangeDt(start: start, to: end, dtSeconds: dt)
            }
            // Era5 has a typical delay of 5 days
            // Per default, check last 14 days for new data. If data is already downloaded, downloading is skipped
            let lastDays = 14
            let time0z = Timestamp.now().with(hour: 0)
            return TimerangeDt(start: time0z.add(lastDays * -86400), to: time0z, dtSeconds: dt)
        }
    }

    var help: String {
        "Download ERA5 from the ECMWF climate data store and convert"
    }
    
    func run(using context: CommandContext, signature: Signature) throws {
        let logger = context.application.logger
        
        let domain = signature.domain.flatMap(CdsDomain.init) ?? .era5
        
        if let stripseaYear = signature.stripseaYear {
            try runStripSea(logger: logger, year: Int(stripseaYear)!)
            return
        }
        guard let cdskey = signature.cdskey else {
            fatalError("cds key is required")
        }
        /// Make sure elevation information is present. Otherwise download it
        if domain != .era5_land {
            // TODO land/sea mask for era5 land
            try downloadElevation(logger: logger, cdskey: cdskey, domain: domain)
        }
        
        /// Only download one specified year
        if let yearStr = signature.year {
            if yearStr.contains("-") {
                let split = yearStr.split(separator: "-")
                guard split.count == 2 else {
                    fatalError("year invalid")
                }
                for year in Int(split[0])! ... Int(split[1])! {
                    try runYear(logger: logger, year: year, cdskey: cdskey, domain: domain)
                }
            } else {
                guard let year = Int(yearStr) else {
                    fatalError("Could not convert year to integer")
                }
                try runYear(logger: logger, year: year, cdskey: cdskey, domain: domain)
            }
            return
        }
        
        /// Select the desired timerange, or use last 14 day
        let timeinterval = signature.getTimeinterval()
        let timeintervalReturned = try downloadDailyFiles(logger: logger, cdskey: cdskey, timeinterval: timeinterval, domain: domain)
        try convertDailyFiles(logger: logger, timeinterval: signature.force ? timeinterval : timeintervalReturned, domain: domain)
    }
    
    func stripSea(logger: Logger, readFilePath: String, writeFilePath: String, elevation: [Float]) throws {
        let domain = CdsDomain.era5
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
    
    func downloadElevation(logger: Logger, cdskey: String, domain: CdsDomain) throws {
        if FileManager.default.fileExists(atPath: domain.surfaceElevationFileOm) {
            return
        }
        
        let downloadDir = domain.downloadDirectory
        try FileManager.default.createDirectory(atPath: downloadDir, withIntermediateDirectories: true)
        let tempDownloadNetcdfFile = "\(downloadDir)elevation.nc"
        
        if !FileManager.default.fileExists(atPath: "\(downloadDir)elevation.nc") {
            logger.info("Downloading elevation and sea mask")
            let pyCode = """
                import cdsapi
                c = cdsapi.Client(url="https://cds.climate.copernicus.eu/api/v2", key="\(cdskey)", verify=True)

                c.retrieve(
                    '\(domain.cdsDatasetName)',
                    {
                        'product_type': 'reanalysis',
                        'format': 'netcdf',
                        'variable': [
                            'geopotential', 'land_sea_mask',
                        ],
                        'time': '00:00',
                        'day': '01',
                        'month': '01',
                        'year': '2022',
                    },
                    '\(tempDownloadNetcdfFile)')
                """
            let tempPythonFile = "\(downloadDir)elevation.py"

            try pyCode.write(toFile: tempPythonFile, atomically: true, encoding: .utf8)
            try Process.spawn(cmd: "python3", args: [tempPythonFile])
        }
        
        logger.info("Converting elevation and sea mask")
        let ncfile = try NetCDF.open(path: tempDownloadNetcdfFile, allowUpdate: false)!

        guard var elevation = try ncfile.getVariable(name: "z")?.readWithScalefactorAndOffset(scalefactor: 0.1, offset: 0, grid: domain.grid) else {
            fatalError("No variable named z available")
        }
        guard var landmask = try ncfile.getVariable(name: "lsm")?.readWithScalefactorAndOffset(scalefactor: 1, offset: 0, grid: domain.grid) else {
            fatalError("No variable named lsm available")
        }
        elevation.shift180LongitudeAndFlipLatitude(nt: 24, ny:  domain.grid.ny, nx: domain.grid.nx)
        landmask.shift180LongitudeAndFlipLatitude(nt: 24, ny:  domain.grid.ny, nx: domain.grid.nx)
        
        /*let a1 = Array2DFastSpace(data: elevation, nLocations: 1440*721, nTime: 1)
        try a1.writeNetcdf(filename: "\(downloadDir)/elevation_converted.nc", nx: 1440, ny: 721)
        let a2 = Array2DFastSpace(data: landmask, nLocations: 1440*721, nTime: 1)
        try a2.writeNetcdf(filename: "\(downloadDir)/landmask_converted.nc", nx: 1440, ny: 721)*/
        
        // Set all sea grid points to -999
        precondition(elevation.count == landmask.count)
        for i in elevation.indices {
            if landmask[i] < 0.5 {
                elevation[i] = -999
            }
        }
        
        try OmFileWriter(dim0: domain.grid.ny, dim1: domain.grid.nx, chunk0: 20, chunk1: 20).write(file: domain.surfaceElevationFileOm, compressionType: .p4nzdec256, scalefactor: 1, all: elevation)
    }
    
    func runStripSea(logger: Logger, year: Int) throws {
        let domain = CdsDomain.era5
        try FileManager.default.createDirectory(atPath: "\(OpenMeteo.dataDictionary)era5-no-sea", withIntermediateDirectories: true)
        logger.info("Read elevation")
        let elevation = try OmFileReader(file: domain.surfaceElevationFileOm).readAll()
        
        for variable in Era5Variable.allCases {
            logger.info("Converting variable \(variable)")
            let fullFile = "\(domain.omfileArchive!)\(variable)_\(year).om"
            let strippedFile = "\(OpenMeteo.dataDictionary)era5-no-sea/\(variable)_\(year).om"
            try stripSea(logger: logger, readFilePath: fullFile, writeFilePath: strippedFile, elevation: elevation)
        }
    }
    
    func runYear(logger: Logger, year: Int, cdskey: String, domain: CdsDomain) throws {
        let timeintervalHourly = TimerangeDt(start: Timestamp(year,1,1), to: Timestamp(year+1,1,1), dtSeconds: 3600)
        let timeintervalDaily = TimerangeDt(start: Timestamp(year,1,1), to: Timestamp(year+1,1,1), dtSeconds: 24*3600)
        let _ = try downloadDailyFiles(logger: logger, cdskey: cdskey, timeinterval: timeintervalDaily, domain: domain)
        let variables = Era5Variable.allCases.filter({ $0.availableForDomain(domain: domain) })
        try convertYear(logger: logger, year: year, domain: domain, variables: variables)
    }
    
    struct CdsQuery: Encodable {
        let product_type = "reanalysis"
        let format = "grib"
        let year: String
        let month: String
        let day: String
        let time: [String]
        let variable: [String]
    }
    
    /// Download ERA5 files from CDS and convert them to daily compressed files
    func downloadDailyFiles(logger: Logger, cdskey: String, timeinterval: TimerangeDt, domain: CdsDomain) throws -> TimerangeDt {
        logger.info("Downloading timerange \(timeinterval.prettyString())")
        
        guard timeinterval.dtSeconds == 86400 else {
            fatalError("need daily time axis")
        }
        
        /// Directory dir, where to place temporary downloaded files
        let downloadDir = domain.downloadDirectory
        try FileManager.default.createDirectory(atPath: downloadDir, withIntermediateDirectories: true)
                
        let variables = Era5Variable.allCases.filter({ $0.availableForDomain(domain: domain) })
        
        /// loop over each day, download data and convert it
        let pid = ProcessInfo.processInfo.processIdentifier
        let tempDownloadNetcdfFile = "\(downloadDir)era5download_\(pid).nc"
        let tempDownloadGribFile = "\(downloadDir)era5download_\(pid).grib"
        let tempPythonFile = "\(downloadDir)era5download_\(pid).py"
        
        /// The effective range of downloaded steps
        /// The lower bound will be adapted if timesteps already exist
        /// The upper bound will be reduced if the files are not yet on the remote server
        var downloadedRange = timeinterval.range.upperBound ..< timeinterval.range.upperBound
        
        let writer = OmFileWriter(dim0: 1, dim1: domain.grid.count, chunk0: 1, chunk1: 600)
        var grib2d = GribArray2D(nx: domain.grid.nx, ny: domain.grid.ny)
        
        timeLoop: for timestamp in timeinterval {
            logger.info("Downloading timestamp \(timestamp.format_YYYYMMdd)")
            let date = timestamp.toComponents()
            let timestampDir = "\(domain.downloadDirectory)\(timestamp.format_YYYYMMdd)"
            
            if FileManager.default.fileExists(atPath: "\(timestampDir)/\(variables[0].rawValue)_\(timestamp.format_YYYYMMdd)00.om") {
                continue
            }
            let ncvariables = variables.map { $0.cdsApiName }
            // Download 1 hour or 24 hours
            let hours = timeinterval.dtSeconds == 3600 ? [timestamp.hour] : Array(0..<24)
            
            let query = CdsQuery(
                year: "\(date.year)",
                month: date.month.zeroPadded(len: 2),
                day: date.day.zeroPadded(len: 2),
                time: hours.map({"'\($0.zeroPadded(len: 2)):00'"}),
                variable: variables.map {$0.cdsApiName}
            )
            let queryEncoded = String(data: try JSONEncoder().encode(query), encoding: .utf8)!
            
            let pyCode = """
                import cdsapi

                c = cdsapi.Client(url="https://cds.climate.copernicus.eu/api/v2", key="\(cdskey)", verify=True)
                try:
                    c.retrieve('\(domain.cdsDatasetName)',\(queryEncoded),'\(tempDownloadGribFile)')
                except Exception as e:
                    if "Please, check that your date selection is valid" in str(e):
                        exit(70)
                    if "the request you have submitted is not valid" in str(e):
                        exit(70)
                    raise e
                """
            
            try pyCode.write(toFile: tempPythonFile, atomically: true, encoding: .utf8)
            do {
                try Process.spawn(cmd: "python3", args: [tempPythonFile])
            } catch SpawnError.commandFailed(cmd: let cmd, returnCode: let code, args: let args) {
                if code == 70 {
                    logger.info("Timestep \(timestamp.iso8601_YYYY_MM_dd) seems to be unavailable. Skipping downloading now.")
                    downloadedRange = min(downloadedRange.lowerBound, timestamp) ..< timestamp
                    break timeLoop
                } else {
                    throw SpawnError.commandFailed(cmd: cmd, returnCode: code, args: args)
                }
            }
            
            try SwiftEccodes.iterateMessages(fileName: tempDownloadGribFile, multiSupport: true) { message in
                let shortName = message.get(attribute: "shortName")!
                guard let variable = variables.first(where: {$0.gribShortName.contains(shortName)}) else {
                    fatalError("Could not find \(shortName) in grib")
                }
                
                let hour = Int(message.get(attribute: "validityTime")!)!/100
                let date = message.get(attribute: "validityDate")!
                logger.info("Converting variable \(variable) \(date) \(hour) \(message.get(attribute: "name")!)")
                
                try grib2d.load(message: message)
                if let scaling = variable.netCdfScaling {
                    grib2d.array.data.multiplyAdd(multiply: Float(scaling.scalefactor), add: Float(scaling.offest))
                }
                grib2d.array.shift180LongitudeAndFlipLatitude()
                
                // For GRIB format, ERA5-Land-T data can be identified by the key expver=0005 in the GRIB header. Consolidated ERA5-Land data is identified by the key expver=0001.
                // TODO switch between consolidated and realtime
                
                //let fastTime = Array2DFastSpace(data: grib2d.array.data, nLocations: domain.grid.count, nTime: nt).transpose()
                /*guard !fastTime[0, 0..<nt].contains(.nan) else {
                    // For realtime updates, the latest day could only contain partial data. Skip it.
                    logger.warning("Timestap \(timestamp.iso8601_YYYY_MM_dd) for variable \(variable) contains missing data. Skipping.")
                    break timeLoop
                }*/
                
                try FileManager.default.createDirectory(atPath: "\(domain.downloadDirectory)\(date)", withIntermediateDirectories: true)
                let omFile = "\(domain.downloadDirectory)\(date)/\(variable.rawValue)_\(date)\(hour.zeroPadded(len: 2)).om"
                try FileManager.default.removeItemIfExists(at: omFile)
                try writer.write(file: omFile, compressionType: .p4nzdec256, scalefactor: variable.scalefactor, all: grib2d.array.data)
            }
            
            // Update downloaded range if download successfull
            if downloadedRange.lowerBound > timestamp {
                downloadedRange = timestamp ..< downloadedRange.upperBound
            }
        }
        
        try FileManager.default.removeItemIfExists(at: tempDownloadNetcdfFile)
        try FileManager.default.removeItemIfExists(at: tempPythonFile)
        return downloadedRange.range(dtSeconds: timeinterval.dtSeconds)
    }
    
    /// Convert daily compressed files to longer compressed files specified by `Era5.omFileLength`. E.g. 14 days in one file.
    func convertDailyFiles(logger: Logger, timeinterval: TimerangeDt, domain: CdsDomain) throws {
        if timeinterval.count == 0 {
            logger.info("No new timesteps could be downloaded. Nothing to do. Existing")
            return
        }
        
        logger.info("Converting timerange \(timeinterval.prettyString())")
       
        /// Directory dir, where to place temporary downloaded files
        let downloadDir = domain.downloadDirectory
        try FileManager.default.createDirectory(atPath: downloadDir, withIntermediateDirectories: true)
        
        let om = OmFileSplitter(basePath: domain.omfileDirectory, nLocations: domain.grid.count, nTimePerFile: domain.omFileLength, yearlyArchivePath: nil)
        
        let variables = Era5Variable.allCases.filter({ $0.availableForDomain(domain: domain) })
        
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
    }
    
    // Data is stored in one file per hour
    func convertYear(logger: Logger, year: Int, domain: CdsDomain, variables: [CdsVariableDownloadable]) throws {
        let timeintervalHourly = TimerangeDt(start: Timestamp(year,1,1), to: Timestamp(year+1,1,1), dtSeconds: 3600)
        
        let nx = domain.grid.nx // 721
        let ny = domain.grid.ny // 1440
        let nt = timeintervalHourly.count // 8784
        
        try FileManager.default.createDirectory(atPath: domain.omfileArchive!, withIntermediateDirectories: true)
        
        // convert to yearly file
        for variable in variables {
            let progress = ProgressTracker(logger: logger, total: nx*ny, label: "Converting variable \(variable)")
            let writeFile = "\(domain.omfileArchive!)\(variable)_\(year).om"
            if FileManager.default.fileExists(atPath: writeFile) {
                continue
            }
            let omFiles = try timeintervalHourly.map { timeinterval -> OmFileReader<MmapFile>? in
                let timestampDir = "\(domain.downloadDirectory)\(timeinterval.format_YYYYMMdd)"
                let omFile = "\(timestampDir)/\(variable.rawValue)_\(timeinterval.format_YYYYMMddHH).om"
                if !FileManager.default.fileExists(atPath: omFile) {
                    return nil
                }
                return try OmFileReader(file: omFile)
            }
            
            // chunk1 must be multiple of 24 hours for deaccumulation
            // chunk 6 locations and 21 days of data
            try OmFileWriter(dim0: ny*nx, dim1: nt, chunk0: 6, chunk1: 21 * 24).write(file: writeFile, compressionType: .p4nzdec256, scalefactor: variable.scalefactor, supplyChunk: { dim0 in
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
                if domain == .cerra {
                    if variable.isAccumulatedSinceModelStart {
                        fasttime.deaccumulateOverTime(slidingWidth: 3, slidingOffset: variable.hasAnalysis ? 0 : 1)
                    }
                }
                progress.add(locationRange.count)
                return ArraySlice(fasttime.data)
            })
            progress.finish()
        }
    }
}

extension Variable {
    /// Assume the variable has attributes scalefactor and offsets and apply all those to get a float array
    fileprivate func readWithScalefactorAndOffset(scalefactor: Double, offset: Double, grid: Gridable) throws -> [Float] {
        guard let ncVariableInt16 = asType(Int16.self) else {
            fatalError("Not Int16")
        }
        guard let ncScalefactor: Double = try getAttribute("scale_factor")?.read() else {
            fatalError("No scale_factor")
        }
        guard let ncOffset: Double = try getAttribute("add_offset")?.read() else {
            fatalError("No add_offset")
        }
        guard let fillValue: Int16 = try getAttribute("_FillValue")?.read() else {
            fatalError("No _FillValue")
        }
        guard let missingValue: Int16 = try getAttribute("missing_value")?.read() else {
            fatalError("No missing_value")
        }
        let data = try ncVariableInt16.read().map { val -> Float in
            if val == missingValue || val == fillValue {
                return Float.nan
            }
            return Float((Double(val) * ncScalefactor + ncOffset) * scalefactor + offset)
        }
        if dimensions[1].name == "expver" && dimensions[1].length == 2 {
            // In case we get 2 experiments, merge them
            // https://confluence.ecmwf.int/display/CUSF/ERA5+CDS+requests+which+return+a+mixture+of+ERA5+and+ERA5T+data
            var dataMerged = [Float]()
            dataMerged.reserveCapacity(24*grid.nx*grid.ny)
            for t in 0..<24 {
                /// Era5 starts eastwards at 0°E... rotate to start at -180°E
                for y in 0..<grid.ny {
                    for x in 0..<grid.nx {
                        /// prelimnary ERA5T data
                        let exp1 = data[t*2*grid.nx*grid.ny + (0)*grid.nx*grid.ny + y*grid.nx + x]
                        /// final era5 data
                        let exp5 = data[t*2*grid.nx*grid.ny + (1)*grid.nx*grid.ny + y*grid.nx + x]
                        
                        if !exp5.isNaN {
                            dataMerged.append(exp5)
                        } else {
                            dataMerged.append(exp1)
                        }
                    }
                }
            }
            return dataMerged
            // merge experiments
        }
        return data
    }
}
