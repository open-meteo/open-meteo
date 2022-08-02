import Foundation
import Vapor
import SwiftNetCDF
import SwiftPFor2D


struct CdoHelper {
    let cdo: CdoIconGlobal?
    let grid: RegularGrid
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
    func downloadIcon(logger: Logger, domain: IconDomains, run: Timestamp, skipFilesIfExisting: Bool, variables: [IconVariable]) throws {
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
    func convertIcon(logger: Logger, domain: IconDomains, run: Timestamp, variables: [IconVariable]) throws {
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
        
        logger.info("Calculating solar radiation field")
        // We only caculate a 24 hour radiation field. For ICON global, this already requires 400 MB memory
        let solar_backwards = domain == .iconD2 ? [] : Zensun.calculateRadiationBackwardsAveraged(grid: grid, timerange: TimerangeDt(start: run, nTime: 24, dtSeconds: 3600))
        //let solar_instant = domain == .iconD2 ? [] : Meteorology.calculateRadiationInstant(grid: grid, startTime: initTimeUnix, nTime: 24, dtSeconds: 3600)
        logger.info("Solar radiation field calculated")
        //let sol2d = Array2DFastSpace(data: solar_instant, nLocations: grid.count, nTime: 24)
        //try! sol2d.writeNetcdf(filename: "\(domain.omfileDirectory)solfac.nc", nx: grid.nx, ny: grid.ny)
        //return

        for variable in variables {
            logger.info("Converting \(variable)")
            
            let v = variable.omFileName.uppercased()

            /// space oriented, but after 72 hours only 3 hour values are filled.
            /// 2.86GB high water for this array
            var data2d = Array2DFastSpace(
                data: [Float](repeating: .nan, count: nLocation * nForecastHours),
                nLocations: nLocation,
                nTime: nForecastHours
            )

            for hour in forecastSteps {
                if hour == 0 && variable.skipHour0 {
                    continue
                }
                let h3 = hour.zeroPadded(len: 3)
                let d = try FloatArrayCompressor.read(file: "\(downloadDirectory)single-level_\(h3)_\(v).fpg", nElements: nLocation)
                data2d.data[hour * nLocation ..< (hour+1) * nLocation] = ArraySlice(d)
            }
            
            // Deaverage radiation. Not really correct for 3h data after 81 hours.
            if variable.isAveragedOverForecastTime {
                for l in 0..<nLocation {
                    var prev = data2d.data[l].isNaN ? 0 : data2d.data[l]
                    var skipped = 0
                    for hour in 1 ..< nForecastHours {
                        let d = data2d.data[hour * nLocation + l] * Float(hour)
                        if d.isNaN {
                            skipped += 1
                            continue
                        }
                        data2d.data[hour * nLocation + l] = (d - prev) / Float(skipped+1)
                        prev = d
                        skipped = 0
                    }
                }
            }
            
            // interpolate missing timesteps. We always fill 2 timesteps at once
            // data looks like: DDDDDDDDDD--D--D--D--D--D
            for hour in 0..<nForecastHours {
                if forecastSteps.contains(hour) {
                    continue
                }
                guard hour % 3 == 1 else {
                    // process 2 timesteps at once
                    continue
                }
                switch variable.interpolationType {
                case .linear:
                    for l in 0..<nLocation {
                        let prev = data2d.data[(hour-1) * nLocation + l]
                        let next = data2d.data[(hour+2) * nLocation + l]
                        data2d.data[hour * nLocation + l] = prev * 2/3 + next * 1/3
                        data2d.data[(hour+1) * nLocation + l] = prev * 1/3 + next * 2/3
                    }
                case .nearest:
                    // fill with next hour. For weather code, we fill with the next hour, because this represents precipitation
                    for l in 0..<nLocation {
                        let next = data2d.data[(hour+2) * nLocation + l]
                        data2d.data[hour * nLocation + l] = next
                        data2d.data[(hour+1) * nLocation + l] = next
                    }
                case .solar_backwards_averaged:
                    // Solar backwards averages data. Data needs to be deaveraged before
                    // First the clear sky index KT is calaculated (KT based on extraterrestrial radiation)
                    // clearsky index is hermite interpolated and then back to actual radiation
                    for l in 0..<nLocation {
                        // point C and D are still 3 h averages
                        let solC1 = (solar_backwards[(hour % 24) * nLocation + l])
                        let solC2 = (solar_backwards[((hour+1) % 24) * nLocation + l])
                        let solC3 = (solar_backwards[((hour+2) % 24) * nLocation + l])
                        let solC = (solC1 + solC2 + solC3) / 3
                        let C = solC <= 0.0001 ? 0 : data2d.data[(hour+2) * nLocation + l] / solC
                        
                        let solB = (solar_backwards[((hour-1) % 24) * nLocation + l])
                        let B = solB <= 0.0001 ? C : data2d.data[(hour-1) * nLocation + l] / solB
                        
                        let solA = (solar_backwards[((hour-4) % 24) * nLocation + l])
                        let A = solA <= 0.0001 || hour-4 < 0 ? B : data2d.data[(hour-4) * nLocation + l] / solA
                        
                        let solD1 = (solar_backwards[((hour+3) % 24) * nLocation + l])
                        let solD2 = (solar_backwards[((hour+4) % 24) * nLocation + l])
                        let solD3 = (solar_backwards[((hour+5) % 24) * nLocation + l])
                        let solD = (solD1 + solD2 + solD3) / 3
                        let D = solD <= 0.0001 || hour+4 >= nForecastHours ? C : data2d.data[(hour+5) * nLocation + l] / solD
                        
                        let a = -A/2.0 + (3.0*B)/2.0 - (3.0*C)/2.0 + D/2.0
                        let b = A - (5.0*B)/2.0 + 2.0*C - D / 2.0
                        let c = -A/2.0 + C/2.0
                        let d = B
                        
                        data2d.data[hour * nLocation + l] = (a*0.3*0.3*0.3 + b*0.3*0.3 + c*0.3 + d) * solC1
                        data2d.data[(hour+1) * nLocation + l] = (a*0.6*0.6*0.6 + b*0.6*0.6 + c*0.6 + d) * solC2
                        data2d.data[(hour+2) * nLocation + l] = C * solC3
                    }
                case .hermite:
                    for l in 0..<nLocation {
                        let A = data2d.data[(hour-4 < 0 ? hour-1 : hour-4) * nLocation + l]
                        let B = data2d.data[(hour-1) * nLocation + l]
                        let C = data2d.data[(hour+2) * nLocation + l]
                        let D = data2d.data[(hour+4 >= nForecastHours ? hour+2 : hour+5) * nLocation + l]
                        let a = -A/2.0 + (3.0*B)/2.0 - (3.0*C)/2.0 + D/2.0
                        let b = A - (5.0*B)/2.0 + 2.0*C - D / 2.0
                        let c = -A/2.0 + C/2.0
                        let d = B
                        data2d.data[hour * nLocation + l] = a*0.3*0.3*0.3 + b*0.3*0.3 + c*0.3 + d
                        data2d.data[(hour+1) * nLocation + l] = a*0.6*0.6*0.6 + b*0.6*0.6 + c*0.6 + d
                    }
                case .hermite_backwards_averaged:
                    /// basically shift the backwards averaged to the center and then do hermite
                    for l in 0..<nLocation {
                        let A = data2d.data[(hour-5 < 0 ? hour-2 : hour-5) * nLocation + l]
                        let B = data2d.data[(hour-2) * nLocation + l]
                        let C = data2d.data[(hour+2) * nLocation + l]
                        let D = data2d.data[(hour+4 >= nForecastHours ? hour+2 : hour+5) * nLocation + l]
                        let a = -A/2.0 + (3.0*B)/2.0 - (3.0*C)/2.0 + D/2.0
                        let b = A - (5.0*B)/2.0 + 2.0*C - D / 2.0
                        let c = -A/2.0 + C/2.0
                        let d = B
                        data2d.data[(hour-1) * nLocation + l] = a*0.3*0.3*0.3 + b*0.3*0.3 + c*0.3 + d
                        data2d.data[(hour) * nLocation + l] = a*0.6*0.6*0.6 + b*0.6*0.6 + c*0.6 + d
                        data2d.data[(hour+1) * nLocation + l] = C
                    }
                }
            }
            
            /// Temperature is stored in kelvin. Convert to celsius
            if variable == .temperature_2m || variable == .dewpoint_2m || variable == .soil_temperature_0cm || variable == .soil_temperature_6cm || variable == .soil_temperature_18cm || variable == .soil_temperature_54cm {
                for i in data2d.data.indices {
                    data2d.data[i] -= 273.15
                }
            }
            // convert to hPa
            if variable == .pressure_msl {
                for i in data2d.data.indices {
                    data2d.data[i] /= 100
                }
            }

            if variable == .soil_moisture_0_1cm {
                for i in data2d.data.indices {
                    // 1cm depth
                    data2d.data[i] *= (0.001 / 0.01)
                }
            }
            if variable == .soil_moisture_1_3cm {
                for i in data2d.data.indices {
                    // 2cm depth
                    data2d.data[i] *= (0.001 / 0.02)
                }
            }
            if variable == .soil_moisture_3_9cm {
                for i in data2d.data.indices {
                    // 6cm depth
                    data2d.data[i] *= (0.001 / 0.06)
                }
            }
            if variable == .soil_moisture_9_27cm {
                for i in data2d.data.indices {
                    // 18cm depth
                    data2d.data[i] *= (0.001 / 0.18)
                }
            }
            if variable == .soil_moisture_27_81cm {
                for i in data2d.data.indices {
                    // 54cm depth
                    data2d.data[i] *= (0.001 / 0.54)
                }
            }
            
            // scale upper level wind
            // In icon global and eu the level actually are 98 and 174 meter
            /*if variable == .u_80m || variable == .v_80m {
                let scale = Meteorology.scaleWindFactor(from: domain == .iconEu ? 78 : 98, to: 80)
                for i in data2d.data.indices {
                    data2d.data[i] *= scale
                }
            }
            if variable == .u_120m || variable == .v_120m {
                let scale = Meteorology.scaleWindFactor(from: domain == .iconEu ? 126 : 174, to: 120)
                for i in data2d.data.indices {
                    data2d.data[i] *= scale
                }
            }*/
            
            // De-accumulate precipitation
            if variable.isAccumulatedSinceModelStart {
                for hour in stride(from: nForecastHours - 1, through: 2, by: -1) {
                    for l in 0..<nLocation {
                        let current = data2d.data[hour * nLocation + l]
                        let previous = data2d.data[(hour-1) * nLocation + l]
                        // due to floating point precision, it can become negative
                        data2d.data[hour * nLocation + l] = max(current - previous, 0)
                    }
                }
            }
            
            /*#if Xcode
            try! data2d.writeNetcdf(filename: "\(domain.omfileDirectory)\(v).nc", nx: grid.nx, ny: grid.ny)
            return
            #endif*/
            
            let ringtime = run.timeIntervalSince1970 / 3600 ..< run.timeIntervalSince1970 / 3600 + nForecastHours
            let skip = variable.skipHour0 ? 1 : 0
            /// the last hour in D2 is broken for latent heat flux and sensible heatflux -> 2022-06-07: fluxes are ok in D2, actually skipLast feature was buggy
            //let skipLast = (variable == .ashfl_s || variable == .alhfl_s) && domain == .iconD2 ? 1 : 0
            let skipLast = 0
            
            logger.info("Create om file")
            let startOm = DispatchTime.now()
            try om.updateFromSpaceOriented(variable: variable.omFileName, array2d: data2d, ringtime: ringtime, skipFirst: skip, smooth: 0, skipLast: skipLast, scalefactor: variable.scalefactor)
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
        
        let onlyVariables: [IconVariable]? = signature.onlyVariables.map {
            $0.split(separator: ",").map {
                guard let variable = IconVariable(rawValue: String($0)) else {
                    fatalError("Invalid variable '\($0)'")
                }
                return variable
            }
        }
        
        let variables = onlyVariables ?? IconVariable.allCases
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
