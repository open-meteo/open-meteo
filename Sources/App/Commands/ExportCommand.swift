import Foundation
import SwiftPFor2D
import Vapor
import SwiftNetCDF

#if ENABLE_PARQUET
import SwiftArrowParquet

/**
 Helper structure to buffer data before writing to a parquet file. Parquet files are not very efficient for small arrays.
 */
final class BufferedParquetFileWriter {
    var locations = [Int64]()
    var latitudes = [Float]()
    var longitudes = [Float]()
    var elevations = [Float]()
    var times = [Int64]()
    var data = [[Float]]()
    var schema: ArrowSchema? = nil
    var writer: ParquetFileWriter? = nil
    let file: String
    
    init(file: String) {
        self.file = file
    }
    
    /// Append new data, if more than 64 MB size rows, flush to writer
    func add(data: [DataAndUnit], variables: [String], timestamps: [Int64], location: Int, latitude: Float, longitude: Float, elevation: Float) throws {
        if self.data.isEmpty {
            self.data = [[Float]](repeating: [Float](), count: data.count)
            
            let columns = [
                ("location_id", ArrowDataType.int64),
                ("latitude", ArrowDataType.float),
                ("longitude", ArrowDataType.float),
                ("elevation", ArrowDataType.float),
                ("time", ArrowDataType.timestamp(unit: .second))
            ] + zip(variables, data).map{("\($0.0)_\($0.1.unit)", ArrowDataType.float)}
            
            let schema = try ArrowSchema(columns)
            let properties = ParquetWriterProperties()
            // Enable compression on all columns
            columns.forEach({properties.setCompression(type: .snappy, path: $0.0)})
            
            writer = try ParquetFileWriter(path: file, schema: schema, properties: properties)
            self.schema = schema
        }
        
        let nt = timestamps.count
        locations.append(contentsOf: [Int64](repeating: Int64(location), count: nt))
        latitudes.append(contentsOf: [Float](repeating: latitude, count: nt))
        longitudes.append(contentsOf: [Float](repeating: longitude, count: nt))
        elevations.append(contentsOf: [Float](repeating: elevation, count: nt))
        times.append(contentsOf: timestamps)
        for (i,d) in data.enumerated() {
            self.data[i].append(contentsOf: d.data)
        }
        let bytesPerRow = (8 + 4 + 4 + 4 + 8 + data.count * 4)
        if locations.count >= 64*1024*1024 / bytesPerRow {
            // flush after 64MB data
            try flush(closeFile: false)
        }
    }
    
    func flush(closeFile: Bool) throws {
        if locations.isEmpty {
            return
        }
        guard let schema, let writer else {
            fatalError("writer or schema not initialised")
        }
        let table = try ArrowTable(schema: schema, arrays: [
            try ArrowArray(int64: locations),
            try ArrowArray(float: latitudes),
            try ArrowArray(float: longitudes),
            try ArrowArray(float: elevations),
            try ArrowArray(timestamp: times, unit: .second)
        ] + data.map( {try ArrowArray(float: $0)}))
        try writer.write(table: table, chunkSize: locations.count)
        
        locations.removeAll(keepingCapacity: true)
        latitudes.removeAll(keepingCapacity: true)
        longitudes.removeAll(keepingCapacity: true)
        elevations.removeAll(keepingCapacity: true)
        times.removeAll(keepingCapacity: true)
        for i in data.indices {
            data[i].removeAll(keepingCapacity: true)
        }
        
        if closeFile {
            try writer.close()
            self.writer = nil
            self.data.removeAll()
        }
    }
}
#endif


/**
 Export a dataset to NetCDF. `Time` is the column major orientation. Use the following command to transpose a NetCDF file
 `brew install nco`
 `ncpdq -O -a time,LAT,LON test.nc test2.nc`
 To remove compression and chunks `ncpdq -O --cnk_plc=unchunk -L 0 -a time,LAT,LON wind_gust_normals.nc wind_gust_normals_transposed.nc`
 
 */
struct ExportCommand: AsyncCommand {
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
        
        @Option(name: "calculate_daily_normals_over_n_years")
        var dailyNormalsOverNYears: Int?
        
        @Option(name: "normals_years")
        var normalsYears: String?
        
        @Option(name: "normals_width")
        var normalsWith: Int?
        
        @Option(name: "format")
        var format: String?
        
        @Option(name: "rain-day-distribution")
        var rainDayDistribution: String?
        
        @Option(name: "latitude-bounds")
        var latitudeBounds: String?
        
        @Option(name: "longitude-bounds")
        var longitudeBounds: String?
        
        @Option(name: "output", short: "o", help: "Output file name. Default: ./output.nc")
        var outputFilename: String?
        
