import Foundation
import Vapor
import SwiftNetCDF
import SwiftPFor2D


/**
 Download wave model form the german weather service
 https://www.dwd.de/DE/leistungen/opendata/help/modelle/legend_ICON_wave_EN_pdf.pdf?__blob=publicationFile&v=3
 
 All equations: https://library.wmo.int/doc_num.php?explnum_id=10979
 */
struct DownloadIconWaveCommand: Command {
    struct Signature: CommandSignature {
        @Argument(name: "domain")
        var domain: String

        @Option(name: "run")
        var run: String?

        @Flag(name: "skip-existing")
        var skipExisting: Bool
        
        @Option(name: "only-variables")
        var onlyVariables: String?
    }

    var help: String {
        "Download a specified wave model run"
    }
    
    func run(using context: CommandContext, signature: Signature) throws {
        guard let domain = IconWaveDomain.init(rawValue: signature.domain) else {
            fatalError("Invalid domain '\(signature.domain)'")
        }
        
        let run = signature.run.map {
            guard let run = Int($0) else {
                fatalError("Invalid run '\($0)'")
            }
            return run
        } ?? domain.lastRun
        
        let onlyVariables: [IconWaveVariable]? = signature.onlyVariables.map {
            $0.split(separator: ",").map {
                guard let variable = IconWaveVariable(rawValue: String($0)) else {
                    fatalError("Invalid variable '\($0)'")
                }
                return variable
            }
        }
        
        let logger = context.application.logger
        let date = Timestamp.now().with(hour: run)
        logger.info("Downloading domain '\(domain.rawValue)' run '\(date.iso8601_YYYY_MM_dd_HH_mm)'")
        
        let variables = onlyVariables ?? IconWaveVariable.allCases
        try download(logger: logger, domain: domain, run: date, skipFilesIfExisting: signature.skipExisting, variables: variables)
        try convert(logger: logger, domain: domain, run: date, variables: variables)
    }
    
    /// Download all timesteps and preliminarily covnert it to compressed files
    func download(logger: Logger, domain: IconWaveDomain, run: Timestamp, skipFilesIfExisting: Bool, variables: [IconWaveVariable]) throws {
        // https://opendata.dwd.de/weather/maritime/wave_models/gwam/grib/00/mdww/GWAM_MDWW_2022072800_000.grib2.bz2
        // https://opendata.dwd.de/weather/maritime/wave_models/ewam/grib/00/mdww/EWAM_MDWW_2022072800_000.grib2.bz2
        let baseUrl = "https://opendata.dwd.de/weather/maritime/wave_models/\(domain.rawValue)/grib/\(run.hour.zeroPadded(len: 2))/"
        let downloadDirectory = "\(OpenMeteo.dataDictionary)\(domain.rawValue)/"
        try FileManager.default.createDirectory(atPath: downloadDirectory, withIntermediateDirectories: true)
        
        let curl = Curl(logger: logger)
        let nx = domain.grid.nx
        let ny = domain.grid.ny
        
        for forecastStep in 0..<domain.countForecastHours {
            /// E.g. 0,3,6...174 for gwam
            let forecastHour = forecastStep * domain.dtHours
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
                    try Process.grib2ToNetcdfShiftLongitudeInvertLatitude(in: tempgrib2, out: tempNc)
                } else {
                    try Process.grib2ToNetCDFInvertLatitude(in: tempgrib2, out: tempNc)
                }
                let data = try NetCDF.readIconWave(file: tempNc)
                
                /// Create elevation file for sea mask
                if !FileManager.default.fileExists(atPath: domain.surfaceElevationFileOm) {
                    var elevation = data
                    for i in elevation.indices {
                        /// `NaN` out of domain, `-999` sea grid point
                        elevation[i] = elevation[i].isNaN ? .nan : -999
                    }
                    //let data2d = Array2DFastSpace(data: elevation, nLocations: elevation.count, nTime: 1)
                    //try data2d.writeNetcdf(filename: "\(downloadDirectory)elevation.nc", nx: nx, ny: ny)
                    try OmFileWriter.write(file: domain.surfaceElevationFileOm, compressionType: .p4nzdec256, scalefactor: 1, dim0: domain.grid.ny, dim1: domain.grid.nx, chunk0: 20, chunk1: 20, all: elevation)
                }
                
                // Save temporarily as compressed om files
                try FileManager.default.removeItemIfExists(at: fileDest)
                try OmFileWriter.write(file: fileDest, compressionType: .p4nzdec256, scalefactor: variable.scalefactor, dim0: nx, dim1: ny, chunk0: nx, chunk1: ny, all: data)
            }
        }
    }
    
    /// Process each variable and update time-series optimised files
    func convert(logger: Logger, domain: IconWaveDomain, run: Timestamp, variables: [IconWaveVariable]) throws {
        let downloadDirectory = "\(OpenMeteo.dataDictionary)\(domain.rawValue)/"
        
        try FileManager.default.createDirectory(atPath: domain.omfileDirectory, withIntermediateDirectories: true)
        let om = OmFileSplitter(basePath: domain.omfileDirectory, nLocations: domain.grid.count, nTimePerFile: domain.omFileLength, yearlyArchivePath: nil)
        
        for variable in variables {
            logger.info("Converting \(variable)")
            
            /// Prepare data as time series optimisied array. It is wrapped in a closure to release memory.
            var data2d = Array2DFastTime(nLocations: domain.grid.count, nTime: domain.countForecastHours)
                
            for forecastStep in 0..<domain.countForecastHours {
                let forecastHour = forecastStep * domain.dtSeconds / 3600
                let d = try OmFileReader(file: "\(downloadDirectory)\(variable.rawValue)_\(forecastHour).om").readAll()
                data2d[0..<data2d.nLocations, forecastStep] = d
            }

            
            logger.info("Create om file")
            let startOm = DispatchTime.now()
            let timeIndexStart = run.timeIntervalSince1970 / domain.dtSeconds
            let timeIndices = timeIndexStart ..< timeIndexStart + data2d.nTime
            //try data2d.writeNetcdf(filename: "\(downloadDirectory)\(variable.rawValue).nc", nx: domain.grid.nx, ny: domain.grid.ny)
            try om.updateFromTimeOriented(variable: variable.rawValue, array2d: data2d, ringtime: timeIndices, skipFirst: 0, smooth: 0, skipLast: 0, scalefactor: variable.scalefactor)
            logger.info("Update om finished in \(startOm.timeElapsedPretty())")
        }
    }
}

extension IconWaveDomain {
    /// Based on the current time , guess the current run that should be available soon on the open-data server
    fileprivate var lastRun: Int {
        let t = Timestamp.now()
        switch self {
        case .ewam: fallthrough
        case .gwam:
            // Wave models have a delay of 3-4 hours after initialisation
            return ((t.hour - 3 + 24) % 24) / 12 * 12
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

