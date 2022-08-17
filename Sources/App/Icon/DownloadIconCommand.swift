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
            

            switch variable.interpolationType {
            case .linear:
                data2d.interpolate2StepsLinear(positions: forecastStepsToInterpolate)
            case .nearest:
                data2d.interpolate2StepsNearest(positions: forecastStepsToInterpolate)
            case .solar_backwards_averaged:
                data2d.interpolate2StepsSolarBackwards(positions: forecastStepsToInterpolate, grid: domain.grid, run: run, dtSeconds: domain.dtSeconds)
            case .hermite:
                data2d.interpolate2StepsHermite(positions: forecastStepsToInterpolate)
            case .hermite_backwards_averaged:
                data2d.interpolate2StepsHermiteBackwardsAveraged(positions: forecastStepsToInterpolate)
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

extension Array2DFastTime {
    mutating func deavergeOverTime(slidingWidth: Int, slidingOffset: Int) {
        for l in 0..<nLocations {
            for start in stride(from: slidingOffset, to: nTime, by: slidingWidth) {
                var prev = self[l, start].isNaN ? 0 : self[l, start]
                var prevH = 1
                var skipped = 0
                for hour in start+1 ..< start+slidingWidth {
                    let d = self[l, hour]
                    let h = hour-start+1
                    if d.isNaN {
                        skipped += 1
                        continue
                    }
                    self[l, hour] = (d * Float(h / (skipped+1)) - prev * Float(prevH / (skipped+1)))
                    prev = d
                    prevH = h
                    skipped = 0
                }
            }
        }
    }
    
    /// Note: Enforces >0
    mutating func deaccumulateOverTime(slidingWidth: Int, slidingOffset: Int) {
        for l in 0..<nLocations {
            for start in stride(from: slidingOffset, to: nTime, by: slidingWidth) {
                for hour in stride(from: start + slidingWidth - 1, through: start + 1, by: -1) {
                    let current = self[l, hour]
                    let previous = self[l, hour-1]
                    // due to floating point precision, it can become negative
                    self[l, hour] = previous.isNaN ? current : max(current - previous, 0)
                }
            }
        }
    }
    
    /// 2 poisitions are interpolated in one step. Steps should align to `hour % 3 == 1`
    mutating func interpolate2StepsLinear(positions: [Int]) {
        for l in 0..<nLocations {
            for hour in positions {
                let prev = self[l, hour-1]
                let next = self[l, hour+2]
                self[l, hour] = prev * 2/3 + next * 1/3
                self[l, hour+1] = prev * 1/3 + next * 2/3
            }
        }
    }
    
    /// 2 poisitions are interpolated in one step. Steps should align to `hour % 3 == 1`
    mutating func interpolate2StepsHermite(positions: [Int]) {
        for l in 0..<nLocations {
            for hour in positions {
                let A = self[l, hour-4 < 0 ? hour-1 : hour-4]
                let B = self[l, hour-1]
                let C = self[l, hour+2]
                let D = self[l, hour+4 >= nTime ? hour+2 : hour+5]
                let a = -A/2.0 + (3.0*B)/2.0 - (3.0*C)/2.0 + D/2.0
                let b = A - (5.0*B)/2.0 + 2.0*C - D / 2.0
                let c = -A/2.0 + C/2.0
                let d = B
                self[l, hour] = a*0.3*0.3*0.3 + b*0.3*0.3 + c*0.3 + d
                self[l, hour+1] = a*0.6*0.6*0.6 + b*0.6*0.6 + c*0.6 + d
            }
        }
    }
    
    /// 2 poisitions are interpolated in one step. Steps should align to `hour % 3 == 1`
    mutating func interpolate2StepsHermiteBackwardsAveraged(positions: [Int]) {
        /// basically shift the backwards averaged to the center and then do hermite
        for l in 0..<nLocations {
            for hour in positions {
                let A = self[l, hour-5 < 0 ? hour-2 : hour-5]
                let B = self[l, hour-2]
                let C = self[l, hour+2]
                let D = self[l, hour+4 >= nTime ? hour+2 : hour+5]
                let a = -A/2.0 + (3.0*B)/2.0 - (3.0*C)/2.0 + D/2.0
                let b = A - (5.0*B)/2.0 + 2.0*C - D / 2.0
                let c = -A/2.0 + C/2.0
                let d = B
                self[l, hour-1] = a*0.3*0.3*0.3 + b*0.3*0.3 + c*0.3 + d
                self[l, hour] = a*0.6*0.6*0.6 + b*0.6*0.6 + c*0.6 + d
                self[l, hour+1] = C
            }
        }
    }
    
    /// 2 poisitions are interpolated in one step. Steps should align to `hour % 3 == 1`
    mutating func interpolate2StepsNearest(positions: [Int]) {
        // fill with next hour. For weather code, we fill with the next hour, because this represents precipitation
        for l in 0..<nLocations {
            for hour in positions {
                let next = self[l, hour+2]
                self[l, hour] = next
                self[l, hour+1] = next
            }
        }
    }
    
    /// 2 poisitions are interpolated in one step. Steps should align to `hour % 3 == 1`
    mutating func interpolate2StepsSolarBackwards(positions: [Int], grid: RegularGrid, run: Timestamp, dtSeconds: Int) {
        // Solar backwards averages data. Data needs to be deaveraged before
        // First the clear sky index KT is calaculated (KT based on extraterrestrial radiation)
        // clearsky index is hermite interpolated and then back to actual radiation
        
        /// Which range of hours solar radiation data is required
        let solarHours = positions.minAndMax().map { $0.min - 4 ..< $0.max + 7 } ?? 0..<0
        let solarTime = TimerangeDt(start: run.add(solarHours.lowerBound * dtSeconds), nTime: solarHours.count, dtSeconds: dtSeconds)
        
        /// Instead of caiculating solar radiation for the entire grid, itterate through a smaller grid portion
        let nx = grid.nx
        let byY = 1
        for cy in 0..<grid.ny/byY+1 {
            let yrange = cy*byY ..< min((cy+1)*byY, grid.ny)
            let locationRange = yrange.lowerBound * nx ..< yrange.upperBound * nx
            /// solar factor, backwards averaged over dt
            let solar2d = Zensun.calculateRadiationBackwardsAveraged(grid: grid, timerange: solarTime, yrange: yrange)
            
            for l in locationRange {
                for hour in positions {
                    let sHour = hour - solarHours.lowerBound
                    let sLocation = l - locationRange.lowerBound
                    // point C and D are still 3 h averages
                    let solC1 = solar2d[sLocation, sHour + 0]
                    let solC2 = solar2d[sLocation, sHour + 1]
                    let solC3 = solar2d[sLocation, sHour + 2]
                    let solC = (solC1 + solC2 + solC3) / 3
                    // At low radiaiton levels it is impossible to estimate KT indices
                    let C = solC <= 0.005 ? 0 : min(self[l, hour+2] / solC, 1100)
                    
                    let solB = solar2d[sLocation, sHour - 1]
                    let B = solB <= 0.005 ? 0 : min(self[l, hour-1] / solB, 1100)
                    
                    let solA = solar2d[sLocation, sHour - 4]
                    let A = solA <= 0.005 ? 0 : hour-4 < 0 ? B : min((self[l, hour-4] / solA), 1100)
                    
                    let solD1 = solar2d[sLocation, sHour + 3]
                    let solD2 = solar2d[sLocation, sHour + 4]
                    let solD3 = solar2d[sLocation, sHour + 5]
                    let solD = (solD1 + solD2 + solD3) / 3
                    let D = solD <= 0.005 ? 0 : hour+4 >= nTime ? C : min((self[l, hour+5] / solD), 1100)
                    
                    let a = -A/2.0 + (3.0*B)/2.0 - (3.0*C)/2.0 + D/2.0
                    let b = A - (5.0*B)/2.0 + 2.0*C - D / 2.0
                    let c = -A/2.0 + C/2.0
                    let d = B
                    
                    self[l, hour] = (a*0.3*0.3*0.3 + b*0.3*0.3 + c*0.3 + d) * solC1
                    self[l, hour+1] = (a*0.6*0.6*0.6 + b*0.6*0.6 + c*0.6 + d) * solC2
                    self[l, hour+2] = C * solC3
                }
            }
        }
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