        @Option(name: "compression", short: "c", help: "Enable NetCDF compression and set the compression level from 0-9")
        var compressionLevel: Int?
        
        @Flag(name: "output_coordinates", help: "Output grid coordinates in NetCDF file")
        var outputCoordinates: Bool
        
        @Flag(name: "output_elevation", help: "Output grid elevation in NetCDF file")
        var outputElevation: Bool
        
        @Flag(name: "ignore_sea", help: "Ignore sea points")
        var ignoreSea: Bool
        
        @Option(name: "ignore_sea_search_radius", help: "Radius to search for land")
        var ignoreSeaSearchRadius: Int?
        
        /// Get time range from parameters
        func getTime(dtSeconds: Int) throws -> TimerangeDt? {
            guard let startDate, let endDate else {
                return nil
            }
            let start = try IsoDate(fromIsoString: startDate).toTimestamp()
            let end = try IsoDate(fromIsoString: endDate).toTimestamp()
            return TimerangeDt(start: start, to: end.add(days: 1), dtSeconds: dtSeconds)
        }
    }
    
    func run(using context: CommandContext, signature: Signature) async throws {
        let logger = context.application.logger
        let domain = try ExportDomain.load(rawValue: signature.domain)
        let regriddingDomain = try TargetGridDomain.load(rawValueOptional: signature.regriddingDomain)
        let format = try ExportFormat.load(rawValueOptional: signature.format) ?? .netcdf
        disableIdleSleep()
        
        let filePath = signature.outputFilename ?? (format == .netcdf ? "./output.nc" : "./output.parquet")
        
        let latitudeBounds = signature.latitudeBounds.map {
            let parts = $0.split(separator: ",")
            return Float(parts[0])! ... Float(parts[1])!
        }
        let longitudeBounds = signature.longitudeBounds.map {
            let parts = $0.split(separator: ",")
            return Float(parts[0])! ... Float(parts[1])!
        }
        
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
        
        switch format {
        case .netcdf:
            try await generateNetCdf(
                logger: logger,
                file: "\(filePath)~",
                domain: domain,
                variable: signature.variable,
                time: time,
                compressionLevel: signature.compressionLevel,
                targetGridDomain: regriddingDomain,
                outputCoordinates: signature.outputCoordinates,
                outputElevation: signature.outputElevation,
                normals: signature.normalsYears.map { ($0.split(separator: ",").map({Int($0)! }), signature.normalsWith ?? 10) },
                rainDayDistribution: DailyNormalsCalculator.RainDayDistribution.load(rawValueOptional: signature.rainDayDistribution)
            )
            try FileManager.default.moveFileOverwrite(from: "\(filePath)~", to: filePath)
        case .parquet:
            try await generateParquet(
                logger: logger,
                file: filePath,
                domain: domain,
                variables: signature.variable.split(separator: ",").map(String.init),
                time: time,
                //compressionLevel: signature.compressionLevel,
                targetGridDomain: regriddingDomain,
                //outputCoordinates: signature.outputCoordinates,
                //outputElevation: signature.outputElevation,
                normals: signature.normalsYears.map { ($0.split(separator: ",").map({Int($0)! }), signature.normalsWith ?? 10) },
                rainDayDistribution: DailyNormalsCalculator.RainDayDistribution.load(rawValueOptional: signature.rainDayDistribution),
                latitudeBounds: latitudeBounds,
                longitudeBounds: longitudeBounds,
                onlySeaAroundSearchRadius: signature.ignoreSea ? (signature.ignoreSeaSearchRadius ?? 0) : nil
            )
        }
    }
    
    func generateParquet(logger: Logger, file: String, domain: ExportDomain, variables: [String], time: TimerangeDt, targetGridDomain: TargetGridDomain?, normals: (years: [Int], width: Int)?, rainDayDistribution: DailyNormalsCalculator.RainDayDistribution?, latitudeBounds: ClosedRange<Float>?, longitudeBounds: ClosedRange<Float>?, onlySeaAroundSearchRadius: Int?) async throws {
        #if ENABLE_PARQUET
        
        let grid = targetGridDomain?.genericDomain.grid ?? domain.grid
        let writer = BufferedParquetFileWriter(file: file)
        
        logger.info("Grid nx=\(grid.nx) ny=\(grid.ny) nTime=\(time.count) nVariables=\(variables.count) (\(time.prettyString()))")
        
        // Calculate daily normals
        if let normals {
            let progress = TransferAmountTracker(logger: logger, totalSize: grid.count * time.count * 4 * variables.count, name: "Processed")
            let normalsCalculator = DailyNormalsCalculator(years: normals.years, normalsWidthInYears: normals.width)
            let nTimeNormals = normalsCalculator.timeBins.count * 365
            //properties.setDataPageSize(nTimeNormals*4)
            let timestamps64 = normals.years.flatMap { TimerangeDt(start: Timestamp($0,1,1), nTime: 365, dtSeconds: 24*3600).map({Int64($0.timeIntervalSince1970)}) }
            logger.info("Calculating daily normals. years=\(normals.years) width=\(normals.width) years. Total raw size \((grid.count * nTimeNormals * 4).bytesHumanReadable)")
            
            if let targetGridDomain {
                let targetDomain = targetGridDomain.genericDomain
                guard let elevationFile = targetDomain.getStaticFile(type: .elevation) else {
                    fatalError("Could not read elevation file for domain \(targetDomain)")
                }
                for l in 0..<grid.count {
                //for l in [grid.findPoint(lat: 47.56, lon: 7.57)!, grid.findPoint(lat: 47.37, lon: 8.55)!] {
                //for l in grid.findPoint(lat: 47.56, lon: 7.57)! ..< grid.findPoint(lat: 47.56, lon: 7.57)!+300 {
                    //if l > 0 {
                    //    break
                    //}
                    let coords = grid.getCoordinates(gridpoint: l)
                    if let latitudeBounds, !latitudeBounds.contains(coords.latitude) {
                        continue
                    }
                    if let longitudeBounds, !longitudeBounds.contains(coords.longitude) {
                        continue
                    }
                    let elevation = try grid.readElevation(gridpoint: l, elevationFile: elevationFile)
                    if let onlySeaAroundSearchRadius, try grid.onlySeaAround(gridpoint: l, elevationFile: elevationFile, searchRadius: onlySeaAroundSearchRadius) {
                        continue
                    }
                    
                    // Read data
                    let reader = try domain.getReader(targetGridDomain: targetGridDomain, lat: coords.latitude, lon: coords.longitude, elevation: elevation.numeric, mode: .land)
                    let rows = try variables.map { variable in
                        let reader = variable == "precipitation_sum_imerg" ? try domain.getReader(targetGridDomain: .imerg, lat: coords.latitude, lon: coords.longitude, elevation: elevation.numeric, mode: .land) : reader
                        let variable = variable == "precipitation_sum_imerg" ? "precipitation_sum" : variable
                        guard let data = try reader.get(mixed: variable, time: time.toSettings()) else {
                            fatalError("Invalid variable \(variable)")
                        }
                        return DataAndUnit(normalsCalculator.calculateDailyNormals(variable: variable, values: ArraySlice(data.data), time: time, rainDayDistribution: rainDayDistribution ?? .end).round(digits: data.unit.significantDigits), data.unit)
                    }
                    try writer.add(data: rows, variables: variables, timestamps: timestamps64, location: l, latitude: coords.latitude, longitude: coords.longitude, elevation: elevation.numeric)
                    await progress.add(time.count * 4 * variables.count)
                }
                try writer.flush(closeFile: true)
                await progress.finish()
                return
            }
            // Loop over locations, read and write
            guard let elevationFile = domain.genericDomain.getStaticFile(type: .elevation) else {
                fatalError("Could not read elevation file for domain \(domain)")
            }
            for gridpoint in 0..<grid.count {
                // Read data
                let reader = try domain.getReader(position: gridpoint)
                let coords = grid.getCoordinates(gridpoint: gridpoint)
                if let latitudeBounds, !latitudeBounds.contains(coords.latitude) {
                    continue
                }
                if let longitudeBounds, !longitudeBounds.contains(coords.longitude) {
                    continue
                }
                let elevation = try grid.readElevation(gridpoint: gridpoint, elevationFile: elevationFile)
                if let onlySeaAroundSearchRadius, try grid.onlySeaAround(gridpoint: gridpoint, elevationFile: elevationFile, searchRadius: onlySeaAroundSearchRadius) {
                    continue
                }
                let rows = try variables.map { variable in
                    guard let data = try reader.get(mixed: variable, time: time.toSettings()) else {
                        fatalError("Invalid variable \(variable)")
                    }
                    return DataAndUnit(normalsCalculator.calculateDailyNormals(variable: variable, values: ArraySlice(data.data), time: time, rainDayDistribution: rainDayDistribution ?? .end).round(digits: data.unit.significantDigits), data.unit)
                }
                try writer.add(data: rows, variables: variables, timestamps: timestamps64, location: gridpoint, latitude: coords.latitude, longitude: coords.longitude, elevation: elevation.numeric)
                await progress.add(time.count * 4 * variables.count)
            }
            try writer.flush(closeFile: true)
            await progress.finish()
            return
        }

        logger.info("Writing data. Total raw size \((grid.count * time.count * 4 * variables.count).bytesHumanReadable)")
        let progress = TransferAmountTracker(logger: logger, totalSize: grid.count * time.count * 4 * variables.count, name: "Processed")
        let timestamps64 = time.map({Int64($0.timeIntervalSince1970)})
        
        /// Interpolate data from one grid to another and perform bias correction
        if let targetGridDomain {
            let targetDomain = targetGridDomain.genericDomain
            guard let elevationFile = targetDomain.getStaticFile(type: .elevation) else {
                fatalError("Could not read elevation file for domain \(targetDomain)")
            }
            
            for l in 0..<grid.count {
                let coords = grid.getCoordinates(gridpoint: l)
                if let latitudeBounds, !latitudeBounds.contains(coords.latitude) {
                    continue
                }
                if let longitudeBounds, !longitudeBounds.contains(coords.longitude) {
                    continue
                }
                let elevation = try grid.readElevation(gridpoint: l, elevationFile: elevationFile)
                if let onlySeaAroundSearchRadius, try grid.onlySeaAround(gridpoint: l, elevationFile: elevationFile, searchRadius: onlySeaAroundSearchRadius) {
                    continue
                }
                let reader = try domain.getReader(targetGridDomain: targetGridDomain, lat: coords.latitude, lon: coords.longitude, elevation: elevation.numeric, mode: .land)
                let rows = try variables.map { variable in
                    let reader = variable == "precipitation_sum_imerg" ? try domain.getReader(targetGridDomain: .imerg, lat: coords.latitude, lon: coords.longitude, elevation: elevation.numeric, mode: .land) : reader
                    let variable = variable == "precipitation_sum_imerg" ? "precipitation_sum" : variable
                    guard let data = try reader.get(mixed: variable, time: time.toSettings()) else {
                        fatalError("Invalid variable \(variable)")
                    }
                    return data
                }
                try writer.add(data: rows, variables: variables, timestamps: timestamps64, location: l, latitude: coords.latitude, longitude: coords.longitude, elevation: elevation.numeric)
                await progress.add(time.count * 4 * variables.count)
            }
            try writer.flush(closeFile: true)
            await progress.finish()
            return
        }
        
        // Loop over locations, read and write
        guard let elevationFile = domain.genericDomain.getStaticFile(type: .elevation) else {
            fatalError("Could not read elevation file for domain \(domain)")
        }
        for gridpoint in 0..<grid.count {
            // Read data
            let reader = try domain.getReader(position: gridpoint)
            let coords = grid.getCoordinates(gridpoint: gridpoint)
            if let latitudeBounds, !latitudeBounds.contains(coords.latitude) {
                continue
            }
            if let longitudeBounds, !longitudeBounds.contains(coords.longitude) {
                continue
            }
            let elevation = try grid.readElevation(gridpoint: gridpoint, elevationFile: elevationFile)
            if let onlySeaAroundSearchRadius, try grid.onlySeaAround(gridpoint: gridpoint, elevationFile: elevationFile, searchRadius: onlySeaAroundSearchRadius) {
                continue
            }
            let rows = try variables.map { variable in
                guard let data = try reader.get(mixed: variable, time: time.toSettings()) else {
                    fatalError("Invalid variable \(variable)")
                }
                return data
            }
            try writer.add(data: rows, variables: variables, timestamps: timestamps64, location: gridpoint, latitude: coords.latitude, longitude: coords.longitude, elevation: elevation.numeric)
            await progress.add(time.count * 4 * variables.count)
        }
        try writer.flush(closeFile: true)
        await progress.finish()
        
        #else
        fatalError("Apache Parquet support not enabled")
        #endif
    }
    
    func generateNetCdf(logger: Logger, file: String, domain: ExportDomain, variable: String, time: TimerangeDt, compressionLevel: Int?, targetGridDomain: TargetGridDomain?, outputCoordinates: Bool, outputElevation: Bool, normals: (years: [Int], width: Int)?, rainDayDistribution: DailyNormalsCalculator.RainDayDistribution?) async throws {
        let grid = targetGridDomain?.genericDomain.grid ?? domain.grid
        
        logger.info("Grid nx=\(grid.nx) ny=\(grid.ny) nTime=\(time.count) (\(time.prettyString()))")
        let ncFile = try NetCDF.create(path: file, overwriteExisting: true)
        try ncFile.setAttribute("TITLE", "\(domain) \(variable)")
        let latDimension = try ncFile.createDimension(name: "LAT", length: grid.ny)
        let lonDimension = try ncFile.createDimension(name: "LON", length: grid.nx)

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
            guard let elevationFile = targetDomain.getStaticFile(type: .elevation) else {
                fatalError("Could not read elevation file for domain \(targetDomain)")
            }
            try ncElevation.write(elevationFile.readAll())
        }
        
        // Calculate daily normals
        if let normals {
            let progress = TransferAmountTracker(logger: logger, totalSize: grid.count * time.count * 4, name: "Processed")
            let normalsCalculator = DailyNormalsCalculator(years: normals.years, normalsWidthInYears: normals.width)
            let nTimeNormals = normalsCalculator.timeBins.count * 365
            let timeDimension = try ncFile.createDimension(name: "time", length: nTimeNormals)
            var ncVariable = try ncFile.createVariable(name: "data", type: Float.self, dimensions: [latDimension, lonDimension, timeDimension])
            if let compressionLevel, compressionLevel > 0 {
                try ncVariable.defineDeflate(enable: true, level: compressionLevel, shuffle: true)
                try ncVariable.defineChunking(chunking: .chunked, chunks: [1, 1, nTimeNormals])
            }
            
            logger.info("Calculating daily normals. years=\(normals.years) width=\(normals.width) years. Total raw size \((grid.count * nTimeNormals * 4).bytesHumanReadable)")
            
            if let targetGridDomain {
                let targetDomain = targetGridDomain.genericDomain
                guard let elevationFile = targetDomain.getStaticFile(type: .elevation) else {
                    fatalError("Could not read elevation file for domain \(targetDomain)")
                }
                for l in 0..<grid.count {
                    let coords = grid.getCoordinates(gridpoint: l)
                    let elevation = try grid.readElevation(gridpoint: l, elevationFile: elevationFile)
                    
                    // Read data
                    let reader = try domain.getReader(targetGridDomain: targetGridDomain, lat: coords.latitude, lon: coords.longitude, elevation: elevation.numeric, mode: .land)
                    guard let data = try reader.get(mixed: variable, time: time.toSettings()) else {
                        fatalError("Invalid variable \(variable)")
                    }
                    let normals = normalsCalculator.calculateDailyNormals(variable: variable, values: ArraySlice(data.data), time: time, rainDayDistribution: rainDayDistribution ?? .end)
                    try ncVariable.write(normals, offset: [l/grid.nx, l % grid.nx, 0], count: [1, 1, normals.count])
                    await progress.add(time.count * 4)
                }
                await progress.finish()
                return
            }
            // Loop over locations, read and write
            for gridpoint in 0..<grid.count {
                // Read data
                let reader = try domain.getReader(position: gridpoint)
                guard let data = try reader.get(mixed: variable, time: time.toSettings())?.data else {
                    fatalError("Invalid variable \(variable)")
                }
                let normals = normalsCalculator.calculateDailyNormals(variable: variable, values: ArraySlice(data), time: time, rainDayDistribution: rainDayDistribution ?? .end)
                try ncVariable.write(normals, offset: [gridpoint/grid.nx, gridpoint % grid.nx, 0], count: [1, 1, normals.count])
                await progress.add(time.count * 4)
            }
            await progress.finish()
            return
        }
        
        let timeDimension = try ncFile.createDimension(name: "time", length: time.count)
        var ncVariable = try ncFile.createVariable(name: "data", type: Float.self, dimensions: [latDimension, lonDimension, timeDimension])
        
        if let compressionLevel, compressionLevel > 0 {
            try ncVariable.defineDeflate(enable: true, level: compressionLevel, shuffle: true)
            try ncVariable.defineChunking(chunking: .chunked, chunks: [1, 1, time.count])
        }
        
        logger.info("Writing data. Total raw size \((grid.count * time.count * 4).bytesHumanReadable)")
        let progress = TransferAmountTracker(logger: logger, totalSize: grid.count * time.count * 4, name: "Processed")
        
        /// Interpolate data from one grid to another and perform bias correction
        if let targetGridDomain {
            let targetDomain = targetGridDomain.genericDomain
            guard let elevationFile = targetDomain.getStaticFile(type: .elevation) else {
                fatalError("Could not read elevation file for domain \(targetDomain)")
            }
            
            for l in 0..<grid.count {
                let coords = grid.getCoordinates(gridpoint: l)
                let elevation = try grid.readElevation(gridpoint: l, elevationFile: elevationFile)
                
                // Read data
                let reader = try domain.getReader(targetGridDomain: targetGridDomain, lat: coords.latitude, lon: coords.longitude, elevation: elevation.numeric, mode: .land)
                guard let data = try reader.get(mixed: variable, time: time.toSettings()) else {
                    fatalError("Invalid variable \(variable)")
                }
                try ncVariable.write(data.data, offset: [l/grid.nx, l % grid.nx, 0], count: [1, 1, time.count])
                await progress.add(time.count * 4)
            }
            await progress.finish()
            return
        }
        
        // Loop over locations, read and write
        for gridpoint in 0..<grid.count {
            // Read data
            let reader = try domain.getReader(position: gridpoint)
            guard let data = try reader.get(mixed: variable, time: time.toSettings()) else {
                fatalError("Invalid variable \(variable)")
            }
            try ncVariable.write(data.data, offset: [gridpoint/grid.nx, gridpoint % grid.nx, 0], count: [1, 1, time.count])
            await progress.add(time.count * 4)
        }
        
        await progress.finish()
    }
}

