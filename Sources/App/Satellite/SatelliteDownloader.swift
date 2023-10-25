import Foundation
import Vapor
import SwiftNetCDF
import SwiftPFor2D

/**
 Download satellite datasets like IMERG
 
 NASA auth:
 echo "machine urs.earthdata.nasa.gov login <uid> password <password>" >> ~/.netrc
 echo "HTTP.NETRC=/Users/patrick/.netrc\nHTTP.COOKIEJAR=/Users/patrick/.urs_cookies" > ~/.dodsrc
 chmod 0600 ~/.netrc
 chmod 0600 ~/.dodsrc
 */
struct SatelliteDownloadCommand: AsyncCommandFix {
    /// 6k locations require around 200 MB memory for a yearly time-series
    static var nLocationsPerChunk = 6_000
    
    struct Signature: CommandSignature {
        @Argument(name: "domain")
        var domain: String
        
        @Option(name: "timeinterval", short: "t", help: "Timeinterval to download with format 20220101-20220131")
        var timeinterval: String?
        
        @Option(name: "year", short: "y", help: "Download one year")
        var year: String?
        
        @Flag(name: "create-fixed-file")
        var createFixedFile: Bool
        
        /// Get the specified timerange in the command, or use the last 7 days as range
        func getTimeinterval() -> TimerangeDt {
            let dt = 3600*24
            if let timeinterval = timeinterval {
                guard timeinterval.count == 17, timeinterval.contains("-") else {
                    fatalError("format looks wrong")
                }
                let start = Timestamp(Int(timeinterval[0..<4])!, Int(timeinterval[4..<6])!, Int(timeinterval[6..<8])!)
                let end = Timestamp(Int(timeinterval[9..<13])!, Int(timeinterval[13..<15])!, Int(timeinterval[15..<17])!).add(days: 1)
                return TimerangeDt(start: start, to: end, dtSeconds: dt)
            }
            // Era5 has a typical delay of 5 days
            // Per default, check last 14 days for new data. If data is already downloaded, downloading is skipped
            let lastDays = 14
            let time0z = Timestamp.now().add(days: -6).with(hour: 0)
            return TimerangeDt(start: time0z.add(days: -1 * lastDays), to: time0z.add(days: 1), dtSeconds: dt)
        }
    }
    
    var help: String {
        "Download satellite datasets"
    }
    
    func run(using context: CommandContext, signature: Signature) async throws {
        let logger  = context.application.logger
        try createImergMaster(logger: logger, domain: .imerg_daily, createFixedFile: signature.createFixedFile)
    }
    
    func createImergMaster(logger: Logger, domain: SatelliteDomain, createFixedFile: Bool) throws {
        guard let master = domain.omFileMaster else {
            fatalError("no master file defined")
        }
        let masterFile = "\(master.path)precipitation_sum_0.om"
        if !FileManager.default.fileExists(atPath: masterFile) {
            try downloadImergDaily(logger: logger, domain: .imerg_daily, timerange: master.time)
            
            try FileManager.default.createDirectory(atPath: master.path, withIntermediateDirectories: true)
            logger.info("Generating master files")
            let readers = try master.time.map { time in
                let omFile = "\(domain.downloadDirectory)precipitation_\(time.format_YYYYMMdd).om"
                return try OmFileReader(file: omFile)
            }
            try OmFileWriter(dim0: domain.grid.count, dim1: master.time.count, chunk0: 8, chunk1: 512)
                .write(logger: logger, file: masterFile, compressionType: .p4nzdec256, scalefactor: 10, nLocationsPerChunk: Self.nLocationsPerChunk, chunkedFiles: readers, dataCallback: nil)
        }
        
        /// Data was not transposed before
        if createFixedFile {
            let masterFileFixed = "\(master.path)precipitation_sum_fixed_0.om"
            if !FileManager.default.fileExists(atPath: masterFileFixed) {
                let progress = ProgressTracker(logger: logger, total: domain.grid.count, label: "Convert \(masterFileFixed)")
                let reader = try OmFileReader(file: masterFile)
                try OmFileWriter(dim0: domain.grid.count, dim1: master.time.count, chunk0: 8, chunk1: 512).write(file: masterFileFixed, compressionType: .p4nzdec256, scalefactor: 10, overwrite: false) { dim0 in
                    let locationRange = dim0..<min(dim0+Self.nLocationsPerChunk, reader.dim0)
                    var ret = Array2DFastTime(nLocations: locationRange.count, nTime: reader.dim1)
                    for (i, location) in locationRange.enumerated() {
                        let x = location % 3600
                        let y = location / 3600
                        let locationRotated = x * 1800 + y
                        ret[i, 0..<ret.nTime] = ArraySlice(try reader.read(dim0Slow: locationRotated..<locationRotated+1, dim1: 0..<ret.nTime))
                    }
                    progress.add(locationRange.count)
                    return ArraySlice(ret.data)
                }
                progress.finish()
            }
        }
        
        if !FileManager.default.fileExists(atPath: domain.getBiasCorrectionFile(for: SatelliteVariable.precipitation_sum.omFileName.file).getFilePath()) {
            try generateBiasCorrectionFields(logger: logger, domain: domain, variables: [.precipitation_sum], time: master.time)
        }
    }
    
