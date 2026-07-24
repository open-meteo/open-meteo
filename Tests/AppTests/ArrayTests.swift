import Foundation
@testable import App
import Testing

@Suite struct ArrayTests {
    @Test func transpose() {
        let spatial = Array2DFastSpace(data: [1, 2, 3, 4, 5, 6], nLocations: 2, nTime: 3)
        let temporal = spatial.transpose()
        #expect(temporal.data == [1, 3, 5, 2, 4, 6])
        let spatial2 = temporal.transpose()
        #expect(spatial2.data == spatial.data)
    }

    @Test func backwardInterpolateInplace() {
        var a: [Float] = [0, 1, .nan, .nan, .nan, 5]
        a.interpolateInplaceBackwards(nTime: 6, isSummation: false)
        #expect(a == [0, 1, 5, 5, 5, 5])

        // Make sure nTime is honored correctly
        a = [0, .nan, 1, .nan, .nan, .nan, 0, .nan, 1, .nan, .nan, .nan]
        a.interpolateInplaceBackwards(nTime: 6, isSummation: false)
        #expect(arraysEqual(Array(a), [0, 1, 1, .nan, .nan, .nan, 0, 1, 1, .nan, .nan, .nan], accuracy: 0.0001))

        // Make sure nTime is honored correctly
        a = [1, .nan, 2, .nan, 1, .nan, 3, .nan, 4, .nan, 1, .nan]
        a.interpolateInplaceBackwards(nTime: 6, isSummation: false)
        #expect(arraysEqual(Array(a), [1, 2, 2, 1, 1, .nan, 3, 4, 4, 1, 1, .nan], accuracy: 0.0001))

        // Check sum
        a = [.nan, .nan, 1.5, .nan, .nan, 1.5, .nan, .nan, 3, .nan, .nan, 3]
        a.interpolateInplaceBackwards(nTime: 6, isSummation: true)
        #expect(arraysEqual(Array(a), [0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 1, 1, 1, 1, 1, 1], accuracy: 0.0001))

        // Check spacing detection
        a = [.nan, .nan, .nan, 1.5, .nan, .nan, 1.5, .nan, .nan, .nan, 3, .nan, .nan, 3]
        a.interpolateInplaceBackwards(nTime: 7, isSummation: true)
        #expect(arraysEqual(Array(a), [.nan, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, .nan, 1, 1, 1, 1, 1, 1], accuracy: 0.0001))
    }

    @Test func interpolateDegrees() {
        let time = TimerangeDt(start: Timestamp(0), nTime: 4, dtSeconds: 3600)
        #expect([Float(10), 350, 20, 300].interpolateLinearDegrees(timeOld: time, timeNew: time.with(dtSeconds: 900), scalefactor: 1) == [10.0, 5.0, 0.0, 355.0, 350.0, 358.0, 5.0, 13.0, 20.0, 0.0, 340.0, 320.0, 300.0, 300.0, 300.0, 300.0])
    }

    @Test func linearInterpolateInplace() {
        var a: [Float] = [0, 1, .nan, .nan, .nan, 5]
        a.interpolateInplaceLinear(nTime: 6)
        #expect(a == [0, 1, 2, 3, 4, 5])

        // Make sure nTime is honored correctly
        a = [0, .nan, 1, .nan, .nan, .nan, 0, .nan, 1, .nan, .nan, .nan]
        a.interpolateInplaceLinear(nTime: 6)
        #expect(arraysEqual(Array(a), [0, 0.5, 1, .nan, .nan, .nan, 0, 0.5, 1, .nan, .nan, .nan], accuracy: 0.0001))

        a = [355, .nan, 20, .nan, .nan, .nan, 340, .nan, 20, .nan, .nan, .nan]
        a.interpolateInplaceLinearDegrees(nTime: 6)
        #expect(arraysEqual(Array(a), [355.0, 7.5, 20.0, .nan, .nan, .nan, 340.0, 0.0, 20.0, .nan, .nan, .nan], accuracy: 0.0001))
    }