extension Gridable {
    /// Return true if there is no land around a 5x5 box
    /// `searchRadius = 2` for 5x5 search
    func onlySeaAround(gridpoint: Int, elevationFile: OmFileReader<MmapFileCached>, searchRadius: Int) throws -> Bool {
        let yy = gridpoint / nx
        let xx = gridpoint % nx
        for y in min(max(yy-searchRadius,0),ny) ..< min(max(yy+searchRadius+1,0),ny) {
            for x in min(max(xx-searchRadius,0),nx) ..< min(max(xx+searchRadius+1,0),nx){
                let point = max(0, min(y * nx + x, count))
                if try !readElevation(gridpoint: point, elevationFile: elevationFile).isSea {
                    return false
                }
            }
        }
        return true
    }
}

/// Calculate daily normals. Combine 5 days to have some sort of statistical significance.
struct DailyNormalsCalculator {
    /// Timerange of individual ranges that may overlap. E.g.  `2025-2034`, `2030-2039`, `2035-2044`, `2040-2049`
    let timeBins: [Range<Timestamp>]
    
    /// Create normals over a given timespan
    init(years: [Int], normalsWidthInYears: Int) {
        timeBins = years.map { year in
            // in case 5 years width, use the year 2022 as center and form 2020-2024 normals
            Timestamp(year - normalsWidthInYears / 2, 1, 1) ..< Timestamp(year + normalsWidthInYears / 2 + normalsWidthInYears % 2, 1, 1)
        }
    }
    