    /// Generate seasonal averages for bias corrections
    func generateBiasCorrectionFields(logger: Logger, domain: SatelliteDomain, variables: [SatelliteVariable], time: TimerangeDt) throws {
        logger.info("Calculating bias correction fields")
        let binsPerYear = 6
        let reader = OmFileSplitter(domain)
        let writer = OmFileWriter(dim0: domain.grid.count, dim1: binsPerYear, chunk0: 200, chunk1: binsPerYear)
        for variable in variables {
            let biasFile = domain.getBiasCorrectionFile(for: variable.omFileName.file).getFilePath()
            if FileManager.default.fileExists(atPath: biasFile) {
                continue
            }
            let progress = ProgressTracker(logger: logger, total: writer.dim0, label: "Convert \(biasFile)")
            try writer.write(file: biasFile, compressionType: .fpxdec32, scalefactor: 1, overwrite: false, supplyChunk: { dim0 in
                let locationRange = dim0..<min(dim0+200, writer.dim0)
                var bias = Array2DFastTime(nLocations: locationRange.count, nTime: binsPerYear)
                try reader.willNeed(variable: variable.omFileName.file, location: locationRange, level: 0, time: time)
                let data = try reader.read2D(variable: variable.omFileName.file, location: locationRange, level: 0, time: time)
                for l in 0..<locationRange.count {
                    bias[l, 0..<binsPerYear] = ArraySlice(BiasCorrectionSeasonalLinear(data[l, 0..<time.count], time: time, binsPerYear: binsPerYear).meansPerYear)
                }
                progress.add(bias.nLocations)
                return ArraySlice(bias.data)
            })
            progress.finish()
        }
    }
    
