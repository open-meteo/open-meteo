import Foundation
import OmFileFormatSwift

func main() throws {
    let controlRangeDim0: Range<UInt64> = 10000..<10001
    let controlRangeDim1: Range<UInt64> = 0..<100
    let inputFilePath = "data/icond2_temp2m_chunk_3960.om"
    let outputFilePath = "data/icond2_temp2m_chunk_3960_v3.om"

    // Read data from the input OM file
    guard let reader = try? OmFileReader2(fn: try MmapFile(fn: FileHandle.openFileReading(file: inputFilePath))) else {
        fatalError("Failed to open file: \(inputFilePath)")
    }

    let dimensions = Array(reader.getDimensions())
    let chunks = Array(reader.getChunkDimensions())

    print("compression: \(reader.compression)")
    print("dimensions: \(dimensions)")
    print("chunks: \(chunks)")
    print("scaleFactor: \(reader.scaleFactor)")

    let controlDataOriginal = reader.read([controlRangeDim0, controlRangeDim1])

    try FileManager.default.removeItemIfExists(at: outputFilePath)
    let fileHandle = try FileHandle.createNewFile(file: outputFilePath)
    
    // Write the compressed data to the output OM file
    let fileWriter = OmFileWriter2(fn: fileHandle, initialCapacity: 1024 * 1024 * 10) // Initial capacity of 10MB
    print("created writer")

    // let rechunkedDimensions = [50, 121]
    let rechunkedDimensions = chunks

    let writer = try fileWriter.prepareArray(
        type: Float.self,
        dimensions: dimensions,
        chunkDimensions: rechunkedDimensions,
        compression: .p4nzdec256,
        scale_factor: reader.scaleFactor,
        add_offset: reader.addOffset
    )

    print("prepared array")

    // Read and write data in chunks
    // Iterate over both chunk dimensions at once
    var chunkStart: UInt64 = 0
    while chunkStart < dimensions[0] {
        let chunkDim0 = min(UInt64(rechunkedDimensions[0]), dimensions[0] - chunkStart)
        print("Chunk start \(chunkStart)")
        
        let chunkData = reader.read([chunkStart..<(chunkStart + chunkDim0), 0..<dimensions[1]])

        try writer.writeData(
            array: chunkData,
            arrayDimensions: [chunkDim0, dimensions[1]]
        )

        print("wrote chunk")

        chunkStart += rechunkedDimensions[0]
    }

    let variableMeta = try writer.finalise()
    print("Finalized Array")

    let variable = try fileWriter.write(array: variableMeta, name: "data", children: [])
    try fileWriter.writeTrailer(rootVariable: variable)

    print("Finished writing")

    // Verify the output
    guard let verificationReader = try? OmFileReader2(fn: try MmapFile(fn: FileHandle.openFileReading(file: outputFilePath))) else {
        fatalError("Failed to open file: \(outputFilePath)")
    }

    let controlDataNew = verificationReader.read([controlRangeDim0, controlRangeDim1])

    print("data from newly written file: \(controlDataNew)")
    assert(controlDataOriginal == controlDataNew, "Data mismatch")
}

// Run the main function
do {
    try main()
} catch {
    print("Error: \(error)")
}
