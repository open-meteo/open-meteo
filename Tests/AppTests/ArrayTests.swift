import Foundation
@testable import App
import XCTest


final class ArrayTests: XCTestCase {
    func testTranspose() {
        let spatial = Array2DFastSpace(data: [1,2,3,4,5,6], nLocations: 2, nTime: 3)
        let temporal = spatial.transpose()
        XCTAssertEqual(temporal.data, [1, 3, 5, 2, 4, 6])
        let spatial2 = temporal.transpose()
        XCTAssertEqual(spatial2.data, spatial.data)
    }
    
    func testBackwardInterpolateInplace() {
        var a: [Float] = [0,1,.nan,.nan,.nan,5]
        a.interpolateInplaceBackwards(nTime: 6, skipFirst: 0)
        XCTAssertEqual(a, [0,1,5,5,5,5])
        
        // Make sure nTime is honored correctly
        a = [0,.nan,1,.nan,.nan,.nan, 0,.nan,1,.nan,.nan,.nan]
        a.interpolateInplaceBackwards(nTime: 6, skipFirst: 0)
        XCTAssertEqualArray(a, [0,1,1,.nan,.nan,.nan, 0,1,1,.nan,.nan,.nan], accuracy: 0.0001)
        
        // Make sure nTime is honored correctly
        a = [.nan,.nan,1,.nan,.nan,.nan, .nan,.nan,1,.nan,.nan,.nan]
        a.interpolateInplaceBackwards(nTime: 6, skipFirst: 1)
        XCTAssertEqualArray(a, [.nan,1,1,.nan,.nan,.nan, .nan,1,1,.nan,.nan,.nan], accuracy: 0.0001)
    }
    
    func testLinearInterpolateInplace() {
        var a: [Float] = [0,1,.nan,.nan,.nan,5]
        a.interpolateInplaceLinear(nTime: 6)
        XCTAssertEqual(a, [0,1,2,3,4,5])
        
        // Make sure nTime is honored correctly
        a = [0,.nan,1,.nan,.nan,.nan, 0,.nan,1,.nan,.nan,.nan]
        a.interpolateInplaceLinear(nTime: 6)
        XCTAssertEqualArray(a, [0,0.5,1,.nan,.nan,.nan, 0,0.5,1,.nan,.nan,.nan], accuracy: 0.0001)
    }
    