    @Test func hermiteInterpolateInplace() {
        var a: [Float] = [0, 1, .nan, 3, .nan, 5, .nan, 0]
        a.interpolateInplaceHermite(nTime: 8, bounds: nil)
        #expect(a == [0.0, 1.0, 1.875, 3.0, 4.4375, 5.0, 2.625, 0.0])

        a = [0, 1, .nan, .nan, 3, .nan, .nan, 5, .nan, .nan, 0]
        a.interpolateInplaceHermite(nTime: 11, bounds: nil)
        #expect(arraysEqual(Array(a), [0.0, 1.0, 1.5185186, 2.2592592, 3.0, 3.925926, 4.851852, 5.0, 3.6666665, 1.5555556, 0.0], accuracy: 0.0001))

        a = [0, 1, .nan, .nan, 3, .nan, .nan, 5, .nan, .nan, 0]
        a.interpolateInplaceHermite(nTime: 11, bounds: 1...3)
        // only bound interpolated values!
        #expect(arraysEqual(Array(a), [0.0, 1.0, 1.5185186, 2.2592592, 3.0, 3, 3, 5.0, 3, 1.5555556, 0.0], accuracy: 0.0001))

        // Ensure left boundary is stable
        a = [.nan, 1, .nan, .nan, 3, .nan, .nan, 5, .nan, .nan, 0]
        a.interpolateInplaceHermite(nTime: 11, bounds: nil)
        #expect(arraysEqual(Array(a), [.nan, 1.0, 1.5185186, 2.2592592, 3.0, 3.925926, 4.851852, 5.0, 3.6666665, 1.5555556, 0.0], accuracy: 0.0001))

        // Ensure mixed point spacing works. First 1x NaN, then switch to 2x NaN spacing
        a = [.nan, 1, .nan, 3, .nan, 5, .nan, 0, .nan, .nan, 10, .nan, .nan, 5]
        a.interpolateInplaceHermite(nTime: a.count, bounds: nil)
        #expect(arraysEqual(Array(a), [.nan, 1.0, 1.875, 3.0, 4.4375, 5.0, 0.7013891, 0.0, 2.8194444, 7.2430553, 10.0, 9.259259, 6.8518515, 5.0], accuracy: 0.0001))
    }
    @Test func solarBackwardsInterpolateInplace() {
        var data: [Float] = [.nan, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.3125, 11.9375, 57.484375, 75.203125, 81.625, 56.3125, 69.359375, 100.671875, 320.9375, 400.78125, 373.76562, 246.95312, 53.632812, 29.242188, 2.578125, -0.109375, 0.0, 0.0625, 0.0859375, -0.0859375, 0.0234375, -0.0859375, 0.140625, -0.03125, 0.2421875, 4.2109375, 3.515625, 8.65625, 14.0, 4.015625, 18.257812, 0.3359375, 4.0, 1.90625, 0.796875, 1.09375, 3.59375, 0.578125, -0.046875, 0.140625, 0.1015625, -0.1953125, -0.015625, -0.109375, 0.2890625, -0.0078125, -0.234375, 0.03125, 2.96875, 27.578125, 98.99219, 126.14844, 183.63281, 261.22656, 319.10156, 409.4922, 386.6797, 374.72656, 353.08594, 311.9453, 132.4375, 70.46875, 8.3828125, -0.0703125, 0.0703125, -0.2578125, 0.0546875, -0.1171875, 0.3671875, -0.2421875, -0.203125, 0.515625, .nan, .nan, 15.9765625, .nan, .nan, 175.58594, .nan, .nan, 411.35938, .nan, .nan, 272.71875, .nan, .nan, 40.820312, .nan, .nan, -0.0234375, .nan, .nan, -0.0859375, .nan, .nan, 0.0546875, .nan, .nan, 0.640625, .nan, .nan, 3.078125, .nan, .nan, 0.875, .nan, .nan, 1.484375, .nan, .nan, 0.0078125, .nan, .nan, -0.0546875, .nan, .nan, 0.140625, .nan, .nan, -0.0625, .nan, .nan, 1.9609375, .nan, .nan, 181.02344, .nan, .nan, 152.05469, .nan, .nan, 40.648438, .nan, .nan, 6.5390625, .nan, .nan, -0.0546875, .nan, .nan, -0.015625, .nan, .nan, 0.1875, .nan, .nan, 20.078125, .nan, .nan, 317.53125, .nan, .nan, 381.72656, .nan, .nan, 250.71094, .nan, .nan, 53.742188, .nan, .nan, -0.3359375, .nan, .nan, 0.171875, .nan, .nan, -0.0625, .nan, .nan, 43.609375, .nan, .nan, 191.8125]

        // this location is exactly at a point where sofac is diverging to 0 on the first step to interpolate
        let coords = IconDomains.icon.grid.getCoordinates(gridpoint: 1256 + 2879 * 1132)
        let grid = RegularGrid(nx: 1, ny: 1, latMin: coords.latitude, lonMin: coords.longitude, dx: 1, dy: 1)
        var time = TimerangeDt(start: Timestamp(2022, 08, 16), nTime: data.count, dtSeconds: 3600)
        data.interpolateInplaceSolarBackwards(time: time, grid: grid, locationRange: 0..<1, missingValuesAreBackwardsAveraged: true)

        #expect(arraysEqual(Array(data[79..<181]), [0.5242653, 11.3631, 36.04232, 105.45289, 172.94234, 248.36255, 393.37476, 428.68173, 412.02167, 358.13098, 276.1412, 183.88408, 83.7504, 35.058258, 3.6522849, 0.0, 0.0, 0.0, 0.0, 0.0, -0.0859375, 0.0, 0.0, 0.0, 0.028416535, 0.5703132, 1.4332252, 2.243131, 2.5714521, 2.2492068, 1.4237796, 1.2621424, 1.3974804, 1.5548719, 1.1574203, 0.5988617, 0.14099018, 0.02171057, 0.0007035945, 0.0, 0.0, 0.0, 0.0, 0.0, 0.140625, 0.0, 0.0, 0.0, 0.15952115, 9.313344, 46.61577, 141.27446, 192.4695, 209.3264, 185.65936, 155.43205, 115.072624, 60.684013, 37.91126, 23.35003, 13.552088, 5.593986, 0.47111583, 0.0, 0.0, 0.0, 0.0, 0.0, -0.015625, 0.0, 0.0, 0.0, 0.35458675, 12.772804, 47.106983, 223.67012, 331.3246, 397.59906, 393.4939, 389.53592, 362.14996, 313.48743, 253.43695, 185.20842, 110.19586, 47.431892, 3.5988238, 0.0, 0.0, 0.0, 0.0, 0.0, 0.171875, 0.0, 0.0, 0.0, 1.1841288, 36.25762, 93.38638, 147.84563, 195.33551, 232.25635], accuracy: 0.001))
        // original: [0.5327332, 7.0458064, 30.065294, 68.640236, 125.21594, 208.47006, 287.15527, 362.1674, 409.62054, 381.09317, 313.93628, 221.14587, 134.36256, 58.54249, 9.156854, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.02641212, 0.35874152, 1.2143807, 2.1519227, 3.0996456, 3.658186, 3.2371387, 2.086485, 0.87108666, 0.88595426, 1.1891304, 1.2009717, 0.6598327, 0.18529162, 0.0016845806, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0, 0, 3.7452843, 43.235752, 122.65912, 215.34958, 233.18326, 206.56552, 151.33687, 110.88687, 69.342674, 32.812675, 17.16428, 7.791204, 1.3503972, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.45440406, 7.076116, 38.64731, 112.47823, 234.80026, 378.12024, 429.4058, 423.3296, 379.82858, 336.3908, 276.80637, 201.91202, 130.41829, 62.39851, 10.584465, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.5342923, 24.450073, 84.617775, 142.16772, 190.57127, 228.64375]

        /// Mix 3 and 6 hourly missing values
        data = [.nan, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.3125, 11.9375, 57.484375, 75.203125, 81.625, 56.3125, 69.359375, 100.671875, 320.9375, 400.78125, 373.76562, 246.95312, 53.632812, 29.242188, 2.578125, -0.109375, 0.0, 0.0625, 0.0859375, -0.0859375, 0.0234375, -0.0859375, 0.140625, -0.03125, 0.2421875, 4.2109375, 3.515625, 8.65625, 14.0, 4.015625, 18.257812, 0.3359375, 4.0, 1.90625, 0.796875, 1.09375, 3.59375, 0.578125, -0.046875, 0.140625, 0.1015625, -0.1953125, -0.015625, -0.109375, 0.2890625, -0.0078125, -0.234375, 0.03125, 2.96875, 27.578125, 98.99219, 126.14844, 183.63281, 261.22656, 319.10156, 409.4922, 386.6797, 374.72656, 353.08594, 311.9453, 132.4375, 70.46875, 8.3828125, -0.0703125, 0.0703125, -0.2578125, 0.0546875, -0.1171875, 0.3671875, -0.2421875, -0.203125, 0.515625, .nan, .nan, 15.9765625, .nan, .nan, 175.58594, .nan, .nan, 411.35938, .nan, .nan, 272.71875, .nan, .nan, 40.820312, .nan, .nan, -0.0234375, .nan, .nan, -0.0859375, .nan, .nan, 0.0546875, .nan, .nan, 0.640625, .nan, .nan, 3.078125, .nan, .nan, 0.875, .nan, .nan, 1.484375, .nan, .nan, 0.0078125, .nan, .nan, -0.0546875, .nan, .nan, 0.140625, .nan, .nan, -0.0625, .nan, .nan, 1.9609375, .nan, .nan, 181.02344, .nan, .nan, 152.05469, .nan, .nan, 40.648438, .nan, .nan, 6.5390625, .nan, .nan, -0.0546875, .nan, .nan, .nan, .nan, .nan, (0.1875 - 0.015625) / 2, .nan, .nan, .nan, .nan, .nan, (317.53125 + 20.078125) / 2, .nan, .nan, .nan, .nan, .nan, (250.71094 + 381.72656) / 2, .nan, .nan, .nan, .nan, .nan, (-0.3359375 + 53.742188) / 2, .nan, .nan, .nan, .nan, .nan, (-0.0625 + 0.171875) / 2, .nan, .nan, .nan, .nan, .nan, (191.8125 + 43.609375) / 2]
        data.interpolateInplaceSolarBackwards(time: time, grid: grid, locationRange: 0..<1, missingValuesAreBackwardsAveraged: true)
        #expect(arraysEqual(Array(data[79..<181]), [0.5242653, 11.3631, 36.04232, 105.45289, 172.94234, 248.36255, 393.37476, 428.68173, 412.02167, 358.13098, 276.1412, 183.88408, 83.7504, 35.058258, 3.6522849, 0.0, 0.0, 0.0, 0.0, 0.0, -0.0859375, 0.0, 0.0, 0.0, 0.028416535, 0.5703132, 1.4332252, 2.243131, 2.5714521, 2.2492068, 1.4237796, 1.2621424, 1.3974804, 1.5548719, 1.1574203, 0.5988617, 0.14099018, 0.02171057, 0.0007035945, 0.0, 0.0, 0.0, 0.0, 0.0, 0.140625, 0.0, 0.0, 0.0, 0.15952115, 9.313344, 46.61577, 141.27446, 192.4695, 209.3264, 185.65936, 155.43205, 115.072624, 60.684013, 37.91126, 23.35003, 13.552088, 5.593986, 0.47111583, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 2.0626147, 53.642685, 135.03218, 212.64182, 279.32706, 330.12177, 370.54282, 378.04684, 361.5002, 322.95676, 266.48816, 197.77786, 109.71282, 47.002304, 3.5036254, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.1777052, 36.088646, 93.07037, 147.87181, 195.52072, 232.53633], accuracy: 0.001))

        /// Immediately 3 hourly data. Note: the left-most values only rely on the clearness index of the first point
        data = [.nan, .nan, .nan, 320.9375, .nan, .nan, 246.95312, .nan, .nan, 2.578125, .nan, .nan, 0.0, .nan, .nan, 0.0]
        time = TimerangeDt(start: Timestamp(2022, 08, 16, 12), nTime: data.count, dtSeconds: 3600)
        data.interpolateInplaceSolarBackwards(time: time, grid: grid, locationRange: 0..<1, missingValuesAreBackwardsAveraged: true)
        #expect(arraysEqual(Array(data), [.nan, 316.5745, 327.14203, 319.096, 355.45486, 253.89552, 131.50894, 33.647484, 6.0189605, 0.35008436, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0], accuracy: 0.001))

        /// Assuming the value afterwards is not averaged correctly
        data = [.nan, .nan, .nan, 304.3659, .nan, .nan, 101.99449, .nan, .nan, 0.0, .nan, .nan, 0.0, .nan, .nan, 0.0]
        time = TimerangeDt(start: Timestamp(2022, 08, 16, 12), nTime: data.count, dtSeconds: 3600)
        data.interpolateInplaceSolarBackwards(time: time, grid: grid, locationRange: 0..<1, missingValuesAreBackwardsAveraged: false)
        #expect(arraysEqual(Array(data), [.nan, 293.12817, 279.38104, 304.3659, 142.60036, 101.0161, 101.99449, 69.3253, 34.452053, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0], accuracy: 0.001))

        data = [321.95593, .nan, 247.148]
        time = TimerangeDt(start: Timestamp(2022, 08, 16, 14), nTime: data.count, dtSeconds: 3600)
        data.interpolateInplaceSolarBackwards(time: time, grid: grid, locationRange: 0..<1, missingValuesAreBackwardsAveraged: false)
        #expect(arraysEqual(Array(data), [321.95593, 268.21445, 247.148], accuracy: 0.001))

        data = [321.95593, .nan]
        time = TimerangeDt(start: Timestamp(2022, 08, 16, 14), nTime: data.count, dtSeconds: 3600)
        data.interpolateInplaceSolarBackwards(time: time, grid: grid, locationRange: 0..<1, missingValuesAreBackwardsAveraged: false)
        #expect(arraysEqual(Array(data), [321.95593, .nan], accuracy: 0.001))
    }
    
