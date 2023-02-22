import XCTest
@testable import SwiftPFor2D
@testable import App
@_implementationOnly import CTurboPFor

final class SwiftPFor2DTests: XCTestCase {
    override func tearDown() {
        try! FileManager.default.removeItemIfExists(at: "writetest.om")
    }
    
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
    
    /// Make sure the last chunk has the correct number of chunks
    func testWriteMoreDataThenExpected() throws {
        let file = "writetest.om"
        try FileManager.default.removeItemIfExists(at: file)
        
        XCTAssertThrowsError(try OmFileWriter(dim0: 5, dim1: 5, chunk0: 2, chunk1: 2).write(file: file, compressionType: .p4nzdec256, scalefactor: 1, supplyChunk: { dim0pos in
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
        
    }
    
    func testWrite() throws {
        let file = "writetest.om"
        try FileManager.default.removeItemIfExists(at: file)
        
        try OmFileWriter(dim0: 5, dim1: 5, chunk0: 2, chunk1: 2).write(file: file, compressionType: .p4nzdec256, scalefactor: 1, supplyChunk: { dim0pos in
            
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
    }
    
    func testWriteFpx() throws {
        let file = "writetest.om"
        try FileManager.default.removeItemIfExists(at: file)
        
        try OmFileWriter(dim0: 5, dim1: 5, chunk0: 2, chunk1: 2).write(file: file, compressionType: .fpxdec32, scalefactor: 1, supplyChunk: { dim0pos in
            
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
    }
}