    /// Switch to precipitation daily normals if required
    func calculateDailyNormals(variable: String, values: ArraySlice<Float>, time: TimerangeDt, rainDayDistribution: RainDayDistribution) -> [Float] {
        return ["precipitation_sum", "snowfall_water_equivalent_sum"].contains(variable) ?
            calculateDailyNormalsPreserveDryDays(values: values, time: time, rainDayDistribution: rainDayDistribution) :
            calculateDailyNormals(values: values, time: time)
    }
    
    /// Calculate mean daily normals
    /// Total `time` of entire data series... e.g. `2025-2049`
    func calculateDailyNormals(values: ArraySlice<Float>, time: TimerangeDt) -> [Float] {
        let nBins = timeBins.count
        var sum = [Float](repeating: 0, count: nBins * 365)
        var count = [Float](repeating: 0, count: nBins * 365)
        for (t, value) in zip(time, values) {
            for (bin, binTime) in timeBins.enumerated() {
                guard binTime.contains(t) else {
                    continue
                }
                for i in -2...2 {
                    /// 0-364
                    let dayOfYear = Int(Float(t.add(days: i).timeIntervalSince1970 / 86400).truncatingRemainder(dividingBy: 365.25)) % 365
                    sum[bin * 365 + dayOfYear] += value
                    count[bin * 365 + dayOfYear] += 1
                }
            }
        }
        for i in sum.indices {
            sum[i] /= count[i]
        }
        return sum
    }
    
    
    enum RainDayDistribution: String, CaseIterable {
        /// Place all rainy days at the beginning of each week
        case end
        