    @Test func solarBackwardsInterpolateInplaceEcmwf() {
        let nan = Float.nan
        var ghi: [Float] = [nan, 0.0, 0.0, 0.0, 0.0, 0.0, 2.0, 88.0, 266.0, 439.0, 571.0, 644.0, 653.0, 596.0, 479.0, 312.0, 128.0, 10.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 2.0, 89.0, 270.0, 444.0, 575.0, 649.0, 657.0, 598.0, 478.0, 313.0, 130.0, 10.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 2.0, 88.0, 266.0, 438.0, 570.0, 643.0, 652.0, 593.0, 471.0, 310.0, 128.0, 10.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 2.0, 89.0, 267.0, 442.0, 572.0, 645.0, 653.0, 594.0, 477.0, 313.0, 130.0, 10.0, 0.0, nan, nan, 0.0, nan, nan, 0.0, nan, nan, 0.0, nan, nan, 1.0, nan, nan, 275.0, nan, nan, 643.0, nan, nan, 479.0, nan, nan, 50.0, nan, nan, 0.0, nan, nan, 0.0, nan, nan, 0.0, nan, nan, 1.0, nan, nan, 279.0, nan, nan, 640.0, nan, nan, 474.0, nan, nan, 49.0, nan, nan, 0.0, nan, nan, 0.0, nan, nan, nan, nan, nan, 0.0, nan, nan, nan, nan, nan, 445.0, nan, nan, nan, nan, nan, 256.0, nan, nan, nan, nan, nan, 0.0, nan, nan, nan, nan, nan, 0.0, nan, nan, nan, nan, nan, 445.0, nan, nan, nan, nan, nan, 257.0, nan, nan, nan, nan, nan, 0.0, nan, nan, nan, nan, nan, 0.0, nan, nan, nan, nan, nan, 444.0, nan, nan, nan, nan, nan, 256.0, nan, nan, nan, nan, nan, 0.0, nan, nan, nan, nan, nan, 0.0, nan, nan, nan, nan, nan, 450.0, nan, nan, nan, nan, nan, 259.0, nan, nan, nan, nan, nan, 0.0, nan, nan, nan, nan, nan, 0.0, nan, nan, nan, nan, nan, 455.0, nan, nan, nan, nan, nan, 262.0, nan, nan, nan, nan, nan, 0.0, nan, nan, nan, nan, nan, 1.0, nan, nan, nan, nan, nan, 458.0, nan, nan, nan, nan, nan, 263.0, nan, nan, nan, nan, nan, 0.0, nan, nan, nan, nan, nan, 1.0, nan, nan, nan, nan, nan, 460.0, nan, nan, nan, nan, nan, 264.0, nan, nan, nan, nan, nan, 0.0, nan, nan, nan, nan, nan, 1.0, nan, nan, nan, nan, nan, 463.0, nan, nan, nan, nan, nan, 266.0, nan, nan, nan, nan, nan, 0.0, nan, nan, nan, nan, nan, 1.0, nan, nan, nan, nan, nan, 466.0, nan, nan, nan, nan, nan, 269.0, nan, nan, nan, nan, nan, 0.0]
        
        let grid = RegularGrid(nx: 1, ny: 1, latMin: -21.898067, lonMin: 14.707091, dx: 1, dy: 1)
        let time = TimerangeDt(start: Timestamp(2026, 07, 19), nTime: ghi.count, dtSeconds: 3600)
        ghi.interpolateInplaceSolarBackwards(time: time, grid: grid, locationRange: 0..<1, missingValuesAreBackwardsAveraged: true)

        #expect(arraysEqual(ghi, [.nan, 0.0, 0.0, 0.0, 0.0, 0.0, 2.0, 88.0, 266.0, 439.0, 571.0, 644.0, 653.0, 596.0, 479.0, 312.0, 128.0, 10.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 2.0, 89.0, 270.0, 444.0, 575.0, 649.0, 657.0, 598.0, 478.0, 313.0, 130.0, 10.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 2.0, 88.0, 266.0, 438.0, 570.0, 643.0, 652.0, 593.0, 471.0, 310.0, 128.0, 10.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 2.0, 89.0, 267.0, 442.0, 572.0, 645.0, 653.0, 594.0, 477.0, 313.0, 130.0, 10.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 2.641379, 109.56815, 279.87936, 435.55246, 593.7506, 665.67957, 669.5698, 617.2214, 492.5633, 327.2153, 137.43695, 12.563041, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 2.8402357, 112.39737, 284.54718, 440.05542, 593.10846, 662.3902, 664.50146, 612.3244, 487.18802, 322.48755, 134.45522, 12.544794, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 3.129067, 121.87054, 301.04474, 451.11264, 558.8752, 616.5909, 620.5059, 562.19696, 466.12115, 329.25638, 162.26038, 16.165117, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 3.3304904, 122.743225, 301.3122, 450.90485, 558.44214, 616.20123, 620.3964, 563.37103, 467.51196, 330.738, 163.68677, 16.692173, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 3.5406032, 123.54953, 301.27374, 450.04324, 556.8913, 614.1509, 618.09125, 560.5414, 465.25235, 329.454, 163.67702, 17.075235, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 3.8264966, 126.35962, 306.01807, 456.2859, 564.1062, 621.74896, 625.48126, 566.4757, 470.2595, 333.31143, 166.22026, 17.733082, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 4.1282215, 128.8829, 309.97015, 461.36993, 569.9852, 628.0339, 631.7577, 572.24084, 475.26202, 337.24487, 168.83755, 18.414743, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 4.435652, 131.00156, 312.7977, 464.63968, 573.42773, 631.3741, 634.7589, 573.85736, 476.6256, 338.48962, 170.07343, 18.953857, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 4.756657, 132.8111, 314.82162, 466.7502, 575.5416, 633.4141, 636.66144, 575.3185, 477.9924, 339.80908, 171.37132, 19.50855, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 5.1123524, 134.90218, 317.4448, 469.76797, 578.8468, 636.8835, 640.1546, 578.8413, 481.17032, 342.47073, 173.3655, 20.152124, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 5.4942536, 136.9132, 319.84033, 472.53635, 582.034, 640.5088, 644.1672, 584.263, 486.15778, 346.55072, 176.12885, 20.899605, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0], accuracy: 0.001))
    }