    func testHermiteInterpolateInplace() {
        var a: [Float] = [0,1,.nan,3,.nan,5,.nan,0]
        a.interpolateInplaceHermite(nTime: 8, bounds: nil)
        XCTAssertEqual(a, [0.0, 1.0, 1.875, 3.0, 4.4375, 5.0, 2.625, 0.0])
        
        a = [0,1,.nan,.nan,3,.nan,.nan,5,.nan,.nan,0]
        a.interpolateInplaceHermite(nTime: 11, bounds: nil)
        XCTAssertEqualArray(a, [0.0, 1.0, 1.5185186, 2.2592592, 3.0, 3.925926, 4.851852, 5.0, 3.6666665, 1.5555556, 0.0], accuracy: 0.0001)
        
        a = [0,1,.nan,.nan,3,.nan,.nan,5,.nan,.nan,0]
        a.interpolateInplaceHermite(nTime: 11, bounds: 1...3)
        // only bound interpolated values!
        XCTAssertEqualArray(a, [0.0, 1.0, 1.5185186, 2.2592592, 3.0, 3, 3, 5.0, 3, 1.5555556, 0.0], accuracy: 0.0001)
        
        // Ensure left boundary is stable
        a = [.nan,1,.nan,.nan,3,.nan,.nan,5,.nan,.nan,0]
        a.interpolateInplaceHermite(nTime: 11, bounds: nil)
        XCTAssertEqualArray(a, [.nan, 1.0, 1.5185186, 2.2592592, 3.0, 3.925926, 4.851852, 5.0, 3.6666665, 1.5555556, 0.0], accuracy: 0.0001)
        
        // Ensure mixed point spacing works. First 1x NaN, then switch to 2x NaN spacing
        a = [.nan,1,.nan,3,.nan,5,.nan,0,.nan,.nan,10,.nan,.nan,5]
        a.interpolateInplaceHermite(nTime: a.count, bounds: nil)
        XCTAssertEqualArray(a, [.nan, 1.0, 1.875, 3.0, 4.4375, 5.0, 0.7013891, 0.0, 2.8194444, 7.2430553, 10.0, 9.259259, 6.8518515, 5.0], accuracy: 0.0001)
    }
    func testSolarBackwardsInterpolateInplace() {
        var data: [Float] = [.nan, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.3125, 11.9375, 57.484375, 75.203125, 81.625, 56.3125, 69.359375, 100.671875, 320.9375, 400.78125, 373.76562, 246.95312, 53.632812, 29.242188, 2.578125, -0.109375, 0.0, 0.0625, 0.0859375, -0.0859375, 0.0234375, -0.0859375, 0.140625, -0.03125, 0.2421875, 4.2109375, 3.515625, 8.65625, 14.0, 4.015625, 18.257812, 0.3359375, 4.0, 1.90625, 0.796875, 1.09375, 3.59375, 0.578125, -0.046875, 0.140625, 0.1015625, -0.1953125, -0.015625, -0.109375, 0.2890625, -0.0078125, -0.234375, 0.03125, 2.96875, 27.578125, 98.99219, 126.14844, 183.63281, 261.22656, 319.10156, 409.4922, 386.6797, 374.72656, 353.08594, 311.9453, 132.4375, 70.46875, 8.3828125, -0.0703125, 0.0703125, -0.2578125, 0.0546875, -0.1171875, 0.3671875, -0.2421875, -0.203125, 0.515625, .nan, .nan, 15.9765625, .nan, .nan, 175.58594, .nan, .nan, 411.35938, .nan, .nan, 272.71875, .nan, .nan, 40.820312, .nan, .nan, -0.0234375, .nan, .nan, -0.0859375, .nan, .nan, 0.0546875, .nan, .nan, 0.640625, .nan, .nan, 3.078125, .nan, .nan, 0.875, .nan, .nan, 1.484375, .nan, .nan, 0.0078125, .nan, .nan, -0.0546875, .nan, .nan, 0.140625, .nan, .nan, -0.0625, .nan, .nan, 1.9609375, .nan, .nan, 181.02344, .nan, .nan, 152.05469, .nan, .nan, 40.648438, .nan, .nan, 6.5390625, .nan, .nan, -0.0546875, .nan, .nan, -0.015625, .nan, .nan, 0.1875, .nan, .nan, 20.078125, .nan, .nan, 317.53125, .nan, .nan, 381.72656, .nan, .nan, 250.71094, .nan, .nan, 53.742188, .nan, .nan, -0.3359375, .nan, .nan, 0.171875, .nan, .nan, -0.0625, .nan, .nan, 43.609375, .nan, .nan, 191.8125]
        
        // this location is exactly at a point where sofac is diverging to 0 on the first step to interpolate
        let coords = IconDomains.icon.grid.getCoordinates(gridpoint: 1256 + 2879 * 1132)
        let grid = RegularGrid(nx: 1, ny: 1, latMin: coords.latitude, lonMin: coords.longitude, dx: 1, dy: 1)
        let time = TimerangeDt(start: Timestamp(2022,08,16), nTime: data.count, dtSeconds: 3600)
        data.interpolateInplaceSolarBackwards(skipFirst: 1, time: time, grid: grid, locationRange: 0..<1)
        
        XCTAssertEqualArray(data[79..<181], [2.582452, 12.639391, 30.065294, 68.45511, 131.95537, 208.47006, 294.40652, 375.17276, 409.62054, 379.85846, 308.57794, 221.1458, 128.9006, 52.322044, 9.156854, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.10571713, 0.5840053, 1.2143807, 2.0561118, 3.0618, 3.658186, 3.1120915, 1.8141747, 0.87108666, 0.92968047, 1.2847098, 1.2009717, 0.6280575, 0.1469994, 0.0016845806, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.023996884, 0.0, 3.7452843, 48.407387, 136.5591, 215.34955, 230.58553, 197.18088, 151.33687, 107.44555, 63.80062, 32.812675, 16.346872, 7.1358676, 1.3503866, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 2.6231868, 13.935116, 38.64731, 115.81589, 251.179, 378.12033, 428.5003, 416.7997, 379.82858, 334.7293, 273.48355, 201.91202, 125.72918, 57.16956, 10.584465, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 6.0511684, 39.51611, 84.617775, 133.85574, 185.37973, 228.64375], accuracy: 0.001)
        // original: [0.5327332, 7.0458064, 30.065294, 68.640236, 125.21594, 208.47006, 287.15527, 362.1674, 409.62054, 381.09317, 313.93628, 221.14587, 134.36256, 58.54249, 9.156854, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.02641212, 0.35874152, 1.2143807, 2.1519227, 3.0996456, 3.658186, 3.2371387, 2.086485, 0.87108666, 0.88595426, 1.1891304, 1.2009717, 0.6598327, 0.18529162, 0.0016845806, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0, 0, 3.7452843, 43.235752, 122.65912, 215.34958, 233.18326, 206.56552, 151.33687, 110.88687, 69.342674, 32.812675, 17.16428, 7.791204, 1.3503972, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.45440406, 7.076116, 38.64731, 112.47823, 234.80026, 378.12024, 429.4058, 423.3296, 379.82858, 336.3908, 276.80637, 201.91202, 130.41829, 62.39851, 10.584465, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.5342923, 24.450073, 84.617775, 142.16772, 190.57127, 228.64375]
        
        /// Mix 3 and 6 hourly missing values
        data = [.nan, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.3125, 11.9375, 57.484375, 75.203125, 81.625, 56.3125, 69.359375, 100.671875, 320.9375, 400.78125, 373.76562, 246.95312, 53.632812, 29.242188, 2.578125, -0.109375, 0.0, 0.0625, 0.0859375, -0.0859375, 0.0234375, -0.0859375, 0.140625, -0.03125, 0.2421875, 4.2109375, 3.515625, 8.65625, 14.0, 4.015625, 18.257812, 0.3359375, 4.0, 1.90625, 0.796875, 1.09375, 3.59375, 0.578125, -0.046875, 0.140625, 0.1015625, -0.1953125, -0.015625, -0.109375, 0.2890625, -0.0078125, -0.234375, 0.03125, 2.96875, 27.578125, 98.99219, 126.14844, 183.63281, 261.22656, 319.10156, 409.4922, 386.6797, 374.72656, 353.08594, 311.9453, 132.4375, 70.46875, 8.3828125, -0.0703125, 0.0703125, -0.2578125, 0.0546875, -0.1171875, 0.3671875, -0.2421875, -0.203125, 0.515625, .nan, .nan, 15.9765625, .nan, .nan, 175.58594, .nan, .nan, 411.35938, .nan, .nan, 272.71875, .nan, .nan, 40.820312, .nan, .nan, -0.0234375, .nan, .nan, -0.0859375, .nan, .nan, 0.0546875, .nan, .nan, 0.640625, .nan, .nan, 3.078125, .nan, .nan, 0.875, .nan, .nan, 1.484375, .nan, .nan, 0.0078125, .nan, .nan, -0.0546875, .nan, .nan, 0.140625, .nan, .nan, -0.0625, .nan, .nan, 1.9609375, .nan, .nan, 181.02344, .nan, .nan, 152.05469, .nan, .nan, 40.648438, .nan, .nan, 6.5390625, .nan, .nan, -0.0546875, .nan, .nan, .nan, .nan, .nan, (0.1875-0.015625)/2, .nan, .nan, .nan, .nan, .nan, (317.53125+20.078125)/2, .nan, .nan, .nan, .nan, .nan, (250.71094+381.72656)/2, .nan, .nan, .nan, .nan, .nan, (-0.3359375+53.742188)/2, .nan, .nan, .nan, .nan, .nan, (-0.0625+0.171875)/2, .nan, .nan, .nan, .nan, .nan, (191.8125+43.609375)/2]
        data.interpolateInplaceSolarBackwards(skipFirst: 1, time: time, grid: grid, locationRange: 0..<1)
        XCTAssertEqualArray(data[79..<181], [2.582452, 12.639391, 30.065294, 68.45511, 131.95537, 208.47006, 294.40652, 375.17276, 409.62054, 379.85846, 308.57794, 221.1458, 128.9006, 52.322044, 9.156854, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.10571713, 0.5840053, 1.2143807, 2.0561118, 3.0618, 3.658186, 3.1120915, 1.8141747, 0.87108666, 0.92968047, 1.2847098, 1.2009717, 0.6280575, 0.1469994, 0.0016845806, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.023996884, 0.0, 3.7452843, 48.407387, 136.5591, 215.34955, 230.58553, 197.18088, 151.33687, 107.44555, 63.80062, 32.812675, 16.346872, 7.1358676, 1.3503866, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 10.932216, 67.74064, 140.7743, 209.2275, 268.54654, 314.84094, 346.61768, 362.2351, 358.46008, 333.3022, 287.07526, 223.13826, 147.78078, 71.59168, 13.511862, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 7.059788, 46.451366, 97.9866, 146.28572, 188.05128, 220.4309], accuracy: 0.001)
        
    }
    
