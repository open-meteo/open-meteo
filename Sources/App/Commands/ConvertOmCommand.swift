import Foundation
import OmFileFormat
import Vapor
import SwiftNetCDF

/**
 Small helper tool to convert between `om` versions and between om file format and NetCDF for debugging

 Examples:
  - Convert to NetCDF: openmeteo-api convert-om data.om --format netcdf -o output.nc --domain ecmwf_ifs025
  - Convert between OM versions: openmeteo-api convert-om data.om --format om3 -o data.om3 --domain ecmwf_ifs025
 */
struct ConvertOmCommand: Command {
    var help: String {
        return "Convert between om file format version or convert to NetCDF"
    }

    struct Signature: CommandSignature {
        @Argument(name: "infile", help: "Input file")
        var infile: String

        @Option(name: "format", help: "Conversion target format: 'netcdf' or 'om3'")
        var format: String?

        @Option(name: "output", short: "o", help: "Output file name. Default: [infile].nc or [infile].om3")
        var outfile: String?

        @Flag(name: "transpose", help: "Transpose data to fast space")
        var transpose: Bool

        @Option(name: "domain", help: "Domain used for grid definition")
        var domain: String?
    }

    func run(using context: CommandContext, signature: Signature) throws {
        let logger = context.application.logger
        logger.info("Processing file: \(signature.infile)")

        let format = signature.format?.lowercased() ?? "netcdf"

        if format == "om3" {
            // Handle conversion to OM3
            guard let domain = signature.domain else {
                throw ConvertOmError("Domain parameter is required for OM3 conversion")
            }
            let domainObj = try DomainRegistry.load(rawValue: domain)
            let outfile = signature.outfile ?? signature.infile.withoutOmSuffix + ".om3"
            if signature.transpose {
                logger.warning("Transpose flag is currently not supported for OM3 conversion")
            }
            logger.info("Converting OM file to v3 with domain: \(domain). Outfile will be: \(outfile)")
            guard let grid = domainObj.getDomain()?.grid else {
                fatalError("Did not get domain grid")
            }
            try convertOmv3(src: signature.infile, dest: outfile, grid: grid)
            return
        } else if format == "netcdf" {
            // Handle conversion to NetCDF
            guard let om = try OmFileReader(file: signature.infile).asArray(of: Float.self) else {
                throw ConvertOmError("Not a float array")
            }
            let dimensions = Array(om.getDimensions())
            let chunks = Array(om.getChunkDimensions())
            logger.info("File dimensions: \(dimensions), chunks: \(chunks)")

            let data = try om.read()
            let outfile = signature.outfile ?? signature.infile.withoutOmSuffix + ".nc"
            logger.info("Converting to NetCDF: \(outfile)")
            try convertToNetCDF(data: data, dimensions: dimensions, outfile: outfile, transpose: signature.transpose, domain: signature.domain, logger: logger)
            return
        } else {
            throw ConvertOmError("Unsupported conversion target: \(format)")
        }
    }

    /// Convert data to NetCDF format
    private func convertToNetCDF(data: [Float], dimensions: [UInt64], outfile: String, transpose: Bool, domain: String?, logger: Logger) throws {
        let ncFile = try NetCDF.create(path: outfile, overwriteExisting: true)
        try ncFile.setAttribute("TITLE", "open-meteo data")

        switch dimensions.count {
        case 2:
            try convertToNetCDF2D(data: data, dimensions: dimensions, ncFile: ncFile, transpose: transpose, domain: domain, logger: logger)
        case 3:
            try convertToNetCDF3D(data: data, dimensions: dimensions, ncFile: ncFile, transpose: transpose)
        default:
            logger.error("Unsupported number of dimensions for netcdf conversion: \(dimensions.count)")
            throw ConvertOmError("Unsupported number of dimensions: \(dimensions.count)")
        }

        logger.info("NetCDF conversion completed successfully")
    }

