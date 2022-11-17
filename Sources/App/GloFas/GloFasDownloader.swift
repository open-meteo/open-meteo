import Foundation
import Vapor
import SwiftPFor2D
import SwiftEccodes

struct GloFasDownloader: Command {
    struct Signature: CommandSignature {
        @Option(name: "timeinterval", short: "t", help: "Timeinterval to download with format 20220101-20220131")
        var timeinterval: String?
        
        @Option(name: "year", short: "y", help: "Download one year")
        var year: String?
        
        @Option(name: "cdskey", short: "k", help: "CDS API user and key like: 123456:8ec08f...")
        var cdskey: String?
        
        /// Get the specified timerange in the command, or use the last 7 days as range
        func getTimeinterval() -> TimerangeDt {
            if let timeinterval = timeinterval {
                guard timeinterval.count == 17, timeinterval.contains("-") else {
                    fatalError("format looks wrong")
                }
                let start = Timestamp(Int(timeinterval[0..<4])!, Int(timeinterval[4..<6])!, Int(timeinterval[6..<8])!)
                let end = Timestamp(Int(timeinterval[9..<13])!, Int(timeinterval[13..<15])!, Int(timeinterval[15..<17])!).add(86400)
                return TimerangeDt(start: start, to: end, dtSeconds: 24*3600)
            }
            // Era5 has a typical delay of 5 days
            // Per default, check last 14 days for new data. If data is already downloaded, downloading is skipped
            let lastDays = 14
            return TimerangeDt(start: Timestamp.now().with(hour: 0).add(lastDays * -86400), nTime: lastDays, dtSeconds: 86400)
        }
    }
    
    var help: String {
        "Download ERA5 from the ECMWF climate data store and convert"
    }
    
