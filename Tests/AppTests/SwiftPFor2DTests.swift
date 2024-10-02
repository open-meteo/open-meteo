import XCTest
@testable import SwiftPFor2D
@testable import App
@_implementationOnly import CTurboPFor

final class SwiftPFor2DTests: XCTestCase {
    func testInMemory() throws {
        let data: [Float] = [0.0, 5.0, 2.0, 3.0, 2.0, 5.0, 6.0, 2.0, 8.0, 3.0, 10.0, 14.0, 12.0, 15.0, 14.0, 15.0, 66.0, 17.0, 12.0, 19.0, 20.0, 21.0, 22.0, 23.0, 24.0]
        let compressed = try OmFileWriter(dim0: 1, dim1: data.count, chunk0: 1, chunk1: 10).writeInMemory(compressionType: .p4nzdec256, scalefactor: 1, all: data)
        XCTAssertEqual(compressed.count, 212)
        //print(compressed.hex)
        let uncompressed = try OmFileReader(fn: DataAsClass(data: compressed)).readAll() // .read(dim0Slow: 0..<1, dim1: 10..<20)
        //print(uncompressed)
        XCTAssertEqualArray(data, uncompressed, accuracy: 0.001)
    }
    
    /// Crashes on linux, but fine on macos
    func testALinuxCrash(){
        //let s = String(cString: cpustr(0))
        //print(s)
        
        let writeBuffer: UnsafeMutablePointer<UInt8> = .allocate(capacity: P4NENC256_BOUND(n: 4, bytesPerElement: 2))
        defer { writeBuffer.deallocate() }
        
        var data: [Int16] = [0,1,5,6]
        data.reserveCapacity(1024)
        let writeLength = data.withUnsafeMutableBufferPointer({ ptr in
            p4nzenc128v16(ptr.baseAddress, ptr.count, writeBuffer.advanced(by: 0))
        })
        XCTAssertEqual(writeLength, 4)
    }
    
    
    /*func testRead() throws {
        // ERA5 temperature
        let read = try OmFileReader(file: "/Users/patrick/Downloads/year_1983.om.download/year_1983.om")
        //let a = try read.read(dim0Slow: 0..<5, dim1: 0..<5)
        print(read.dim0, read.dim1, read.chunk0, read.chunk1)
        // dims 6483600 8760
        // chunks 6 504
        // 18'781'857.12 chunks
        // 143 MB index!
    }*/
    
    /// Make sure the last chunk has the correct number of chunks
    func testWriteMoreDataThenExpected() throws {
        let file = "writetest.om"
        try FileManager.default.removeItemIfExists(at: file)
        
        XCTAssertThrowsError(try OmFileWriter(dim0: 5, dim1: 5, chunk0: 2, chunk1: 2).write(file: file, compressionType: .p4nzdec256, scalefactor: 1, overwrite: false, supplyChunk: { dim0pos in
            if dim0pos == 0 {
                return ArraySlice((0..<10).map({ Float($0) }))
            }
            if dim0pos == 2 {
                return ArraySlice((10..<20).map({ Float($0) }))
            }
            if dim0pos == 4 {
                // Here it is now 30 instead of 25
                return ArraySlice((20..<30).map({ Float($0) }))
            }
            fatalError("Not expected")
        }))
        try FileManager.default.removeItem(atPath: "\(file)~")
    }
    