    /**
     Loop over timerange, download daily files and convert them to om files
     */
    func downloadImergDaily(logger: Logger, domain: SatelliteDomain, timerange: TimerangeDt) throws {
        try FileManager.default.createDirectory(atPath: domain.downloadDirectory, withIntermediateDirectories: true)
        let progress = ProgressTracker(logger: logger, total: timerange.count, label: "Total download")
        
        for time in timerange {
            let year = time.toComponents().year
            let month = time.toComponents().month.zeroPadded(len: 2)
            let yyyymmdd = time.format_YYYYMMdd
            let openDap = "https://gpm1.gesdisc.eosdis.nasa.gov/opendap/GPM_L3/GPM_3IMERGDL.06/\(year)/\(month)/3B-DAY-L.metrePerSecond.MRG.3IMERG.\(yyyymmdd)-S000000-E235959.V06.nc4"
            let destination = "\(domain.downloadDirectory)precipitation_\(yyyymmdd).om"
            let domain = SatelliteDomain.imerg_daily
            
            if FileManager.default.fileExists(atPath: destination) {
                continue
            }
            logger.info("Downloading \(yyyymmdd)")
            
            let ncFile = try NetCDF.openOrWait(path: openDap, deadline: Date().addingTimeInterval(60), logger: logger)
            let dimensions = ncFile.getDimensions()
            guard dimensions.count == 4 else {
                fatalError("Expected 4 dimensions, got \(dimensions.count)")
            }
            let nx = dimensions.first(where: {$0.name == "lon"})!.length
            let ny = dimensions.first(where: {$0.name == "lat"})!.length
            
            guard nx == domain.grid.nx, ny == domain.grid.ny else {
                fatalError("Wrong domain dimensions \(nx), \(ny)")
            }
            
            guard var data = try ncFile.getVariable(name: "precipitationCal")?.asType(Float.self)?.read() else {
                fatalError("No precipitationCal in netcdf file")
            }
            for i in data.indices {
                if data[i] <= -999 {
                    data[i] = .nan
                }
            }
            // lat and lon dimensions are flipped in original data. Transpose [lon,lat] to [lat,lon]
            let transposed = Array2DFastTime(data: data, nLocations: nx, nTime: ny).transpose().data
            
            //try Array2DFastSpace(data: transposed, nLocations: nx*ny, nTime: 1).writeNetcdf(filename: "imerg.nc", nx: nx, ny: ny)
            //fatalError()
            
            try OmFileWriter(dim0: 1, dim1: data.count, chunk0: 1, chunk1: Self.nLocationsPerChunk)
                .write(file: destination, compressionType: .p4nzdec256, scalefactor: 10, all: transposed)
            progress.add(1)
        }
        progress.finish()
    }
}

enum SatelliteVariable: String, CaseIterable, GenericVariableMixable, GenericVariable {
    case precipitation_sum
    
    
    var omFileName: (file: String, level: Int) {
        return (rawValue, 0)
    }
    
    var scalefactor: Float {
        return 10
    }
    
    var interpolation: ReaderInterpolation {
        return .backwards_sum
    }
    
    var unit: SiUnit {
        switch self {
        case .precipitation_sum:
            return .millimetre
        }
    }
    
    var isElevationCorrectable: Bool {
        return false
    }
    
    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
}

enum SatelliteDomain: String, CaseIterable, GenericDomain {
    case imerg_daily
    
    var dtSeconds: Int {
        switch self {
        case .imerg_daily:
            return 3600*24
        }
    }
    
    func getStaticFile(type: ReaderStaticVariable) -> OmFileReader<MmapFile>? {
        return nil
    }
    
    /// Filename of the surface elevation file
    var surfaceElevationFileOm: String {
        "\(omfileDirectory)HSURF.om"
    }
    
    var downloadDirectory: String {
        return "\(OpenMeteo.dataDictionary)download-\(rawValue)/"
    }
    
    var omfileDirectory: String {
        return "\(OpenMeteo.dataDictionary)omfile-\(rawValue)//"
    }
    
    var omfileArchive: String? {
        return "\(OpenMeteo.dataDictionary)yearly-\(rawValue)//"
    }
    
    var omFileMaster: (path: String, time: TimerangeDt)? {
        switch self {
        case .imerg_daily:
                let path = "\(OpenMeteo.dataDictionary)master-\(rawValue)/"
                return (path, TimerangeDt(start: Timestamp(2000,06,01), to: Timestamp(2023, 1, 1), dtSeconds: dtSeconds))
        }
    }
    
    /// Use store 14 days per om file
    var omFileLength: Int {
        // 24 hours over 21 days = 504 timesteps per file
        // Afterwards the om compressor will combine 6 locations to one chunks
        // 6 * 504 = 3024 values per compressed chunk
        // In case for a 1 year API call, around 51 kb will have to be decompressed with 34 IO operations
        return 24 * 21
    }
    
    var grid: Gridable {
        switch self {
        case .imerg_daily:
            return RegularGrid(nx: 3600, ny: 1800, latMin: -89.95, lonMin: -179.95, dx: 0.1, dy: 0.1)
        }
    }
    
    var isElevationCorrectable: Bool {
        return false
    }
    
    var omFileName: (file: String, level: Int) {
        return (rawValue, 0)
    }
    
    var interpolation: ReaderInterpolation {
        fatalError("Interpolation not required for cerra")
    }
    
    var requiresOffsetCorrectionForMixing: Bool {
         return false
    }
}


