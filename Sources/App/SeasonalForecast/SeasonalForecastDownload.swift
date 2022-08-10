import Foundation
import Vapor
import SwiftPFor2D


/**
 
 NCEP CFSv2 https://nomads.ncep.noaa.gov/pub/data/nccf/com/cfs/prod/cfs.20220808/00/
 https://rda.ucar.edu/datasets/ds094.0/#metadata/grib2.html?_do=y
 
 requires jpeg2000 support for eccodes, brew needs to rebuild
 brew edit eccodes
 set DENABLE_JPG_LIBJASPER to ON
 brew reinstall eccodes --build-from-source
 */
struct SeasonalForecastDownload: Command {
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
        "Download seasonal forecasts from Copernicus"
    }
    
    func run(using context: CommandContext, signature: Signature) throws {
        let logger = context.application.logger
        guard let domain = SeasonalForecastDomain.init(rawValue: signature.domain) else {
            fatalError("Invalid domain '\(signature.domain)'")
        }
        switch domain {
        case .ecmwf:
            fatalError()
        case .ukMetOffice:
            fatalError()
        case .meteoFrance:
            fatalError()
        case .dwd:
            fatalError()
        case .cmcc:
            fatalError()
        case .ncep:
            let variables: [CfsVariable] = signature.onlyVariables.map {
                $0.split(separator: ",").map {
                    guard let variable = CfsVariable(rawValue: String($0)) else {
                        fatalError("Invalid variable '\($0)'")
                    }
                    return variable
                }
            } ?? CfsVariable.allCases
            
            let run = signature.run.map {
                guard let run = Int($0) else {
                    fatalError("Invalid run '\($0)'")
                }
                return run
            } ?? Timestamp.now().hour - 6
            
            /// 18z run is available the day after starting 00:56
            let date = Timestamp.now().add(-6*3600).with(hour: run)
            
            if !signature.skipExisting {
                try downloadCfs(logger: logger, domain: domain, run: date, variables: variables)
            }
            //try convertCfs(logger: logger, domain: domain, run: run, variables: variables)
        case .jma:
            fatalError()
        case .eccc:
            fatalError()
        }
    }
    
    func downloadCfs(logger: Logger, domain: SeasonalForecastDomain, run: Timestamp, variables: [CfsVariable]) throws {
        try FileManager.default.createDirectory(atPath: domain.downloadDirectory, withIntermediateDirectories: true)
        let curl = Curl(logger: logger)
        let nx = domain.grid.nx
        let ny = domain.grid.ny
        
        let timeinterval = TimerangeDt(start: run, nTime: domain.nForecastHours, dtSeconds: domain.dtSeconds)
        for (forecastStep,time) in timeinterval.enumerated() {
            /// Since model start
            let forecastHour = forecastStep * domain.dtHours
            logger.info("Downloading hour \(forecastHour)")
            for member in 0..<domain.nMembers {
                /// Forecast member 2-4 have only 45 days forecast
                if member > 0 && forecastHour > 1080 {
                    continue
                }
                // https://nomads.ncep.noaa.gov/pub/data/nccf/com/cfs/prod/cfs.20220808/06/6hrly_grib_01/flxf2022080818.01.2022080806.grb2.idx
                let url = "https://nomads.ncep.noaa.gov/pub/data/nccf/com/cfs/prod/cfs.\(run.format_YYYYMMdd)/\(run.hour.zeroPadded(len: 2))/6hrly_grib_\(member.zeroPadded(len: 2))/flxf\(time.format_YYYYMMddHH).\(member.zeroPadded(len: 2)).\(run.format_YYYYMMddHH).grb2"
                
                for (variable, data2) in try curl.downloadIndexedGrib(url: url, variables: variables) {
                    var data = data2
                    data.shift180LongitudeAndFlipLatitude()
                    for i in data.data.indices {
                        if data.data[i] >= 9999 {
                            data.data[i] = .nan
                        }
                    }
                    data.data.multiplyAdd(multiply: variable.gribMultiplyAdd.multiply, add: variable.gribMultiplyAdd.add)

                    //try data.writeNetcdf(filename: "\(domain.downloadDirectory)\(variable.rawValue)_\(forecastHour).nc")
                    
                    let fileDest = "\(domain.downloadDirectory)\(variable.rawValue)_\(member)_\(forecastHour).om"
                    try FileManager.default.removeItemIfExists(at: fileDest)
                    try OmFileWriter.write(file: fileDest, compressionType: .p4nzdec256, scalefactor: variable.scalefactor, dim0: nx, dim1: ny, chunk0: nx, chunk1: ny, all: data.data)
                }
            }
        }
    }
    
    /// Process each variable and update time-series optimised files
    func convertCfs(logger: Logger, domain: SeasonalForecastDomain, run: Timestamp, variables: [CfsVariable]) throws {
        let downloadDirectory = domain.downloadDirectory
        
        try FileManager.default.createDirectory(atPath: domain.omfileDirectory, withIntermediateDirectories: true)
        let om = OmFileSplitter(basePath: domain.omfileDirectory, nLocations: domain.grid.count, nTimePerFile: domain.omFileLength, yearlyArchivePath: nil)
        
        for variable in variables {
            logger.info("Converting \(variable)")
            for member in 0..<domain.nMembers {
                
                /// Prepare data as time series optimisied array. It is wrapped in a closure to release memory.
                var data2d = Array2DFastTime(nLocations: domain.grid.count, nTime: domain.nForecastHours)
                    
                for forecastStep in 0..<domain.nForecastHours {
                    let forecastHour = forecastStep * domain.dtSeconds / 3600
                    let d = try OmFileReader(file: "\(downloadDirectory)\(variable.rawValue)_\(forecastHour).om").readAll()
                    data2d[0..<data2d.nLocations, forecastStep] = d
                }

                
                logger.info("Create om file")
                let startOm = DispatchTime.now()
                let timeIndexStart = run.timeIntervalSince1970 / domain.dtSeconds
                let timeIndices = timeIndexStart ..< timeIndexStart + data2d.nTime
                //try data2d.writeNetcdf(filename: "\(downloadDirectory)\(variable.rawValue).nc", nx: domain.grid.nx, ny: domain.grid.ny)
                try om.updateFromTimeOriented(variable: "\(variable.rawValue)_\(member)", array2d: data2d, ringtime: timeIndices, skipFirst: 0, smooth: 0, skipLast: 0, scalefactor: variable.scalefactor)
                logger.info("Update om finished in \(startOm.timeElapsedPretty())")
            }
        }
    }
}


