import Foundation
import Vapor
import OmFileFormat

/**
Upgrade legacy om-files to new version. Transposes data to proper 3d context.
 */
struct MigrationCommand: AsyncCommand {
    struct Signature: CommandSignature {
        @Flag(name: "execute", help: "Perform file moves")
        var execute: Bool
    }
    
    var help: String {
        "Perform database migration"
    }
    
    func run(using context: CommandContext, signature: Signature) async throws {
        let logger = context.application.logger
        // loop over data directory
        let execute = signature.execute
        
        let pathUrl = URL(fileURLWithPath: OpenMeteo.dataDirectory, isDirectory: true)
        let resourceKeys = Set<URLResourceKey>([.nameKey, .isDirectoryKey, .contentModificationDateKey, .fileSizeKey])
        
        guard let directoryEnumerator = FileManager.default.enumerator(at: pathUrl, includingPropertiesForKeys: Array(resourceKeys), options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]) else {
            logger.warning("No files at \(pathUrl)")
            return
        }
        
        for case let fileURL as URL in directoryEnumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: resourceKeys),
                  let isDirectory = resourceValues.isDirectory,
                  let name = resourceValues.name, 
                  !name.contains("~"),
                  isDirectory
            else {
                continue
            }
            
            guard let domain = DomainRegistry(rawValue: name) else {
                logger.warning("Skipping \(name)")
                continue
            }
            let grid = domain == .copernicus_dem90 ? nil : domain.getDomain().grid
            guard let directoryEnumerator = FileManager.default.enumerator(at: URL(fileURLWithPath: "\(OpenMeteo.dataDirectory)\(name)", isDirectory: true), includingPropertiesForKeys: Array(resourceKeys), options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]) else {
                logger.warning("No files at \(OpenMeteo.dataDirectory)\(name)")
                continue
            }
            for case let fileURL as URL in directoryEnumerator {
                guard let resourceValues = try? fileURL.resourceValues(forKeys: resourceKeys),
                      let isDirectory = resourceValues.isDirectory,
                      let variable = resourceValues.name,
                      !variable.contains("~"),
                      isDirectory
                else {
                    continue
                }
                let path = "\(OpenMeteo.dataDirectory)\(name)/\(variable)"
                
                guard let directoryEnumerator = FileManager.default.enumerator(at: URL(fileURLWithPath: path, isDirectory: true), includingPropertiesForKeys: Array(resourceKeys), options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]) else {
                    logger.warning("No files at \(path)")
                    continue
                }
                for case let fileURL as URL in directoryEnumerator {
                    guard let resourceValues = try? fileURL.resourceValues(forKeys: resourceKeys),
                          let isDirectory = resourceValues.isDirectory,
                          let file = resourceValues.name,
                          !file.contains("~"),
                          file.suffix(3) == ".om",
                          !isDirectory
                    else {
                        continue
                    }
                    //logger.info("Processing \(domain)/\(variable)/\(file)")
                    try await convertToNewFormat(logger: logger, file: "\(path)/\(file)", grid: grid, execute: execute)
                }
            }
        }
    }
    
    /// Read om file and write it as version 3 and reshape data to proper 3d files
    /// If no grid is given, assume that files are converted 1:1. This is the case for the DEM model
    func convertToNewFormat(logger: Logger, file: String, grid: Gridable?, execute: Bool) async throws {
        let temporary = "\(file)~"
        FileManager.default.waitIfFileWasRecentlyModified(at: temporary)
        try FileManager.default.removeItemIfExists(at: temporary)
        // Read data from the input OM file
        guard let readfile = try? OmFileReader(file: file) else {
            logger.warning("Failed to open file: \(file)")
            return
        }
        guard let reader = readfile.asArray(of: Float.self), readfile.isLegacyFormat() else {
            logger.info("File already in new format \(file)")
            return
        }
        let dimensions = Array(reader.getDimensions())
        let chunks = Array(reader.getChunkDimensions())
        guard dimensions.count == 2 else {
            logger.warning("Invalid dimension count \(file)")
            return
        }
        let ny = UInt64(grid?.ny ?? Int(dimensions[0]))
        let nx = UInt64(grid?.nx ?? Int(dimensions[1]))
        
        
        // Simple file like surface elevation
        // No need to re-chunk data. Just 1:1 migration
        if dimensions.count == 2 && ny == dimensions[0] && nx == dimensions[1] {
            logger.info("Migrate simple \(file) dimensions=\(dimensions) chunks=\(chunks)")
            guard execute else {
                return
            }
            let writeFn = try FileHandle.createNewFile(file: temporary)
            let fileWriter = OmFileWriter(fn: writeFn, initialCapacity: 1024 * 1024 * 10)
            let writer = try fileWriter.prepareArray(
                type: Float.self,
                dimensions: dimensions,
                chunkDimensions: chunks,
                compression: reader.compression,
                scale_factor: reader.scaleFactor,
                add_offset: reader.addOffset
            )
            let data = try reader.read()
            try writer.writeData(array: data)
            let variable = try fileWriter.write(
                array: try writer.finalise(),
                name: "",
                children: []
            )
            try fileWriter.writeTrailer(rootVariable: variable)
            try writeFn.close()
            
            /// Read data again to ensure the written data matches exactly
            guard let verify = try OmFileReader(file: temporary).asArray(of: Float.self)?.read() else {
                fatalError("Could not read temporary file")
            }
            guard data.isSimilar(verify) else {
                fatalError("Data does not match")
            }
            try FileManager.default.moveFileOverwrite(from: temporary, to: file)
            return
        }
        
        guard dimensions.count == 2, nx * ny == dimensions[0] else {
            logger.warning("Dimensions do not agree \(file). E.g. no support for ensemble files")
            return
        }
        let nt = dimensions[1]
        let dimensionsOut = [ny, nx, nt]
        let chunksOut = [1,chunks[0],chunks[1]]
        logger.info("Migrate \(file) new dimensions=\(dimensionsOut) chunks=\(chunksOut)")
        
        guard execute else {
            return
        }
        
        let writeFn = try FileHandle.createNewFile(file: temporary)
        let fileWriter = OmFileWriter(fn: writeFn, initialCapacity: 1024 * 1024 * 10)
        let writer = try fileWriter.prepareArray(
            type: Float.self,
            dimensions: dimensionsOut,
            chunkDimensions: chunksOut,
            compression: reader.compression,
            scale_factor: reader.scaleFactor,
            add_offset: reader.addOffset
        )
        
        let progress = TransferAmountTracker(logger: logger, totalSize: 4 * Int(dimensions.reduce(1, *)), name: "Convert")

        /// Reshape data from flattened 2D to 3D context
        for yStart in stride(from: 0, to: ny, by: UInt64.Stride(chunksOut[0])) {
            for xStart in stride(from: 0, to: nx, by: UInt64.Stride(chunksOut[1])) {
                for tStart in stride(from: 0, to: nt, by: UInt64.Stride(chunksOut[2])) {
                    let yRange = yStart ..< min(yStart + chunksOut[0], ny)
                    let xRange = xStart ..< min(xStart + chunksOut[1], nx)
                    let tRange = tStart ..< min(tStart + chunksOut[2], nt)
                    //print("chunk y=\(yRange) x=\(xRange) t=\(tRange)")
                    
                    var chunk = [Float](repeating: .nan, count: yRange.count * xRange.count * tRange.count)
                    for (row, y) in yRange.enumerated() {
                        try reader.read(
                            into: &chunk,
                            range: [y * nx + xRange.startIndex ..< y * nx + xRange.endIndex, tRange],
                            intoCubeOffset: [UInt64(row * xRange.count), 0],
                            intoCubeDimension: [UInt64(yRange.count * xRange.count), UInt64(tRange.count)]
                        )
                    }
                    try writer.writeData(
                        array: chunk,
                        arrayDimensions: [UInt64(yRange.count), UInt64(xRange.count), UInt64(tRange.count)],
                        arrayOffset: nil,
                        arrayCount: nil
                    )
                    await progress.add(chunk.count * 4)
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
        let progressVerify = TransferAmountTracker(logger: logger, totalSize: 4 * Int(dimensions.reduce(1, *)), name: "Verify")
        for yStart in stride(from: 0, to: ny, by: UInt64.Stride(chunksOut[0])) {
            for xStart in stride(from: 0, to: nx, by: UInt64.Stride(chunksOut[1])) {
                for tStart in stride(from: 0, to: nt, by: UInt64.Stride(chunksOut[2])) {
                    let yRange = yStart ..< min(yStart + chunksOut[0], ny)
                    let xRange = xStart ..< min(xStart + chunksOut[1], nx)
                    let tRange = tStart ..< min(tStart + chunksOut[2], nt)
                    
                    var chunk = [Float](repeating: .nan, count: yRange.count * xRange.count * tRange.count)
                    for (row, y) in yRange.enumerated() {
                        try reader.read(
                            into: &chunk,
                            range: [y * nx + xRange.startIndex ..< y * nx + xRange.endIndex, tRange],
                            intoCubeOffset: [UInt64(row * xRange.count), 0],
                            intoCubeDimension: [UInt64(yRange.count * xRange.count), UInt64(tRange.count)]
                        )
                    }
                    let verifyData = try verify.read(range: [yRange, xRange, tRange])
                    guard chunk.isSimilar(verifyData) else {
                        fatalError("Data does not match \(yRange) \(xRange) \(tRange)")
                    }
                    await progressVerify.add(chunk.count * 4)
                }
            }
        }
        await progressVerify.finish()
        try FileManager.default.moveFileOverwrite(from: temporary, to: file)
    }
}

fileprivate extension Array where Element == Float {
    func isSimilar(_ b: [Float], accuracy: Float = 0.0001) -> Bool {
        let a = self
        guard a.count == b.count else {
            return false
        }
        for (a1,b1) in zip(a,b) {
            if a1.isNaN && b1.isNaN {
                continue
            }
            if a1.isNaN || b1.isNaN || abs(a1 - b1) > accuracy {
                return false
            }
        }
        return true
    }
}