    /// Handle 2D data conversion to NetCDF
    private func convertToNetCDF2D(data: [Float], dimensions: [UInt64], ncFile: Group, transpose: Bool, domain: String?, logger: Logger) throws {
        if let domain = domain {
            let domainObj = try DomainRegistry.load(rawValue: domain)
            guard let grid = domainObj.getDomain()?.grid else {
                fatalError("Did not get domain grid")
            }
            let ny = grid.ny
            let nx = grid.nx
            let nt = Int(dimensions[1])

            guard dimensions[0] == nx * ny, ny > 1, nx > 1 else {
                throw ConvertOmError("Wrong grid! Expected \(nx * ny) locations, got \(dimensions[0])")
            }

            if transpose {
                // Fast time dimension (locations, time) -> (time, locations)
                var ncVariable = try ncFile.createVariable(name: "data", type: Float.self, dimensions: [
                    try ncFile.createDimension(name: "time", length: nt),
                    try ncFile.createDimension(name: "LAT", length: ny),
                    try ncFile.createDimension(name: "LON", length: nx)
                ])
                let transposedData = Array2DFastTime(data: data, nLocations: nx * ny, nTime: nt).transpose()
                try ncVariable.write(transposedData.data)
            } else {
                // Default layout
                var ncVariable = try ncFile.createVariable(name: "data", type: Float.self, dimensions: [
                    try ncFile.createDimension(name: "LAT", length: ny),
                    try ncFile.createDimension(name: "LON", length: nx),
                    try ncFile.createDimension(name: "time", length: nt)
                ])
                try ncVariable.write(data)
            }
        } else {
            logger.warning("No domain provided, converting to LAT and LON dimensions, which might not be what you want for weather domains!")
            logger.warning("If you want to convert to a proper 3-dimensional NetCDF file, please provide a domain (for grid dimensions).")

            // Default layout
            var ncVariable = try ncFile.createVariable(name: "data", type: Float.self, dimensions: [
                try ncFile.createDimension(name: "LAT", length: Int(dimensions[0])),
                try ncFile.createDimension(name: "LON", length: Int(dimensions[1]))
            ])
            try ncVariable.write(data)
        }
    }

    /// Handle 3D data conversion to NetCDF
    private func convertToNetCDF3D(data: [Float], dimensions: [UInt64], ncFile: Group, transpose: Bool) throws {
        let ny = Int(dimensions[0])
        let nx = Int(dimensions[1])
        let nt = Int(dimensions[2])

        if transpose {
            // Transpose to fast space (lat, lon, time) -> (time, lat, lon)
            var ncVariable = try ncFile.createVariable(name: "data", type: Float.self, dimensions: [
                try ncFile.createDimension(name: "time", length: nt),
                try ncFile.createDimension(name: "LAT", length: ny),
                try ncFile.createDimension(name: "LON", length: nx)
            ])

            let transposed = Array3D(data: data, dim0: ny, dim1: nx, dim2: nt).transpose()
            try ncVariable.write(transposed.data)
        } else {
            var ncVariable = try ncFile.createVariable(name: "data", type: Float.self, dimensions: [
                try ncFile.createDimension(name: "LAT", length: ny),
                try ncFile.createDimension(name: "LON", length: nx),
                try ncFile.createDimension(name: "time", length: nt)
            ])
            try ncVariable.write(data)
        }
    }

