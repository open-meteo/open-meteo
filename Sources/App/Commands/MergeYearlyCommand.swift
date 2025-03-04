import Foundation
import OmFileFormat
import Vapor


struct MergeYearlyCommand: AsyncCommand {
    var help: String {
        return "Merge database chunks into yearly files"
    }
    
    struct Signature: CommandSignature {
        @Argument(name: "domain", help: "Domain e.g. ")
        var domain: String
        
        @Argument(name: "years", help: "A singe year or a range of years. E.g. 2017-2020")
        var years: String
        
        @Option(name: "variables", help: "Only process a list of coma separated variables")
        var variables: String?
        
        @Flag(name: "force", help: "Generate yearly file, even if it already exists")
        var force: Bool
        
        @Flag(name: "delete", help: "Delete the underlaying chunks")
        var delete: Bool
    }
    
    func run(using context: CommandContext, signature: Signature) async throws {
        let logger = context.application.logger
        let domain = try DomainRegistry.load(rawValue: signature.domain)
        let years = signature.years.getYearsRange()
        
        let variables: [String] = try signature.variables.map({$0.split(separator: ",").map(String.init)}) ?? FileManager.default.contentsOfDirectory(atPath: domain.directory).filter { !$0.contains(".") && $0 != "static" }
        
        for year in years {
            for variable in variables {
                try await Self.generateYearlyFile(logger: logger, domain: domain.getDomain(), year: year, variable: variable, force: signature.force)
            }
        }
        
        // determinate chunks to be deleted (chunk fully covered in years range)
        // print chunks to be deleted
        // if delete flag is set, actually delete them
    }
    