    func testRangeFraction() {
        XCTAssertEqual((100..<1000).interpolated(atFraction: 0.5), 550)
        XCTAssertEqual((100..<1000).interpolated(atFraction: 0), 100)
        XCTAssertEqual((100..<1000).interpolated(atFraction: 1), 1000)
        XCTAssertEqual((100..<1000).interpolated(atFraction: -0.1), 100)
        XCTAssertEqual((100..<1000).interpolated(atFraction: 1.1), 1000)
        
        XCTAssertEqual((100..<1000).fraction(of: 550), 0.5)
        XCTAssertEqual((100..<1000).fraction(of: 100), 0)
        XCTAssertEqual((100..<1000).fraction(of: 1000), 1)
        XCTAssertEqual((100..<1000).fraction(of: 90), 0)
        XCTAssertEqual((100..<1000).fraction(of: 1010), 1)
    }
    
    func testDeaccumulate() {
        var data = Array2DFastTime(data: [1,2,3,1,2,3], nLocations: 2, nTime: 3)
        data.deaccumulateOverTime(slidingOffset: 0)
        XCTAssertEqual(data.data, [1, 1, 1, 1, 1, 1])
        
        var data2 = Array2DFastTime(data: [.nan,1,2,1,2,3], nLocations: 2, nTime: 3)
        data2.deaccumulateOverTime(slidingOffset: 0)
        XCTAssertTrue(data2.data[0].isNaN)
        XCTAssertEqual(data2.data[1..<6], [1, 1, 1, 1, 1])
        
        var data4 = Array2DFastTime(data: [.nan,1,2,3,3.1,3.3,3.9], nLocations: 1, nTime: 7)
        data4.deaccumulateOverTime(slidingOffset: 1)
        XCTAssertTrue(data4.data[0].isNaN)
        XCTAssertEqualArray(data4.data[1..<7], [1.0, 1.0, 1.0, 0.1, 0.2, 0.6], accuracy: 0.001)
        
        // Allow one missing value to be ignored
        var data5 = Array2DFastTime(data: [5,.nan,9,5,.nan,9], nLocations: 2, nTime: 3)
        data5.deaccumulateOverTime(slidingOffset: 0)
        XCTAssertEqualArray(data5.data, [5, .nan, 2, 5, .nan, 2], accuracy: 0.001)
    }
    