    @Test func rangeFraction() {
        #expect((100..<1000).interpolated(atFraction: 0.5) == 550)
        #expect((100..<1000).interpolated(atFraction: 0) == 100)
        #expect((100..<1000).interpolated(atFraction: 1) == 1000)
        #expect((100..<1000).interpolated(atFraction: -0.1) == 100)
        #expect((100..<1000).interpolated(atFraction: 1.1) == 1000)

        #expect((100..<1000).fraction(of: 550) == 0.5)
        #expect((100..<1000).fraction(of: 100) == 0)
        #expect((100..<1000).fraction(of: 1000) == 1)
        #expect((100..<1000).fraction(of: 90) == 0)
        #expect((100..<1000).fraction(of: 1010) == 1)
    }

    @Test func deaverage() {
        var data = Array2DFastTime(data: [1, 2, 3, 1, 2, 3], nLocations: 2, nTime: 3)
        data.deavergeOverTime()
        #expect(data.data == [1.0, 3.0, 5.0, 1.0, 3.0, 5.0])

        data = Array2DFastTime(data: [.nan, 2, 3, .nan, 2, 3], nLocations: 2, nTime: 3)
        data.deavergeOverTime()
        #expect(arraysEqual(Array(data.data), [.nan, 2.0, 4.0, .nan, 2.0, 4.0], accuracy: 0.001))

        data = Array2DFastTime(data: [.nan, .nan, 2, 3, .nan, .nan, 2, 3], nLocations: 2, nTime: 4)
        data.deavergeOverTime()
        #expect(arraysEqual(Array(data.data), [.nan, .nan, 2.0, 4.0, .nan, .nan, 2.0, 4.0], accuracy: 0.001))

        data = Array2DFastTime(data: [1, 2, .nan, 3.25, 1, 2, .nan, 3.25], nLocations: 2, nTime: 4)
        data.deavergeOverTime()
        #expect(arraysEqual(Array(data.data), [1.0, 3.0, .nan, 4.5, 1.0, 3.0, .nan, 4.5], accuracy: 0.001))

        data = Array2DFastTime(data: [1, 2, 3.25, 3.25, 1, 2, 3.25, 3.25], nLocations: 2, nTime: 4)
        data.deavergeOverTime()
        #expect(arraysEqual(Array(data.data), [1.0, 3.0, 5.75, 3.25, 1.0, 3.0, 5.75, 3.25], accuracy: 0.001))

        data = Array2DFastTime(data: [10, 10, .nan, 10, 10, 10, .nan, 10], nLocations: 2, nTime: 4)
        data.deavergeOverTime()
        #expect(arraysEqual(Array(data.data), [10.0, 10.0, .nan, 10.0, 10.0, 10.0, .nan, 10.0], accuracy: 0.001))
    }