    /// Read om file and write it as version 3 and reshape data to proper 3d files
    func convertOmv3(src: String, dest: String, grid: Gridable) throws {
        // Read data from the input OM file
        guard let readfile = try? OmFileReader(fn: try MmapFile(fn: FileHandle.openFileReading(file: src))),
              let reader = readfile.asArray(of: Float.self) else {
            throw ConvertOmError("Failed to open file: \(src)")
        }

        let dimensions = Array(reader.getDimensions())
        let chunks = Array(reader.getChunkDimensions())

        print("compression: \(reader.compression)")
        print("dimensions: \(dimensions)")
        print("chunks: \(chunks)")
        print("scaleFactor: \(reader.scaleFactor)")

        let ny = UInt64(grid.ny)
        let nx = UInt64(grid.nx)
        let nt = dimensions[1]

        guard dimensions.count == 2, nx * ny == dimensions[0], ny > 1, nx > 1 else {
            throw ConvertOmError("Wrong grid! Expected \(nx * ny) locations, got \(dimensions[0])")
        }

        let dimensionsOut = [ny, nx, nt]
        let chunksOut = [1, chunks[0], chunks[1]]
        // TODO somehow 5x5 is larger than 1x25....

        /*let dataRaw = try reader.read(range: [0..<ny*nx, 0..<nt])
        print("data read")
        if false {
            let ncFile = try NetCDF.create(path: "\(dest).nc", overwriteExisting: true)
            try ncFile.setAttribute("TITLE", "open-meteo file convert")
            // to fast space
            var ncVariable = try ncFile.createVariable(name: "data", type: Float.self, dimensions: [
                try ncFile.createDimension(name: "time", length: Int(nt)),
                try ncFile.createDimension(name: "LAT", length: Int(ny)),
                try ncFile.createDimension(name: "LON", length: Int(nx))
            ])
            let data2 = Array2DFastTime(data: dataRaw, nLocations: Int(nx*ny), nTime: Int(nt)).transpose()
            print("transpose done")
            try ncVariable.write(data2.data)
            print("nc wwrite done")
            return
        }*/

        try FileManager.default.removeItemIfExists(at: dest)
        let fileHandle = try FileHandle.createNewFile(file: dest)

        // Write the compressed data to the output OM file
        let fileWriter = OmFileWriter(fn: fileHandle, initialCapacity: 1024 * 1024 * 10) // Initial capacity of 10MB
        print("created writer")

        let writer = try fileWriter.prepareArray(
            type: Float.self,
            dimensions: dimensionsOut,
            chunkDimensions: chunksOut,
            compression: reader.compression,
            scale_factor: reader.scaleFactor,
            add_offset: reader.addOffset
        )

        print("prepared array")

        /// Reshape data from flated 2D to 3D context
        for yStart in stride(from: 0, to: ny, by: UInt64.Stride(chunksOut[0])) {
            for xStart in stride(from: 0, to: nx, by: UInt64.Stride(chunksOut[1])) {
                for tStart in stride(from: 0, to: nt, by: UInt64.Stride(chunksOut[2])) {
                    let yRange = yStart ..< min(yStart + chunksOut[0], ny)
                    let xRange = xStart ..< min(xStart + chunksOut[1], nx)
                    let tRange = tStart ..< min(tStart + chunksOut[2], nt)
                    // print("chunk y=\(yRange) x=\(xRange) t=\(tRange)")

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

        let variableMeta = try writer.finalise()
        print("Finalized Array")

        let variable = try fileWriter.write(array: variableMeta, name: "data", children: [])
        try fileWriter.writeTrailer(rootVariable: variable)

        print("Finished writing")

        /*// Verify the output
        guard let verificationFile = try? OmFileReader(fn: try MmapFile(fn: FileHandle.openFileReading(file: dest))),
            let verificationReader = verificationFile.asArray(of: Float.self) else {
            fatalError("Failed to open file: \(dest)")
        }

        let dataVerify = try verificationReader.read(range: [0..<ny, 0..<nx, 0..<nt])


        guard dataVerify == dataRaw else {
            for i in 0..<min(dataVerify.count, 1000) {
                if dataVerify[i] != dataRaw[i] {//}&& !dataRaw[i].isNaN && !dataVerify[i].isNaN {
                    print(i, dataVerify[i], dataRaw[i])
                }
            }
            print("verify failed")
            fatalError()
        }*/
    }
}

struct ConvertOmError: Error {
    let message: String

    init(_ message: String) {
        self.message = message
    }
}

extension String {
    var withoutOmSuffix: String {
        if hasSuffix(".om") {
            return String(dropLast(3))
        }
        return self
    }
}

extension Array3D {
    /// Transpose the array to swap dimensions: (dim0, dim1, dim2) -> (dim2, dim0, dim1)
    /// This effectively changes from (lat, lon, time) to (time, lat, lon)
    func transpose() -> Array3D {
        precondition(data.count == dim0 * dim1 * dim2)

        return data.withUnsafeBufferPointer { data in
            let out = [Float](unsafeUninitializedCapacity: data.count) { buffer, initializedCount in
                for d0 in 0..<dim0 {
                    for d1 in 0..<dim1 {
                        for d2 in 0..<dim2 {
                            // From (d0, d1, d2) to (d2, d0, d1)
                            let srcIdx = d0 * dim1 * dim2 + d1 * dim2 + d2
                            let dstIdx = d2 * dim0 * dim1 + d0 * dim1 + d1
                            buffer[dstIdx] = data[srcIdx]
                        }
                    }
                }
                initializedCount = data.count
            }
            return Array3D(data: out, dim0: dim2, dim1: dim0, dim2: dim1)
        }
    }
}
