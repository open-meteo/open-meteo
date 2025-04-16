import Foundation
import Vapor
import SwiftNetCDF
import OmFileFormat

/**
 Download satellite datasets like IMERG
 
 NASA auth:
 echo "machine urs.earthdata.nasa.gov login <uid> password <password>" >> ~/.netrc
 echo "HTTP.NETRC=/Users/patrick/.netrc\nHTTP.COOKIEJAR=/Users/patrick/.urs_cookies" > ~/.dodsrc
 chmod 0600 ~/.netrc
 chmod 0600 ~/.dodsrc
 */
struct SatelliteDownloadCommand: AsyncCommand {
    /// 6k locations require around 200 MB memory for a yearly time-series
    static var nLocationsPerChunk = 6_000

    struct Signature: CommandSignature {
        @Argument(name: "domain")
        var domain: String

        @Option(name: "timeinterval", short: "t", help: "Timeinterval to download with format 20220101-20220131")
        var timeinterval: String?

        @Option(name: "year", short: "y", help: "Download one year")
        var year: String?

        /// Get the specified timerange in the command, or use the last 7 days as range
        func getTimeinterval() throws -> TimerangeDt {
            let dt = 3600 * 24
            if let timeinterval = timeinterval {
                return try Timestamp.parseRange(yyyymmdd: timeinterval).toRange(dt: dt)
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
        fatalError("IMERG downloader not available anymore")

        // let logger  = context.application.logger
        // try createImergMaster(logger: logger, domain: .imerg_daily)
    }

    /*func createImergMaster(logger: Logger, domain: SatelliteDomain) throws {
        guard let master = domain.masterTimeRange else {
            fatalError("no master file defined")
        }
        let masterTime = TimerangeDt(range: master, dtSeconds: domain.dtSeconds)
        let masterFile = OmFileManagerReadable.domainChunk(domain: domain.domainRegistry, variable: "precipitation_sum", type: .master, chunk: 0, ensembleMember: 0, previousDay: 0)
        if !FileManager.default.fileExists(atPath: masterFile.getFilePath()) {
            try downloadImergDaily(logger: logger, domain: .imerg_daily, timerange: masterTime)
            
            try masterFile.createDirectory()
            logger.info("Generating master files")
            let readers = try masterTime.map { time in
                let omFile = "\(domain.downloadDirectory)precipitation_\(time.format_YYYYMMdd).om"
                return try OmFileReader(file: omFile)
            }
            try OmFileWriter(dim0: domain.grid.count, dim1: masterTime.count, chunk0: 8, chunk1: 512)
                .write(logger: logger, file: masterFile.getFilePath(), compressionType: .pfor_delta2d_int16, scalefactor: 10, nLocationsPerChunk: Self.nLocationsPerChunk, chunkedFiles: readers, dataCallback: nil)
        }
        
        if !FileManager.default.fileExists(atPath: domain.getBiasCorrectionFile(for: SatelliteVariable.precipitation_sum.omFileName.file).getFilePath()) {
            try generateBiasCorrectionFields(logger: logger, domain: domain, variables: [.precipitation_sum], time: masterTime)
        }
    }*/

    /// Generate seasonal averages for bias corrections
    /*func generateBiasCorrectionFields(logger: Logger, domain: SatelliteDomain, variables: [SatelliteVariable], time: TimerangeDt) throws {
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
            try writer.write(file: biasFile, compressionType: .fpx_xor2d, scalefactor: 1, overwrite: false, supplyChunk: { dim0 in
                let locationRange = dim0..<min(dim0+200, writer.dim0)
                var bias = Array2DFastTime(nLocations: locationRange.count, nTime: binsPerYear)
                try reader.willNeed(variable: variable.omFileName.file, location: locationRange, level: 0, time: time.toSettings())
                let data = try reader.read2D(variable: variable.omFileName.file, location: locationRange, level: 0, time: time.toSettings())
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
                .write(file: destination, compressionType: .pfor_delta2d_int16, scalefactor: 10, all: transposed)
            progress.add(1)
        }
        progress.finish()
    }*/
}

enum SatelliteVariable: String, CaseIterable, GenericVariableMixable, GenericVariable {
    case precipitation_sum

    var storePreviousForecast: Bool {
        return false
    }

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
            return 3600 * 24
        }
    }

    var domainRegistry: DomainRegistry {
        switch self {
        case .imerg_daily:
            return .nasa_imerg_daily
        }
    }

    var domainRegistryStatic: DomainRegistry? {
        return domainRegistry
    }

    var hasYearlyFiles: Bool {
        return true
    }

    var masterTimeRange: Range<Timestamp>? {
        return Timestamp(2000, 06, 01) ..< Timestamp(2023, 1, 1)
    }

    var updateIntervalSeconds: Int {
        switch self {
        case .imerg_daily:
            0
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
