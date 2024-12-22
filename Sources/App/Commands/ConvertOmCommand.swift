import Foundation
import OmFileFormatSwift
import Vapor
import SwiftNetCDF

/**
 Small helper tool to convert a `om` file to NetCDF for debugging
 
 e.g. openmeteo-api convert-om /Volumes/2TB_1GBs/data/master-MRI_AGCM3_2_S/windgusts_10m_mean_linear_bias_seasonal.om --nx 1920 --transpose -o temp.nc
 
 */
struct ConvertOmCommand: Command {
    var help: String {
        return "Convert an om file to to NetCDF"
    }
    
    struct Signature: CommandSignature {
        @Argument(name: "infile", help: "Input file")
        var infile: String
        
        @Option(name: "output", short: "o", help: "Output file name. Default: ./output.nc")
        var outfile: String?
        
        @Flag(name: "transpose", help: "Transpose data to fast space")
        var transpose: Bool
        
        @Option(name: "nx", help: "Use this nx value to convert to d3")
        var nx: Int?
        
        @Option(name: "domain", help: "Domain used for grid definiton")
        var domain: String?
    }
    
    func run(using context: CommandContext, signature: Signature) throws {
        let logger = context.application.logger
        
        if let domain = signature.domain {
            let domain = try DomainRegistry.load(rawValue: domain)
            let oufile = signature.outfile ?? "\(signature.infile).om3"
            try convertOmv3(src: signature.infile, dest: oufile, grid: domain.getDomain().grid)
            return
        }

        
        let om = try OmFileReader(file: signature.infile)
        logger.info("dim0=\(om.dim0) dim1=\(om.dim1) chunk0=\(om.chunk0) chunk1=\(om.chunk1)")
        
        let data = try om.readAll()
        
        let oufile = signature.outfile ?? "\(signature.infile).nc"
        let ncFile = try NetCDF.create(path: oufile, overwriteExisting: true)
        try ncFile.setAttribute("TITLE", "open-meteo file convert")
        
        if let nx = signature.nx {
            let ny = om.dim0 / nx
            if signature.transpose {
                logger.info("Transpose to nx=\(nx) ny=\(ny)")
                // to fast space
                var ncVariable = try ncFile.createVariable(name: "data", type: Float.self, dimensions: [
                    try ncFile.createDimension(name: "time", length: om.dim1),
                    try ncFile.createDimension(name: "LAT", length: ny),
                    try ncFile.createDimension(name: "LON", length: nx)
                ])
                let data2 = Array2DFastTime(data: data, nLocations: om.dim0, nTime: om.dim1).transpose()
                try ncVariable.write(data2.data)
            } else {
                // fast time dimension
                var ncVariable = try ncFile.createVariable(name: "data", type: Float.self, dimensions: [
                    try ncFile.createDimension(name: "LAT", length: ny),
                    try ncFile.createDimension(name: "LON", length: nx),
                    try ncFile.createDimension(name: "time", length: om.dim1)
                ])
                try ncVariable.write(data)
            }
        } else {
            var ncVariable = try ncFile.createVariable(name: "data", type: Float.self, dimensions: [
                try ncFile.createDimension(name: "LAT", length: om.dim1),
                try ncFile.createDimension(name: "LON", length: om.dim0),
            ])
            try ncVariable.write(data)
        }
    }

    /// Read om file and write it as version 3 and reshape data to proper 3d files
    func convertOmv3(src: String, dest: String, grid: Gridable) throws {
        // Read data from the input OM file
        guard let reader = try? OmFileReader2(fn: try MmapFile(fn: FileHandle.openFileReading(file: src))) else {
            fatalError("Failed to open file: \(src)")
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
            fatalError("wrong grid")
        }
        
        let dimensionsOut = [ny, nx, nt]
        let chunksOut = [5,5,chunks[1]]
        // TODO somehow 5x5 is larger than 1x25....
        
        let dataRaw = reader.read([0..<ny*nx, 0..<nt], io_size_merge: .max)
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
        }
        
        try FileManager.default.removeItemIfExists(at: dest)
        let fileHandle = try FileHandle.createNewFile(file: dest)

        // Write the compressed data to the output OM file
        let fileWriter = OmFileWriter2(fn: fileHandle, initialCapacity: 1024 * 1024 * 10) // Initial capacity of 10MB
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
                    //print("chunk y=\(yRange) x=\(xRange) t=\(tRange)")
                    
                    var chunk = [Float](repeating: .nan, count: yRange.count * xRange.count * tRange.count)
                    for (row, y) in yRange.enumerated() {
                        reader.read(
                            into: &chunk,
                            dimRead: [y * nx + xRange.startIndex ..< y * nx + xRange.endIndex, tRange],
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
        
        // Verify the output
        guard let verificationReader = try? OmFileReader2(fn: try MmapFile(fn: FileHandle.openFileReading(file: dest))) else {
            fatalError("Failed to open file: \(dest)")
        }

        let dataVerify = verificationReader.read([0..<ny, 0..<nx, 0..<nt], io_size_max: .max, io_size_merge: .max)
        
        
        guard dataVerify == dataRaw else {
            for i in 0..<min(dataVerify.count, 1000) {
                if dataVerify[i] != dataRaw[i] {//}&& !dataRaw[i].isNaN && !dataVerify[i].isNaN {
                    print(i, dataVerify[i], dataRaw[i])
                }
            }
            print("verify failed")
            fatalError()
        }
    }
}