    func testSolfactorBackwards() {
        let time = TimerangeDt(start: Timestamp(2022,08,17), nTime: 48, dtSeconds: 3600)
        let grid = RegularGrid(nx: 1, ny: 1, latMin: 47, lonMin: 4.5, dx: 1, dy: 1)
        /*let solfac = Zensun.calculateRadiationBackwardsSubsampled(grid: grid, timerange: time, steps: 120).data
        XCTAssertEqual(solfac, [0.0, 0.0, 0.0, 0.0, 0.0, 0.0038180633, 0.1195483, 0.2877683, 0.44766656, 0.5883302, 0.70015657, 0.77550805, 0.8092315, 0.7990114, 0.7455277, 0.65240955, 0.52598935, 0.37486944, 0.20933856, 0.04605455, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0031137501, 0.11629447, 0.2847902, 0.4449114, 0.5857303, 0.6976339, 0.772979, 0.8066118, 0.7962221, 0.7424943, 0.6490812, 0.52233285, 0.37087443, 0.20501684, 0.042716768, 0.0, 0.0, 0.0, 0.0])*/
        
        let solfac2 = Zensun.calculateRadiationBackwardsAveraged(grid: grid, locationRange: 0..<1, timerange: time).data
        XCTAssertEqualArray(solfac2, [0.0, 0.0, 0.0, 0.0, 0.0, 0.0086724935, 0.12018183, 0.28839692, 0.44824192, 0.58880746, 0.7004983, 0.7756852, 0.8092266, 0.79881954, 0.74515647, 0.6518793, 0.52533007, 0.37412113, 0.20854692, 0.052031536, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.006979696, 0.116929695, 0.28541934, 0.4454871, 0.58620775, 0.6979755, 0.7731552, 0.8066067, 0.79602385, 0.74211675, 0.64854336, 0.5216657, 0.37011757, 0.20421669, 0.049818266, 0.0, 0.0, 0.0, 0.0], accuracy: 0.0001)
        
        //print(zip(solfac,solfac2).map(-))
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
        if abs(a1 - b1) > accuracy {
            failed = true
            break
        }
    }
    if failed {
        for (a1,b1) in zip(a,b) {
            if a1.isNaN && b1.isNaN {
                continue
            }
            if abs(a1 - b1) > accuracy {
                print("\(a1)\t\(b1)\t\(a1-b1)")
            }
        }
        XCTAssertEqual(a, b)
    }
}