    @Test func deaccumulate() {
        var data = Array2DFastTime(data: [1, 2, 3, 1, 2, 3], nLocations: 2, nTime: 3)
        data.deaccumulateOverTime()
        #expect(data.data == [1, 1, 1, 1, 1, 1])

        var data2 = Array2DFastTime(data: [.nan, 1, 2, 1, 2, 3], nLocations: 2, nTime: 3)
        data2.deaccumulateOverTime()
        #expect(data2.data[0].isNaN)
        #expect(data2.data[1..<6] == [1, 1, 1, 1, 1])

        var data4 = Array2DFastTime(data: [.nan, 1, 2, 3, 3.1, 3.3, 3.9], nLocations: 1, nTime: 7)
        data4.deaccumulateOverTime()
        #expect(data4.data[0].isNaN)
        #expect(arraysEqual(Array(data4.data[1..<7]), [1.0, 1.0, 1.0, 0.1, 0.2, 0.6], accuracy: 0.001))

        // Allow one missing value to be ignored
        var data5 = Array2DFastTime(data: [5, .nan, 9, 5, .nan, 9], nLocations: 2, nTime: 3)
        data5.deaccumulateOverTime()
        #expect(arraysEqual(Array(data5.data), [5, .nan, 2, 5, .nan, 2], accuracy: 0.001))
    }