    /// Generate a yearly file for a specified domain, variable and year
    static func generateYearlyFile(logger: Logger, domain: GenericDomain, year: Int, variable: String, force: Bool) async throws {
        let registry = domain.domainRegistry
        logger.info("Processing variable \(variable) for year \(year)")
        let yearlyFilePath = "\(registry.directory)/\(variable)/year_\(year).om"
        let fileManager = FileManager.default
        
        guard !fileManager.fileExists(atPath: yearlyFilePath) || force else {
            logger.info("Yearly file /\(variable)/year_\(year).om already exists. Skipping.")
            return
        }
        
        let omFileLength = domain.omFileLength
        let dtSeconds = domain.dtSeconds
        let yearTime = TimerangeDt(start: Timestamp(year, 1, 1), to: Timestamp(year+1, 1, 1), dtSeconds: dtSeconds)
        let grid = domain.grid
        let ny = UInt64(grid.ny)
        let nx = UInt64(grid.nx)
        let nt = UInt64(yearTime.count)
        let indexTime = yearTime.toIndexTime()
        let chunkRange = indexTime.divideRoundedUp(divisor: omFileLength)
        let chunkFiles = try chunkRange.compactMap { chunkIndex -> (file: OmFileReaderArray<MmapFile, Float>, indexTime: Range<Int>)? in
            let file = "\(registry.directory)/\(variable)/chunk_\(chunkIndex).om"
            guard fileManager.fileExists(atPath: file) else {
                logger.info("Chunk file \(variable)/chunk_\(chunkIndex).om does not exist. Skipping.")
                return nil
            }
            guard let reader = try OmFileReader(file: file).asArray(of: Float.self) else {
                return nil
            }
            /*guard reader.getDimensions().count == 3 else {
                logger.info("Chunk file \(variable)/chunk_\(chunkIndex).om is not using 3D files. Skipping.")
                return nil
            }*/
            let indexTime = chunkIndex*omFileLength ..< (chunkIndex+1)*omFileLength
            return (reader, indexTime)
        }
        guard chunkFiles.count == chunkRange.count else {
            logger.warning("Not all chunk files are available. Skipping year \(year).")
            return
        }
        
        /// Hardcoded to 6 locations times 21 days => 3024 elements. Maybe find a better chunk shape.
        let chunksOut: [UInt64] = [1, 6, 21 * 24]
        //let chunksXY = OmFileSplitter.calculateSpatialXYChunk(domain: domain.getDomain(), nMembers: 1, nTime: 1)
        //let chunksOut = [UInt64(chunksXY.y), UInt64(chunksXY.x), UInt64(omFileLength * 4)]
        
        let dimensionsOut = [ny, nx, UInt64(yearTime.count)]
        
        let temporary = "\(yearlyFilePath)~"
        let writeFn = try FileHandle.createNewFile(file: temporary)
        let fileWriter = OmFileWriter(fn: writeFn, initialCapacity: 1024 * 1024 * 10)
        let writer = try fileWriter.prepareArray(
            type: Float.self,
            dimensions: dimensionsOut,
            chunkDimensions: chunksOut,
            compression: chunkFiles.last!.file.compression,
            scale_factor: chunkFiles.last!.file.scaleFactor,
            add_offset: chunkFiles.last!.file.addOffset
        )
        
        let progress = TransferAmountTracker(logger: logger, totalSize: 4 * Int(dimensionsOut.reduce(1, *)), name: "Convert")
        for yStart in stride(from: 0, to: ny, by: UInt64.Stride(chunksOut[0])) {
            for xStart in stride(from: 0, to: nx, by: UInt64.Stride(chunksOut[1])) {
                for tStart in stride(from: 0, to: nt, by: UInt64.Stride(chunksOut[2])) {
                    let yRange = yStart ..< min(yStart + chunksOut[0], ny)
                    let xRange = xStart ..< min(xStart + chunksOut[1], nx)
                    let tRange = tStart ..< min(tStart + chunksOut[2], nt)
                    let chunkIndexTime = Int(tRange.lowerBound) + indexTime.lowerBound ..< Int(tRange.upperBound) + indexTime.lowerBound
                    
                    var data = [Float](repeating: .nan, count: yRange.count * xRange.count * tRange.count)
                    //print("chunk y=\(yRange) x=\(xRange) t=\(tRange)")
                    for chunk in chunkFiles {
                        guard let offsets = chunkIndexTime.intersect(fileTime: chunk.indexTime) else {
                            continue
                        }
                        switch chunk.file.getDimensions().count {
                        case 2:
                            // legacy 2D case
                            for (row, y) in yRange.enumerated() {
                                try chunk.file.read(
                                    into: &data,
                                    range: [y * nx + xRange.startIndex ..< y * nx + xRange.endIndex, offsets.file.toUInt64()],
                                    intoCubeOffset: [UInt64(row * xRange.count), UInt64(offsets.array.lowerBound)],
                                    intoCubeDimension: [UInt64(yRange.count * xRange.count), UInt64(tRange.count)]
                                )
                            }
                        case 3:
                            try chunk.file.read(
                                into: &data,
                                range: [yRange, xRange, offsets.file.toUInt64()],
                                intoCubeOffset: [0, 0, UInt64(offsets.array.lowerBound)],
                                intoCubeDimension: [UInt64(yRange.count), UInt64(xRange.count), UInt64(tRange.count)]
                            )
                        default:
                            fatalError("Unexpected number of dimensions")
                        }
                    }
                    try writer.writeData(
                        array: data,
                        arrayDimensions: [UInt64(yRange.count), UInt64(xRange.count), UInt64(tRange.count)],
                        arrayOffset: nil,
                        arrayCount: nil
                    )
                    await progress.add(data.count * 4)
                }
            }
        }
        await progress.finish()
        let variable = try fileWriter.write(
            array: try writer.finalise(),
            name: "",
            children: []
        )
        try fileWriter.writeTrailer(rootVariable: variable)
        try writeFn.close()
        
        /// Read data again to ensure the written data matches exactly
        guard let verify = try OmFileReader(file: temporary).asArray(of: Float.self) else {
            fatalError("Could not read temporary file")
        }
        let progressVerify = TransferAmountTracker(logger: logger, totalSize: 4 * Int(dimensionsOut.reduce(1, *)), name: "Verify")
        for yStart in stride(from: 0, to: ny, by: UInt64.Stride(chunksOut[0])) {
            for xStart in stride(from: 0, to: nx, by: UInt64.Stride(chunksOut[1])) {
                for tStart in stride(from: 0, to: nt, by: UInt64.Stride(chunksOut[2])) {
                    let yRange = yStart ..< min(yStart + chunksOut[0], ny)
                    let xRange = xStart ..< min(xStart + chunksOut[1], nx)
                    let tRange = tStart ..< min(tStart + chunksOut[2], nt)
                    let chunkIndexTime = Int(tRange.lowerBound) + indexTime.lowerBound ..< Int(tRange.upperBound) + indexTime.lowerBound
                    
                    var data = [Float](repeating: .nan, count: yRange.count * xRange.count * tRange.count)
                    for chunk in chunkFiles {
                        guard let offsets = chunkIndexTime.intersect(fileTime: chunk.indexTime) else {
                            continue
                        }
                        switch chunk.file.getDimensions().count {
                        case 2:
                            // legacy 2D case
                            for (row, y) in yRange.enumerated() {
                                try chunk.file.read(
                                    into: &data,
                                    range: [y * nx + xRange.startIndex ..< y * nx + xRange.endIndex, offsets.file.toUInt64()],
                                    intoCubeOffset: [UInt64(row * xRange.count), UInt64(offsets.array.lowerBound)],
                                    intoCubeDimension: [UInt64(yRange.count * xRange.count), UInt64(tRange.count)]
                                )
                            }
                        case 3:
                            try chunk.file.read(
                                into: &data,
                                range: [yRange, xRange, offsets.file.toUInt64()],
                                intoCubeOffset: [0, 0, UInt64(offsets.array.lowerBound)],
                                intoCubeDimension: [UInt64(yRange.count), UInt64(xRange.count), UInt64(tRange.count)]
                            )
                        default:
                            fatalError("Unexpected number of dimensions")
                        }
                    }
                    let verifyData = try verify.read(range: [yRange, xRange, tRange])
                    guard data.isSimilar(verifyData) else {
                        fatalError("Data does not match \(yRange) \(xRange) \(tRange)")
                    }
                    await progressVerify.add(data.count * 4)
                }
            }
        }
        await progressVerify.finish()
        try FileManager.default.moveFileOverwrite(from: temporary, to: yearlyFilePath)
    }
}

fileprivate extension String {
    /// Expect a single year or a range of years. Format `2017` or `2017-2020`
    func getYearsRange(valid: ClosedRange<Int> = 1900...2100) -> ClosedRange<Int> {
        if self.contains("-") {
            let parts = self.split(separator: "-")
            guard parts.count == 2,
                  parts[0].count == 4,
                  parts[1].count == 4,
                  let first = Int(parts[0]),
                  let last = Int(parts[1]),
                  valid.contains(first),
                  valid.contains(last),
                  last >= first
            else {
                fatalError("Invalid year range: \(self)")
            }
            return first...last
        }
        guard self.count == 4,
              let year = Int(self),
              valid.contains(year)
        else {
            fatalError("Invalid year range: \(self)")
        }
        return year ... year
    }
}
