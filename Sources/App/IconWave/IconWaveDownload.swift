import Foundation
import Vapor
import SwiftNetCDF
import SwiftPFor2D


/**
 Download wave model form the german weather service
 https://www.dwd.de/DE/leistungen/opendata/help/modelle/legend_ICON_wave_EN_pdf.pdf?__blob=publicationFile&v=3
 
 All equations: https://library.wmo.int/doc_num.php?explnum_id=10979
 */
struct DownloadIconWaveCommand: AsyncCommand {
    struct Signature: CommandSignature {
        @Argument(name: "domain")
        var domain: String

        @Option(name: "run")
        var run: String?

        @Flag(name: "skip-existing", help: "ONLY FOR TESTING! Do not use in production. May update the database with stale data")
        var skipExisting: Bool
        
        @Option(name: "only-variables")
        var onlyVariables: String?
        
        @Option(name: "upload-s3-bucket", help: "Upload open-meteo database to an S3 bucket after processing")
        var uploadS3Bucket: String?
    }

    var help: String {
        "Download a specified wave model run"
    }
    
    func run(using context: CommandContext, signature: Signature) async throws {
        let domain = try IconWaveDomain.load(rawValue: signature.domain)
        
        let run = signature.run.map {
            guard let run = Int($0) else {
                fatalError("Invalid run '\($0)'")
            }
            return run
        } ?? domain.lastRun
        
        let onlyVariables = try IconWaveVariable.load(commaSeparatedOptional: signature.onlyVariables)
        
        let logger = context.application.logger
        let date = Timestamp.now().with(hour: run)
        logger.info("Downloading domain '\(domain.rawValue)' run '\(date.iso8601_YYYY_MM_dd_HH_mm)'")
        
        let variables = onlyVariables ?? IconWaveVariable.allCases
        try await download(application: context.application, domain: domain, run: date, skipFilesIfExisting: signature.skipExisting, variables: variables)
        try convert(logger: logger, domain: domain, run: date, variables: variables)
        
        if let uploadS3Bucket = signature.uploadS3Bucket {
            try domain.domainRegistry.syncToS3(bucket: uploadS3Bucket, variables: variables)
        }
    }
    
