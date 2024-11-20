import XCTest
@testable import OmFileFormatSwift
@testable import App
@_implementationOnly import OmFileFormatC

final class OmFileFormatTests: XCTestCase {
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
    
    // TODO test for no IO merging
    
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
        let fn = try FileHandle.createNewFile(file: file)
        
        let fileWriter = OmFileWriter2(fn: fn, bufferCapacity: 1)
        let writer = fileWriter.prepareArray(type: Float.self, dimensions: [100,100,10], chunkDimensions: [2,2,2], compression: .p4nzdec256, scale_factor: 1, add_offset: 0)
        
        let data = (0..<100000).map({Float($0 % 10000)})
        try writer.writeData(array: data, arrayDimensions: [100,100,10], arrayRead: [0..<100, 0..<100, 0..<10])
        let variableMeta = writer.finalise()
        let variable = fileWriter.write(array: variableMeta, name: "data", children: [])
        try fileWriter.writeTrailer(rootVariable: variable)
        
        let readFn = try MmapFile(fn: FileHandle.openFileReading(file: file))
        let read = try OmFileReader2(fn: readFn)
        
        let a1 = read.read([50..<51, 20..<21, 1..<2])
        XCTAssertEqual(a1, [201.0])
                
        let a = read.read([0..<100, 0..<100, 0..<10])
        XCTAssertEqual(a, data)
    }
    
    func testWriteChunks() throws {
        let file = "writetest.om"
        try FileManager.default.removeItemIfExists(at: file)
        
        let fn = try FileHandle.createNewFile(file: file)
        let fileWriter = OmFileWriter2(fn: fn, bufferCapacity: 1)
        
        let writer = fileWriter.prepareArray(type: Float.self, dimensions: [5,5], chunkDimensions: [2,2], compression: .p4nzdec256, scale_factor: 1, add_offset: 0)
        
        // Directly feed individual chunks
        try writer.writeData(array: [0.0, 1.0, 5.0, 6.0], arrayDimensions: [2,2], arrayRead: [0..<2, 0..<2])
        try writer.writeData(array: [2.0, 3.0, 7.0, 8.0], arrayDimensions: [2,2], arrayRead: [0..<2, 0..<2])
        try writer.writeData(array: [4.0, 9.0], arrayDimensions: [2,1], arrayRead: [0..<2, 0..<1])
        try writer.writeData(array: [10.0, 11.0, 15.0, 16.0], arrayDimensions: [2,2], arrayRead: [0..<2, 0..<2])
        try writer.writeData(array: [12.0, 13.0, 17.0, 18.0], arrayDimensions: [2,2], arrayRead: [0..<2, 0..<2])
        try writer.writeData(array: [14.0, 19.0], arrayDimensions: [2,1], arrayRead: [0..<2, 0..<1])
        try writer.writeData(array: [20.0, 21.0], arrayDimensions: [1,2], arrayRead: [0..<1, 0..<2])
        try writer.writeData(array: [22.0, 23.0], arrayDimensions: [1,2], arrayRead: [0..<1, 0..<2])
        try writer.writeData(array: [24.0], arrayDimensions: [1,1], arrayRead: [0..<1, 0..<1])
        let variableMeta = writer.finalise()
        let variable = fileWriter.write(array: variableMeta, name: "data", children: [])
        try fileWriter.writeTrailer(rootVariable: variable)
        
        let readFn = try MmapFile(fn: FileHandle.openFileReading(file: file))
        let read = try OmFileReader2(fn: readFn)
        
        let a = read.read([0..<5, 0..<5])
        XCTAssertEqual(a, [0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 17.0, 18.0, 19.0, 20.0, 21.0, 22.0, 23.0, 24.0])
    }
    
    func testOffsetWrite() throws {
        let file = "writetest.om"
        try FileManager.default.removeItemIfExists(at: file)
        
        let fn = try FileHandle.createNewFile(file: file)
        let fileWriter = OmFileWriter2(fn: fn, bufferCapacity: 1)
        
        let writer = fileWriter.prepareArray(type: Float.self, dimensions: [5,5], chunkDimensions: [2,2], compression: .p4nzdec256, scale_factor: 1, add_offset: 0)
        
        /// Deliberately add NaN on all positions that should not be written to the file. Only the inner 5x5 array is written
        let data = [.nan, .nan, .nan, .nan, .nan, .nan, .nan, .nan, Float(0.0), 1.0, 2.0, 3.0, 4.0, .nan, .nan, 5.0, 6.0, 7.0, 8.0, 9.0, .nan, .nan, 10.0, 11.0, 12.0, 13.0, 14.0, .nan, .nan, 15.0, 16.0, 17.0, 18.0, 19.0, .nan, .nan, 20.0, 21.0, 22.0, 23.0, 24.0, .nan, .nan, .nan, .nan, .nan, .nan, .nan, .nan]
        try writer.writeData(array: data, arrayDimensions: [7,7], arrayRead: [1..<6, 1..<6])
        
        let variableMeta = writer.finalise()
        let variable = fileWriter.write(array: variableMeta, name: "data", children: [])
        try fileWriter.writeTrailer(rootVariable: variable)
        
        let readFn = try MmapFile(fn: FileHandle.openFileReading(file: file))
        let read = try OmFileReader2(fn: readFn)
        XCTAssertEqual(read.dataType, .float_array)
        XCTAssertEqual(read.compression, .p4nzdec256)
        XCTAssertEqual(read.scaleFactor, 1)
        XCTAssertEqual(read.addOffset, 0)
        XCTAssertEqual(read.getDimensions().count, 2)
        XCTAssertEqual(read.getDimensions()[0], 5)
        XCTAssertEqual(read.getDimensions()[1], 5)
        XCTAssertEqual(read.getChunkDimensions()[0], 2)
        XCTAssertEqual(read.getChunkDimensions()[1], 2)
        
        let a = read.read([0..<5, 0..<5])
        XCTAssertEqual(a, [0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 17.0, 18.0, 19.0, 20.0, 21.0, 22.0, 23.0, 24.0])
    }
    
    func testWrite3D() throws {
        let file = "writetest.om"
        try FileManager.default.removeItemIfExists(at: file)
        
        let dims = [UInt64(3),3,3]
        let data = [Float(0.0), 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 17.0, 18.0, 19.0, 20.0, 21.0, 22.0, 23.0, 24.0, 25.0, 26.0]
        
        let fn = try FileHandle.createNewFile(file: file)
        let fileWriter = OmFileWriter2(fn: fn, bufferCapacity: 1)
        
        let writer = fileWriter.prepareArray(type: Float.self, dimensions: dims, chunkDimensions: [2,2,2], compression: .p4nzdec256, scale_factor: 1, add_offset: 0)
        try writer.writeData(array: data, arrayDimensions: [3,3,3], arrayRead: [0..<3, 0..<3, 0..<3])
        let variableMeta = writer.finalise()
        
        let int32Attribute = fileWriter.write(value: Int32(12323154), name: "int32", children: [])
        let doubleAttribute = fileWriter.write(value: Double(12323154), name: "double", children: [])
        let variable = fileWriter.write(array: variableMeta, name: "data", children: [int32Attribute, doubleAttribute])
        
        try fileWriter.writeTrailer(rootVariable: variable)
        
        let readFn = try MmapFile(fn: FileHandle.openFileReading(file: file))
        let read = try OmFileReader2(fn: readFn)
        
        XCTAssertEqual(read.numberOfChildren, 2)
        let child = read.getChild(0)!
        XCTAssertEqual(child.readScalar(), Int32(12323154))
        XCTAssertEqual(child.getName(), "int32")
        let child2 = read.getChild(1)!
        XCTAssertEqual(child2.readScalar(), Double(12323154))
        XCTAssertEqual(child2.getName(), "double")
        XCTAssertNil(read.getChild(2))
        
        let a = read.read([0..<3, 0..<3, 0..<3])
        XCTAssertEqual(a, data)
        
        // single index
        for x in 0..<dims[0] {
            for y in 0..<dims[1] {
                for z in 0..<dims[2] {
                    XCTAssertEqual(read.read([x..<x+1, y..<y+1, z..<z+1]), [Float(x*3*3 + y*3 + z)])
                }
            }
        }
    }
    
    func testWritev3() throws {
        let file = "writetest.om"
        try FileManager.default.removeItemIfExists(at: file)
        
        let dims = [UInt64(5),5]
        let fn = try FileHandle.createNewFile(file: file)
        let fileWriter = OmFileWriter2(fn: fn, bufferCapacity: 1)
        
        let writer = fileWriter.prepareArray(type: Float.self, dimensions: dims, chunkDimensions: [2,2], compression: .p4nzdec256, scale_factor: 1, add_offset: 0, lutChunkElementCount: 2)
        
        let data = [Float(0.0), 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 17.0, 18.0, 19.0, 20.0, 21.0, 22.0, 23.0, 24.0]
        try writer.writeData(array: data, arrayDimensions: [5,5], arrayRead: [0..<5, 0..<5])
        let variableMeta = writer.finalise()
        let variable = fileWriter.write(array: variableMeta, name: "data", children: [])
        try fileWriter.writeTrailer(rootVariable: variable)
        
        let readFn = try MmapFile(fn: FileHandle.openFileReading(file: file))
        let read = try OmFileReader2(fn: readFn, lutChunkElementCount: 2)
        

        let a = read.read([0..<5, 0..<5])
        XCTAssertEqual(a, [0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 17.0, 18.0, 19.0, 20.0, 21.0, 22.0, 23.0, 24.0])
        
        // single index
        for x in 0..<dims[0] {
            for y in 0..<dims[1] {
                XCTAssertEqual(read.read([x..<x+1, y..<y+1]), [Float(x*5 + y)])
            }
        }
        
        // Read into an existing array with an offset
        for x in 0..<dims[0] {
            for y in 0..<dims[1] {
                var r = [Float](repeating: .nan, count: 9)
                r.withUnsafeMutableBufferPointer({
                    read.read(into: $0.baseAddress!, dimRead: [x..<x+1, y..<y+1], intoCubeOffset: [1,1], intoCubeDimension: [3,3])
                })
                XCTAssertEqualArray(r, [.nan, .nan, .nan, .nan, Float(x*5 + y), .nan, .nan, .nan, .nan], accuracy: 0.001)
            }
        }
        
        // 2x in fast dim
        for x in 0..<dims[0] {
            for y in 0..<dims[1]-1 {
                XCTAssertEqual(read.read([x..<x+1, y..<y+2]), [Float(x*5 + y), Float(x*5 + y + 1)])
            }
        }
        
        // 2x in slow dim
        for x in 0..<dims[0]-1 {
            for y in 0..<dims[1] {
                XCTAssertEqual(read.read([x..<x+2, y..<y+1]), [Float(x*5 + y), Float((x+1)*5 + y)])
            }
        }
        
        // 2x2
        for x in 0..<dims[0]-1 {
            for y in 0..<dims[1]-1 {
                XCTAssertEqual(read.read([x..<x+2, y..<y+2]), [Float(x*5 + y), Float(x*5 + y + 1), Float((x+1)*5 + y), Float((x+1)*5 + y + 1)])
            }
        }
        // 3x3
        for x in 0..<dims[0]-2 {
            for y in 0..<dims[1]-2 {
                XCTAssertEqual(read.read([x..<x+3, y..<y+3]), [Float(x*5 + y), Float(x*5 + y + 1), Float(x*5 + y + 2), Float((x+1)*5 + y), Float((x+1)*5 + y + 1),  Float((x+1)*5 + y + 2), Float((x+2)*5 + y), Float((x+2)*5 + y + 1),  Float((x+2)*5 + y + 2)])
            }
        }
        
        // 1x5
        for x in 0..<dims[1] {
            XCTAssertEqual(read.read([x..<x+1, 0..<5]), [Float(x*5), Float(x*5+1), Float(x*5+2), Float(x*5+3), Float(x*5+4)])
        }
        
        // 5x1
        for x in 0..<dims[0] {
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
    
    func testWritev3MaxIOLimit() throws {
        let file = "writetest.om"
        try FileManager.default.removeItemIfExists(at: file)
        
        let dims = [UInt64(5),5]
        let fn = try FileHandle.createNewFile(file: file)
        let fileWriter = OmFileWriter2(fn: fn, bufferCapacity: 1)
        
        let writer = fileWriter.prepareArray(type: Float.self, dimensions: dims, chunkDimensions: [2,2], compression: .p4nzdec256, scale_factor: 1, add_offset: 0, lutChunkElementCount: 2)
        
        let data = [Float(0.0), 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 17.0, 18.0, 19.0, 20.0, 21.0, 22.0, 23.0, 24.0]
        try writer.writeData(array: data, arrayDimensions: [5,5], arrayRead: [0..<5, 0..<5])
        let variableMeta = writer.finalise()
        let variable = fileWriter.write(array: variableMeta, name: "data", children: [])
        try fileWriter.writeTrailer(rootVariable: variable)
        
        let readFn = try MmapFile(fn: FileHandle.openFileReading(file: file))
        let read = try OmFileReader2(fn: readFn, lutChunkElementCount: 2)
        

        let a = read.read([0..<5, 0..<5], io_size_max: 0, io_size_merge: 0)
        XCTAssertEqual(a, [0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 17.0, 18.0, 19.0, 20.0, 21.0, 22.0, 23.0, 24.0])
        
        // single index
        for x in 0..<dims[0] {
            for y in 0..<dims[1] {
                XCTAssertEqual(read.read([x..<x+1, y..<y+1], io_size_max: 0, io_size_merge: 0), [Float(x*5 + y)])
            }
        }
        
        // Read into an existing array with an offset
        for x in 0..<dims[0] {
            for y in 0..<dims[1] {
                var r = [Float](repeating: .nan, count: 9)
                r.withUnsafeMutableBufferPointer({
                    read.read(into: $0.baseAddress!, dimRead: [x..<x+1, y..<y+1], intoCubeOffset: [1,1], intoCubeDimension: [3,3], io_size_max: 0, io_size_merge: 0)
                })
                XCTAssertEqualArray(r, [.nan, .nan, .nan, .nan, Float(x*5 + y), .nan, .nan, .nan, .nan], accuracy: 0.001)
            }
        }
        
        // 2x in fast dim
        for x in 0..<dims[0] {
            for y in 0..<dims[1]-1 {
                XCTAssertEqual(read.read([x..<x+1, y..<y+2], io_size_max: 0, io_size_merge: 0), [Float(x*5 + y), Float(x*5 + y + 1)])
            }
        }
        
        // 2x in slow dim
        for x in 0..<dims[0]-1 {
            for y in 0..<dims[1] {
                XCTAssertEqual(read.read([x..<x+2, y..<y+1], io_size_max: 0, io_size_merge: 0), [Float(x*5 + y), Float((x+1)*5 + y)])
            }
        }
        
        // 2x2
        for x in 0..<dims[0]-1 {
            for y in 0..<dims[1]-1 {
                XCTAssertEqual(read.read([x..<x+2, y..<y+2], io_size_max: 0, io_size_merge: 0), [Float(x*5 + y), Float(x*5 + y + 1), Float((x+1)*5 + y), Float((x+1)*5 + y + 1)])
            }
        }
        // 3x3
        for x in 0..<dims[0]-2 {
            for y in 0..<dims[1]-2 {
                XCTAssertEqual(read.read([x..<x+3, y..<y+3], io_size_max: 0, io_size_merge: 0), [Float(x*5 + y), Float(x*5 + y + 1), Float(x*5 + y + 2), Float((x+1)*5 + y), Float((x+1)*5 + y + 1),  Float((x+1)*5 + y + 2), Float((x+2)*5 + y), Float((x+2)*5 + y + 1),  Float((x+2)*5 + y + 2)])
            }
        }
        
        // 1x5
        for x in 0..<dims[1] {
            XCTAssertEqual(read.read([x..<x+1, 0..<5], io_size_max: 0, io_size_merge: 0), [Float(x*5), Float(x*5+1), Float(x*5+2), Float(x*5+3), Float(x*5+4)])
        }
        
        // 5x1
        for x in 0..<dims[0] {
            XCTAssertEqual(read.read([0..<5, x..<x+1], io_size_max: 0, io_size_merge: 0), [Float(x), Float(x+5), Float(x+10), Float(x+15), Float(x+20)])
        }
        
        /*// test interpolation
        XCTAssertEqualArray(try read.readInterpolated(dim0X: 0, dim0XFraction: 0.5, dim0Y: 0, dim0YFraction: 0.5, dim0Nx: 2, dim1: 0..<5), [7.5, 8.5, 9.5, 10.5, 11.5], accuracy: 0.001)
        XCTAssertEqualArray(try read.readInterpolated(dim0X: 0, dim0XFraction: 0.1, dim0Y: 0, dim0YFraction: 0.2, dim0Nx: 2, dim1: 0..<5), [2.5, 3.4999998, 4.5, 5.5, 6.5], accuracy: 0.001)
        XCTAssertEqualArray(try read.readInterpolated(dim0X: 0, dim0XFraction: 0.9, dim0Y: 0, dim0YFraction: 0.2, dim0Nx: 2, dim1: 0..<5), [6.5, 7.5, 8.5, 9.5, 10.5], accuracy: 0.001)
        XCTAssertEqualArray(try read.readInterpolated(dim0X: 0, dim0XFraction: 0.1, dim0Y: 0, dim0YFraction: 0.9, dim0Nx: 2, dim1: 0..<5), [9.5, 10.499999, 11.499999, 12.5, 13.499999], accuracy: 0.001)
        XCTAssertEqualArray(try read.readInterpolated(dim0X: 0, dim0XFraction: 0.8, dim0Y: 0, dim0YFraction: 0.9, dim0Nx: 2, dim1: 0..<5), [12.999999, 14.0, 15.0, 16.0, 17.0], accuracy: 0.001)*/
        try FileManager.default.removeItem(atPath: file)
    }
    
    func testOldWriterNewReader() throws {
        let file = "writetest.om"
        try FileManager.default.removeItemIfExists(at: file)
        
        let fn = try OmFileWriter(dim0: 5, dim1: 5, chunk0: 2, chunk1: 2).write(file: file, compressionType: .p4nzdec256, scalefactor: 1, overwrite: false, supplyChunk: { dim0pos in
            
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
        
        let read = try OmFileReader2(fn: try MmapFile(fn: fn))
        let dims = read.getDimensions()
        let a = read.read([0..<5, 0..<5], io_size_max: 0, io_size_merge: 0)
        XCTAssertEqual(a, [0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 17.0, 18.0, 19.0, 20.0, 21.0, 22.0, 23.0, 24.0])
        
        // single index
        for x in 0..<dims[0] {
            for y in 0..<dims[1] {
                XCTAssertEqual(read.read([x..<x+1, y..<y+1], io_size_max: 0, io_size_merge: 0), [Float(x*5 + y)])
            }
        }
        
        // Read into an existing array with an offset
        for x in 0..<dims[0] {
            for y in 0..<dims[1] {
                var r = [Float](repeating: .nan, count: 9)
                r.withUnsafeMutableBufferPointer({
                    read.read(into: $0.baseAddress!, dimRead: [x..<x+1, y..<y+1], intoCubeOffset: [1,1], intoCubeDimension: [3,3], io_size_max: 0, io_size_merge: 0)
                })
                XCTAssertEqualArray(r, [.nan, .nan, .nan, .nan, Float(x*5 + y), .nan, .nan, .nan, .nan], accuracy: 0.001)
            }
        }
        
        // 2x in fast dim
        for x in 0..<dims[0] {
            for y in 0..<dims[1]-1 {
                XCTAssertEqual(read.read([x..<x+1, y..<y+2], io_size_max: 0, io_size_merge: 0), [Float(x*5 + y), Float(x*5 + y + 1)])
            }
        }
        
        // 2x in slow dim
        for x in 0..<dims[0]-1 {
            for y in 0..<dims[1] {
                XCTAssertEqual(read.read([x..<x+2, y..<y+1], io_size_max: 0, io_size_merge: 0), [Float(x*5 + y), Float((x+1)*5 + y)])
            }
        }
        
        // 2x2
        for x in 0..<dims[0]-1 {
            for y in 0..<dims[1]-1 {
                XCTAssertEqual(read.read([x..<x+2, y..<y+2], io_size_max: 0, io_size_merge: 0), [Float(x*5 + y), Float(x*5 + y + 1), Float((x+1)*5 + y), Float((x+1)*5 + y + 1)])
            }
        }
        // 3x3
        for x in 0..<dims[0]-2 {
            for y in 0..<dims[1]-2 {
                XCTAssertEqual(read.read([x..<x+3, y..<y+3], io_size_max: 0, io_size_merge: 0), [Float(x*5 + y), Float(x*5 + y + 1), Float(x*5 + y + 2), Float((x+1)*5 + y), Float((x+1)*5 + y + 1),  Float((x+1)*5 + y + 2), Float((x+2)*5 + y), Float((x+2)*5 + y + 1),  Float((x+2)*5 + y + 2)])
            }
        }
        
        // 1x5
        for x in 0..<dims[1] {
            XCTAssertEqual(read.read([x..<x+1, 0..<5], io_size_max: 0, io_size_merge: 0), [Float(x*5), Float(x*5+1), Float(x*5+2), Float(x*5+3), Float(x*5+4)])
        }
        
        // 5x1
        for x in 0..<dims[0] {
            XCTAssertEqual(read.read([0..<5, x..<x+1], io_size_max: 0, io_size_merge: 0), [Float(x), Float(x+5), Float(x+10), Float(x+15), Float(x+20)])
        }
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

func XCTAssertEqualArray<T: Collection>(_ a: T, _ b: T, accuracy: Float) where T.Element == Float, T: Equatable {
    guard a.count == b.count else {
        XCTFail("Array length different")
        return
    }
    var failed = false
    for (a1,b1) in zip(a,b) {
        if a1.isNaN && b1.isNaN {
            continue
        }
        if a1.isNaN || b1.isNaN || abs(a1 - b1) > accuracy {
            failed = true
            break
        }
    }
    if failed {
        for (a1,b1) in zip(a,b) {
            if a1.isNaN && b1.isNaN {
                continue
            }
            if a1.isNaN || b1.isNaN || abs(a1 - b1) > accuracy {
                print("\(a1)\t\(b1)\t\(a1-b1)")
            }
        }
        XCTAssertEqual(a, b)
    }
}
