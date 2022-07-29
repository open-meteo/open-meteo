import Foundation
import Vapor
import SwiftNetCDF
import SwiftPFor2D

enum IconWaveDomain: String, Codable, CaseIterable, LosslessStringConvertibleEnum {
    case gwam
    case ewam
    
    var omfileDirectory: String {
        return "./data/omfile-\(rawValue)/"
    }
    
    /// Number of time steps in each time series optimised file. 5 days more than each run.
    var omFileLength: Int {
        let dtHours = dtSeconds/3600
        return countForecastHours + 5 * 24 / dtHours
    }
    
    var dtSeconds: Int {
        switch self {
        case .gwam:
            return 3*3600
        case .ewam:
            return 3600
        }
    }
    
    var grid: RegularGrid {
        switch self {
        case .gwam:
            return RegularGrid(nx: 1440, ny: 699, latMin: -85.25, lonMin: -180, dx: 0.25, dy: 0.25)
        case .ewam:
            return RegularGrid(nx: 526, ny: 721, latMin: 30, lonMin: -10.5, dx: 0.1, dy: 0.05)
        }
    }
    
    /// Number of actual forecast timesteps per run
    var countForecastHours: Int {
        switch self {
        case .gwam:
            return 59
        case .ewam:
            return 79
        }
    }
}

enum IconWaveVariable: String, CaseIterable, Codable {
    case windspeed_10m
    case winddirection_10m
    case significant_wave_height
    case energy_wave_period
    case mean_wave_direction
    case wind_significant_wave_height
    case wind_wave_period
    case wind_wave_peak_period
    case wind_wave_direction
    case swell_significant_wave_height
    case swell_wave_period
    case swell_wave_peak_period
    case swell_wave_direction
    
    /// Name used on the dwd open data server
    var dwdName: String {
        switch self {
        case .windspeed_10m:
            return "sp_10m"
        case .winddirection_10m:
            return "dd_10m"
        case .significant_wave_height:
            return "swh"
        case .energy_wave_period:
            return "tm10"
        case .mean_wave_direction:
            return "mwd"
        case .wind_significant_wave_height:
            return "shww"
        case .wind_wave_period:
            return "mpww"
        case .wind_wave_peak_period:
            return "ppww"
        case .wind_wave_direction:
            return "mdww"
        case .swell_significant_wave_height:
            return "shts"
        case .swell_wave_period:
            return "mpts"
        case .swell_wave_peak_period:
            return "ppts"
        case .swell_wave_direction:
            return "mdts"
        }
    }
    
    /// Si unit
    var unit: SiUnit {
        switch self {
        case .windspeed_10m:
            return .ms
        case .winddirection_10m:
            return .degreeDirection
        case .significant_wave_height:
            return .meter
        case .energy_wave_period:
            return .second
        case .mean_wave_direction:
            return .degreeDirection
        case .wind_significant_wave_height:
            return .meter
        case .wind_wave_period:
            return .second
        case .wind_wave_peak_period:
            return .second
        case .wind_wave_direction:
            return .degreeDirection
        case .swell_significant_wave_height:
            return .meter
        case .swell_wave_period:
            return .second
        case .swell_wave_peak_period:
            return .second
        case .swell_wave_direction:
            return .degreeDirection
        }
    }
    
    var scalefactor: Float {
        let period: Float = 20 // 0.05s resolution
        let height: Float = 20 // 0.05m resolution
        let direction: Float = 1
        switch self {
        case .windspeed_10m:
            return 36 // 0.1 kmh resolution
        case .winddirection_10m:
            return direction
        case .significant_wave_height:
            return height
        case .energy_wave_period:
            return period
        case .mean_wave_direction:
            return direction
        case .wind_significant_wave_height:
            return height
        case .wind_wave_period:
            return period
        case .wind_wave_peak_period:
            return period
        case .wind_wave_direction:
            return direction
        case .swell_significant_wave_height:
            return height
        case .swell_wave_period:
            return period
        case .swell_wave_peak_period:
            return period
        case .swell_wave_direction:
            return direction
        }
    }
}

/**
 Download wave model form the german weather service
 https://www.dwd.de/DE/leistungen/opendata/help/modelle/legend_ICON_wave_EN_pdf.pdf?__blob=publicationFile&v=3
 */
struct DownloadIconWaveCommand: Command {
    struct Signature: CommandSignature {
        @Argument(name: "domain")
        var domain: IconWaveDomain

        @Argument(name: "run")
        var run: String

        @Flag(name: "skip-existing")
        var skipExisting: Bool
        
        @Option(name: "only-variable")
        var onlyVariable: String?
    }

    var help: String {
        "Download a specified wave model run"
    }
    
    func run(using context: CommandContext, signature: Signature) throws {
        guard let run = Int(signature.run) else {
            fatalError("Invalid run")
        }
        let logger = context.application.logger
        let domain = signature.domain
        let date = Timestamp.now().with(hour: run)
        logger.info("Downloading domain '\(domain.rawValue)' run '\(date.iso8601_YYYY_MM_dd_HH_mm)'")
        
        try download(logger: logger, domain: domain, run: date, skipFilesIfExisting: signature.skipExisting, variables: IconWaveVariable.allCases)
        try convert(logger: logger, domain: domain, run: date, variables: IconWaveVariable.allCases)
    }
    