        /// Distribute rainy days throughout the week
        case mixed
    }
    
    /// Calculate daily mean values, but preserve events below a certain threshold. E.g. for precipitation. Approach:
    /// - Split a year into 52 parts (each 7 days long)
    /// - For each "part" calculate sum, count and the number below a threshold
    /// - Also distribute each "value" into 5 parts to reduce outliners. Effectivly calcualting 35 days sliding values
    /// - To restore daily normals, calculate the average for each part and distribute according to "days below threshold"
    /// - Days below threhold (dry days) will be at the beginning of each 11-day part
    ///
    /// Total `time` of entire data series... e.g. `2025-2049`
    func calculateDailyNormalsPreserveDryDays(values: ArraySlice<Float>, time: TimerangeDt, lowerThanThreshold: Float = 0.3, rainDayDistribution: RainDayDistribution) -> [Float] {
        let nBins = timeBins.count
        
        /// Number of parts to split a year into. 365.25 / 52 = ~7.02 days
        let partPerYear = 52
        /// Sum of all values
        var partsSum = [Float](repeating: 0, count: nBins * partPerYear)
        /// Sum of all events where value is below threshold
        var partsEvents = [Float](repeating: 0, count: nBins * partPerYear)
        /// Number of values accumulated for this part
        var partsCount = [Float](repeating: 0, count: nBins * partPerYear)
        /// Number of seconds in e.g. ~7 days
        let secondsPerPart = Timestamp.secondsPerAverageYear / partPerYear
        
        // Calculate statistics for each part
        for (t, value) in zip(time, values) {
            for (bin, binTime) in timeBins.enumerated() {
                guard binTime.contains(t) else {
                    continue
                }
                let partIndex = (t.timeIntervalSince1970 / secondsPerPart) % partPerYear
                // Distribute the value also to the previous and next bin
                for i in -2...2 {
                    partsSum[bin * partPerYear + ((partIndex+i) % partPerYear)] += value
                    partsCount[bin * partPerYear + ((partIndex+i) % partPerYear)] += 1
                    if value < lowerThanThreshold {
                        partsEvents[bin * partPerYear + ((partIndex+i) % partPerYear)] += 1
                    }
                }
            }
        }
        // Restore 365 daily normals. The first days of a part will always be "dry days"
        return (0..<365*nBins).map { i in
            let daysPerPart = 365 / partPerYear
            let yearIndex = i / 365
            let partIndex = min((i % 365) / daysPerPart, partPerYear-1)
            let index = yearIndex * partPerYear + partIndex
            let fractionBelowThreshold = partsEvents[index] / partsSum[index]
            let dryDays = Int(round(fractionBelowThreshold * Float(daysPerPart)))
            let wetDays = max(daysPerPart - dryDays, 1)
            let dayOfPart = i % daysPerPart
            switch rainDayDistribution {
            case .end:
                if dayOfPart < dryDays {
                    return 0
                }
            case .mixed:
                let rainDayPositions: [Int]
                switch wetDays {
                case 1:
                    rainDayPositions = [3]
                case 2:
                    rainDayPositions = [1, 4]
                case 3:
                    rainDayPositions = [1, 3, 5]
                case 4:
                    rainDayPositions = [0, 2, 4, 6]
                case 5:
                    rainDayPositions = [0, 2, 4, 5, 6]
                case 6:
                    rainDayPositions = [0, 1, 2, 4, 5, 6]
                case 7:
                    rainDayPositions = [0, 1, 2, 3, 4, 5, 6]
                default:
                    fatalError("Not reachable")
                }
                if !rainDayPositions.contains(dayOfPart) {
                    return 0
                }
            }
            return partsSum[index] / partsCount[index] / (Float(wetDays) / Float(daysPerPart))
        }
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

enum ExportFormat: String, RawRepresentableString, CaseIterable {
    case netcdf
    case parquet
}

enum ExportDomain: String, CaseIterable {
    case CMCC_CM2_VHR4
    case FGOALS_f3_H
    case HiRAM_SIT_HR
    case MRI_AGCM3_2_S
    case EC_Earth3P_HR
    case MPI_ESM1_2_XR
    case NICAM16_8S
    case glofas_v3_consolidated
    case glofas_v4_consolidated
    case glofas_v3_forecast
    case glofas_v3_seasonal
    case era5_land
    case era5
    case ecmwf_ifs
    
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
        case .glofas_v3_consolidated:
            return GloFasDomain.consolidatedv3
        case .glofas_v4_consolidated:
            return GloFasDomain.consolidated
        case .glofas_v3_forecast:
            return GloFasDomain.forecastv3
        case .glofas_v3_seasonal:
            return GloFasDomain.seasonalv3
        case .era5_land:
            return CdsDomain.era5_land
        case .era5:
            return CdsDomain.era5
        case .ecmwf_ifs:
            return CdsDomain.ecmwf_ifs
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
        case .glofas_v3_consolidated:
            return nil
        case .glofas_v4_consolidated:
            return nil
        case .glofas_v3_forecast:
            return nil
        case .glofas_v3_seasonal:
            return nil
        case .era5_land:
            return nil
        case .era5:
            return nil
        case .ecmwf_ifs:
            return nil
        }
    }
    
