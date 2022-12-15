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
        
        @Option(name: "server", help: "Root server path. Default: 'https://data.ecmwf.int/forecasts/'")
        var server: String?

        @Flag(name: "skip-existing")
        var skipExisting: Bool
    }

    var help: String {
        "Download a specified ecmwf model run"
    }
    
    func run(using context: CommandContext, signature: Signature) async throws {
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
        
        let base = signature.server ?? "https://data.ecmwf.int/forecasts/"

        try await downloadEcmwf(application: context.application, base: base, run: date, skipFilesIfExisting: signature.skipExisting)
        try convertEcmwf(logger: logger, run: date)
    }
    
    func downloadEcmwf(application: Application, base: String, run: Timestamp, skipFilesIfExisting: Bool) async throws {
        let logger = application.logger
        let domain = EcmwfDomain.ifs04
        
        
        let dateStr = run.format_YYYYMMdd
        let curl = Curl(logger: logger, client: application.dedicatedHttpClient)
        let downloadDirectory = domain.downloadDirectory
        try FileManager.default.createDirectory(atPath: downloadDirectory, withIntermediateDirectories: true)
        
        let forecastSteps = domain.getDownloadForecastSteps(run: run.hour)
        
        let product = run.hour == 0 || run.hour == 12 ? "oper" : "scda"
        let runStr = run.hour.zeroPadded(len: 2)
        
        var grib2d = GribArray2D(nx: domain.grid.nx, ny: domain.grid.ny)
        
        let nLocationsPerChunk = OmFileSplitter(basePath: domain.omfileDirectory, nLocations: domain.grid.count, nTimePerFile: domain.omFileLength, yearlyArchivePath: nil).nLocationsPerChunk
        let writer = OmFileWriter(dim0: 1, dim1: domain.grid.count, chunk0: 1, chunk1: nLocationsPerChunk)
        
        for hour in forecastSteps {
            logger.info("Downloading hour \(hour)")
            
            let variables = EcmwfVariable.allCases.filter { variable in
                let file = "\(downloadDirectory)\(variable.omFileName)_\(hour).om"
                return !skipFilesIfExisting || FileManager.default.fileExists(atPath: file)
            }
            
            if variables.isEmpty {
                continue
            }
            
            //https://data.ecmwf.int/forecasts/20220831/00z/0p4-beta/oper/20220831000000-0h-oper-fc.grib2
            //https://data.ecmwf.int/forecasts/20220831/00z/0p4-beta/oper/20220831000000-12h-oper-fc.grib2
            let url = "\(base)\(dateStr)/\(runStr)z/0p4-beta/\(product)/\(dateStr)\(runStr)0000-\(hour)h-\(product)-fc.grib2"
            
            for message in try await curl.downloadGrib(url: url, bzip2Decode: false) {
                let shortName = message.get(attribute: "shortName")!
                let levelhPa = message.get(attribute: "level").flatMap(Int.init)!
                
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
                
                try grib2d.load(message: message)
                grib2d.array.flipLatitude()
                
                // Scaling before compression with scalefactor
                if let fma = variable.multiplyAdd {
                    grib2d.array.data.multiplyAdd(multiply: fma.multiply, add: fma.add)
                }
                
                let file = "\(downloadDirectory)\(variable.omFileName)_\(hour).om"
                try FileManager.default.removeItemIfExists(at: file)
                
                
                let compression = variable.isAccumulatedSinceModelStart ? CompressionType.fpxdec32 : .p4nzdec256
                try writer.write(file: file, compressionType: compression, scalefactor: variable.scalefactor, all: grib2d.array.data)
            }
        }
        curl.printStatistics()
    }
    
    func convertEcmwf(logger: Logger, run: Timestamp) throws {
        let domain = EcmwfDomain.ifs04
        let downloadDirectory = domain.downloadDirectory
        
        let forecastSteps = domain.getDownloadForecastSteps(run: run.hour)
        let nTime = forecastSteps.max()! / domain.dtHours + 1
        
        let time = TimerangeDt(start: run, nTime: nTime * domain.dtHours, dtSeconds: domain.dtSeconds)
        
        let nLocations = domain.grid.nx * domain.grid.ny
        let ringtime = run.timeIntervalSince1970 / domain.dtSeconds ..< run.timeIntervalSince1970 / domain.dtSeconds + nTime
        
        try FileManager.default.createDirectory(atPath: domain.omfileDirectory, withIntermediateDirectories: true)
        let om = OmFileSplitter(basePath: domain.omfileDirectory, nLocations: nLocations, nTimePerFile: domain.omFileLength, yearlyArchivePath: nil)
        let nLocationsPerChunk = om.nLocationsPerChunk
        
        var data2d = Array2DFastTime(nLocations: nLocationsPerChunk, nTime: nTime)
        var readTemp = [Float](repeating: .nan, count: nLocationsPerChunk)
        
        for variable in EcmwfVariable.allCases {
            let progress = ProgressTracker(logger: logger, total: nLocations, label: "Convert \(variable.rawValue)")
            let skip = 0
            
            let readers: [(hour: Int, reader: OmFileReader<MmapFile>)] = try forecastSteps.compactMap({ hour in
                let reader = try OmFileReader(file: "\(downloadDirectory)\(variable.omFileName)_\(hour).om")
                try reader.willNeed()
                return (hour, reader)
            })
            
            let interpolationHours = (0..<nTime).compactMap { hour -> Int? in
                if forecastSteps.contains(hour * domain.dtHours) {
                    return nil
                }
                return hour
            }
            
            try om.updateFromTimeOrientedStreaming(variable: variable.omFileName, ringtime: ringtime, skipFirst: skip, smooth: 0, skipLast: 0, scalefactor: variable.scalefactor) { d0offset in
                
                let locationRange = d0offset ..< min(d0offset+nLocationsPerChunk, nLocations)
                data2d.data.fillWithNaNs()
                for reader in readers {
                    try reader.reader.read(into: &readTemp, arrayRange: 0..<locationRange.count, dim0Slow: 0..<1, dim1: locationRange)
                    data2d[0..<data2d.nLocations, reader.hour / domain.dtHours] = readTemp
                }
                
                data2d.interpolate1Step(interpolation: variable.interpolation, interpolationHours: interpolationHours, width: 1, time: time, grid: domain.grid, locationRange: locationRange)
                
                // De-accumulate precipitation
                if variable.isAccumulatedSinceModelStart {
                    data2d.deaccumulateOverTime(slidingWidth: data2d.nTime, slidingOffset: 0)
                }
                
                progress.add(locationRange.count)
                return data2d.data[0..<locationRange.count * nTime]
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
    fileprivate var lastRun: Int {
        let t = Timestamp.now()
        switch self {
        case .ifs04:
            // ECMWF has a delay of 7-8 hours after initialisation
            return ((t.hour - 7 + 24) % 24) / 6 * 6
        }
    }
}
