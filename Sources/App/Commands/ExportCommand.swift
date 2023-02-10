import Foundation
import Vapor
import SwiftNetCDF

/**
 Export a dataset to NetCDF. `Time` is the column major orientation. Use the following command to transpose a NetCDF file
 `brew install nco`
 `ncpdq -O -a time,LAT,LON test.nc test2.nc`
 */
struct ExportCommand: AsyncCommandFix {
    var help: String {
        return "Export to dataset to NetCDF"
    }
    
    struct Signature: CommandSignature {
        @Argument(name: "domains", help: "Model domain")
        var domain: String
        
        @Argument(name: "variable", help: "Weather variable")
        var variable: String
        
        @Option(name: "start_date")
        var startDate: String?
        
        @Option(name: "end_date")
        var endDate: String?
        
        @Option(name: "compression", short: "c", help: "Enable NetCDF compression and set the compression level from 1-9")
        var compressionLevel: Int?
        
        /// Get time range from parameters
        func getTime(dtSeconds: Int) throws -> TimerangeDt? {
            guard let startDate, let endDate else {
                return nil
            }
            let start = try IsoDate(fromIsoString: startDate).toTimestamp()
            let end = try IsoDate(fromIsoString: endDate).toTimestamp()
            return TimerangeDt(start: start, to: end.add(dtSeconds), dtSeconds: dtSeconds)
        }
    }
    
    /**
     Limitations:
     - no derived daily variables yet
     
     TODO:
     - file names
     - dynamic nChunkLocations calculation
     */
    func run(using context: CommandContext, signature: Signature) async throws {
        let logger = context.application.logger
        let domain = try ExportDomain.load(rawValue: signature.domain)
        let filePath = "./test.nc"
        
        guard let time = try signature.getTime(dtSeconds: 86400) else {
            fatalError("no time")
        }
        let grid = domain.grid
        logger.info("Exporing variable \(signature.variable) for dataset \(domain)")
        logger.info("Grid nx=\(grid.nx) ny=\(grid.ny) nTime=\(time.count) (\(time.prettyString()))")
        let size = grid.count * time.count * 4
        logger.info("Total raw size \(size.bytesHumanReadable)")
        
        try generateNetCdf(logger: logger, file: filePath, domain: domain, variable: signature.variable, time: time, nLocationChunk: 48, compressionLevel: signature.compressionLevel)
        try FileManager.default.moveFileOverwrite(from: "\(filePath)~", to: filePath)
    }
    
    func generateNetCdf(logger: Logger, file: String, domain: ExportDomain, variable: String, time: TimerangeDt, nLocationChunk: Int, compressionLevel: Int?) throws {
        let grid = domain.grid

        let ncFile = try NetCDF.create(path: "\(file)~", overwriteExisting: true)
        try ncFile.setAttribute("TITLE", "\(domain) \(variable)")
        
        var ncVariable = try ncFile.createVariable(name: "data", type: Float.self, dimensions: [
            try ncFile.createDimension(name: "LAT", length: grid.ny),
            try ncFile.createDimension(name: "LON", length: grid.nx),
            try ncFile.createDimension(name: "time", length: time.count)
        ])
        
        if let compressionLevel {
            try ncVariable.defineDeflate(enable: true, level: compressionLevel, shuffle: true)
            try ncVariable.defineChunking(chunking: .chunked, chunks: [1, nLocationChunk, time.count])
        }

        let progress = TransferAmountTracker(logger: logger, totalSize: grid.count * time.count * 4)
        
        // Loop over chunks of locations, read and write
        for l in stride(from: 0, to: grid.count, by: nLocationChunk) {
            // Prefetch the next location chunk
            let positionNext = min(l+nLocationChunk, grid.count)..<min(l+nLocationChunk*2, grid.count)
            let readerNext = try domain.getReader(position: positionNext)
            let _ = try readerNext.prefetchData(mixed: variable, time: time)
            
            // Read data
            let position = l..<min(l+nLocationChunk, grid.count)
            let reader = try domain.getReader(position: position)
            guard let data = try reader.get(mixed: variable, time: time) else {
                fatalError("Invalid variable \(variable)")
            }
            try ncVariable.write(data.data, offset: [l/grid.nx, l % grid.nx, 0], count: [1, position.count, time.count])
            progress.add(position.count * time.count * 4)
        }
        
        progress.finish()
    }
}


enum ExportDomain: String, CaseIterable {
    case CMCC_CM2_VHR4
    case MRI_AGCM3_2_S
    case CMCC_CM2_VHR4_downscaled
    
    var genericDomain: GenericDomain {
        switch self {
        case .CMCC_CM2_VHR4:
            return Cmip6Domain.CMCC_CM2_VHR4
        case .MRI_AGCM3_2_S:
            return Cmip6Domain.MRI_AGCM3_2_S
        case .CMCC_CM2_VHR4_downscaled:
            // need domain with downscaling
            return CdsDomain.era5_land
        }
    }
    
    var grid: Gridable {
        return genericDomain.grid
    }
    
    func getReader(position: Range<Int>) throws -> any GenericReaderMixable {
        switch self {
        case .CMCC_CM2_VHR4:
            return Cmip6Reader<GenericReader<Cmip6Domain, Cmip6Variable>>(domain: .CMCC_CM2_VHR4, position: position)
        case .MRI_AGCM3_2_S:
            return Cmip6Reader<GenericReader<Cmip6Domain, Cmip6Variable>>(domain: .MRI_AGCM3_2_S, position: position)
        case .CMCC_CM2_VHR4_downscaled:
            return Cmip6Reader<Cmip6BiasCorrector>(domain: .CMCC_CM2_VHR4, position: position)
        }
    }
}