    func testWriteLarge() throws {
        let file = "writetest.om"
        try FileManager.default.removeItemIfExists(at: file)
        
        let writer = OmFileEncoder(dimensions: [100,100,10], chunkDimensions: [2,2,2], compression: .p4nzdec256, scalefactor: 1)
        // TODO fix buffer size
        let buffer = OmFileBufferedWriter(capacity: 1014*1024)//writer.maximum_buffer_capacity())
        
        let fn = try FileHandle.createNewFile(file: file)
        
        let data = (0..<100000).map({Float($0 % 10000)})
        try buffer.writeHeader(fn: fn)
        // TODO dataOffset should be stored in LUT, but this will cause issues for old file compatibility
        let dataOffset = buffer.totalBytesWritten
        try writer.writeData(array: data, arrayDimensions: [100,100,10], arrayRead: [0..<100, 0..<100, 0..<10], fn: fn, out: buffer)
        let lutStart = buffer.totalBytesWritten
        let lutChunkLength = try writer.writeLut(out: buffer, fn: fn)
        let jsonVariable = OmFileJSONVariable(
            name: nil,
            dimensions: writer.dims,
            chunks: writer.chunks,
            dimensionNames: nil,
            scalefactor: writer.scalefactor,
            compression: writer.compression,
            dataOffset: dataOffset,
            lutOffset: lutStart,
            lutChunkSize: lutChunkLength
        )
        let json = OmFileJSON(variables: [jsonVariable], someAttributes: nil)
        try buffer.writeTrailer(meta: json, fn: fn)
        
        let readFn = try MmapFile(fn: FileHandle.openFileReading(file: file))
        let read = try OmFileDecoder.open_file(fn: readFn)
        
        let a1 = read.read([50..<51, 20..<21, 1..<2])
        XCTAssertEqual(a1, [201.0])
                
        let a = read.read([0..<100, 0..<100, 0..<10])
        XCTAssertEqual(a, data)
    }
    
    func testWriteChunks() throws {
        let file = "writetest.om"
        try FileManager.default.removeItemIfExists(at: file)
        
        let writer = OmFileEncoder(dimensions: [5,5], chunkDimensions: [2,2], compression: .p4nzdec256, scalefactor: 1)
        let buffer = OmFileBufferedWriter(capacity: writer.maximum_buffer_capacity())
        
        let fn = try FileHandle.createNewFile(file: file)
        
        // Directly feed individual chunks
        try buffer.writeHeader(fn: fn)
        // TODO dataOffset should be stored in LUT, but this will cause issues for old file compatibility
        let dataOffset = buffer.totalBytesWritten
        try writer.writeData(array: [0.0, 1.0, 5.0, 6.0], arrayDimensions: [2,2], arrayRead: [0..<2, 0..<2], fn: fn, out: buffer)
        try writer.writeData(array: [2.0, 3.0, 7.0, 8.0], arrayDimensions: [2,2], arrayRead: [0..<2, 0..<2], fn: fn, out: buffer)
        try writer.writeData(array: [4.0, 9.0], arrayDimensions: [2,1], arrayRead: [0..<2, 0..<1], fn: fn, out: buffer)
        try writer.writeData(array: [10.0, 11.0, 15.0, 16.0], arrayDimensions: [2,2], arrayRead: [0..<2, 0..<2], fn: fn, out: buffer)
        try writer.writeData(array: [12.0, 13.0, 17.0, 18.0], arrayDimensions: [2,2], arrayRead: [0..<2, 0..<2], fn: fn, out: buffer)
        try writer.writeData(array: [14.0, 19.0], arrayDimensions: [2,1], arrayRead: [0..<2, 0..<1], fn: fn, out: buffer)
        try writer.writeData(array: [20.0, 21.0], arrayDimensions: [1,2], arrayRead: [0..<1, 0..<2], fn: fn, out: buffer)
        try writer.writeData(array: [22.0, 23.0], arrayDimensions: [1,2], arrayRead: [0..<1, 0..<2], fn: fn, out: buffer)
        try writer.writeData(array: [24.0], arrayDimensions: [1,1], arrayRead: [0..<1, 0..<1], fn: fn, out: buffer)
        let lutStart = buffer.totalBytesWritten
        let lutChunkLength = try writer.writeLut(out: buffer, fn: fn)
        let jsonVariable = OmFileJSONVariable(
            name: nil,
            dimensions: writer.dims,
            chunks: writer.chunks,
            dimensionNames: nil,
            scalefactor: writer.scalefactor,
            compression: writer.compression,
            dataOffset: dataOffset,
            lutOffset: lutStart,
            lutChunkSize: lutChunkLength
        )
        let json = OmFileJSON(variables: [jsonVariable], someAttributes: nil)
        try buffer.writeTrailer(meta: json, fn: fn)
        
        let readFn = try MmapFile(fn: FileHandle.openFileReading(file: file))
        let read = try OmFileDecoder.open_file(fn: readFn)
        
        let a = read.read([0..<5, 0..<5])
        XCTAssertEqual(a, [0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 17.0, 18.0, 19.0, 20.0, 21.0, 22.0, 23.0, 24.0])
    }
    
