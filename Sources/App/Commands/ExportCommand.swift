import Foundation
import SwiftPFor2D
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
        
        @Option(name: "regridding", help: "Regrid data to a specified grid, perform bias and elevation correction")
        var regriddingDomain: String?
        
        @Option(name: "start_date")
        var startDate: String?
        
        @Option(name: "end_date")
        var endDate: String?
        
        @Option(name: "output", short: "o", help: "Output file name. Default: ./output.nc")
        var outputFilename: String?
        
        @Option(name: "compression", short: "c", help: "Enable NetCDF compression and set the compression level from 0-9")
        var compressionLevel: Int?
        
        @Flag(name: "output_coordinates", help: "Output grid coordinates in NetCDF file")
        var outputCoordinates: Bool
        
        @Flag(name: "output_elevation", help: "Output grid elevation in NetCDF file")
        var outputElevation: Bool
        
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
     TODO:
     - dynamic nChunkLocations calculation
     - normals calculation
     - export glofas
     - export era5 (needs 2D solar)
     */
    func run(using context: CommandContext, signature: Signature) async throws {
        let logger = context.application.logger
        let domain = try ExportDomain.load(rawValue: signature.domain)
        let regriddingDomain = try TargetGridDomain.load(rawValueOptional: signature.regriddingDomain)
        let filePath = signature.outputFilename ?? "./output.nc"
        
        /*let om = try OmFileReader(file: "/Volumes/2TB_1GBs/data/master-MRI_AGCM3_2_S/temperature_2m_max_linear_bias_seasonal.om")
        
        let data = try om.readAll()
        let grid2 = Cmip6Domain.MRI_AGCM3_2_S.grid
        
        let ncFile = try NetCDF.create(path: filePath, overwriteExisting: true)
        try ncFile.setAttribute("TITLE", "\(domain) aa")
        
        var ncVariable = try ncFile.createVariable(name: "data", type: Float.self, dimensions: [
            try ncFile.createDimension(name: "LAT", length: grid2.ny),
            try ncFile.createDimension(name: "LON", length: grid2.nx),
            try ncFile.createDimension(name: "time", length: 6)
        ])
        try ncVariable.write(data)
        return*/
        
        
        guard let time = try signature.getTime(dtSeconds: domain.genericDomain.dtSeconds) else {
            fatalError("start_date and end_date must be specified")
        }
        logger.info("Exporing variable \(signature.variable) for dataset \(domain) to file '\(filePath)'")

        try generateNetCdf(
            logger: logger,
            file: "\(filePath)~",
            domain: domain,
            variable: signature.variable,
            time: time,
            nLocationChunk: 48,
            compressionLevel: signature.compressionLevel,
            targetGridDomain: regriddingDomain,
            outputCoordinates: signature.outputCoordinates,
            outputElevation: signature.outputElevation
        )
        try FileManager.default.moveFileOverwrite(from: "\(filePath)~", to: filePath)
    }
    
    func generateNetCdf(logger: Logger, file: String, domain: ExportDomain, variable: String, time: TimerangeDt, nLocationChunk: Int, compressionLevel: Int?, targetGridDomain: TargetGridDomain?, outputCoordinates: Bool, outputElevation: Bool) throws {
        let grid = targetGridDomain?.genericDomain.grid ?? domain.grid
        
        logger.info("Grid nx=\(grid.nx) ny=\(grid.ny) nTime=\(time.count) (\(time.prettyString()))")
        let size = grid.count * time.count * 4
        logger.info("Total raw size \(size.bytesHumanReadable)")

        let ncFile = try NetCDF.create(path: file, overwriteExisting: true)
        try ncFile.setAttribute("TITLE", "\(domain) \(variable)")
        
        let latDimension = try ncFile.createDimension(name: "LAT", length: grid.ny)
        let lonDimension = try ncFile.createDimension(name: "LON", length: grid.nx)
        let timeDimension = try ncFile.createDimension(name: "time", length: time.count)
        
        if outputCoordinates {
            logger.info("Writing coordinates")
            var ncLat = try ncFile.createVariable(name: "latitude", type: Float.self, dimensions: [latDimension])
            var ncLon = try ncFile.createVariable(name: "longitude", type: Float.self, dimensions: [lonDimension])
            try ncLat.write((0..<grid.ny).map{ grid.getCoordinates(gridpoint: $0 * grid.nx).latitude })
            try ncLon.write((0..<grid.nx).map{ grid.getCoordinates(gridpoint: $0).longitude })
        }
        if outputElevation {
            logger.info("Writing elevation information")
            var ncElevation = try ncFile.createVariable(name: "elevation", type: Float.self, dimensions: [latDimension, lonDimension])
            let targetDomain = targetGridDomain?.genericDomain ?? domain.genericDomain
            guard let elevationFile = targetDomain.elevationFile else {
                fatalError("Could not read elevation file for domain \(targetDomain)")
            }
            try ncElevation.write(elevationFile.readAll())
        }
        
        var ncVariable = try ncFile.createVariable(name: "data", type: Float.self, dimensions: [latDimension, lonDimension, timeDimension])
        
        if let compressionLevel, compressionLevel > 0 {
            try ncVariable.defineDeflate(enable: true, level: compressionLevel, shuffle: true)
            try ncVariable.defineChunking(chunking: .chunked, chunks: [1, nLocationChunk, time.count])
        }

        logger.info("Writing data")
        let progress = TransferAmountTracker(logger: logger, totalSize: grid.count * time.count * 4)
        
        /// Interpolate data from one grid to another and perform bias correction
        if let targetGridDomain {
            let targetDomain = targetGridDomain.genericDomain
            guard let elevationFile = targetDomain.elevationFile else {
                fatalError("Could not read elevation file for domain \(targetDomain)")
            }
            
            for l in 0..<grid.count {
                let coords = grid.getCoordinates(gridpoint: l)
                let elevation = try grid.readElevation(gridpoint: l, elevationFile: elevationFile)
                
                // Read data
                let reader = try domain.getReader(targetGridDomain: targetGridDomain, lat: coords.latitude, lon: coords.longitude, elevation: elevation.numeric, mode: .land)
                guard let data = try reader.get(mixed: variable, time: time) else {
                    fatalError("Invalid variable \(variable)")
                }
                try ncVariable.write(data.data, offset: [l/grid.nx, l % grid.nx, 0], count: [1, 1, time.count])
                progress.add(time.count * 4)
            }
            progress.finish()
            return
        }
        
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

enum TargetGridDomain: String, CaseIterable {
    /// interpolates weights to 10 km, uses elevation information from era5 land
    case era5_interpolated_10km
    case era5_land
    case imerg
    
    var genericDomain: GenericDomain {
        switch self {
        case .era5_interpolated_10km:
            fallthrough
        case .era5_land:
            return CdsDomain.era5_land
        case .imerg:
            return SatelliteDomain.imerg_daily
        }
    }
}

enum ExportDomain: String, CaseIterable {
    case CMCC_CM2_VHR4
    case FGOALS_f3_H
    case HiRAM_SIT_HR
    case MRI_AGCM3_2_S
    case EC_Earth3P_HR
    case MPI_ESM1_2_XR
    case NICAM16_8S
    
    var genericDomain: GenericDomain {
        switch self {
        case .CMCC_CM2_VHR4:
            return Cmip6Domain.CMCC_CM2_VHR4
        case .MRI_AGCM3_2_S:
            return Cmip6Domain.MRI_AGCM3_2_S
        case .FGOALS_f3_H:
            return Cmip6Domain.FGOALS_f3_H
        case .HiRAM_SIT_HR:
            return Cmip6Domain.HiRAM_SIT_HR
        case .EC_Earth3P_HR:
            return Cmip6Domain.EC_Earth3P_HR
        case .MPI_ESM1_2_XR:
            return Cmip6Domain.MPI_ESM1_2_XR
        case .NICAM16_8S:
            return Cmip6Domain.NICAM16_8S
        }
    }
    
    var cmipDomain: Cmip6Domain? {
        switch self {
        case .CMCC_CM2_VHR4:
            return Cmip6Domain.CMCC_CM2_VHR4
        case .MRI_AGCM3_2_S:
            return Cmip6Domain.MRI_AGCM3_2_S
        case .FGOALS_f3_H:
            return Cmip6Domain.FGOALS_f3_H
        case .HiRAM_SIT_HR:
            return Cmip6Domain.HiRAM_SIT_HR
        case .EC_Earth3P_HR:
            return Cmip6Domain.EC_Earth3P_HR
        case .MPI_ESM1_2_XR:
            return Cmip6Domain.MPI_ESM1_2_XR
        case .NICAM16_8S:
            return Cmip6Domain.NICAM16_8S
        }
    }
    
    var grid: Gridable {
        return genericDomain.grid
    }
    
    func getReader(position: Range<Int>) throws -> any GenericReaderMixable {
        switch self {
        case .CMCC_CM2_VHR4:
            return Cmip6Reader(reader: GenericReader(domain: Cmip6Domain.CMCC_CM2_VHR4, position: position))
        case .MRI_AGCM3_2_S:
            return Cmip6Reader(reader: GenericReader(domain: Cmip6Domain.MRI_AGCM3_2_S, position: position))
        case .FGOALS_f3_H:
            return Cmip6Reader(reader: GenericReader(domain: Cmip6Domain.FGOALS_f3_H, position: position))
        case .HiRAM_SIT_HR:
            return Cmip6Reader(reader: GenericReader(domain: Cmip6Domain.HiRAM_SIT_HR, position: position))
        case .EC_Earth3P_HR:
            return Cmip6Reader(reader: GenericReader(domain: Cmip6Domain.EC_Earth3P_HR, position: position))
        case .MPI_ESM1_2_XR:
            return Cmip6Reader(reader: GenericReader(domain: Cmip6Domain.MPI_ESM1_2_XR, position: position))
        case .NICAM16_8S:
            return Cmip6Reader(reader: GenericReader(domain: Cmip6Domain.NICAM16_8S, position: position))
        }
    }
    
    func getReader(targetGridDomain: TargetGridDomain, lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode) throws -> any GenericReaderMixable {

        guard let cmipDomain = self.cmipDomain else {
            fatalError("Regridding only supported for CMIP domains")
        }
        switch targetGridDomain {
        case .era5_interpolated_10km:
            guard let biasCorrector = try Cmip6BiasCorrectorInterpolatedWeights(domain: cmipDomain, referenceDomain: CdsDomain.era5, lat: lat, lon: lon, elevation: elevation, mode: mode) else {
                throw ForecastapiError.noDataAvilableForThisLocation
            }
            return Cmip6Reader(reader: biasCorrector)
        case .era5_land:
            guard let biasCorrector = try Cmip6BiasCorrectorEra5Seamless(domain: cmipDomain, lat: lat, lon: lon, elevation: elevation, mode: mode) else {
                throw ForecastapiError.noDataAvilableForThisLocation
            }
            return Cmip6Reader(reader: biasCorrector)
        case .imerg:
            guard let biasCorrector = try Cmip6BiasCorrectorGenericDomain(domain: cmipDomain, referenceDomain: SatelliteDomain.imerg_daily, lat: lat, lon: lon, elevation: elevation, mode: mode) else {
                throw ForecastapiError.noDataAvilableForThisLocation
            }
            return Cmip6Reader(reader: biasCorrector)
        }
    }
}