    /// Download all timesteps and preliminarily covnert it to compressed files
    func download(logger: Logger, domain: IconWaveDomain, run: Timestamp, skipFilesIfExisting: Bool, variables: [IconWaveVariable]) throws {
        // https://opendata.dwd.de/weather/maritime/wave_models/gwam/grib/00/mdww/GWAM_MDWW_2022072800_000.grib2.bz2
        // https://opendata.dwd.de/weather/maritime/wave_models/ewam/grib/00/mdww/EWAM_MDWW_2022072800_000.grib2.bz2
        let baseUrl = "https://opendata.dwd.de/weather/maritime/wave_models/\(domain.rawValue)/grib/\(run.hour.zeroPadded(len: 2))/"
        let downloadDirectory = "./data/\(domain.rawValue)/"
        try FileManager.default.createDirectory(atPath: downloadDirectory, withIntermediateDirectories: true)
        
        let curl = Curl(logger: logger)
        let nx = domain.grid.nx
        let ny = domain.grid.ny
        
        for forecastStep in 0..<domain.countForecastHours {
            /// E.g. 0,3,6...174 for gwam
            let forecastHour = forecastStep * domain.dtSeconds / 3600
            logger.info("Downloading hour \(forecastHour)")
            
            for variable in variables {
                let url = "\(baseUrl)\(variable.dwdName)/\(domain.rawValue.uppercased())_\(variable.dwdName.uppercased())_\(run.format_YYYYMMddHH)_\(forecastHour.zeroPadded(len: 3)).grib2.bz2"
                
                let fileDest = "\(downloadDirectory)\(variable.rawValue)_\(forecastHour).om"
                if skipFilesIfExisting && FileManager.default.fileExists(atPath: fileDest) {
                    continue
                }
                let tempNc = "\(downloadDirectory)temp.nc"
                let tempgrib2 = "\(downloadDirectory)temp.grib2"
                let tempBz2 = "\(tempgrib2).bz2"
                try curl.download(
                    url: url,
                    to: tempBz2
                )
                try Process.bunzip2(file: tempBz2)
                if domain == .gwam {
                    try Process.grib2ToNetcdfShiftLongitude(in: tempgrib2, out: tempNc)
                } else {
                    try Process.grib2ToNetcdf(in: tempgrib2, out: tempNc)
                }
                let data = try NetCDF.readIconWave(file: tempNc)
                
                // Save temporarily as compressed om files
                try FileManager.default.removeItemIfExists(at: fileDest)
                try OmFileWriter.write(file: fileDest, compressionType: .p4nzdec256, scalefactor: variable.scalefactor, dim0: nx, dim1: ny, chunk0: nx, chunk1: ny, all: data)
            }
        }
    }
    
    /// Process each variable and update time-series optimised files
    func convert(logger: Logger, domain: IconWaveDomain, run: Timestamp, variables: [IconWaveVariable]) throws {
        let downloadDirectory = "./data/\(domain.rawValue)/"
        
        try FileManager.default.createDirectory(atPath: domain.omfileDirectory, withIntermediateDirectories: true)
        let om = OmFileSplitter(basePath: domain.omfileDirectory, nLocations: domain.grid.count, nTimePerFile: domain.omFileLength, yearlyArchivePath: nil)
        
        for variable in variables {
            logger.info("Converting \(variable)")
            
            var data2d = Array2DFastSpace(
                data: [Float](repeating: .nan, count: domain.grid.count * domain.countForecastHours),
                nLocations: domain.grid.count,
                nTime: domain.countForecastHours
            )
            
            for forecastStep in 0..<domain.countForecastHours {
                let forecastHour = forecastStep * domain.dtSeconds / 3600
                let d = try OmFileReader(file: "\(downloadDirectory)\(variable.rawValue)_\(forecastHour).om").readAll()
                data2d[forecastStep, 0..<data2d.nLocations] = ArraySlice(d)
            }
            
            logger.info("Create om file")
            let startOm = DispatchTime.now()
            let timeIndexStart = run.timeIntervalSince1970 / domain.dtSeconds
            let timeIndices = timeIndexStart ..< timeIndexStart + data2d.nTime
            try om.updateFromSpaceOriented(variable: variable.rawValue, array2d: data2d, ringtime: timeIndices, skipFirst: 0, smooth: 0, skipLast: 0, scalefactor: variable.scalefactor)
            logger.info("Update om finished in \(startOm.timeElapsedPretty())")
        }
    }
}

extension NetCDF {
    static func readIconWave(file: String) throws -> [Float] {
        guard let nc = try NetCDF.open(path: file, allowUpdate: false) else {
            fatalError("File \(file) does not exist")
        }
        guard let v = nc.getVariables().first(where: {$0.dimensions.count >= 3}) else {
            fatalError("Could not find data variable with 3d/4d data")
        }
        guard let varFloat = v.asType(Float.self) else {
            fatalError("Netcdf variable is not float type")
        }
        var d = try varFloat.read()
        for x in d.indices {
            if d[x] < -100000000 {
                d[x] = .nan
            }
        }
        return d
    }
}

