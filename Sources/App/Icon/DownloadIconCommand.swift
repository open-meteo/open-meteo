import Foundation
import Vapor
import SwiftNetCDF
import SwiftPFor2D


struct CdoHelper {
    let cdo: CdoIconGlobal?
    let grid: Gridable
    let domain: IconDomains
    
    init(domain: IconDomains, logger: Logger) throws {
        // icon global needs resampling to plate carree
        cdo = domain == .icon ? try CdoIconGlobal(logger: logger, workDirectory: domain.downloadDirectory) : nil
        grid = domain.grid
        self.domain = domain
    }
    
    func readGrib2Bz2(_ filename: String) throws -> [Float] {
        let tempNc = "\(domain.downloadDirectory)temp.nc"
        let gribFile = String(filename.dropLast(4))
        
        try Process.bunzip2(file: filename)
        if let cdo = cdo {
            // resample to regular latlon (icon global)
            try cdo.remap(in: gribFile, out: tempNc)
        } else {
            // just convert grib2 to netcdf
            try Process.grib2ToNetcdf(in: gribFile, out: tempNc)
        }
        try FileManager.default.removeItem(atPath: gribFile)
        guard let nc = try NetCDF.open(path: tempNc, allowUpdate: false) else {
            fatalError("File test.nc does not exist")
        }
        guard let v = nc.getVariables().first(where: {$0.dimensions.count >= 3}) else {
            fatalError("Could not find data variable with 3d/4d data")
        }
        precondition(v.dimensions[v.dimensions.count-1].length == grid.nx)
        precondition(v.dimensions[v.dimensions.count-2].length == grid.ny)
        guard let varFloat = v.asType(Float.self) else {
            fatalError("Netcdf variable is not float type")
        }
        /// icon-d2 total precip, aswdir and aswdifd have 15 minutes values
        let offset = v.dimensions.count == 3 ? [0,0,0] : [0,0,0,0]
        let count = v.dimensions.count == 3 ? [1,grid.ny,grid.nx] : [1,1,grid.ny,grid.nx]
        var d = try varFloat.read(offset: offset, count: count)
        for x in d.indices {
            if d[x] < -100000000 {
                d[x] = .nan
            }
        }
        return d
    }
    
    /**
     Convert surface elevation. Out of grid positions are NaN. Sea grid points are -999.
     */
    func convertSurfaceElevation() throws {
        if FileManager.default.fileExists(atPath: domain.surfaceElevationFileOm) {
            return
        }
        
        // use special numbers for SEA grid points?
        try Process.bunzip2(file: "\(domain.downloadDirectory)time-invariant_HSURF.grib2.bz2")
        var hsurf = try readGrib2Bz2("\(domain.downloadDirectory)time-invariant_HSURF.grib2.bz2")
        
        try Process.bunzip2(file: "\(domain.downloadDirectory)time-invariant_FR_LAND.grib2.bz2")
        let landFraction = try readGrib2Bz2("\(domain.downloadDirectory)time-invariant_FR_LAND.grib2.bz2")
        
        // Set all sea grid points to -999
        precondition(hsurf.count == landFraction.count)
        for i in hsurf.indices {
            if landFraction[i] < 0.5 {
                hsurf[i] = -999
            }
        }
        
        try OmFileWriter.write(file: domain.surfaceElevationFileOm, compressionType: .p4nzdec256, scalefactor: 1, dim0: domain.grid.ny, dim1: domain.grid.nx, chunk0: 20, chunk1: 20, all: hsurf)
    }
}

