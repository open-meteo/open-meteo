import Foundation
import Vapor
import SwiftNetCDF


/**
 Download from
 https://confluence.ecmwf.int/display/UDOC/ECMWF+Open+Data+-+Real+Time
 https://data.ecmwf.int/forecasts/20220131/00z/0p4-beta/oper/
 
 model info (not everything is open data) https://www.ecmwf.int/en/forecasts/datasets/set-i
 */
struct DownloadEcmwfCommand: Command {
    struct Signature: CommandSignature {
        @Option(name: "run")
        var run: String?

        @Flag(name: "skip-existing")
        var skipExisting: Bool
    }

    var help: String {
        "Download a specified ecmwf model run"
    }
    
    func run(using context: CommandContext, signature: Signature) throws {
        let run = signature.run.map {
            guard let run = Int($0) else {
                fatalError("Invalid run '\($0)'")
            }
            return run
        } ?? EcmwfDomain.ifs04.lastRun
        let logger = context.application.logger

        // 18z run starts downloading on the next day
        let twoHoursAgo = Timestamp.now().add(-7200)
        let date = twoHoursAgo.with(hour: run)
        logger.info("Downloading domain ECMWF run '\(date.iso8601_YYYY_MM_dd_HH_mm)'")

        try downloadEcmwf(logger: logger, run: date, skipFilesIfExisting: signature.skipExisting)
        try convertEcmwf(logger: logger, run: date)
    }
    
    func downloadEcmwf(logger: Logger, run: Timestamp, skipFilesIfExisting: Bool) throws {
        let domain = EcmwfDomain.ifs04
        let base = "https://data.ecmwf.int/forecasts/"
        
        let dateStr = run.format_YYYYMMdd
        let curl = Curl(logger: logger)
        let downloadDirectory = "./data/ecmwf-forecast/"
        try FileManager.default.createDirectory(atPath: downloadDirectory, withIntermediateDirectories: true)
        let filenameTemp = "\(downloadDirectory)temp.grib2"
        
        let forecastSteps = domain.getDownloadForecastSteps(run: run.hour)
        
        let product = run.hour == 0 || run.hour == 12 ? "oper" : "scda"
        let runStr = run.hour.zeroPadded(len: 2)
        
        for hour in forecastSteps {
            logger.info("Downloading hour \(hour)")
            
            //https://data.ecmwf.int/forecasts/20220131/00z/0p4-beta/oper/20220131000000-0h-oper-fc.grib2
            //https://data.ecmwf.int/forecasts/20220131/00z/0p4-beta/oper/20220131000000-12h-oper-fc.grib2
            let filenameFrom = "\(base)\(dateStr)/\(runStr)z/0p4-beta/\(product)/\(dateStr)\(runStr)0000-\(hour)h-\(product)-fc.grib2"
            let filenameConverted = "\(downloadDirectory)/\(hour)h.nc"
            
            if skipFilesIfExisting && FileManager.default.fileExists(atPath: filenameConverted) {
                continue
            }
            try curl.download(
                url: filenameFrom,
                to: filenameTemp
            )
            try Process.grib2ToNetCDFInvertLatitude(in: filenameTemp, out: filenameConverted)
        }
    }
    