    func testOffsetWrite() throws {
        let file = "writetest.om"
        try FileManager.default.removeItemIfExists(at: file)
        
        let writer = OmFileEncoder(dimensions: [5,5], chunkDimensions: [2,2], compression: .p4nzdec256, scalefactor: 1)
        // TODO fix buffer size
        let buffer = OmFileBufferedWriter(capacity: 1014*1024)//writer.maximum_buffer_capacity())
        let fn = try FileHandle.createNewFile(file: file)
        
        /// Deliberately add NaN on all positions that should not be written to the file. Only the inner 5x5 array is written
        let data = [.nan, .nan, .nan, .nan, .nan, .nan, .nan, .nan, Float(0.0), 1.0, 2.0, 3.0, 4.0, .nan, .nan, 5.0, 6.0, 7.0, 8.0, 9.0, .nan, .nan, 10.0, 11.0, 12.0, 13.0, 14.0, .nan, .nan, 15.0, 16.0, 17.0, 18.0, 19.0, .nan, .nan, 20.0, 21.0, 22.0, 23.0, 24.0, .nan, .nan, .nan, .nan, .nan, .nan, .nan, .nan]
        try buffer.writeHeader(fn: fn)
        // TODO dataOffset should be stored in LUT, but this will cause issues for old file compatibility
        let dataOffset = buffer.totalBytesWritten
        try writer.writeData(array: data, arrayDimensions: [7,7], arrayRead: [1..<6, 1..<6], fn: fn, out: buffer)
        
        let lutStart = buffer.totalBytesWritten
        let lutChunkLength = try writer.writeLut(out: buffer, fn: fn)
        let jsonVariable = OmFileJSONVariable(
            name: nil,
            dimensions: writer.dims,
            chunks: writer.chunks,
            dimensionNames: nil,
            scalefactor: writer.scalefactor,
            compression: writer.compression,
            dataOffset: dataOffset,
            lutOffset: lutStart,
            lutChunkSize: lutChunkLength
        )
        let json = OmFileJSON(variables: [jsonVariable], someAttributes: nil)
        try buffer.writeTrailer(meta: json, fn: fn)
        let readFn = try MmapFile(fn: FileHandle.openFileReading(file: file))
        let read = try OmFileDecoder.open_file(fn: readFn)
        
        let a = read.read([0..<5, 0..<5])
        XCTAssertEqual(a, [0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 17.0, 18.0, 19.0, 20.0, 21.0, 22.0, 23.0, 24.0])
    }
    
    func testWrite3D() throws {
        let file = "writetest.om"
        try FileManager.default.removeItemIfExists(at: file)
        
        let writer = OmFileEncoder(dimensions: [3,3,3], chunkDimensions: [2,2,2], compression: .p4nzdec256, scalefactor: 1)
        // TODO fix buffer size
        let buffer = OmFileBufferedWriter(capacity: 1014*1024)//writer.maximum_buffer_capacity())
        let fn = try FileHandle.createNewFile(file: file)
        
        let data = [Float(0.0), 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 17.0, 18.0, 19.0, 20.0, 21.0, 22.0, 23.0, 24.0, 25.0, 26.0]
        try buffer.writeHeader(fn: fn)
        // TODO dataOffset should be stored in LUT, but this will cause issues for old file compatibility
        let dataOffset = buffer.totalBytesWritten
        try writer.writeData(array: data, arrayDimensions: [3,3,3], arrayRead: [0..<3, 0..<3, 0..<3], fn: fn, out: buffer)
        let lutStart = buffer.totalBytesWritten
        let lutChunkLength = try writer.writeLut(out: buffer, fn: fn)
        let jsonVariable = OmFileJSONVariable(
            name: nil,
            dimensions: writer.dims,
            chunks: writer.chunks,
            dimensionNames: nil,
            scalefactor: writer.scalefactor,
            compression: writer.compression,
            dataOffset: dataOffset,
            lutOffset: lutStart,
            lutChunkSize: lutChunkLength
        )
        let json = OmFileJSON(variables: [jsonVariable], someAttributes: nil)
        try buffer.writeTrailer(meta: json, fn: fn)
        
        let readFn = try MmapFile(fn: FileHandle.openFileReading(file: file))
        let read = try OmFileDecoder.open_file(fn: readFn)
        
        
        let a = read.read([0..<3, 0..<3, 0..<3])
        XCTAssertEqual(a, data)
        
        // single index
        for x in 0..<read.dims[0] {
            for y in 0..<read.dims[1] {
                for z in 0..<read.dims[2] {
                    XCTAssertEqual(read.read([x..<x+1, y..<y+1, z..<z+1]), [Float(x*3*3 + y*3 + z)])
                }
            }
        }
    }
    
