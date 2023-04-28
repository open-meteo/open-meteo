import Foundation
import Vapor
import SwiftPFor2D
import SwiftEccodes

/**
Gem regional and global Downloader
 - Regional https://dd.weather.gc.ca/model_gem_regional/10km/grib2/
 - Global https://dd.weather.gc.ca/model_gem_global/15km/grib2/lat_lon/
 
 High perf server
 - Global https://hpfx.collab.science.gc.ca/20221121/WXO-DD/model_gem_global/15km/grib2/lat_lon/00/
 - Regional https://hpfx.collab.science.gc.ca/20221121/WXO-DD/model_gem_regional/10km/grib2/00/

 TODO:
 - elevation and sea mask for hrdps
 */
struct GemDownload: AsyncCommandFix {
    struct Signature: CommandSignature {
        @Argument(name: "domain")
        var domain: String
        
        @Option(name: "run")
        var run: String?
        
        @Option(name: "past-days")
        var pastDays: Int?
        
        @Flag(name: "skip-existing")
        var skipExisting: Bool
        
        @Flag(name: "create-netcdf")
        var createNetcdf: Bool
        
        //@Flag(name: "upper-level", help: "Download upper-level variables on pressure levels")
        //var upperLevel: Bool
        
        @Option(name: "only-variables")
        var onlyVariables: String?
    }
    
    var help: String {
        "Download Gem models"
    }
    
