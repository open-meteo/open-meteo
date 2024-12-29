import Foundation
import Vapor
import OmFileFormat

/**
Upgrade legacy om-files to new version. Transposes data to proper 3d context.
 */
struct MigrationCommand: Command {
    struct Signature: CommandSignature {
        @Flag(name: "execute", help: "Perform file moves")
        var execute: Bool
    }
    
    var help: String {
        "Perform database migration"
    }
    
    func run(using context: CommandContext, signature: Signature) throws {
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
            
            guard let domain = DomainRegistry(rawValue: name), domain != .copernicus_dem90 else {
                logger.warning("Skipping \(name)")
                continue
            }
            let grid = domain.getDomain().grid
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
                
                logger.info("Processing \(domain) variable \(variable)")
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
                    logger.info("Processing \(domain)/\(variable)/\(file)")
                    try convertToNewFormat(logger: logger, file: "\(path)/\(file)", grid: grid, execute: execute)
                }
            }
        }
    }
    
    /// Read om file and write it as version 3 and reshape data to proper 3d files
    func convertToNewFormat(logger: Logger, file: String, grid: Gridable, execute: Bool) throws {
        let temporary = "\(file)~"
        // Read data from the input OM file
        guard let readfile = try? OmFileReader2(file: file),
              let reader = readfile.asArray(of: Float.self) else {
            logger.warning("Failed to open file: \(file)")
            return
        }
        let dimensions = Array(reader.getDimensions())
        let chunks = Array(reader.getChunkDimensions())
        let ny = UInt64(grid.ny)
        let nx = UInt64(grid.nx)
        let nt = dimensions[1]
        
        // TODO check for legacy files. static files stay the same
        guard dimensions.count == 2, nx * ny == dimensions[0] else {
            logger.warning("Dimensions do not agree \(file)")
            return
        }
        let dimensionsOut = [ny, nx, nt]
        let chunksOut = [1,chunks[0],chunks[1]]
        logger.info("Migrate \(file) new dimensions=\(dimensionsOut) chunks=\(chunksOut)")
        
        guard execute else {
            return
        }
        
        // TODO migrate small issues like pressure in era5 files?
        
        
        try FileManager.default.removeItemIfExists(at: temporary)
        let writeFn = try FileHandle.createNewFile(file: temporary)

        // Write the compressed data to the output OM file
        let fileWriter = OmFileWriter2(fn: writeFn, initialCapacity: 1024 * 1024 * 10) // Initial capacity of 10MB

        let writer = try fileWriter.prepareArray(
            type: Float.self,
            dimensions: dimensionsOut,
            chunkDimensions: chunksOut,
            compression: reader.compression,
            scale_factor: reader.scaleFactor,
            add_offset: reader.addOffset
        )

        /// Reshape data from flated 2D to 3D context
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
                }
            }
        }
       

        let variable = try fileWriter.write(
            array: try writer.finalise(),
            name: "",
            children: []
        )
        try fileWriter.writeTrailer(rootVariable: variable)

        try writeFn.close()
        try FileManager.default.moveFileOverwrite(from: temporary, to: file)
    }
}