    /// Download all timesteps and preliminarily covnert it to compressed files
    func download(application: Application, domain: IconWaveDomain, run: Timestamp, skipFilesIfExisting: Bool, variables: [IconWaveVariable]) async throws {
        // https://opendata.dwd.de/weather/maritime/wave_models/gwam/grib/00/mdww/GWAM_MDWW_2022072800_000.grib2.bz2
        // https://opendata.dwd.de/weather/maritime/wave_models/ewam/grib/00/mdww/EWAM_MDWW_2022072800_000.grib2.bz2
        let baseUrl = "http://opendata.dwd.de/weather/maritime/wave_models/\(domain.rawValue)/grib/\(run.hour.zeroPadded(len: 2))/"
        let logger = application.logger
        try FileManager.default.createDirectory(atPath: domain.downloadDirectory, withIntermediateDirectories: true)
        
        let curl = Curl(logger: logger, client: application.dedicatedHttpClient)
        let nLocationsPerChunk = OmFileSplitter(domain).nLocationsPerChunk
        let nx = domain.grid.nx
        let ny = domain.grid.ny
        
        let writer = OmFileWriter(dim0: 1, dim1: domain.grid.count, chunk0: 1, chunk1: nLocationsPerChunk)
        
        var grib2d = GribArray2D(nx: nx, ny: ny)
        
        for forecastStep in 0..<domain.countForecastHours {
            /// E.g. 0,3,6...174 for gwam
            let forecastHour = forecastStep * domain.dtHours
            logger.info("Downloading hour \(forecastHour)")
            
            for variable in variables {
                let url = "\(baseUrl)\(variable.dwdName)/\(domain.rawValue.uppercased())_\(variable.dwdName.uppercased())_\(run.format_YYYYMMddHH)_\(forecastHour.zeroPadded(len: 3)).grib2.bz2"
                
                let fileDest = "\(domain.downloadDirectory)\(variable.rawValue)_\(forecastHour).om"
                if skipFilesIfExisting && FileManager.default.fileExists(atPath: fileDest) {
                    continue
                }
                
                let message = try await curl.downloadGrib(url: url, bzip2Decode: true)[0]
                try grib2d.load(message: message)
                if domain == .gwam {
                    grib2d.array.shift180LongitudeAndFlipLatitude()
                } else {
                    grib2d.array.flipLatitude()
                }
                
                /// Create elevation file for sea mask
                if !FileManager.default.fileExists(atPath: domain.surfaceElevationFileOm.getFilePath()) {
                    var elevation = grib2d.array.data
                    for i in elevation.indices {
                        /// `NaN` out of domain, `-999` sea grid point
                        elevation[i] = elevation[i].isNaN ? .nan : -999
                    }
                    //let data2d = Array2DFastSpace(data: elevation, nLocations: elevation.count, nTime: 1)
                    //try data2d.writeNetcdf(filename: "\(downloadDirectory)elevation.nc", nx: nx, ny: ny)
                    try OmFileWriter(dim0: domain.grid.ny, dim1: domain.grid.nx, chunk0: 20, chunk1: 20).write(file: domain.surfaceElevationFileOm.getFilePath(), compressionType: .p4nzdec256, scalefactor: 1, all: elevation)
                }
                
                // Save temporarily as compressed om files
                try FileManager.default.removeItemIfExists(at: fileDest)
                try writer.write(file: fileDest, compressionType: .p4nzdec256, scalefactor: variable.scalefactor, all: grib2d.array.data)
            }
        }
        await curl.printStatistics()
    }
    
    /// Process each variable and update time-series optimised files
    func convert(logger: Logger, domain: IconWaveDomain, run: Timestamp, variables: [IconWaveVariable]) throws {        
        let nLocations = domain.grid.count
        let om = OmFileSplitter(domain)
        let nLocationsPerChunk = om.nLocationsPerChunk
        let nTime = domain.countForecastHours
        let time = TimerangeDt(start: run, nTime: nTime, dtSeconds: domain.dtSeconds)
        
        var data2d = Array2DFastTime(nLocations: nLocationsPerChunk, nTime: nTime)
        var readTemp = [Float](repeating: .nan, count: nLocationsPerChunk)
        
        let forecastHours = stride(from: 0, to: domain.countForecastHours * domain.dtHours, by: domain.dtHours)
        
        for variable in variables {
            let progress = ProgressTracker(logger: logger, total: nLocations, label: "Convert \(variable.rawValue)")
            let skip = 0

            let readers: [(hour: Int, reader: OmFileReader<MmapFile>)] = try forecastHours.compactMap({ hour in
                let reader = try OmFileReader(file: "\(domain.downloadDirectory)\(variable.rawValue)_\(hour).om")
                try reader.willNeed()
                return (hour, reader)
            })
            
            try om.updateFromTimeOrientedStreaming(variable: variable.omFileName.file, time: time, skipFirst: skip, scalefactor: variable.scalefactor, storePreviousForecast: variable.storePreviousForecast) { d0offset in
                
                let locationRange = d0offset ..< min(d0offset+nLocationsPerChunk, nLocations)
                data2d.data.fillWithNaNs()
                for reader in readers {
                    try reader.reader.read(into: &readTemp, arrayRange: 0..<locationRange.count, arrayDim1Length: locationRange.count, dim0Slow: 0..<1, dim1: locationRange)
                    data2d[0..<data2d.nLocations, reader.hour / domain.dtHours] = readTemp
                }

                progress.add(locationRange.count)
                return data2d.data[0..<locationRange.count * nTime]
            }
            progress.finish()
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