    @Test func solfactorBackwards() {
        let time = TimerangeDt(start: Timestamp(2022, 08, 17), nTime: 48, dtSeconds: 3600)
        let grid = RegularGrid(nx: 1, ny: 1, latMin: 47, lonMin: 4.5, dx: 1, dy: 1)
        /*let solfac = Zensun.calculateRadiationBackwardsSubsampled(grid: grid, timerange: time, steps: 120).data
        #expect(solfac == [0.0, 0.0, 0.0, 0.0, 0.0, 0.0038180633, 0.1195483, 0.2877683, 0.44766656, 0.5883302, 0.70015657, 0.77550805, 0.8092315, 0.7990114, 0.7455277, 0.65240955, 0.52598935, 0.37486944, 0.20933856, 0.04605455, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0031137501, 0.11629447, 0.2847902, 0.4449114, 0.5857303, 0.6976339, 0.772979, 0.8066118, 0.7962221, 0.7424943, 0.6490812, 0.52233285, 0.37087443, 0.20501684, 0.042716768, 0.0, 0.0, 0.0, 0.0])*/

        let solfac2 = Zensun.calculateRadiationBackwardsAveraged(grid: grid, locationRange: 0..<1, timerange: time).data
        #expect(arraysEqual(solfac2, [0.0, 0.0, 0.0, 0.0, 0.0, 0.0039792103, 0.12013578, 0.2881744, 0.44786763, 0.58831614, 0.6999318, 0.77508986, 0.8086508, 0.79830927, 0.74475336, 0.65161735, 0.52523357, 0.37420243, 0.20880632, 0.04575032, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0032499183, 0.11683395, 0.2851496, 0.44506305, 0.58565885, 0.69734, 0.7724759, 0.8059283, 0.79540026, 0.74159133, 0.64815325, 0.5214387, 0.37007153, 0.20435601, 0.042335168, 0.0, 0.0, 0.0, 0.0]))

        // print(zip(solfac,solfac2).map(-))
    }
    