    func convertEcmwf(logger: Logger, run: Timestamp) throws {
        let domain = EcmwfDomain.ifs04
        let downloadDirectory = "./data/ecmwf-forecast/"
        
        let forecastSteps = domain.getDownloadForecastSteps(run: run.hour)
        let nForecastHours = forecastSteps.max()! / domain.dtHours + 1
        
        let nLocation = domain.grid.nx * domain.grid.ny
        
        /// The time data is placed in the ring
        let ringtime = run.timeIntervalSince1970 / domain.dtSeconds ..< run.timeIntervalSince1970 / domain.dtSeconds + nForecastHours
        
        try FileManager.default.createDirectory(atPath: domain.omfileDirectory, withIntermediateDirectories: true)
        let om = OmFileSplitter(basePath: domain.omfileDirectory, nLocations: nLocation, nTimePerFile: domain.omFileLength, yearlyArchivePath: nil)
        
        for variable in EcmwfVariable.allCases {
            logger.debug("Converting \(variable)")
            
            /// Prepare data as time series optimisied array
            var data2d = Array2DFastTime(nLocations: nLocation, nTime: nForecastHours)
            
            for hour in forecastSteps {
                /*if hour == 0 && variable.skipHour0 {
                    continue
                }*/
                let d = try Self.readNetcdf(file: "\(downloadDirectory)\(hour)h.nc", variable: variable.gribName, levelOffset: variable.level, nx: domain.grid.nx, ny: domain.grid.ny)
                data2d[0..<nLocation, hour/domain.dtHours] = d
            }
            
            let interpolationHours = (0..<nForecastHours).compactMap { hour -> Int? in
                if forecastSteps.contains(hour * domain.dtHours) {
                    return nil
                }
                return hour
            }
            
            switch variable.interpolation {
            case .linear:
                for l in 0..<nLocation {
                    for hour in interpolationHours {
                        let prev = data2d[l, hour-1]
                        let next = data2d[l, hour+1]
                        data2d[l, hour] = prev * 1/2 + next * 1/2
                    }
                }
            case .hermite:
                for l in 0..<nLocation {
                    for hour in interpolationHours {
                        let A = data2d[l, hour-3 < 0 ? hour-1 : hour-3]
                        let B = data2d[l, hour-1]
                        let C = data2d[l, hour+1]
                        let D = data2d[l, hour+2 >= nForecastHours ? hour+1 : hour+3]
                        let a = -A/2.0 + (3.0*B)/2.0 - (3.0*C)/2.0 + D/2.0
                        let b = A - (5.0*B)/2.0 + 2.0*C - D / 2.0
                        let c = -A/2.0 + C/2.0
                        let d = B
                        data2d[l, hour] = a*0.5*0.5*0.5 + b*0.5*0.5 + c*0.5 + d
                    }
                }
            }
            
            /// Temperature is stored in kelvin. Convert to celsius
            if variable.rawValue.contains("temperature") {
                for i in data2d.data.indices {
                    data2d.data[i] -= 273.15
                }
            }
            
            /*#if Xcode
            try! data2d.writeNetcdf(filename: "\(EcmwfDomain.omfileDirectory)\(variable).nc", nx: domain.grid.nx, ny: domain.grid.ny)
            return
            #endif*/
            
            logger.info("Create om file")
            let startOm = DispatchTime.now()
            try om.updateFromTimeOriented(variable: variable.nameInFiles, array2d: data2d, ringtime: ringtime, skipFirst: 0, smooth: 0, skipLast: 0, scalefactor: variable.scalefactor)
            logger.info("Update om finished in \(startOm.timeElapsedPretty())")
        }
        
        var indexTimeEnd = run.timeIntervalSince1970 + 241 * 3600
        if run.hour == 6 || run.hour == 18 {
            // run 6 and 18 only have 90 instead 240
            indexTimeEnd += (240 - 90) * 3600
        }
        let indexTimeStart = indexTimeEnd - domain.omFileLength * domain.dtSeconds + 12 * 3600
        try "\(run.timeIntervalSince1970),\(domain.omFileLength),\(indexTimeStart),\(indexTimeEnd)".write(toFile: "\(domain.omfileDirectory)init.txt", atomically: true, encoding: .utf8)
    }
    
    static func readNetcdf(file: String, variable: String, levelOffset: Int?, nx: Int, ny: Int) throws -> [Float] {
        guard let nc = try NetCDF.open(path: file, allowUpdate: false) else {
            fatalError("File \(file) does not exist")
        }
        guard let v = nc.getVariable(name: variable) else {
            fatalError("Could not find data variable with 3d/4d data")
        }
        precondition(v.dimensions[v.dimensions.count-1].length == nx)
        precondition(v.dimensions[v.dimensions.count-2].length == ny)
        guard let varFloat = v.asType(Float.self) else {
            fatalError("Netcdf variable is not float type")
        }
        /// icon-d2 total precip, aswdir and aswdifd has 15 minutes precip inside
        let offset = v.dimensions.count == 3 ? [0,0,0] : [0,levelOffset!,0,0]
        let count = v.dimensions.count == 3 ? [1,ny,nx] : [1,1,ny,nx]
        var d = try varFloat.read(offset: offset, count: count)
        for x in d.indices {
            if d[x] < -100000000 {
                d[x] = .nan
            }
        }
        return d
    }
}

extension EcmwfDomain {
    /// Based on the current time , guess the current run that should be available soon on the open-data server
    fileprivate var lastRun: Int {
        let t = Timestamp.now()
        switch self {
        case .ifs04:
            // ECMWF has a delay of 7-8 hours after initialisation
            return ((t.hour - 7 + 24) % 24) / 6 * 6
        }
    }
}