struct DownloadIconCommand: Command {
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
        "Download a specified icon model run"
    }
    
    /// Download ICON global, eu and d2 *.grid2.bz2 files
    func downloadIcon(logger: Logger, domain: IconDomains, run: Timestamp, skipFilesIfExisting: Bool, variables: [IconVariableDownloadable]) throws {
        let gridType = domain == .icon ? "icosahedral" : "regular-lat-lon"
        let downloadDirectory = domain.downloadDirectory
        try FileManager.default.createDirectory(atPath: downloadDirectory, withIntermediateDirectories: true)
        
        let domainPrefix = "\(domain.rawValue)_\(domain.region)"
        let cdo = try CdoHelper(domain: domain, logger: logger)
        
        // https://opendata.dwd.de/weather/nwp/icon/grib/00/t_2m/icon_global_icosahedral_single-level_2022070800_000_T_2M.grib2.bz2
        // https://opendata.dwd.de/weather/nwp/icon-eu/grib/00/t_2m/icon-eu_europe_regular-lat-lon_single-level_2022072000_000_T_2M.grib2.bz2
        let serverPrefix = "https://opendata.dwd.de/weather/nwp/\(domain.rawValue)/grib/\(run.hour.zeroPadded(len: 2))/"
        let dateStr = run.format_YYYYMMddHH
        let curl = Curl(logger: logger)
        // surface elevation
        // https://opendata.dwd.de/weather/nwp/icon/grib/00/hsurf/icon_global_icosahedral_time-invariant_2022072400_HSURF.grib2.bz2
        if (skipFilesIfExisting && FileManager.default.fileExists(atPath: "\(downloadDirectory)time-invariant_HSURF.grib2.bz2")) == false {
            let file: String
            if domain == .iconD2 {
                file = "\(serverPrefix)hsurf/\(domainPrefix)_\(gridType)_time-invariant_\(dateStr)_000_0_hsurf.grib2.bz2"
            } else {
                file = "\(serverPrefix)hsurf/\(domainPrefix)_\(gridType)_time-invariant_\(dateStr)_HSURF.grib2.bz2"
            }
            try curl.download(
                url: file,
                to: "\(downloadDirectory)time-invariant_HSURF.grib2.bz2"
            )
        }
        
        // land fraction
        if (skipFilesIfExisting && FileManager.default.fileExists(atPath: "\(downloadDirectory)time-invariant_FR_LAND.grib2.bz2")) == false {
            let file: String
            if domain == .iconD2 {
                file = "\(serverPrefix)fr_land/\(domainPrefix)_\(gridType)_time-invariant_\(dateStr)_000_0_fr_land.grib2.bz2"
            } else {
                file = "\(serverPrefix)fr_land/\(domainPrefix)_\(gridType)_time-invariant_\(dateStr)_FR_LAND.grib2.bz2"
            }
            try curl.download(
                url: file,
                to: "\(downloadDirectory)time-invariant_FR_LAND.grib2.bz2"
            )
        }

        let forecastSteps = domain.getDownloadForecastSteps(run: run.hour)
        for hour in forecastSteps {
            logger.info("Downloading hour \(hour)")
            let h3 = hour.zeroPadded(len: 3)
            for variable in variables {
                if hour == 0 && variable.skipHour0 {
                    continue
                }
                let v = variable.getVarAndLevel(domain: domain)
                let level = v.level.map({"_\($0)"}) ?? ""
                var filenameFrom = "\(domainPrefix)_\(gridType)_\(v.cat)_\(dateStr)_\(h3)\(level)_\(v.variable.uppercased()).grib2.bz2"
                if domain == .iconD2 {
                    let level = v.level.map({"_\($0)"}) ?? "_2d"
                    filenameFrom = "\(domainPrefix)_\(gridType)_\(v.cat)_\(dateStr)_\(h3)\(level)_\(v.variable).grib2.bz2"
                }
                let filenameDest = "single-level_\(h3)_\(variable.omFileName.uppercased()).fpg"
                if skipFilesIfExisting && FileManager.default.fileExists(atPath: "\(downloadDirectory)\(filenameDest)") {
                    continue
                }
                try curl.download(
                    url: "\(serverPrefix)\(v.variable)/\(filenameFrom)",
                    to: "\(downloadDirectory)temp.grib2.bz2"
                )
                // Uncompress bz2, reproject to regular grid, convert to netcdf and read into memory
                // Especially reprojecting is quite slow, therefore we can better utilise the download time waiting for the next file
                let data = try cdo.readGrib2Bz2("\(downloadDirectory)temp.grib2.bz2")
                // Write data as encoded floats to disk
                try FileManager.default.removeItemIfExists(at: "\(downloadDirectory)\(filenameDest)")
                try FloatArrayCompressor.write(file: "\(downloadDirectory)\(filenameDest)", data: data)
            }
        }
    }

    /// unompress and remap
    /// Process variable after variable
    func convertIcon(logger: Logger, domain: IconDomains, run: Timestamp, variables: [IconVariableDownloadable]) throws {
        let downloadDirectory = domain.downloadDirectory
        let cdo = try CdoHelper(domain: domain, logger: logger)
        let grid = domain.grid
        
        let forecastSteps = domain.getDownloadForecastSteps(run: run.hour)
        let nForecastHours = domain.nForecastHours(run: run.hour)
        let nLocation = grid.nx * grid.ny
        
        try FileManager.default.createDirectory(atPath: domain.omfileDirectory, withIntermediateDirectories: true)
        let om = OmFileSplitter(basePath: domain.omfileDirectory, nLocations: nLocation, nTimePerFile: domain.omFileLength, yearlyArchivePath: nil)

        // ICON global + eu only have 3h data after 78 hours
        // ICON global 6z and 18z have 120 instead of 180 forecast hours
        // Stategy: Read each variable in a spatial array and interpolate missing values
        // Afterwards merge into temporal data files
        
        try cdo.convertSurfaceElevation()

        for variable in variables {
            let startConvert = DispatchTime.now()
            logger.info("Converting \(variable)")
            
            let v = variable.omFileName.uppercased()

            /// time oriented, but after 72 hours only 3 hour values are filled.
            /// 2.86GB high water for this array
            var data2d = Array2DFastTime(nLocations: nLocation, nTime: nForecastHours)

            for hour in forecastSteps {
                if hour == 0 && variable.skipHour0 {
                    continue
                }
                let h3 = hour.zeroPadded(len: 3)
                data2d[0..<nLocation, hour] = try FloatArrayCompressor.read(file: "\(downloadDirectory)single-level_\(h3)_\(v).fpg", nElements: nLocation)
            }
            
            
            // Deaverage radiation. Not really correct for 3h data after 81 hours, but interpolation will correct in the next step.
            if variable.isAveragedOverForecastTime {
                data2d.deavergeOverTime(slidingWidth: data2d.nTime, slidingOffset: 1)
            }
            
            // interpolate missing timesteps. We always fill 2 timesteps at once
            // data looks like: DDDDDDDDDD--D--D--D--D--D
            let forecastStepsToInterpolate = (0..<nForecastHours).compactMap { hour -> Int? in
                if forecastSteps.contains(hour) || hour % 3 != 1 {
                    // process 2 timesteps at once
                    return nil
                }
                return hour
            }
            
            // Fill in missing hourly values after switching to 3h
            data2d.interpolate2Steps(type: variable.interpolationType, positions: forecastStepsToInterpolate, grid: domain.grid, run: run, dtSeconds: domain.dtSeconds)
            
            if let fma = variable.multiplyAdd {
                data2d.data.multiplyAdd(multiply: fma.multiply, add: fma.add)
            }
            
            // De-accumulate precipitation
            if variable.isAccumulatedSinceModelStart {
                data2d.deaccumulateOverTime(slidingWidth: data2d.nTime, slidingOffset: 1)
            }
            
            //try data2d.transpose().writeNetcdf(filename: "\(domain.downloadDirectory)\(v).nc", nx: grid.nx, ny: grid.ny)
            
            let ringtime = run.timeIntervalSince1970 / 3600 ..< run.timeIntervalSince1970 / 3600 + nForecastHours
            let skip = variable.skipHour0 ? 1 : 0
            /// the last hour in D2 is broken for latent heat flux and sensible heatflux -> 2022-06-07: fluxes are ok in D2, actually skipLast feature was buggy
            //let skipLast = (variable == .ashfl_s || variable == .alhfl_s) && domain == .iconD2 ? 1 : 0
            let skipLast = 0
            
            logger.info("Reading and interpolation done in \(startConvert.timeElapsedPretty()). Starting om file update")
            let startOm = DispatchTime.now()
            try om.updateFromTimeOriented(variable: variable.omFileName, array2d: data2d, ringtime: ringtime, skipFirst: skip, smooth: 0, skipLast: skipLast, scalefactor: variable.scalefactor)
            logger.info("Update om finished in \(startOm.timeElapsedPretty())")
        }
        logger.info("write init.txt")
        // TODO write also valid until date range
        try "\(run.timeIntervalSince1970)".write(toFile: domain.initFileNameOm, atomically: true, encoding: .utf8)
    }

    func run(using context: CommandContext, signature: Signature) throws {
        guard let domain = IconDomains.init(rawValue: signature.domain) else {
            fatalError("Invalid domain '\(signature.domain)'")
        }
        
        let run = signature.run.map {
            guard let run = Int($0) else {
                fatalError("Invalid run '\($0)'")
            }
            return run
        } ?? domain.lastRun
        
        let onlyVariables: [IconVariableDownloadable]? = signature.onlyVariables.map {
            $0.split(separator: ",").map {
                if let variable = IconPressureVariable(rawValue: String($0)) {
                    return variable
                }
                guard let variable = IconSurfaceVariable(rawValue: String($0)) else {
                    fatalError("Invalid variable '\($0)'")
                }
                return variable
            }
        }
        
        let variables = onlyVariables ?? domain.allVariables
        let logger = context.application.logger

        let date = Timestamp.now().with(hour: run)
        logger.info("Downloading domain '\(domain.rawValue)' run '\(date.iso8601_YYYY_MM_dd_HH_mm)'")

        try downloadIcon(logger: logger, domain: domain, run: date, skipFilesIfExisting: signature.skipExisting, variables: variables)
        try convertIcon(logger: logger, domain: domain, run: date, variables: variables)
    }
}

extension IconDomains {
    /// Based on the current time , guess the current run that should be available soon on the open-data server
    fileprivate var lastRun: Int {
        let t = Timestamp.now()
        switch self {
        case .icon: fallthrough
        case .iconEu:
            // Icon has a delay of 2-3 hours after initialisation
            return ((t.hour - 2 + 24) % 24) / 6 * 6
        case .iconD2:
            // Icon d2 has a delay of 1 hour and runs every 3 hours
            return ((t.hour - 1 + 24) % 24) / 3 * 3
        }
    }
}