    @Test func integrateIfNaN() {
        var a: [Float] = [0,1,2,3,4,5,6,.nan,.nan,.nan]
        a.integrateIfNaN([.nan,.nan,0,0,0,0,0,7,8,9])
        #expect(a == [0,1,2,3,4,5,6,7,8,9])
        
        a = [0,0,0,0,.nan,.nan,.nan,.nan,.nan]
        a.integrateIfNaN([.nan,.nan,0,0,2,2,2,2,2])
        #expect(a == [0,0,0,0,2,2,2,2,2])
        
        a = [0,0,0,0,0,.nan,.nan,.nan,.nan]
        a.integrateIfNaNSmooth([3,3,3,3,3,3,3,3,3])
        #expect(a == [0,0,0.75,1.5,2.25,3,3,3,3])
    }
}

/// Predicate for comparing two arrays of Float with accuracy, handling NaN.
func arraysEqual<T: Collection>(_ a: T, _ b: T, accuracy: Float = 0.0001) -> Bool where T.Element == Float, T: Equatable  {
    guard a.count == b.count else {
        Issue.record("Array length different: \(a.count) vs \(b.count)")
        return false
    }
    var failed = false
    for (a1, b1) in zip(a, b) {
        if a1.isNaN && b1.isNaN { continue }
        if a1.isNaN || b1.isNaN || abs(a1 - b1) > accuracy {
            failed = true
            break
        }
    }
    if failed {
        Issue.record("Arrays differ (accuracy \(accuracy))")

        for (a1, b1) in zip(a, b) {
            if a1.isNaN && b1.isNaN { continue }
            if a1.isNaN || b1.isNaN || abs(a1 - b1) > accuracy {
                Issue.record("Array element mismatch: \(a1) vs \(b1)")
            }
        }
        return false
    }
    return true
}
