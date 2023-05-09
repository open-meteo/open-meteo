import Foundation
import SwiftPFor2D
import Vapor


/**
 Download from
 https://confluence.ecmwf.int/display/UDOC/ECMWF+Open+Data+-+Real+Time
 https://data.ecmwf.int/forecasts/20220831/00z/0p4-beta/oper/
 
 model info (not everything is open data) https://www.ecmwf.int/en/forecasts/datasets/set-i
 */
struct DownloadEcmwfCommand: AsyncCommandFix {
    struct Signature: CommandSignature {
        @Option(name: "run")
        var run: String?
        
        @Option(name: "domain")
        var domain: String?
        
        @Option(name: "server", help: "Root server path. Default: 'https://data.ecmwf.int/forecasts/'")
        var server: String?

        @Flag(name: "skip-existing")
        var skipExisting: Bool
        
        @Flag(name: "upper-level", help: "Download upper-level variables on pressure levels for ensemble model")
        var upperLevel: Bool
        
        @Option(name: "only-variables")
        var onlyVariables: String?
    }

    var help: String {
        "Download a specified ecmwf model run"
    }
    
    func run(using context: CommandContext, signature: Signature) async throws {
        disableIdleSleep()
        
        let domain = signature.domain.map {
            guard let domain = EcmwfDomain(rawValue: $0) else {
                fatalError("Could not initialise domain from \($0)")
            }
            return domain
        } ?? EcmwfDomain.ifs04
        
        let run = try signature.run.flatMap(Timestamp.fromRunHourOrYYYYMMDD) ?? domain.lastRun
        
        let logger = context.application.logger

        logger.info("Downloading domain ECMWF run '\(run.iso8601_YYYY_MM_dd_HH_mm)'")
        
        let onlyVariables = try EcmwfVariable.load(commaSeparatedOptional: signature.onlyVariables)
        let surfaceVariables = EcmwfVariable.allCases.filter({($0.level ?? 0) < 50})
        let pressureVariables = EcmwfVariable.allCases.filter({($0.level ?? 0) >= 50})
        let defaultVariables = domain == .ifs04_ensemble ? (signature.upperLevel ? pressureVariables : surfaceVariables) : EcmwfVariable.allCases
        let variables = onlyVariables ?? defaultVariables
        
        let base = signature.server ?? "https://data.ecmwf.int/forecasts/"

        try FileManager.default.createDirectory(atPath: domain.downloadDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(atPath: domain.omfileDirectory, withIntermediateDirectories: true)
        try await downloadEcmwfElevation(application: context.application, domain: domain, base: base, run: run)
        try await downloadEcmwf(application: context.application, domain: domain, base: base, run: run, skipFilesIfExisting: signature.skipExisting, variables: variables)
        try convertEcmwf(logger: logger, domain: domain, run: run, variables: variables)
    }
    
    /// Download elevation file
    func downloadEcmwfElevation(application: Application, domain: EcmwfDomain, base: String, run: Timestamp) async throws {
        let logger = application.logger
        let surfaceElevationFileOm = domain.surfaceElevationFileOm
        if FileManager.default.fileExists(atPath: surfaceElevationFileOm) {
            return
        }
        try FileManager.default.createDirectory(atPath: domain.omfileDirectory, withIntermediateDirectories: true)
        let curl = Curl(logger: logger, client: application.dedicatedHttpClient)
        
        var generateElevationFileData: (lsm: [Float]?, surfacePressure: [Float]?, sealevelPressure: [Float]?, temperature_2m: [Float]?) = (nil, nil, nil, nil)
        var grib2d = GribArray2D(nx: domain.grid.nx, ny: domain.grid.ny)
        
        logger.info("Downloading height and elevation data")
        let url = domain.getUrl(base: base, run: run, hour: 0)
        for message in try await curl.downloadEcmwfIndexed(url: url, isIncluded: { entry in
            guard entry.number == nil else {
                // ignore ensemble members, only use control
                return false
            }
            return entry.levtype == .sfc && ["lsm", "2t", "sp", "msl"].contains(entry.param)
        }) {
            let shortName = message.get(attribute: "shortName")!
            try grib2d.load(message: message)
            grib2d.array.flipLatitude()
            
            switch shortName {
            case "lsm":
                generateElevationFileData.lsm = grib2d.array.data
            case "2t":
                grib2d.array.data.multiplyAdd(multiply: 1, add: -273.15)
                generateElevationFileData.temperature_2m = grib2d.array.data
            case "sp":
                grib2d.array.data.multiplyAdd(multiply: 1/100, add: 0)
                generateElevationFileData.surfacePressure = grib2d.array.data
            case "msl":
                grib2d.array.data.multiplyAdd(multiply: 1/100, add: 0)
                generateElevationFileData.sealevelPressure = grib2d.array.data
            default:
                fatalError("Received too many grib messages \(shortName)")
            }
        }
        logger.info("Generating elevation file")
        guard let lsm = generateElevationFileData.lsm else {
            fatalError("Did not get LSM data")
        }
        guard let surfacePressure = generateElevationFileData.surfacePressure,
              let sealevelPressure = generateElevationFileData.sealevelPressure,
              let temperature_2m = generateElevationFileData.temperature_2m else {
            fatalError("Did not get pressure data")
        }
        let elevation: [Float] = zip(zip(surfacePressure, sealevelPressure), zip(temperature_2m, lsm)).map {
            let ((surfacePressure, sealevelPressure), (temperature_2m, landmask)) = $0
            return landmask < 0.5 ? -999 : Meteorology.elevation(sealevelPressure: sealevelPressure, surfacePressure: surfacePressure, temperature_2m: temperature_2m)
        }
        try Array2DFastSpace(data: elevation, nLocations: domain.grid.count, nTime: 1).writeNetcdf(filename: "\(domain.downloadDirectory)/elevation.nc", nx: domain.grid.nx, ny: domain.grid.ny)
        try OmFileWriter(dim0: domain.grid.ny, dim1: domain.grid.nx, chunk0: 20, chunk1: 20).write(file: domain.surfaceElevationFileOm, compressionType: .p4nzdec256, scalefactor: 1, all: elevation)
    }
    
    /// Download ECMWF ifs open data
    func downloadEcmwf(application: Application, domain: EcmwfDomain, base: String, run: Timestamp, skipFilesIfExisting: Bool, variables: [EcmwfVariable]) async throws {
        let logger = application.logger
        let curl = Curl(logger: logger, client: application.dedicatedHttpClient)
        let downloadDirectory = domain.downloadDirectory
        let forecastSteps = domain.getDownloadForecastSteps(run: run.hour)
        var grib2d = GribArray2D(nx: domain.grid.nx, ny: domain.grid.ny)
        let nLocationsPerChunk = OmFileSplitter(basePath: domain.omfileDirectory, nLocations: domain.grid.count, nTimePerFile: domain.omFileLength, yearlyArchivePath: nil).nLocationsPerChunk
        let writer = OmFileWriter(dim0: 1, dim1: domain.grid.count, chunk0: 1, chunk1: nLocationsPerChunk)
        
        for hour in forecastSteps {
            logger.info("Downloading hour \(hour)")
            
            let variables = variables.filter { variable in
                let file = "\(downloadDirectory)\(variable.omFileName.file)_\(hour).om"
                return !skipFilesIfExisting || FileManager.default.fileExists(atPath: file)
            }
            if variables.isEmpty {
                continue
            }
            let url = domain.getUrl(base: base, run: run, hour: hour)
            for message in try await curl.downloadEcmwfIndexed(url: url, isIncluded: { entry in
                return variables.contains(where: { variable in
                    if let level = entry.level {
                        // entry is a pressure level variable
                        return variable.level == level && entry.param == variable.gribName
                    }
                    return entry.param == variable.gribName
                })
            }) {
                let shortName = message.get(attribute: "shortName")!
                let levelhPa = message.get(attribute: "level").flatMap(Int.init)!
                let member = message.get(attribute: "perturbationNumber").flatMap(Int.init) ?? 0
                
                guard let variable = variables.first(where: { variable in
                    if variable == .total_column_integrated_water_vapour && shortName == "tcwv" {
                        return true
                    }
                    return shortName == variable.gribName && levelhPa == (variable.level ?? 0)
                }) else {
                    print(
                        message.get(attribute: "name")!,
                        message.get(attribute: "shortName")!,
                        message.get(attribute: "level")!,
                        message.get(attribute: "paramId")!
                    )
                    if message.get(attribute: "name") == "unknown" {
                        message.iterate(namespace: .ls).forEach({print($0)})
                        message.iterate(namespace: .parameter).forEach({print($0)})
                        message.iterate(namespace: .mars).forEach({print($0)})
                        message.iterate(namespace: .all).forEach({print($0)})
                    }
                    fatalError("Got unknown variable \(shortName) \(levelhPa)")
                }
                //logger.info("Processing \(variable)")
                
                try grib2d.load(message: message)
                grib2d.array.flipLatitude()
                
                // Scaling before compression with scalefactor
                if let fma = variable.multiplyAdd {
                    grib2d.array.data.multiplyAdd(multiply: fma.multiply, add: fma.add)
                }
                
                let memberStr = member > 0 ? "_\(member)" : ""
                let file = "\(downloadDirectory)\(variable.omFileName.file)_\(hour)\(memberStr).om"
                try FileManager.default.removeItemIfExists(at: file)
                
                let compression = variable.isAccumulatedSinceModelStart ? CompressionType.fpxdec32 : .p4nzdec256
                try writer.write(file: file, compressionType: compression, scalefactor: variable.scalefactor, all: grib2d.array.data)
            }
        }
        curl.printStatistics()
    }
    
    func convertEcmwf(logger: Logger, domain: EcmwfDomain, run: Timestamp, variables: [EcmwfVariable]) throws {
        let downloadDirectory = domain.downloadDirectory
        let nMembers = domain.ensembleMembers
        
        let forecastSteps = domain.getDownloadForecastSteps(run: run.hour)
        let nTime = forecastSteps.max()! / domain.dtHours + 1
        
        let time = TimerangeDt(start: run, nTime: nTime, dtSeconds: domain.dtSeconds)
        
        let nLocations = domain.grid.nx * domain.grid.ny
        
        let om = OmFileSplitter(basePath: domain.omfileDirectory, nLocations: nLocations * nMembers, nTimePerFile: domain.omFileLength, yearlyArchivePath: nil, chunknLocations: nMembers > 1 ? nMembers : nil)
        let nLocationsPerChunk = om.nLocationsPerChunk
        
        var data3d = Array3DFastTime(nLocations: nLocationsPerChunk, nLevel: nMembers, nTime: nTime)
        var readTemp = [Float](repeating: .nan, count: nLocationsPerChunk)
        
        for variable in variables {
            let progress = ProgressTracker(logger: logger, total: nLocations * nMembers, label: "Convert \(variable.rawValue)")
            let skip = 0
        
            let readers: [(hour: Int, reader: [OmFileReader<MmapFile>])] = try forecastSteps.compactMap({ hour in
                let readers = try (0..<nMembers).map { member in
                    let memberStr = member > 0 ? "_\(member)" : ""
                    return try OmFileReader(file: "\(downloadDirectory)\(variable.omFileName.file)_\(hour)\(memberStr).om")
                }
                return (hour, readers)
            })
            
            let interpolationHours = (0..<nTime).compactMap { hour -> Int? in
                if forecastSteps.contains(hour * domain.dtHours) {
                    return nil
                }
                return hour
            }
            
            try om.updateFromTimeOrientedStreaming(variable: variable.omFileName.file, indexTime: time.toIndexTime(), skipFirst: skip, smooth: 0, skipLast: 0, scalefactor: variable.scalefactor) { offset in
                let d0offset = offset / nMembers
                
                let locationRange = d0offset ..< min(d0offset+nLocationsPerChunk, nLocations)
                data3d.data.fillWithNaNs()
                for reader in readers {
                    for (i, memberReader) in reader.reader.enumerated() {
                        try memberReader.read(into: &readTemp, arrayRange: 0..<locationRange.count, arrayDim1Length: locationRange.count, dim0Slow: 0..<1, dim1: locationRange)
                        data3d[0..<data3d.nLocations, i, reader.hour / domain.dtHours] = readTemp
                    }
                }
                
                data3d.interpolate1Step(interpolation: variable.interpolation, interpolationHours: interpolationHours, width: 1, time: time, grid: domain.grid, locationRange: locationRange)
                
                // De-accumulate precipitation
                if variable.isAccumulatedSinceModelStart {
                    data3d.deaccumulateOverTime(slidingWidth: data3d.nTime, slidingOffset: 0)
                }
                
                progress.add(locationRange.count * nMembers)
                return data3d.data[0..<locationRange.count * nTime * nMembers]
            }
            progress.finish()
        }
        
        var indexTimeEnd = run.timeIntervalSince1970 + 241 * 3600
        if run.hour == 6 || run.hour == 18 {
            // run 6 and 18 only have 90 instead 240
            indexTimeEnd += (240 - 90) * 3600
        }
        let indexTimeStart = indexTimeEnd - domain.omFileLength * domain.dtSeconds + 12 * 3600
        try "\(run.timeIntervalSince1970),\(domain.omFileLength),\(indexTimeStart),\(indexTimeEnd)".write(toFile: "\(domain.omfileDirectory)init.txt", atomically: true, encoding: .utf8)
    }
}

extension EcmwfDomain {
    /// Based on the current time , guess the current run that should be available soon on the open-data server
    fileprivate var lastRun: Timestamp {
        // 18z run starts downloading on the next day
        let twoHoursAgo = Timestamp.now().add(-7200)
        let t = Timestamp.now()
        switch self {
        case .ifs04_ensemble:
            fallthrough
        case .ifs04:
            // ECMWF has a delay of 7-8 hours after initialisation
            return twoHoursAgo.with(hour: ((t.hour - 7 + 24) % 24) / 6 * 6)
        }
    }
    /// Get download url for a given domain and timestep
    fileprivate func getUrl(base: String, run: Timestamp, hour: Int) -> String {
        let runStr = run.hour.zeroPadded(len: 2)
        let dateStr = run.format_YYYYMMdd
        switch self {
        case .ifs04:
            let product = run.hour == 0 || run.hour == 12 ? "oper" : "scda"
            return "\(base)\(dateStr)/\(runStr)z/0p4-beta/\(product)/\(dateStr)\(runStr)0000-\(hour)h-\(product)-fc.grib2"
        case .ifs04_ensemble:
            return "\(base)\(dateStr)/\(runStr)z/0p4-beta/enfo/\(dateStr)\(runStr)0000-\(hour)h-enfo-ef.grib2"
        }
    }
}
