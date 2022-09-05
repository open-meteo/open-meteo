import Foundation
import Vapor
import SwiftNetCDF
import SwiftPFor2D


enum Era5: GenericDomain {
    case era5
    
    var dtSeconds: Int {
        return 3600
    }
    
    var elevationFile: OmFileReader? {
        return Self.era5ElevationFile
    }
    
    private static var era5ElevationFile = try? OmFileReader(file: Self.era5.surfaceElevationFileOm)
    
    /// Filename of the surface elevation file
    var surfaceElevationFileOm: String {
        "\(omfileDirectory)HSURF.om"
    }
    
    var downloadDirectory: String {
        return "\(OpenMeteo.dataDictionary)era5/"
    }
    
    var omfileDirectory: String {
        return "\(OpenMeteo.dataDictionary)omfile-era5/"
    }
    
    var omfileArchive: String? {
        return "\(OpenMeteo.dataDictionary)yearly-era5/"
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
        RegularGrid(nx: 1440, ny: 721, latMin: -90, lonMin: -180, dx: 0.25, dy: 0.25)
    }
}

/// Might be used to decode API queries later
enum Era5Variable: String, CaseIterable, Codable, GenericVariable {
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
    
    var interpolation: ReaderInterpolation {
        fatalError("Interpolation not required for era5")
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
    var netCdfScaling: (offest: Double, scalefactor: Double) {
        switch self {
        case .wind_u_component_100m: return (0, 1)
        case .wind_v_component_100m: return (0, 1)
        case .wind_u_component_10m: return (0, 1)
        case .wind_v_component_10m: return (0, 1)
        case .windgusts_10m: return (0, 1)
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
        case .soil_moisture_0_to_7cm: return (0, 1)
        case .soil_moisture_7_to_28cm: return (0, 1)
        case .soil_moisture_28_to_100cm: return (0, 1)
        case .soil_moisture_100_to_255cm: return (0, 1)
        case .shortwave_radiation: return (0, 1/3600) // joules to watt
        case .precipitation: return (0, 1000) // meter to millimeter
        case .direct_radiation: return (0, 1/3600)
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
        
        @Option(name: "stripseaYear", short: "s", help: "strip sea of converted files")
        var stripseaYear: String?
        
        @Option(name: "cdskey", short: "k", help: "CDS API user and key like: 123456:8ec08f...")
        var cdskey: String?
        
        /// Get the specified timerange in the command, or use the last 7 days as range
        func getTimeinterval() -> TimerangeDt {
            if let timeinterval = timeinterval {
                guard timeinterval.count == 17, timeinterval.contains("-") else {
                    fatalError("format looks wrong")
                }
                let start = Timestamp(Int(timeinterval[0..<4])!, Int(timeinterval[4..<6])!, Int(timeinterval[6..<8])!)
                let end = Timestamp(Int(timeinterval[9..<13])!, Int(timeinterval[13..<15])!, Int(timeinterval[15..<17])!).add(86400)
                return TimerangeDt(start: start, to: end, dtSeconds: 24*3600)
            }
            // Era5 has a typical delay of 5 days
            // Per default, check last 14 days for new data. If data is already downloaded, downloading is skipped
            let lastDays = 14
            return TimerangeDt(start: Timestamp.now().with(hour: 0).add(lastDays * -86400), nTime: lastDays, dtSeconds: 86400)
        }
    }

    var help: String {
        "Download ERA5 from the ECMWF climate data store and convert"
    }
    
    func stripSea(logger: Logger, readFilePath: String, writeFilePath: String, elevation: [Float]) throws {
        let domain = Era5.era5
        if FileManager.default.fileExists(atPath: writeFilePath) {
            return
        }
        let read = try OmFileReader(file: readFilePath)
        
        var percent = 0
        try OmFileWriter.write(file: writeFilePath, compressionType: .p4nzdec256, scalefactor: read.scalefactor, dim0: read.dim0, dim1: read.dim1, chunk0: read.chunk0, chunk1: read.chunk1) { dim0 in
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
    
    func downloadElevation(logger: Logger, cdskey: String) throws {
        let domain = Era5.era5
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
                    'reanalysis-era5-single-levels',
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
            try Process.spawnOrDie(cmd: "python3", args: [tempPythonFile])
        }
        
        logger.info("Converting elevation and sea mask")
        let ncfile = try NetCDF.open(path: tempDownloadNetcdfFile, allowUpdate: false)!

        guard var elevation = try ncfile.getVariable(name: "z")?.readWithScalefactorAndOffset(scalefactor: 0.1, offset: 0) else {
            fatalError("No variable named z available")
        }
        guard var landmask = try ncfile.getVariable(name: "lsm")?.readWithScalefactorAndOffset(scalefactor: 1, offset: 0) else {
            fatalError("No variable named lsm available")
        }
        elevation.shift180LongitudeAndFlipLatitude(nt: 24, ny: 721, nx: 1440)
        landmask.shift180LongitudeAndFlipLatitude(nt: 24, ny: 721, nx: 1440)
        
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
        
        try OmFileWriter.write(file: domain.surfaceElevationFileOm, compressionType: .p4nzdec256, scalefactor: 1, dim0: domain.grid.ny, dim1: domain.grid.nx, chunk0: 20, chunk1: 20, all: elevation)
    }
    
    func runStripSea(logger: Logger, year: Int) throws {
        let domain = Era5.era5
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
    
    func runYear(logger: Logger, year: Int, cdskey: String) throws {
        let domain = Era5.era5
        let timeinterval = TimerangeDt(start: Timestamp(year,1,1), to: Timestamp(year+1,1,1), dtSeconds: 24*3600)
        let _ = try downloadDailyFiles(logger: logger, cdskey: cdskey, timeinterval: timeinterval)
        
        let nx = domain.grid.nx // 721
        let ny = domain.grid.ny // 1440
        let nt = timeinterval.count * 24 // 8784
        
        let variables = Era5Variable.allCases
        
        // convert to yearly file
        for variable in variables {
            logger.info("Converting variable \(variable)")
            let writeFile = "\(domain.omfileArchive!)\(variable)_\(year).om"
            if FileManager.default.fileExists(atPath: writeFile) {
                continue
            }
            let omFiles = try timeinterval.map { timeinterval -> OmFileReader in
                let timestampDir = "\(domain.downloadDirectory)\(timeinterval.format_YYYYMMdd)"
                let omFile = "\(timestampDir)/\(variable.rawValue)_\(timeinterval.format_YYYYMMdd).om"
                return try OmFileReader(file: omFile)
            }
            var percent = 0
            var looptime = DispatchTime.now()
            try OmFileWriter.write(file: writeFile, compressionType: .p4nzdec256, scalefactor: variable.scalefactor, dim0: ny*nx, dim1: nt, chunk0: 6, chunk1: nt/8) { dim0 in
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
                    try omfile.willNeed(dim0Slow: locationRange, dim1: 0..<24)
                    let read = try omfile.read(dim0Slow: locationRange, dim1: 0..<24)
                    let read2d = Array2DFastTime(data: read, nLocations: locationRange.count, nTime: 24)
                    for l in 0..<locationRange.count {
                        fasttime[l, i*24 ..< (i+1)*24] = read2d[l, 0..<24]
                    }
                }
                return ArraySlice(fasttime.data)
            }
        }
    }
    
    /// Download ERA5 files from CDS and convert them to daily compressed files
    func downloadDailyFiles(logger: Logger, cdskey: String, timeinterval: TimerangeDt) throws -> TimerangeDt {
        let domain = Era5.era5
        logger.info("Downloading timerange \(timeinterval.prettyString())")
        
        /// Directory dir, where to place temporary downloaded files
        let downloadDir = domain.downloadDirectory
        try FileManager.default.createDirectory(atPath: downloadDir, withIntermediateDirectories: true)
                
        let variables = Era5Variable.allCases // [Era5Variable.wind_u_component_10m, .wind_v_component_10m, .wind_u_component_100m, .wind_v_component_100m]
        
        /// loop over each day, download data and convert it
        let tempDownloadNetcdfFile = "\(downloadDir)era5download_\(ProcessInfo.processInfo.processIdentifier).nc"
        let tempPythonFile = "\(downloadDir)era5download_\(ProcessInfo.processInfo.processIdentifier).py"
        
        /// The effective range of downloaded steps
        /// The lower bound will be adapted if timesteps already exist
        /// The upper bound will be reduced if the files are not yet on the remote server
        var downloadedRange = timeinterval.range.upperBound ..< timeinterval.range.upperBound
        
        timeLoop: for timestamp in timeinterval {
            logger.info("Downloading timestamp \(timestamp.iso8601_YYYY_MM_dd)")
            let date = timestamp.toComponents()
            let timestampDir = "\(domain.downloadDirectory)\(timestamp.format_YYYYMMdd)"
            
            if FileManager.default.fileExists(atPath: "\(timestampDir)/\(variables[0].rawValue)_\(timestamp.format_YYYYMMdd).om") {
                continue
            }
            
            let ncvariables = variables.map { $0.cdsApiName }
            let variablesEncoded = String(data: try JSONEncoder().encode(ncvariables), encoding: .utf8)!
            
            let pyCode = """
                import cdsapi

                c = cdsapi.Client(url="https://cds.climate.copernicus.eu/api/v2", key="\(cdskey)", verify=True)
                try:
                    c.retrieve(
                        'reanalysis-era5-single-levels',
                        {
                            'product_type': 'reanalysis',
                            'format': 'netcdf',
                            'variable': \(variablesEncoded),
                            'year': '\(date.year)',
                            'month': '\(date.month)',
                            'day': '\(date.day)',
                            'time': [
                                '00:00', '01:00', '02:00',
                                '03:00', '04:00', '05:00',
                                '06:00', '07:00', '08:00',
                                '09:00', '10:00', '11:00',
                                '12:00', '13:00', '14:00',
                                '15:00', '16:00', '17:00',
                                '18:00', '19:00', '20:00',
                                '21:00', '22:00', '23:00',
                            ],
                        },
                        '\(tempDownloadNetcdfFile)')
                except Exception as e:
                    if "Please, check that your date selection is valid" in str(e):
                        exit(70)
                    raise e
                """
            
            try pyCode.write(toFile: tempPythonFile, atomically: true, encoding: .utf8)
            do {
                try Process.spawnOrDie(cmd: "python3", args: [tempPythonFile])
            } catch SpawnError.commandFailed(cmd: let cmd, returnCode: let code, args: let args, let stderr) {
                if code == 70 {
                    logger.info("Timestep \(timestamp.iso8601_YYYY_MM_dd) seems to be unavailable. Skipping downloading now.")
                    downloadedRange = min(downloadedRange.lowerBound, timestamp) ..< timestamp
                    break timeLoop
                } else {
                    throw SpawnError.commandFailed(cmd: cmd, returnCode: code, args: args, stderr: stderr)
                }
            }
            
            let ncfile = try NetCDF.open(path: tempDownloadNetcdfFile, allowUpdate: false)!
            
            try FileManager.default.createDirectory(atPath: timestampDir, withIntermediateDirectories: true)
            
            for variable in variables {
                logger.info("Converting variable \(variable)")
                guard let ncVariable = ncfile.getVariable(name: variable.netCdfName) else {
                    fatalError("No variable named MyData available")
                }
                let scaling = variable.netCdfScaling
                var data = try ncVariable.readWithScalefactorAndOffset(scalefactor: scaling.scalefactor, offset: scaling.offest)
                
                data.shift180LongitudeAndFlipLatitude(nt: 24, ny: 721, nx: 1440)
                
                let fastTime = Array2DFastSpace(data: data, nLocations: 721*1440, nTime: 24).transpose()
                
                guard !fastTime[0, 0..<24].contains(.nan) else {
                    // For realtime updates, the latest day could only contain partial data. Skip it.
                    logger.warning("Timestap \(timestamp.iso8601_YYYY_MM_dd) for variable \(variable) contains missing data. Skipping.")
                    break timeLoop
                }
                
                //let a2 = Array2DFastSpace(data: data, nLocations: 1440*721, nTime: 24)
                //try a2.writeNetcdf(filename: "\(timestampDir)/\(variable.rawValue)_\(timestamp.format_YYYYMMdd).nc", nx: 1440, ny: 721)
                
                /// around 47.37°N/0°E latitude, at 12:00 UTC
                //let basel = Era5.grid.findPoint(lat: 47.56, lon: 7.57)!
                //let start = (0*1440*721) + basel
                //print(data[start..<start+100])
                
                let omFile = "\(timestampDir)/\(variable.rawValue)_\(timestamp.format_YYYYMMdd).om"
                try FileManager.default.removeItemIfExists(at: omFile)
                // Write time oriented file
                try OmFileWriter.write(file: omFile, compressionType: .p4nzdec256, scalefactor: variable.scalefactor, dim0: fastTime.nLocations, dim1: fastTime.nTime, chunk0: 600, chunk1: fastTime.nTime, all: fastTime.data)
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
    func convertDailyFiles(logger: Logger, timeinterval: TimerangeDt) throws {
        let domain = Era5.era5
        if timeinterval.count == 0 {
            logger.info("No new timesteps could be downloaded. Nothing to do. Existing")
            return
        }
        
        logger.info("Converting timerange \(timeinterval.prettyString())")
       
        /// Directory dir, where to place temporary downloaded files
        let downloadDir = domain.downloadDirectory
        try FileManager.default.createDirectory(atPath: downloadDir, withIntermediateDirectories: true)
        
        let om = OmFileSplitter(basePath: domain.omfileDirectory, nLocations: domain.grid.count, nTimePerFile: domain.omFileLength, yearlyArchivePath: nil)
        
        let variables = Era5Variable.allCases // [Era5Variable.wind_u_component_10m, .wind_v_component_10m, .wind_u_component_100m, .wind_v_component_100m]
        
        /// loop over each day convert it
        for variable in variables {
            logger.info("Converting variable \(variable)")
            
            let nt = timeinterval.count * 24
            let nLoc = domain.grid.count
            
            var fasttime = Array2DFastTime(data: [Float](repeating: .nan, count: nt*nLoc), nLocations: nLoc, nTime: nt)
            
            for (i,timestamp) in timeinterval.enumerated() {
                logger.info("Reading timestamp \(timestamp.iso8601_YYYY_MM_dd)")
                let timestampDir = "\(domain.downloadDirectory)\(timestamp.format_YYYYMMdd)"
                guard FileManager.default.fileExists(atPath: timestampDir) else {
                    continue
                }
                
                let omFile =  "\(timestampDir)/\(variable.rawValue)_\(timestamp.format_YYYYMMdd).om"
                let dataDay = try OmFileReader(file: omFile).readAll()
                
                let read2d = Array2DFastTime(data: dataDay, nLocations: nLoc, nTime: 24)
                for l in 0..<nLoc {
                    fasttime[l, i*24 ..< (i+1)*24] = read2d[l, 0..<24]
                }
            }
            
            logger.info("Writing \(variable)")
            let ringtime = timeinterval.range.lowerBound.timeIntervalSince1970 / 3600 ..< timeinterval.range.upperBound.timeIntervalSince1970 / 3600
            try om.updateFromTimeOriented(variable: variable.rawValue, array2d: fasttime, ringtime: ringtime, skipFirst: 0, smooth: 0, skipLast: 0, scalefactor: variable.scalefactor)
        }
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
        /// Make sure elevation information is present. Otherwise download it
        try downloadElevation(logger: logger, cdskey: cdskey)
        
        /// Only download one specified year
        if let yearStr = signature.year {
            guard let year = Int(yearStr) else {
                fatalError("Could not convert year to integer")
            }
            try runYear(logger: logger, year: year, cdskey: cdskey)
            return
        }
        
        /// Select the desired timerange, or use last 14 day
        var timeinterval = signature.getTimeinterval()
        timeinterval = try downloadDailyFiles(logger: logger, cdskey: cdskey, timeinterval: timeinterval)
        try convertDailyFiles(logger: logger, timeinterval: timeinterval)
    }
}

extension Variable {
    /// Assume the variable has attributes scalefactor and offsets and apply all those to get a float array
    fileprivate func readWithScalefactorAndOffset(scalefactor: Double, offset: Double) throws -> [Float] {
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
            dataMerged.reserveCapacity(24*1440*721)
            for t in 0..<24 {
                /// Era5 starts eastwards at 0°E... rotate to start at -180°E
                for y in 0..<721 {
                    for x in 0..<1440 {
                        /// prelimnary ERA5T data
                        let exp1 = data[t*2*1440*721 + (0)*1440*721 + y*1440 + x]
                        /// final era5 data
                        let exp5 = data[t*2*1440*721 + (1)*1440*721 + y*1440 + x]
                        
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