    func testWritev3() throws {
        let file = "writetest.om"
        try FileManager.default.removeItemIfExists(at: file)
        
        let writer = OmFileEncoder(dimensions: [5,5], chunkDimensions: [2,2], compression: .p4nzdec256, scalefactor: 1, lutChunkElementCount: 2)
        // TODO fix buffer size
        let buffer = OmFileBufferedWriter(capacity: 1014*1024)//writer.maximum_buffer_capacity())
        let fn = try FileHandle.createNewFile(file: file)
        
        let data = [Float(0.0), 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 17.0, 18.0, 19.0, 20.0, 21.0, 22.0, 23.0, 24.0]
        try buffer.writeHeader(fn: fn)
        // TODO dataOffset should be stored in LUT, but this will cause issues for old file compatibility
        let dataOffset = buffer.totalBytesWritten
        try writer.writeData(array: data, arrayDimensions: [5,5], arrayRead: [0..<5, 0..<5], fn: fn, out: buffer)
        let lutStart = buffer.totalBytesWritten
        let lutChunkLength = try writer.writeLut(out: buffer, fn: fn)
        let jsonVariable = OmFileJSONVariable(
            name: nil,
            dimensions: writer.dims,
            chunks: writer.chunks,
            dimensionNames: nil,
            scalefactor: writer.scalefactor,
            compression: writer.compression,
            dataOffset: dataOffset,
            lutOffset: lutStart,
            lutChunkSize: lutChunkLength
        )
        let json = OmFileJSON(variables: [jsonVariable], someAttributes: nil)
        try buffer.writeTrailer(meta: json, fn: fn)
        
        let readFn = try MmapFile(fn: FileHandle.openFileReading(file: file))
        let read = try OmFileDecoder.open_file(fn: readFn, lutChunkElementCount: 2)
        

        let a = read.read([0..<5, 0..<5])
        XCTAssertEqual(a, [0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 17.0, 18.0, 19.0, 20.0, 21.0, 22.0, 23.0, 24.0])
        
        // single index
        for x in 0..<read.dims[0] {
            for y in 0..<read.dims[1] {
                XCTAssertEqual(read.read([x..<x+1, y..<y+1]), [Float(x*5 + y)])
            }
        }
        
        // Read into an existing array with an offset
        for x in 0..<read.dims[0] {
            for y in 0..<read.dims[1] {
                var r = [Float](repeating: .nan, count: 9)
                r.withUnsafeMutableBufferPointer({
                    read.read(into: $0.baseAddress!, dimRead: [x..<x+1, y..<y+1], intoCoordLower: [1,1], intoCubeDimension: [3,3])
                })
                XCTAssertEqualArray(r, [.nan, .nan, .nan, .nan, Float(x*5 + y), .nan, .nan, .nan, .nan], accuracy: 0.001)
            }
        }
        
        // 2x in fast dim
        for x in 0..<read.dims[0] {
            for y in 0..<read.dims[1]-1 {
                XCTAssertEqual(read.read([x..<x+1, y..<y+2]), [Float(x*5 + y), Float(x*5 + y + 1)])
            }
        }
        
        // 2x in slow dim
        for x in 0..<read.dims[0]-1 {
            for y in 0..<read.dims[1] {
                XCTAssertEqual(read.read([x..<x+2, y..<y+1]), [Float(x*5 + y), Float((x+1)*5 + y)])
            }
        }
        
        // 2x2
        for x in 0..<read.dims[0]-1 {
            for y in 0..<read.dims[1]-1 {
                XCTAssertEqual(read.read([x..<x+2, y..<y+2]), [Float(x*5 + y), Float(x*5 + y + 1), Float((x+1)*5 + y), Float((x+1)*5 + y + 1)])
            }
        }
        // 3x3
        for x in 0..<read.dims[0]-2 {
            for y in 0..<read.dims[1]-2 {
                XCTAssertEqual(read.read([x..<x+3, y..<y+3]), [Float(x*5 + y), Float(x*5 + y + 1), Float(x*5 + y + 2), Float((x+1)*5 + y), Float((x+1)*5 + y + 1),  Float((x+1)*5 + y + 2), Float((x+2)*5 + y), Float((x+2)*5 + y + 1),  Float((x+2)*5 + y + 2)])
            }
        }
        
        // 1x5
        for x in 0..<read.dims[1] {
            XCTAssertEqual(read.read([x..<x+1, 0..<5]), [Float(x*5), Float(x*5+1), Float(x*5+2), Float(x*5+3), Float(x*5+4)])
        }
        
        // 5x1
        for x in 0..<read.dims[0] {
            XCTAssertEqual(read.read([0..<5, x..<x+1]), [Float(x), Float(x+5), Float(x+10), Float(x+15), Float(x+20)])
        }
        
        /*// test interpolation
        XCTAssertEqualArray(try read.readInterpolated(dim0X: 0, dim0XFraction: 0.5, dim0Y: 0, dim0YFraction: 0.5, dim0Nx: 2, dim1: 0..<5), [7.5, 8.5, 9.5, 10.5, 11.5], accuracy: 0.001)
        XCTAssertEqualArray(try read.readInterpolated(dim0X: 0, dim0XFraction: 0.1, dim0Y: 0, dim0YFraction: 0.2, dim0Nx: 2, dim1: 0..<5), [2.5, 3.4999998, 4.5, 5.5, 6.5], accuracy: 0.001)
        XCTAssertEqualArray(try read.readInterpolated(dim0X: 0, dim0XFraction: 0.9, dim0Y: 0, dim0YFraction: 0.2, dim0Nx: 2, dim1: 0..<5), [6.5, 7.5, 8.5, 9.5, 10.5], accuracy: 0.001)
        XCTAssertEqualArray(try read.readInterpolated(dim0X: 0, dim0XFraction: 0.1, dim0Y: 0, dim0YFraction: 0.9, dim0Nx: 2, dim1: 0..<5), [9.5, 10.499999, 11.499999, 12.5, 13.499999], accuracy: 0.001)
        XCTAssertEqualArray(try read.readInterpolated(dim0X: 0, dim0XFraction: 0.8, dim0Y: 0, dim0YFraction: 0.9, dim0Nx: 2, dim1: 0..<5), [12.999999, 14.0, 15.0, 16.0, 17.0], accuracy: 0.001)*/
        try FileManager.default.removeItem(atPath: file)
    }
    
    
    func testWrite() throws {
        let file = "writetest.om"
        try FileManager.default.removeItemIfExists(at: file)
        
        try OmFileWriter(dim0: 5, dim1: 5, chunk0: 2, chunk1: 2).write(file: file, compressionType: .p4nzdec256, scalefactor: 1, overwrite: false, supplyChunk: { dim0pos in
            
            if dim0pos == 0 {
                return ArraySlice((0..<10).map({ Float($0) }))
            }
            if dim0pos == 2 {
                return ArraySlice((10..<20).map({ Float($0) }))
            }
            if dim0pos == 4 {
                return ArraySlice((20..<25).map({ Float($0) }))
            }
            fatalError("Not expected")
        })
        
        let read = try OmFileReader(file: file)
        let a = try read.read(dim0Slow: 0..<5, dim1: 0..<5)
        XCTAssertEqual(a, [0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 17.0, 18.0, 19.0, 20.0, 21.0, 22.0, 23.0, 24.0])
        
        // single index
        for x in 0..<read.dim0 {
            for y in 0..<read.dim1 {
                XCTAssertEqual(try read.read(dim0Slow: x..<x+1, dim1: y..<y+1), [Float(x*5 + y)])
            }
        }
        
        // 2x in fast dim
        for x in 0..<read.dim0 {
            for y in 0..<read.dim1-1 {
                XCTAssertEqual(try read.read(dim0Slow: x..<x+1, dim1: y..<y+2), [Float(x*5 + y), Float(x*5 + y + 1)])
            }
        }
        
        // 2x in slow dim
        for x in 0..<read.dim0-1 {
            for y in 0..<read.dim1 {
                XCTAssertEqual(try read.read(dim0Slow: x..<x+2, dim1: y..<y+1), [Float(x*5 + y), Float((x+1)*5 + y)])
            }
        }
        
        // 2x2
        for x in 0..<read.dim0-1 {
            for y in 0..<read.dim1-1 {
                XCTAssertEqual(try read.read(dim0Slow: x..<x+2, dim1: y..<y+2), [Float(x*5 + y), Float(x*5 + y + 1), Float((x+1)*5 + y), Float((x+1)*5 + y + 1)])
            }
        }
        // 3x3
        for x in 0..<read.dim0-2 {
            for y in 0..<read.dim1-2 {
                XCTAssertEqual(try read.read(dim0Slow: x..<x+3, dim1: y..<y+3), [Float(x*5 + y), Float(x*5 + y + 1), Float(x*5 + y + 2), Float((x+1)*5 + y), Float((x+1)*5 + y + 1),  Float((x+1)*5 + y + 2), Float((x+2)*5 + y), Float((x+2)*5 + y + 1),  Float((x+2)*5 + y + 2)])
            }
        }
        
        // 1x5
        for x in 0..<read.dim1 {
            XCTAssertEqual(try read.read(dim0Slow: x..<x+1, dim1: 0..<5), [Float(x*5), Float(x*5+1), Float(x*5+2), Float(x*5+3), Float(x*5+4)])
        }
        
        // 5x1
        for x in 0..<read.dim0 {
            XCTAssertEqual(try read.read(dim0Slow: 0..<5, dim1: x..<x+1), [Float(x), Float(x+5), Float(x+10), Float(x+15), Float(x+20)])
        }
        
        // test interpolation
        XCTAssertEqualArray(try read.readInterpolated(dim0X: 0, dim0XFraction: 0.5, dim0Y: 0, dim0YFraction: 0.5, dim0Nx: 2, dim1: 0..<5), [7.5, 8.5, 9.5, 10.5, 11.5], accuracy: 0.001)
        XCTAssertEqualArray(try read.readInterpolated(dim0X: 0, dim0XFraction: 0.1, dim0Y: 0, dim0YFraction: 0.2, dim0Nx: 2, dim1: 0..<5), [2.5, 3.4999998, 4.5, 5.5, 6.5], accuracy: 0.001)
        XCTAssertEqualArray(try read.readInterpolated(dim0X: 0, dim0XFraction: 0.9, dim0Y: 0, dim0YFraction: 0.2, dim0Nx: 2, dim1: 0..<5), [6.5, 7.5, 8.5, 9.5, 10.5], accuracy: 0.001)
        XCTAssertEqualArray(try read.readInterpolated(dim0X: 0, dim0XFraction: 0.1, dim0Y: 0, dim0YFraction: 0.9, dim0Nx: 2, dim1: 0..<5), [9.5, 10.499999, 11.499999, 12.5, 13.499999], accuracy: 0.001)
        XCTAssertEqualArray(try read.readInterpolated(dim0X: 0, dim0XFraction: 0.8, dim0Y: 0, dim0YFraction: 0.9, dim0Nx: 2, dim1: 0..<5), [12.999999, 14.0, 15.0, 16.0, 17.0], accuracy: 0.001)
        try FileManager.default.removeItem(atPath: file)
    }
    
