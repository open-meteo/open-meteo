import Foundation
import Vapor
import SwiftPFor2D
import SwiftEccodes


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
            let date = Timestamp.now().add(-24*3600).with(hour: run) // TODO
            try downloadCfsElevation(logger: logger, domain: domain, run: date)
            
            try downloadCfs(logger: logger, domain: domain, run: date, skipFilesIfExisting: signature.skipExisting, variables: variables)
            try convertCfs(logger: logger, domain: domain, run: date, variables: variables)
        case .jma:
            fatalError()
        case .eccc:
            fatalError()
        }
    }
    
    /// download cfs domain
    func downloadCfsElevation(logger: Logger, domain: SeasonalForecastDomain, run: Timestamp) throws {
        /// download seamask and height
        if FileManager.default.fileExists(atPath: domain.surfaceElevationFileOm) {
            return
        }
        
        try FileManager.default.createDirectory(atPath: domain.omfileDirectory, withIntermediateDirectories: true)
        
        logger.info("Downloading height and elevation data")
        let url = "https://nomads.ncep.noaa.gov/pub/data/nccf/com/cfs/prod/cfs.\(run.format_YYYYMMdd)/\(run.hour.zeroPadded(len: 2))/6hrly_grib_01/flxf\(run.format_YYYYMMddHH).01.\(run.format_YYYYMMddHH).grb2"
        
        enum ElevationVariable: String, CurlIndexedVariable, CaseIterable {
            case height
            case landmask
            
            var gribIndexName: String {
                switch self {
                case .height:
                    return ":HGT:surface:"
                case .landmask:
                    return ":LAND:surface:"
                }
            }
        }
        
        var height: Array2D? = nil
        var landmask: Array2D? = nil
        let curl = Curl(logger: logger)
        for (variable, data2) in try curl.downloadIndexedGrib(url: url, variables: ElevationVariable.allCases) {
            var data = data2
            data.shift180LongitudeAndFlipLatitude()
            switch variable {
            case .height:
                height = data
            case .landmask:
                landmask = data
            }
            //try data.writeNetcdf(filename: "\(domain.downloadDirectory)\(variable.rawValue).nc")
        }
        guard var height = height, let landmask = landmask else {
            fatalError("Could not download land and sea mask")
        }
        for i in height.data.indices {
            // landmask: 0=sea, 1=land
            height.data[i] = landmask.data[i] == 1 ? height.data[i] : -999
        }
        try OmFileWriter.write(file: domain.surfaceElevationFileOm, compressionType: .p4nzdec256, scalefactor: 1, dim0: domain.grid.ny, dim1: domain.grid.nx, chunk0: 20, chunk1: 20, all: height.data)
    }
    
    func downloadCfs(logger: Logger, domain: SeasonalForecastDomain, run: Timestamp, skipFilesIfExisting: Bool, variables: [CfsVariable]) throws {
        try FileManager.default.createDirectory(atPath: domain.downloadDirectory, withIntermediateDirectories: true)
        
        let curl = Curl(logger: logger)
        let gribVariables = Array(Set(variables.map{$0.timeGribName}))
        
        for gribVariable in gribVariables {
            logger.info("Downloading varibale \(gribVariable)")
            for member in 1..<domain.nMembers+1 {
                // https://nomads.ncep.noaa.gov/pub/data/nccf/com/cfs/prod/cfs.20220808/18/time_grib_01/tmin.01.2022080818.daily.grb2.idx
                let url = "https://nomads.ncep.noaa.gov/pub/data/nccf/com/cfs/prod/cfs.\(run.format_YYYYMMdd)/18/time_grib_\(member.zeroPadded(len: 2))/\(gribVariable).\(member.zeroPadded(len: 2)).\(run.format_YYYYMMddHH).daily.grb2"
                
                let fileDest = "\(domain.downloadDirectory)\(gribVariable)_\(member).grb2"
                if skipFilesIfExisting && FileManager.default.fileExists(atPath: fileDest) {
                    continue
                }
                
                try curl.download(url: url, to: fileDest)
            }
        }
    }
    
    /// Process each variable and update time-series optimised files
    func convertCfs(logger: Logger, domain: SeasonalForecastDomain, run: Timestamp, variables: [CfsVariable]) throws {
        let downloadDirectory = domain.downloadDirectory
        
        try FileManager.default.createDirectory(atPath: domain.omfileDirectory, withIntermediateDirectories: true)
        let om = OmFileSplitter(basePath: domain.omfileDirectory, nLocations: domain.grid.count, nTimePerFile: domain.omFileLength, yearlyArchivePath: nil)
        
        let gribVariables = Array(Set(variables.map{$0.timeGribName}))
        
        for gribVariable in gribVariables {
            for member in 1..<domain.nMembers+1 {
                logger.info("Converting \(gribVariable), member \(member)")
                let grib = try GribFile(file: "\(domain.downloadDirectory)\(gribVariable)_\(member).grb2")
                
                /// Note, first forecast hour is always missing
                let nForecastHours = Int(grib.messages.last!.get(attribute: "stepRange")!)! / domain.dtHours + 1
                
                /// wind grib contains u and v components
                var vars = [CfsVariable: Array2DFastTime]()
                let startReadGrib = DispatchTime.now()
                
                for message in grib.messages {
                    let shortName = message.get(attribute: "shortName")!
                    let level = message.get(attribute: "level")!
                    let forecastStep = Int(message.get(attribute: "step")!)! / domain.dtHours
                    var data = try message.read2D()
                    data.shift180LongitudeAndFlipLatitude()
                    
                    guard let variable = variables.first(where: {$0.timeGribKey == "\(shortName)\(level)"}) ?? variables.first(where: {$0.timeGribName == gribVariable}) else {
                        fatalError("Could not resolve grib variable to cfs variable")
                    }
                    guard data.nx == domain.grid.nx, data.ny == domain.grid.ny else {
                        fatalError("Wrong dimensions. Got \(data.nx)x\(data.ny). Expected \(domain.grid.nx)x\(domain.grid.ny)")
                    }
                    data.data.multiplyAdd(multiply: variable.gribMultiplyAdd.multiply, add: variable.gribMultiplyAdd.add)
                    
                    if vars[variable] == nil {
                        vars[variable] = Array2DFastTime(nLocations: data.nx*data.ny, nTime: nForecastHours)
                    }
                    vars[variable]![0..<data.ny*data.nx, forecastStep] = data.data
                }
                
                logger.info("Grib read finished in \(startReadGrib.timeElapsedPretty())")
                
                for (variable, data) in vars {
                    let startOm = DispatchTime.now()
                    let timeIndexStart = run.timeIntervalSince1970 / domain.dtSeconds
                    let timeIndices = timeIndexStart ..< timeIndexStart + data.nTime
                    try data.transpose().writeNetcdf(filename: "\(downloadDirectory)\(variable.rawValue)_\(member).nc", nx: domain.grid.nx, ny: domain.grid.ny)
                    try om.updateFromTimeOriented(variable: "\(variable.rawValue)_\(member)", array2d: data, ringtime: timeIndices, skipFirst: 1, smooth: 0, skipLast: 0, scalefactor: variable.scalefactor)
                    logger.info("Update om finished in \(startOm.timeElapsedPretty())")
                }
            }
        }
    }
}


extension GribMessage {
    func read2D() throws -> Array2D {
        let data = try getDouble().map(Float.init)
        guard let nx = get(attribute: "Nx").map(Int.init) ?? nil else {
            fatalError("Could not get Nx")
        }
        guard let ny = get(attribute: "Ny").map(Int.init) ?? nil else {
            fatalError("Could not get Ny")
        }
        return Array2D(data: data, nx: nx, ny: ny)
    }
}
