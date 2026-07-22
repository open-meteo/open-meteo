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

        #expect(arraysEqual(Array(data[79..<181]), [0.8053542, 13.953969, 33.170364, 136.3478, 178.71373, 211.69629, 405.2331, 419.32886, 409.51614, 324.1688, 277.6556, 216.33188, 80.39204, 37.940945, 4.127945, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.028199535, 0.55328256, 1.340393, 2.385557, 3.1334403, 3.7153778, 0.8620944, 0.89206165, 0.8708439, 1.7673343, 1.5114607, 1.17433, 0.015540478, 0.007193428, 0.0007035945, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.07449099, 1.6732771, 4.135044, 140.01247, 184.30556, 218.7523, 149.83507, 155.03905, 151.28996, 48.47956, 41.396168, 32.069576, 13.1401415, 5.9582195, 0.51882625, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.6493625, 16.912052, 42.672966, 245.09239, 323.34058, 384.16074, 376.21518, 389.26843, 379.69592, 299.53546, 255.3609, 197.23643, 109.11354, 48.402714, 3.710316, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.1821455, 36.224712, 93.42127, 147.74565, 195.3539, 232.33792], accuracy: 0.001))
        // original: [0.5327332, 7.0458064, 30.065294, 68.640236, 125.21594, 208.47006, 287.15527, 362.1674, 409.62054, 381.09317, 313.93628, 221.14587, 134.36256, 58.54249, 9.156854, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.02641212, 0.35874152, 1.2143807, 2.1519227, 3.0996456, 3.658186, 3.2371387, 2.086485, 0.87108666, 0.88595426, 1.1891304, 1.2009717, 0.6598327, 0.18529162, 0.0016845806, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0, 0, 3.7452843, 43.235752, 122.65912, 215.34958, 233.18326, 206.56552, 151.33687, 110.88687, 69.342674, 32.812675, 17.16428, 7.791204, 1.3503972, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.45440406, 7.076116, 38.64731, 112.47823, 234.80026, 378.12024, 429.4058, 423.3296, 379.82858, 336.3908, 276.80637, 201.91202, 130.41829, 62.39851, 10.584465, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.5342923, 24.450073, 84.617775, 142.16772, 190.57127, 228.64375]

        /// Mix 3 and 6 hourly missing values
        data = [.nan, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.3125, 11.9375, 57.484375, 75.203125, 81.625, 56.3125, 69.359375, 100.671875, 320.9375, 400.78125, 373.76562, 246.95312, 53.632812, 29.242188, 2.578125, -0.109375, 0.0, 0.0625, 0.0859375, -0.0859375, 0.0234375, -0.0859375, 0.140625, -0.03125, 0.2421875, 4.2109375, 3.515625, 8.65625, 14.0, 4.015625, 18.257812, 0.3359375, 4.0, 1.90625, 0.796875, 1.09375, 3.59375, 0.578125, -0.046875, 0.140625, 0.1015625, -0.1953125, -0.015625, -0.109375, 0.2890625, -0.0078125, -0.234375, 0.03125, 2.96875, 27.578125, 98.99219, 126.14844, 183.63281, 261.22656, 319.10156, 409.4922, 386.6797, 374.72656, 353.08594, 311.9453, 132.4375, 70.46875, 8.3828125, -0.0703125, 0.0703125, -0.2578125, 0.0546875, -0.1171875, 0.3671875, -0.2421875, -0.203125, 0.515625, .nan, .nan, 15.9765625, .nan, .nan, 175.58594, .nan, .nan, 411.35938, .nan, .nan, 272.71875, .nan, .nan, 40.820312, .nan, .nan, -0.0234375, .nan, .nan, -0.0859375, .nan, .nan, 0.0546875, .nan, .nan, 0.640625, .nan, .nan, 3.078125, .nan, .nan, 0.875, .nan, .nan, 1.484375, .nan, .nan, 0.0078125, .nan, .nan, -0.0546875, .nan, .nan, 0.140625, .nan, .nan, -0.0625, .nan, .nan, 1.9609375, .nan, .nan, 181.02344, .nan, .nan, 152.05469, .nan, .nan, 40.648438, .nan, .nan, 6.5390625, .nan, .nan, -0.0546875, .nan, .nan, .nan, .nan, .nan, (0.1875 - 0.015625) / 2, .nan, .nan, .nan, .nan, .nan, (317.53125 + 20.078125) / 2, .nan, .nan, .nan, .nan, .nan, (250.71094 + 381.72656) / 2, .nan, .nan, .nan, .nan, .nan, (-0.3359375 + 53.742188) / 2, .nan, .nan, .nan, .nan, .nan, (-0.0625 + 0.171875) / 2, .nan, .nan, .nan, .nan, .nan, (191.8125 + 43.609375) / 2]
        data.interpolateInplaceSolarBackwards(time: time, grid: grid, locationRange: 0..<1, missingValuesAreBackwardsAveraged: true)
        #expect(arraysEqual(Array(data[79..<181]), [0.8053542, 13.953969, 33.170364, 136.3478, 178.71373, 211.69629, 405.2331, 419.32886, 409.51614, 324.1688, 277.6556, 216.33188, 80.39204, 37.940945, 4.127945, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.028199535, 0.55328256, 1.340393, 2.385557, 3.1334403, 3.7153778, 0.8620944, 0.89206165, 0.8708439, 1.7673343, 1.5114607, 1.17433, 0.015540478, 0.007193428, 0.0007035945, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.07449099, 1.6732771, 4.135044, 140.01247, 184.30556, 218.7523, 149.83507, 155.03905, 151.28996, 48.47956, 41.396168, 32.069576, 13.1401415, 5.9582195, 0.51882625, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 2.0407073, 53.14835, 134.10541, 211.8866, 279.53348, 332.11356, 353.4735, 365.7377, 356.74384, 327.104, 278.86374, 215.38962, 108.43148, 48.10015, 3.687123, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.1777052, 36.08865, 93.07037, 147.87181, 195.52072, 232.53633], accuracy: 0.001))

        /// Immediately 3 hourly data. Note: the left-most values only rely on the clearness index of the first point
        data = [.nan, .nan, .nan, 320.9375, .nan, .nan, 246.95312, .nan, .nan, 2.578125, .nan, .nan, 0.0, .nan, .nan, 0.0]
        time = TimerangeDt(start: Timestamp(2022, 08, 16, 12), nTime: data.count, dtSeconds: 3600)
        data.interpolateInplaceSolarBackwards(time: time, grid: grid, locationRange: 0..<1, missingValuesAreBackwardsAveraged: true)
        #expect(arraysEqual(Array(data), [.nan, 316.0364, 327.0396, 319.73636, 292.1722, 251.32156, 197.36557, 4.932851, 2.45144, 0.35008436, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0], accuracy: 0.001))

        /// Assuming the value afterwards is not averaged correctly
        data = [.nan, .nan, .nan, 304.3659, .nan, .nan, 101.99449, .nan, .nan, 0.0, .nan, .nan, 0.0, .nan, .nan, 0.0]
        time = TimerangeDt(start: Timestamp(2022, 08, 16, 12), nTime: data.count, dtSeconds: 3600)
        data.interpolateInplaceSolarBackwards(time: time, grid: grid, locationRange: 0..<1, missingValuesAreBackwardsAveraged: false)
        #expect(arraysEqual(Array(data), [.nan, 300.8438, 311.31808, 304.3659, 150.98862, 129.87785, 101.99449, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0], accuracy: 0.001))

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

        #expect(arraysEqual(ghi, [.nan, 0.0, 0.0, 0.0, 0.0, 0.0, 2.0, 88.0, 266.0, 439.0, 571.0, 644.0, 653.0, 596.0, 479.0, 312.0, 128.0, 10.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 2.0, 89.0, 270.0, 444.0, 575.0, 649.0, 657.0, 598.0, 478.0, 313.0, 130.0, 10.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 2.0, 88.0, 266.0, 438.0, 570.0, 643.0, 652.0, 593.0, 471.0, 310.0, 128.0, 10.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 2.0, 89.0, 267.0, 442.0, 572.0, 645.0, 653.0, 594.0, 477.0, 313.0, 130.0, 10.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 113.4106, 283.92728, 427.66217, 597.38226, 662.0409, 669.57684, 593.89386, 493.93085, 349.17523, 136.96745, 13.032542, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 115.733215, 288.03485, 433.232, 594.6803, 658.90936, 666.41046, 587.34534, 488.7334, 345.9213, 133.94763, 13.052369, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 120.86013, 298.94937, 448.9765, 557.9791, 618.1032, 625.13165, 559.9777, 466.19412, 330.36655, 163.18219, 16.279432, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 121.82374, 299.41772, 448.9773, 557.6361, 617.56964, 624.5753, 561.3607, 467.57504, 331.74155, 164.52411, 16.798477, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 122.55372, 299.2358, 447.97403, 556.0289, 615.6245, 622.5832, 558.38086, 465.31702, 330.53033, 164.57942, 17.192474, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 125.26804, 303.7995, 454.03812, 563.17267, 623.3548, 630.367, 564.1263, 470.32635, 334.47946, 167.20424, 17.863855, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 127.769356, 307.72296, 459.0982, 569.04517, 629.6622, 636.70215, 569.8609, 475.32632, 338.42548, 169.83685, 18.550552, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 129.76706, 310.32455, 462.1452, 572.3994, 633.16815, 640.1956, 571.24243, 476.69254, 339.78412, 171.17422, 19.106777, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 131.53069, 312.27536, 464.1881, 574.4896, 635.2632, 642.25323, 572.62805, 478.05743, 341.13818, 172.50674, 19.66971, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 133.62857, 314.9311, 467.24478, 577.815, 638.71106, 645.66943, 576.1849, 481.23077, 343.78015, 174.4892, 20.315025, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 135.77632, 317.6136, 470.30676, 581.1262, 642.1298, 649.0474, 581.9053, 486.20816, 347.71042, 177.12851, 21.047543, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0], accuracy: 0.001))
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