    func run(using context: CommandContext, signature: Signature) throws {
        let logger = context.application.logger
        guard let cdskey = signature.cdskey else {
            fatalError("cds key is required")
        }
        
        /// Only download one specified year
        if let yearStr = signature.year {
            guard let year = Int(yearStr) else {
                fatalError("Could not convert year to integer")
            }
            try downloadYear(logger: logger, year: year, cdskey: cdskey)
            return
        }
        
    }
    
    
    func downloadYear(logger: Logger, year: Int, cdskey: String) throws {
        let domain = GloFasDomain.consolidated
        
        let downloadDir = domain.downloadDirectory
        try FileManager.default.createDirectory(atPath: downloadDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(atPath: domain.omfileArchive!, withIntermediateDirectories: true)
        let gribFile = "\(downloadDir)glofasv4_\(year).grib"
        
        if !FileManager.default.fileExists(atPath: gribFile) {
            logger.info("Downloading year \(year)")
            let pyCode = """
                import cdsapi
                c = cdsapi.Client(url="https://cds.climate.copernicus.eu/api/v2", key="\(cdskey)", verify=True)
                
                c.retrieve(
                    'cems-glofas-historical',
                    {
                        'system_version': 'version_4_0',
                        'variable': 'river_discharge_in_the_last_24_hours',
                        'format': 'grib',
                        'hyear': '2021',
                        'hmonth': [
                            'april', 'august', 'december',
                            'february', 'january', 'july',
                            'june', 'march', 'may',
                            'november', 'october', 'september',
                        ],
                        'hday': [
                            '01', '02', '03',
                            '04', '05', '06',
                            '07', '08', '09',
                            '10', '11', '12',
                            '13', '14', '15',
                            '16', '17', '18',
                            '19', '20', '21',
                            '22', '23', '24',
                            '25', '26', '27',
                            '28', '29', '30',
                            '31',
                        ],
                        'hydrological_model': 'lisflood',
                        'product_type': 'consolidated',
                    },
                    '\(gribFile)')
                """
            let tempPythonFile = "\(downloadDir)glofasdownload.py"
            
            try pyCode.write(toFile: tempPythonFile, atomically: true, encoding: .utf8)
            try Process.spawn(cmd: "python3", args: [tempPythonFile])
        }
        
        logger.info("Converting year \(year) to daily files")
        
        let ny = domain.grid.ny
        let nx = domain.grid.nx
        // 21k locations -> 30MB chunks for 1 year
        let nLocationChunk = nx * ny / 1000
        var grib2d = GribArray2D(nx: nx, ny: ny)
        
        let grib = try GribFile(file: gribFile)
        for message in grib.messages {
            /// Date in ISO timestamp string format `20210101`
            let date = message.get(attribute: "dataDate")!
            logger.info("Converting day \(date)")
            let dailyFile = "\(downloadDir)glofas_\(date).fpx"
            if FileManager.default.fileExists(atPath: dailyFile) {
                continue
            }
            try grib2d.load(message: message)
            grib2d.array.flipLatitude()
            //try grib2d.array.writeNetcdf(filename: "\(downloadDir)glofas_\(date).nc")
           
            try OmFileWriter(dim0: ny*nx, dim1: 1, chunk0: nLocationChunk, chunk1: 1).write(file: dailyFile, compressionType: .p4nzdec256logarithmic, scalefactor: 1000, all: grib2d.array.data)
        }
        
        logger.info("Converting daily files time series")
        let time = TimerangeDt(range: Timestamp(year, 1, 1) ..< Timestamp(year+1, 1, 1), dtSeconds: 3600*24)
        let nt = time.count
        let yearlyFile = "\(domain.omfileArchive!)river_discharge_\(year).om"
        
        let omFiles = try time.map { time -> OmFileReader in
            let omFile = "\(downloadDir)glofas_\(time.format_YYYYMMdd).fpx"
            return try OmFileReader(file: omFile)
        }
        
        var percent = 0
        var looptime = DispatchTime.now()
        // Scale logarithmic. Max discharge around 400_000 m3/s
        // Note: delta 2d coding (chunk0=6) save around 15% space
        try OmFileWriter(dim0: ny*nx, dim1: nt, chunk0: 6, chunk1: time.count).write(file: yearlyFile, compressionType: .p4nzdec256logarithmic, scalefactor: 1000, supplyChunk: { dim0 in
            
            let ratio = Int(Float(dim0) / (Float(nx*ny)) * 100)
            if percent != ratio {
                /// time ~4.5 seconds
                logger.info("\(ratio) %, time per step \(looptime.timeElapsedPretty())")
                looptime = DispatchTime.now()
                percent = ratio
            }
            
            /// Process around 360 MB memory at once
            let locationRange = dim0..<min(dim0+nLocationChunk, nx*ny)
            
            var fasttime = Array2DFastTime(data: [Float](repeating: .nan, count: nt * locationRange.count), nLocations: locationRange.count, nTime: nt)
            
            for (i, omfile) in omFiles.enumerated() {
                try omfile.willNeed(dim0Slow: locationRange, dim1: 0..<1)
                let read = try omfile.read(dim0Slow: locationRange, dim1: 0..<1)
                let read2d = Array2DFastTime(data: read, nLocations: locationRange.count, nTime: 1)
                for l in 0..<locationRange.count {
                    fasttime[l, i ..< (i+1)] = read2d[l, 0..<1]
                }
            }
            return ArraySlice(fasttime.data)
        })
    }
}

enum GloFasDomain: String, GenericDomain {
    case consolidated
    
    var omfileDirectory: String {
        return "\(OpenMeteo.dataDictionary)omfile-glofas-\(rawValue)/"
    }
    var downloadDirectory: String {
        return "\(OpenMeteo.dataDictionary)download-glofas-\(rawValue)/"
    }
    var omfileArchive: String? {
        return "\(OpenMeteo.dataDictionary)archive-glofas-\(rawValue)/"
    }
    
    var grid: Gridable {
        switch self {
        case .consolidated:
            return RegularGrid(nx: 7200, ny: 3000, latMin: -60, lonMin: -180, dx: 0.05, dy: 0.05)
        }
    }
    
    var dtSeconds: Int {
        return 3600*24
    }
    
    var elevationFile: SwiftPFor2D.OmFileReader? {
        return nil
    }
    
    var omFileLength: Int {
        switch self {
        case .consolidated:
            return 100 // 100 days per file
        }
    }
}

enum GloFasVariable: String, Codable, GenericVariable {
    case river_discharge
    
    var omFileName: String {
        return rawValue
    }
    
    var scalefactor: Float {
        return 1
    }
    
    var interpolation: ReaderInterpolation {
        return .hermite(bounds: 0...10_000_000)
    }
    
    var unit: SiUnit {
        return .qubicMeterPerSecond
    }
    
    var isElevationCorrectable: Bool {
        return false
    }
}