    func testNaN() throws {
        let file = "writetest.om"
        try FileManager.default.removeItemIfExists(at: file)
        
        let data = (0..<(5*5)).map({ val in Float.nan })
        try OmFileWriter(dim0: 5, dim1: 5, chunk0: 5, chunk1: 5).write(file: file, compressionType: .p4nzdec256, scalefactor: 1, all: data)
        
        let read = try OmFileReader(file: file)
        let data2 = try read.read(dim0Slow: nil, dim1: nil)
        print(data2)
        XCTAssertTrue(try read.read(dim0Slow: 1..<2, dim1: 1..<2)[0].isNaN)
        try FileManager.default.removeItem(atPath: file)
    }
    
    func testWriteFpx() throws {
        let file = "writetest.om"
        try FileManager.default.removeItemIfExists(at: file)
        
        try OmFileWriter(dim0: 5, dim1: 5, chunk0: 2, chunk1: 2).write(file: file, compressionType: .fpxdec32, scalefactor: 1, overwrite: false, supplyChunk: { dim0pos in
            
            if dim0pos == 0 {
                return ArraySlice((0..<10).map({ Float($0) }))
            }
            if dim0pos == 2 {
                return ArraySlice((10..<20).map({ Float($0) }))
            }
            if dim0pos == 4 {
                return ArraySlice((20..<25).map({ Float($0) }))
            }
            fatalError("Not expected")
        })
        
        let read = try OmFileReader(file: file)
        let a = try read.read(dim0Slow: 0..<5, dim1: 0..<5)
        XCTAssertEqual(a, [0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 17.0, 18.0, 19.0, 20.0, 21.0, 22.0, 23.0, 24.0])
        
        // single index
        for x in 0..<read.dim0 {
            for y in 0..<read.dim1 {
                XCTAssertEqual(try read.read(dim0Slow: x..<x+1, dim1: y..<y+1), [Float(x*5 + y)])
            }
        }
        
        // 2x in fast dim
        for x in 0..<read.dim0 {
            for y in 0..<read.dim1-1 {
                XCTAssertEqual(try read.read(dim0Slow: x..<x+1, dim1: y..<y+2), [Float(x*5 + y), Float(x*5 + y + 1)])
            }
        }
        
        // 2x in slow dim
        for x in 0..<read.dim0-1 {
            for y in 0..<read.dim1 {
                XCTAssertEqual(try read.read(dim0Slow: x..<x+2, dim1: y..<y+1), [Float(x*5 + y), Float((x+1)*5 + y)])
            }
        }
        
        // 2x2
        for x in 0..<read.dim0-1 {
            for y in 0..<read.dim1-1 {
                XCTAssertEqual(try read.read(dim0Slow: x..<x+2, dim1: y..<y+2), [Float(x*5 + y), Float(x*5 + y + 1), Float((x+1)*5 + y), Float((x+1)*5 + y + 1)])
            }
        }
        // 3x3
        for x in 0..<read.dim0-2 {
            for y in 0..<read.dim1-2 {
                XCTAssertEqual(try read.read(dim0Slow: x..<x+3, dim1: y..<y+3), [Float(x*5 + y), Float(x*5 + y + 1), Float(x*5 + y + 2), Float((x+1)*5 + y), Float((x+1)*5 + y + 1),  Float((x+1)*5 + y + 2), Float((x+2)*5 + y), Float((x+2)*5 + y + 1),  Float((x+2)*5 + y + 2)])
            }
        }
        
        // 1x5
        for x in 0..<read.dim1 {
            XCTAssertEqual(try read.read(dim0Slow: x..<x+1, dim1: 0..<5), [Float(x*5), Float(x*5+1), Float(x*5+2), Float(x*5+3), Float(x*5+4)])
        }
        
        // 5x1
        for x in 0..<read.dim0 {
            XCTAssertEqual(try read.read(dim0Slow: 0..<5, dim1: x..<x+1), [Float(x), Float(x+5), Float(x+10), Float(x+15), Float(x+20)])
        }
        try FileManager.default.removeItem(atPath: file)
    }
    
    func testNaNfpx() throws {
        let file = "writetest.om"
        try FileManager.default.removeItemIfExists(at: file)
        
        let data = (0..<(5*5)).map({ val in Float.nan })
        try OmFileWriter(dim0: 5, dim1: 5, chunk0: 5, chunk1: 5).write(file: file, compressionType: .fpxdec32, scalefactor: 1, all: data)
        
        let read = try OmFileReader(file: file)
        let data2 = try read.read(dim0Slow: nil, dim1: nil)
        print(data2)
        XCTAssertTrue(try read.read(dim0Slow: 1..<2, dim1: 1..<2)[0].isNaN)
        try FileManager.default.removeItem(atPath: file)
    }
}