    var grid: Gridable {
        return genericDomain.grid
    }
    
    func getReader(position: Int) throws -> any GenericReaderProtocol {
        let options = GenericReaderOptions()
        
        switch self {
        case .CMCC_CM2_VHR4:
            return Cmip6ReaderPostBiasCorrected(reader: Cmip6ReaderPreBiasCorrection(reader: try GenericReader(domain: Cmip6Domain.CMCC_CM2_VHR4, position: position), domain: Cmip6Domain.CMCC_CM2_VHR4), domain: Cmip6Domain.CMCC_CM2_VHR4)
        case .MRI_AGCM3_2_S:
            return Cmip6ReaderPostBiasCorrected(reader: Cmip6ReaderPreBiasCorrection(reader: try GenericReader(domain: Cmip6Domain.MRI_AGCM3_2_S, position: position), domain: .MRI_AGCM3_2_S), domain: .MRI_AGCM3_2_S)
        case .FGOALS_f3_H:
            return Cmip6ReaderPostBiasCorrected(reader: Cmip6ReaderPreBiasCorrection(reader: try GenericReader(domain: Cmip6Domain.FGOALS_f3_H, position: position), domain: .FGOALS_f3_H), domain: .FGOALS_f3_H)
        case .HiRAM_SIT_HR:
            return Cmip6ReaderPostBiasCorrected(reader: Cmip6ReaderPreBiasCorrection(reader: try GenericReader(domain: Cmip6Domain.HiRAM_SIT_HR, position: position), domain: .HiRAM_SIT_HR), domain: .HiRAM_SIT_HR)
        case .EC_Earth3P_HR:
            return Cmip6ReaderPostBiasCorrected(reader: Cmip6ReaderPreBiasCorrection(reader: try GenericReader(domain: Cmip6Domain.EC_Earth3P_HR, position: position), domain: .EC_Earth3P_HR), domain: .EC_Earth3P_HR)
        case .MPI_ESM1_2_XR:
            return Cmip6ReaderPostBiasCorrected(reader: Cmip6ReaderPreBiasCorrection(reader: try GenericReader(domain: Cmip6Domain.MPI_ESM1_2_XR, position: position), domain: .MPI_ESM1_2_XR), domain: .MPI_ESM1_2_XR)
        case .NICAM16_8S:
            return Cmip6ReaderPostBiasCorrected(reader: Cmip6ReaderPreBiasCorrection(reader: try GenericReader(domain: Cmip6Domain.NICAM16_8S, position: position), domain: .NICAM16_8S), domain: .NICAM16_8S)
        case .glofas_v3_consolidated:
            return try GenericReader<GloFasDomain, GloFasVariable>(domain: GloFasDomain.consolidatedv3, position: position)
        case .glofas_v4_consolidated:
            return try GenericReader<GloFasDomain, GloFasVariable>(domain: GloFasDomain.consolidated, position: position)
        case .glofas_v3_forecast:
            return try GenericReader<GloFasDomain, GloFasVariable>(domain: GloFasDomain.forecastv3, position: position)
        case .glofas_v3_seasonal:
            return try GenericReader<GloFasDomain, GloFasVariableMember>(domain: GloFasDomain.seasonalv3, position: position)
        case .era5_land:
            return Era5Reader(reader: GenericReaderCached<CdsDomain, Era5Variable>(reader: try GenericReader<CdsDomain, Era5Variable>(domain: .era5_land, position: position)), options: options)
        case .era5:
            return Era5Reader(reader: GenericReaderCached<CdsDomain, Era5Variable>(reader: try GenericReader<CdsDomain, Era5Variable>(domain: .era5, position: position)), options: options)
        case .ecmwf_ifs:
            return Era5Reader(reader: GenericReaderCached<CdsDomain, Era5Variable>(reader: try GenericReader<CdsDomain, Era5Variable>(domain: .ecmwf_ifs, position: position)), options: options)
        }
    }
    
