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
        a.interpolateInplaceBackwards(nTime: 6, isSummation: false)
        XCTAssertEqual(a, [0,1,5,5,5,5])
        
        // Make sure nTime is honored correctly
        a = [0,.nan,1,.nan,.nan,.nan, 0,.nan,1,.nan,.nan,.nan]
        a.interpolateInplaceBackwards(nTime: 6, isSummation: false)
        XCTAssertEqualArray(a, [0,1,1,.nan,.nan,.nan, 0,1,1,.nan,.nan,.nan], accuracy: 0.0001)
        
        // Make sure nTime is honored correctly
        a = [1,.nan,2,.nan,1,.nan, 3,.nan,4,.nan,1,.nan]
        a.interpolateInplaceBackwards(nTime: 6, isSummation: false)
        XCTAssertEqualArray(a, [1,2,2,1,1,.nan, 3,4,4,1,1,.nan], accuracy: 0.0001)
        
        // Check sum
        a = [.nan,.nan,1.5,.nan,.nan,1.5, .nan,.nan,3,.nan,.nan,3]
        a.interpolateInplaceBackwards(nTime: 6, isSummation: true)
        XCTAssertEqualArray(a, [0.5,0.5,0.5,0.5,0.5,0.5, 1,1,1,1,1,1], accuracy: 0.0001)
        
        // Check spacing detection
        a = [.nan,.nan,.nan,1.5,.nan,.nan,1.5, .nan,.nan,.nan,3,.nan,.nan,3]
        a.interpolateInplaceBackwards(nTime: 7, isSummation: true)
        XCTAssertEqualArray(a, [.nan,0.5,0.5,0.5,0.5,0.5,0.5, .nan,1,1,1,1,1,1], accuracy: 0.0001)
    }
    
    func testInterpolateDegrees() {
        let time = TimerangeDt(start: Timestamp(0), nTime: 4, dtSeconds: 3600)
        XCTAssertEqual([Float(10),350,20,300].interpolateLinearDegrees(timeOld: time, timeNew: time.with(dtSeconds: 900), scalefactor: 1), [10.0, 5.0, 0.0, 355.0, 350.0, 358.0, 5.0, 13.0, 20.0, 0.0, 340.0, 320.0, 300.0, 300.0, 300.0, 300.0])
    }
    
    func testLinearInterpolateInplace() {
        var a: [Float] = [0,1,.nan,.nan,.nan,5]
        a.interpolateInplaceLinear(nTime: 6)
        XCTAssertEqual(a, [0,1,2,3,4,5])
        
        // Make sure nTime is honored correctly
        a = [0,.nan,1,.nan,.nan,.nan, 0,.nan,1,.nan,.nan,.nan]
        a.interpolateInplaceLinear(nTime: 6)
        XCTAssertEqualArray(a, [0,0.5,1,.nan,.nan,.nan, 0,0.5,1,.nan,.nan,.nan], accuracy: 0.0001)
        
        a = [355,.nan,20,.nan,.nan,.nan, 340,.nan,20,.nan,.nan,.nan]
        a.interpolateInplaceLinearDegrees(nTime: 6)
        XCTAssertEqualArray(a, [355.0, 7.5, 20.0, .nan, .nan, .nan, 340.0, 0.0, 20.0, .nan, .nan, .nan], accuracy: 0.0001)
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
        var time = TimerangeDt(start: Timestamp(2022,08,16), nTime: data.count, dtSeconds: 3600)
        data.interpolateInplaceSolarBackwards(time: time, grid: grid, locationRange: 0..<1, missingValuesAreBackwardsAveraged: true)
        
        XCTAssertEqualArray(data[79..<181], [2.7751129, 12.565333, 29.92181, 68.30576, 131.8756, 208.47153, 294.43616, 375.1984, 409.64493, 379.91507, 308.65784, 221.19334, 128.86157, 52.262794, 9.649313, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.114281915, 0.58105505, 1.2083836, 2.049771, 3.058337, 3.6581643, 3.113253, 1.8148575, 0.87113553, 0.9296356, 1.2847356, 1.2012333, 0.62843615, 0.14723891, 0.0017813047, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.024401145, 0.0, 3.7263098, 48.388783, 136.54715, 215.34631, 230.58772, 197.1857, 151.3438, 107.45953, 63.816956, 32.818916, 16.335684, 7.1231337, 1.4328097, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 2.870412, 13.837922, 38.44829, 115.605644, 251.0613, 378.11237, 428.5317, 416.82214, 379.8396, 334.78162, 273.56696, 201.93892, 125.62505, 57.04836, 11.268686, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 6.6770487, 39.30699, 84.17851, 133.38658, 185.12206, 228.63828], accuracy: 0.001)
        // original: [0.5327332, 7.0458064, 30.065294, 68.640236, 125.21594, 208.47006, 287.15527, 362.1674, 409.62054, 381.09317, 313.93628, 221.14587, 134.36256, 58.54249, 9.156854, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.02641212, 0.35874152, 1.2143807, 2.1519227, 3.0996456, 3.658186, 3.2371387, 2.086485, 0.87108666, 0.88595426, 1.1891304, 1.2009717, 0.6598327, 0.18529162, 0.0016845806, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0, 0, 3.7452843, 43.235752, 122.65912, 215.34958, 233.18326, 206.56552, 151.33687, 110.88687, 69.342674, 32.812675, 17.16428, 7.791204, 1.3503972, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.45440406, 7.076116, 38.64731, 112.47823, 234.80026, 378.12024, 429.4058, 423.3296, 379.82858, 336.3908, 276.80637, 201.91202, 130.41829, 62.39851, 10.584465, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.5342923, 24.450073, 84.617775, 142.16772, 190.57127, 228.64375]
        
        /// Mix 3 and 6 hourly missing values
        data = [.nan, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.3125, 11.9375, 57.484375, 75.203125, 81.625, 56.3125, 69.359375, 100.671875, 320.9375, 400.78125, 373.76562, 246.95312, 53.632812, 29.242188, 2.578125, -0.109375, 0.0, 0.0625, 0.0859375, -0.0859375, 0.0234375, -0.0859375, 0.140625, -0.03125, 0.2421875, 4.2109375, 3.515625, 8.65625, 14.0, 4.015625, 18.257812, 0.3359375, 4.0, 1.90625, 0.796875, 1.09375, 3.59375, 0.578125, -0.046875, 0.140625, 0.1015625, -0.1953125, -0.015625, -0.109375, 0.2890625, -0.0078125, -0.234375, 0.03125, 2.96875, 27.578125, 98.99219, 126.14844, 183.63281, 261.22656, 319.10156, 409.4922, 386.6797, 374.72656, 353.08594, 311.9453, 132.4375, 70.46875, 8.3828125, -0.0703125, 0.0703125, -0.2578125, 0.0546875, -0.1171875, 0.3671875, -0.2421875, -0.203125, 0.515625, .nan, .nan, 15.9765625, .nan, .nan, 175.58594, .nan, .nan, 411.35938, .nan, .nan, 272.71875, .nan, .nan, 40.820312, .nan, .nan, -0.0234375, .nan, .nan, -0.0859375, .nan, .nan, 0.0546875, .nan, .nan, 0.640625, .nan, .nan, 3.078125, .nan, .nan, 0.875, .nan, .nan, 1.484375, .nan, .nan, 0.0078125, .nan, .nan, -0.0546875, .nan, .nan, 0.140625, .nan, .nan, -0.0625, .nan, .nan, 1.9609375, .nan, .nan, 181.02344, .nan, .nan, 152.05469, .nan, .nan, 40.648438, .nan, .nan, 6.5390625, .nan, .nan, -0.0546875, .nan, .nan, .nan, .nan, .nan, (0.1875-0.015625)/2, .nan, .nan, .nan, .nan, .nan, (317.53125+20.078125)/2, .nan, .nan, .nan, .nan, .nan, (250.71094+381.72656)/2, .nan, .nan, .nan, .nan, .nan, (-0.3359375+53.742188)/2, .nan, .nan, .nan, .nan, .nan, (-0.0625+0.171875)/2, .nan, .nan, .nan, .nan, .nan, (191.8125+43.609375)/2]
        data.interpolateInplaceSolarBackwards(time: time, grid: grid, locationRange: 0..<1, missingValuesAreBackwardsAveraged: true)
        XCTAssertEqualArray(data[79..<181], [2.7751129, 12.565333, 29.92181, 68.30576, 131.8756, 208.47153, 294.43616, 375.1984, 409.64493, 379.91507, 308.65784, 221.19334, 128.86157, 52.262794, 9.649313, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.114281915, 0.58105505, 1.2083836, 2.049771, 3.058337, 3.6581643, 3.113253, 1.8148575, 0.87113553, 0.9296356, 1.2847356, 1.2012333, 0.62843615, 0.14723891, 0.0017813047, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.024401145, 0.0, 3.7263098, 48.388783, 136.54715, 215.34631, 230.58772, 197.1857, 151.3438, 107.45953, 63.816956, 32.818916, 16.335684, 7.1231337, 1.4328097, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 12.024332, 67.70339, 140.62544, 208.97667, 268.2166, 314.4697, 346.27148, 361.9829, 358.3321, 333.28455, 287.1204, 223.18909, 147.80145, 71.60986, 14.433392, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 7.8246827, 46.422653, 97.88847, 146.12347, 187.83421, 220.17207], accuracy: 0.001)
        
        /// Immediately 3 hourly data. Note: the left-most values only rely on the clearness index of the first point
        data = [.nan, .nan, .nan, 320.9375, .nan, .nan, 246.95312, .nan, .nan, 2.578125, .nan, .nan, 0.0, .nan, .nan, 0.0]
        time = TimerangeDt(start: Timestamp(2022,08,16,12), nTime: data.count, dtSeconds: 3600)
        data.interpolateInplaceSolarBackwards(time: time, grid: grid, locationRange: 0..<1, missingValuesAreBackwardsAveraged: true)
        XCTAssertEqualArray(data, [.nan, 316.37225, 326.621, 319.8192, 294.02402, 253.06091, 201.56267, 101.99449, 25.591284, 0.6671406, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0], accuracy: 0.001)
        
        /// Assuming the value afterwards is not averaged correctly
        data = [.nan, .nan, .nan, 304.3659, .nan, .nan, 101.99449, .nan, .nan, 0.0, .nan, .nan, 0.0, .nan, .nan, 0.0]
        time = TimerangeDt(start: Timestamp(2022,08,16,12), nTime: data.count, dtSeconds: 3600)
        data.interpolateInplaceSolarBackwards(time: time, grid: grid, locationRange: 0..<1, missingValuesAreBackwardsAveraged: false)
        XCTAssertEqualArray(data, [.nan, 301.08548, 310.839, 304.3659, 241.74438, 162.12485, 101.99449, 46.063854, 10.676279, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0], accuracy: 0.001)
        
        data = [321.95593, .nan, 247.148]
        time = TimerangeDt(start: Timestamp(2022,08,16,14), nTime: data.count, dtSeconds: 3600)
        data.interpolateInplaceSolarBackwards(time: time, grid: grid, locationRange: 0..<1, missingValuesAreBackwardsAveraged: false)
        XCTAssertEqualArray(data, [321.95593, 290.95282, 247.148], accuracy: 0.001) 
        
        data = [321.95593, .nan]
        time = TimerangeDt(start: Timestamp(2022,08,16,14), nTime: data.count, dtSeconds: 3600)
        data.interpolateInplaceSolarBackwards(time: time, grid: grid, locationRange: 0..<1, missingValuesAreBackwardsAveraged: false)
        XCTAssertEqualArray(data, [321.95593, .nan], accuracy: 0.001)
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
    
    func testDeaverage() {
        var data = Array2DFastTime(data: [1,2,3,1,2,3], nLocations: 2, nTime: 3)
        data.deavergeOverTime()
        XCTAssertEqual(data.data, [1.0, 3.0, 5.0, 1.0, 3.0, 5.0])
        
        data = Array2DFastTime(data: [.nan,2,3,.nan,2,3], nLocations: 2, nTime: 3)
        data.deavergeOverTime()
        XCTAssertEqualArray(data.data, [.nan, 2.0, 4.0, .nan, 2.0, 4.0], accuracy: 0.001)
        
        data = Array2DFastTime(data: [.nan,.nan,2,3, .nan,.nan,2,3], nLocations: 2, nTime: 4)
        data.deavergeOverTime()
        XCTAssertEqualArray(data.data, [.nan, .nan, 2.0, 4.0, .nan, .nan, 2.0, 4.0], accuracy: 0.001)
        
        data = Array2DFastTime(data: [1,2,.nan,3.25,1,2,.nan,3.25], nLocations: 2, nTime: 4)
        data.deavergeOverTime()
        XCTAssertEqualArray(data.data, [1.0, 3.0, .nan, 4.5, 1.0, 3.0, .nan, 4.5], accuracy: 0.001)
        
        data = Array2DFastTime(data: [1,2,3.25,3.25,1,2,3.25,3.25], nLocations: 2, nTime: 4)
        data.deavergeOverTime()
        XCTAssertEqualArray(data.data, [1.0, 3.0, 5.75, 3.25, 1.0, 3.0, 5.75, 3.25], accuracy: 0.001)
        
        data = Array2DFastTime(data: [10 ,10,.nan,10,10,10,.nan,10], nLocations: 2, nTime: 4)
        data.deavergeOverTime()
        XCTAssertEqualArray(data.data, [10.0, 10.0, .nan, 10.0, 10.0, 10.0, .nan, 10.0], accuracy: 0.001)
    }
    
    func testDeaccumulate() {
        var data = Array2DFastTime(data: [1,2,3,1,2,3], nLocations: 2, nTime: 3)
        data.deaccumulateOverTime()
        XCTAssertEqual(data.data, [1, 1, 1, 1, 1, 1])
        
        var data2 = Array2DFastTime(data: [.nan,1,2,1,2,3], nLocations: 2, nTime: 3)
        data2.deaccumulateOverTime()
        XCTAssertTrue(data2.data[0].isNaN)
        XCTAssertEqual(data2.data[1..<6], [1, 1, 1, 1, 1])
        
        var data4 = Array2DFastTime(data: [.nan,1,2,3,3.1,3.3,3.9], nLocations: 1, nTime: 7)
        data4.deaccumulateOverTime()
        XCTAssertTrue(data4.data[0].isNaN)
        XCTAssertEqualArray(data4.data[1..<7], [1.0, 1.0, 1.0, 0.1, 0.2, 0.6], accuracy: 0.001)
        
        // Allow one missing value to be ignored
        var data5 = Array2DFastTime(data: [5,.nan,9,5,.nan,9], nLocations: 2, nTime: 3)
        data5.deaccumulateOverTime()
        XCTAssertEqualArray(data5.data, [5, .nan, 2, 5, .nan, 2], accuracy: 0.001)
    }
    
    func testSolfactorBackwards() {
        let time = TimerangeDt(start: Timestamp(2022,08,17), nTime: 48, dtSeconds: 3600)
        let grid = RegularGrid(nx: 1, ny: 1, latMin: 47, lonMin: 4.5, dx: 1, dy: 1)
        /*let solfac = Zensun.calculateRadiationBackwardsSubsampled(grid: grid, timerange: time, steps: 120).data
        XCTAssertEqual(solfac, [0.0, 0.0, 0.0, 0.0, 0.0, 0.0038180633, 0.1195483, 0.2877683, 0.44766656, 0.5883302, 0.70015657, 0.77550805, 0.8092315, 0.7990114, 0.7455277, 0.65240955, 0.52598935, 0.37486944, 0.20933856, 0.04605455, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0031137501, 0.11629447, 0.2847902, 0.4449114, 0.5857303, 0.6976339, 0.772979, 0.8066118, 0.7962221, 0.7424943, 0.6490812, 0.52233285, 0.37087443, 0.20501684, 0.042716768, 0.0, 0.0, 0.0, 0.0])*/
        
        let solfac2 = Zensun.calculateRadiationBackwardsAveraged(grid: grid, locationRange: 0..<1, timerange: time).data
        XCTAssertEqualArray(solfac2, [0.0, 0.0, 0.0, 0.0, 0.0, 0.010957998, 0.12013578, 0.2881744, 0.44786763, 0.58831614, 0.6999318, 0.77508986, 0.8086508, 0.79830927, 0.74475336, 0.65161735, 0.52523357, 0.37420243, 0.20880632, 0.054484148, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.009240662, 0.11683395, 0.2851496, 0.44506305, 0.5856591, 0.69734, 0.7724759, 0.8059283, 0.79540026, 0.74159133, 0.64815325, 0.5214387, 0.37007153, 0.20435601, 0.052217532, 0.0, 0.0, 0.0, 0.0], accuracy: 0.0001)
        
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