    func run(using context: CommandContext, signature: Signature) async throws {
        let start = DispatchTime.now()
        let logger = context.application.logger
        let domain = try GemDomain.load(rawValue: signature.domain)
        
        let run = try signature.run.flatMap(Timestamp.fromRunHourOrYYYYMMDD) ?? domain.lastRun
        
        let onlyVariables: [GemVariableDownloadable]? = signature.onlyVariables.map {
            $0.split(separator: ",").map {
                if let variable = GemPressureVariable(rawValue: String($0)) {
                    return variable
                }
                guard let variable = GemSurfaceVariable(rawValue: String($0)) else {
                    fatalError("Invalid variable '\($0)'")
                }
                return variable
            }
        }
        
        let variablesAll: [GemVariableDownloadable] = GemSurfaceVariable.allCases + domain.levels.flatMap {
            level in GemPressureVariableType.allCases.compactMap { variable in
                return GemPressureVariable(variable: variable, level: level)
            }
        }
        
        let variables = onlyVariables ?? variablesAll
        
        logger.info("Downloading domain '\(domain.rawValue)' run '\(run.iso8601_YYYY_MM_dd_HH_mm)'")
        
        try FileManager.default.createDirectory(atPath: domain.downloadDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(atPath: domain.omfileDirectory, withIntermediateDirectories: true)
        
        try await downloadElevation(application: context.application, domain: domain, run: run)
        try await download(application: context.application, domain: domain, variables: variables, run: run, skipFilesIfExisting: signature.skipExisting)
        try convert(logger: logger, domain: domain, variables: variables, run: run, createNetcdf: signature.createNetcdf)
        logger.info("Finished in \(start.timeElapsedPretty())")
    }
    
    // download seamask and height
    func downloadElevation(application: Application, domain: GemDomain, run: Timestamp) async throws {
        if domain == .gem_hrdps_continental {
            // HGT_SFC_0 file is missing... no idea why
            return
        }
        
        let logger = application.logger
        let surfaceElevationFileOm = domain.surfaceElevationFileOm
        if FileManager.default.fileExists(atPath: surfaceElevationFileOm) {
            return
        }
        try FileManager.default.createDirectory(atPath: domain.omfileDirectory, withIntermediateDirectories: true)
        
        logger.info("Downloading height and elevation data")
        
        var height: Array2D? = nil
        
        let curl = Curl(logger: logger, client: application.dedicatedHttpClient, deadLineHours: 4)
        
        var grib2d = GribArray2D(nx: domain.grid.nx, ny: domain.grid.ny)
        
        let terrainUrl = domain.getUrl(run: run, hour: 0, gribName: "HGT_SFC_0")
        for message in try await curl.downloadGrib(url: terrainUrl, bzip2Decode: false) {
            try grib2d.load(message: message)
            height = grib2d.array
            //try grib2d.array.writeNetcdf(filename: "\(domain.downloadDirectory)terrain.nc")
        }
        
        if domain != .gem_global_ensemble {
            let landmaskUrl = domain.getUrl(run: run, hour: 0, gribName: "LAND_SFC_0")
            var landmask: Array2D? = nil
            for message in try await curl.downloadGrib(url: landmaskUrl, bzip2Decode: false) {
                try grib2d.load(message: message)
                landmask = grib2d.array
                //try grib2d.array.writeNetcdf(filename: "\(domain.downloadDirectory)landmask.nc")
            }
            if height != nil, let landmask {
                for i in landmask.data.indices {
                    // landmask: 0=sea, 1=land
                    height!.data[i] = landmask.data[i] >= 0.5 ? height!.data[i] : -999
                }
            }
        }
        
        guard let height else {
            fatalError("Could not download land and sea mask")
        }
        try OmFileWriter(dim0: domain.grid.ny, dim1: domain.grid.nx, chunk0: 20, chunk1: 20).write(file: surfaceElevationFileOm, compressionType: .p4nzdec256, scalefactor: 1, all: height.data)
    }
    
    /// Download data and store as compressed files for each timestep
    func download(application: Application, domain: GemDomain, variables: [GemVariableDownloadable], run: Timestamp, skipFilesIfExisting: Bool) async throws {
        let logger = application.logger
        let curl = Curl(logger: logger, client: application.dedicatedHttpClient, deadLineHours: domain == .gem_global_ensemble ? 10 : 5)
        let downloadDirectory = domain.downloadDirectory
        
        let nLocationsPerChunk = OmFileSplitter(basePath: domain.omfileDirectory, nLocations: domain.grid.count, nTimePerFile: domain.omFileLength, yearlyArchivePath: nil).nLocationsPerChunk
        let writer = OmFileWriter(dim0: 1, dim1: domain.grid.count, chunk0: 1, chunk1: nLocationsPerChunk)
        
        var grib2d = GribArray2D(nx: domain.grid.nx, ny: domain.grid.ny)
                
        let forecastHours = domain.getForecastHours(run: run)
        for hour in forecastHours {
            logger.info("Downloading hour \(hour)")
            let h3 = hour.zeroPadded(len: 3)
            for variable in variables {
                guard let gribName = variable.gribName(domain: domain) else {
                    continue
                }
                if hour == 0 && variable.skipHour0 {
                    continue
                }
                if !variable.includedFor(hour: hour, domain: domain) {
                    continue
                }
                let filenameDest = "\(downloadDirectory)\(variable.omFileName)_\(h3).om"
                if skipFilesIfExisting && FileManager.default.fileExists(atPath: filenameDest) {
                    continue
                }
                
                let url = domain.getUrl(run: run, hour: hour, gribName: gribName)
                
                for message in try await curl.downloadGrib(url: url, bzip2Decode: false) {
                    let member = message.get(attribute: "perturbationNumber").flatMap(Int.init) ?? 0
                    let memberStr = member > 0 ? "_\(member)" : ""
                    let filenameDest = "\(downloadDirectory)\(variable.omFileName)_\(h3)\(memberStr).om"
                    //try message.debugGrid(grid: domain.grid, flipLatidude: false, shift180Longitude: true)
                    //fatalError()
                    try grib2d.load(message: message)
                    if domain == .gem_global_ensemble {
                        // Only ensemble model is shifted by 180°
                        grib2d.array.shift180Longitudee()
                    }
                    
                    try FileManager.default.removeItemIfExists(at: filenameDest)
                    // Scaling before compression with scalefactor
                    if let fma = variable.multiplyAdd(dtSeconds: domain.dtSeconds) {
                        grib2d.array.data.multiplyAdd(multiply: fma.multiply, add: fma.add)
                    }
                    
                    //try grib2d.array.writeNetcdf(filename: "\(domain.downloadDirectory)\(variable.omFileName)_\(h3)\(memberStr).nc")
                    let compression = variable.isAccumulatedSinceModelStart ? CompressionType.fpxdec32 : .p4nzdec256
                    try writer.write(file: filenameDest, compressionType: compression, scalefactor: variable.scalefactor, all: grib2d.array.data)
                }
            }
        }
        curl.printStatistics()
    }
    
    /// Process each variable and update time-series optimised files
    func convert(logger: Logger, domain: GemDomain, variables: [GemVariableDownloadable], run: Timestamp, createNetcdf: Bool) throws {
        let downloadDirectory = domain.downloadDirectory
        let grid = domain.grid
        
        let forecastHours = domain.getForecastHours(run: run)
        let nTime = forecastHours.max()! / domain.dtHours + 1
        let time = TimerangeDt(start: run, nTime: nTime, dtSeconds: domain.dtSeconds)
        let nLocations = grid.nx * grid.ny
        
        try FileManager.default.createDirectory(atPath: domain.omfileDirectory, withIntermediateDirectories: true)
        let om = OmFileSplitter(basePath: domain.omfileDirectory, nLocations: nLocations, nTimePerFile: domain.omFileLength, yearlyArchivePath: nil)
        let nLocationsPerChunk = om.nLocationsPerChunk
        
        var data2d = Array2DFastTime(nLocations: nLocationsPerChunk, nTime: nTime)
        var readTemp = [Float](repeating: .nan, count: nLocationsPerChunk)

        for variable in variables {
            guard variable.gribName(domain: domain) != nil else {
                continue
            }
            let skip = variable.skipHour0 ? 1 : 0

            for member in 0..<domain.ensembleMembers {
                let memberStr = member > 0 ? "_\(member)" : ""
                let progress = ProgressTracker(logger: logger, total: nLocations, label: "Convert \(variable.rawValue)\(memberStr)")
                let readers: [(hour: Int, reader: OmFileReader<MmapFile>)] = try forecastHours.compactMap({ hour in
                    if hour == 0 && variable.skipHour0 {
                        return nil
                    }
                    if !variable.includedFor(hour: hour, domain: domain) {
                        return nil
                    }
                    let h3 = hour.zeroPadded(len: 3)
                    let reader = try OmFileReader(file: "\(downloadDirectory)\(variable.omFileName)_\(h3)\(memberStr).om")
                    try reader.willNeed()
                    return (hour, reader)
                })
                
                try om.updateFromTimeOrientedStreaming(variable: "\(variable.omFileName)\(memberStr)", indexTime: time.toIndexTime(), skipFirst: skip, smooth: 0, skipLast: 0, scalefactor: variable.scalefactor) { d0offset in
                    
                    let locationRange = d0offset ..< min(d0offset+nLocationsPerChunk, nLocations)
                    data2d.data.fillWithNaNs()
                    for reader in readers {
                        try reader.reader.read(into: &readTemp, arrayDim1Range: 0..<locationRange.count, arrayDim1Length: locationRange.count, dim0Slow: 0..<1, dim1: locationRange)
                        data2d[0..<data2d.nLocations, reader.hour / domain.dtHours] = readTemp
                    }
                    
                    if domain.dtHours == 3 {
                        /// interpolate 6 to 3 hours for ensemble 0.5°
                        let interpolationHours = (0..<nTime).compactMap { hour -> Int? in
                            if forecastHours.contains(hour * domain.dtHours) {
                                return nil
                            }
                            return hour
                        }
                        data2d.interpolate1Step(interpolation: variable.interpolation, interpolationHours: interpolationHours, width: 1, time: time, grid: domain.grid, locationRange: locationRange)
                    }
                    
                    // De-accumulate precipitation
                    if variable.isAccumulatedSinceModelStart {
                        data2d.deaccumulateOverTime(slidingWidth: data2d.nTime, slidingOffset: 1)
                    }
                    
                    progress.add(locationRange.count)
                    return data2d.data[0..<locationRange.count * nTime]
                }
                progress.finish()
            }
        }
    }
}