    func getReader(targetGridDomain: TargetGridDomain, lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode) throws -> any GenericReaderProtocol {

        guard let cmipDomain = self.cmipDomain else {
            fatalError("Regridding only supported for CMIP domains")
        }
        switch targetGridDomain {
        case .era5_interpolated_10km:
            guard let biasCorrector = try Cmip6BiasCorrectorInterpolatedWeights(domain: cmipDomain, referenceDomain: CdsDomain.era5, lat: lat, lon: lon, elevation: elevation, mode: mode) else {
                throw ForecastapiError.noDataAvilableForThisLocation
            }
            return Cmip6ReaderPostBiasCorrected(reader: biasCorrector, domain: cmipDomain)
        case .era5_land:
            guard let biasCorrector = try Cmip6BiasCorrectorEra5Seamless(domain: cmipDomain, lat: lat, lon: lon, elevation: elevation, mode: mode) else {
                throw ForecastapiError.noDataAvilableForThisLocation
            }
            return Cmip6ReaderPostBiasCorrected(reader: biasCorrector, domain: cmipDomain)
        case .imerg:
            guard let biasCorrector = try Cmip6BiasCorrectorGenericDomain(domain: cmipDomain, referenceDomain: SatelliteDomain.imerg_daily, lat: lat, lon: lon, elevation: elevation, mode: mode) else {
                throw ForecastapiError.noDataAvilableForThisLocation
            }
            return Cmip6ReaderPostBiasCorrected(reader: biasCorrector, domain: cmipDomain)
        }
    }
}
