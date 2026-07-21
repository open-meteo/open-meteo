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

        #expect(arraysEqual(Array(data[79..<181]), [0.028364176, 13.041756, 34.859566, 134.21664, 178.85152, 213.6897, 404.96976, 419.67096, 409.43738, 326.924, 277.87677, 213.35542, 84.955376, 36.644356, 0.8612166, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0006319527, 0.5141044, 1.4071387, 2.347784, 3.135881, 3.750709, 0.86153764, 0.89279646, 0.87066567, 1.7825711, 1.5126762, 1.1578774, 0.016408836, 0.006912922, 0.00011574036, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0009761292, 1.5452754, 4.336561, 137.7664, 184.45068, 220.85323, 149.73898, 155.16806, 151.25703, 48.903625, 41.429802, 31.611887, 13.85926, 5.693711, 0.0642173, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0044760797, 15.517791, 44.7121, 241.10808, 323.59793, 387.8877, 375.97583, 389.59573, 379.60815, 302.19467, 255.57039, 194.36775, 114.93618, 45.964626, 0.3257541, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.003744676, 33.01374, 97.81064, 145.3113, 195.51114, 234.61507], accuracy: 0.001))
        // original: [0.5327332, 7.0458064, 30.065294, 68.640236, 125.21594, 208.47006, 287.15527, 362.1674, 409.62054, 381.09317, 313.93628, 221.14587, 134.36256, 58.54249, 9.156854, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.02641212, 0.35874152, 1.2143807, 2.1519227, 3.0996456, 3.658186, 3.2371387, 2.086485, 0.87108666, 0.88595426, 1.1891304, 1.2009717, 0.6598327, 0.18529162, 0.0016845806, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0, 0, 3.7452843, 43.235752, 122.65912, 215.34958, 233.18326, 206.56552, 151.33687, 110.88687, 69.342674, 32.812675, 17.16428, 7.791204, 1.3503972, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.45440406, 7.076116, 38.64731, 112.47823, 234.80026, 378.12024, 429.4058, 423.3296, 379.82858, 336.3908, 276.80637, 201.91202, 130.41829, 62.39851, 10.584465, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.5342923, 24.450073, 84.617775, 142.16772, 190.57127, 228.64375]

        /// Mix 3 and 6 hourly missing values
        data = [.nan, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.3125, 11.9375, 57.484375, 75.203125, 81.625, 56.3125, 69.359375, 100.671875, 320.9375, 400.78125, 373.76562, 246.95312, 53.632812, 29.242188, 2.578125, -0.109375, 0.0, 0.0625, 0.0859375, -0.0859375, 0.0234375, -0.0859375, 0.140625, -0.03125, 0.2421875, 4.2109375, 3.515625, 8.65625, 14.0, 4.015625, 18.257812, 0.3359375, 4.0, 1.90625, 0.796875, 1.09375, 3.59375, 0.578125, -0.046875, 0.140625, 0.1015625, -0.1953125, -0.015625, -0.109375, 0.2890625, -0.0078125, -0.234375, 0.03125, 2.96875, 27.578125, 98.99219, 126.14844, 183.63281, 261.22656, 319.10156, 409.4922, 386.6797, 374.72656, 353.08594, 311.9453, 132.4375, 70.46875, 8.3828125, -0.0703125, 0.0703125, -0.2578125, 0.0546875, -0.1171875, 0.3671875, -0.2421875, -0.203125, 0.515625, .nan, .nan, 15.9765625, .nan, .nan, 175.58594, .nan, .nan, 411.35938, .nan, .nan, 272.71875, .nan, .nan, 40.820312, .nan, .nan, -0.0234375, .nan, .nan, -0.0859375, .nan, .nan, 0.0546875, .nan, .nan, 0.640625, .nan, .nan, 3.078125, .nan, .nan, 0.875, .nan, .nan, 1.484375, .nan, .nan, 0.0078125, .nan, .nan, -0.0546875, .nan, .nan, 0.140625, .nan, .nan, -0.0625, .nan, .nan, 1.9609375, .nan, .nan, 181.02344, .nan, .nan, 152.05469, .nan, .nan, 40.648438, .nan, .nan, 6.5390625, .nan, .nan, -0.0546875, .nan, .nan, .nan, .nan, .nan, (0.1875 - 0.015625) / 2, .nan, .nan, .nan, .nan, .nan, (317.53125 + 20.078125) / 2, .nan, .nan, .nan, .nan, .nan, (250.71094 + 381.72656) / 2, .nan, .nan, .nan, .nan, .nan, (-0.3359375 + 53.742188) / 2, .nan, .nan, .nan, .nan, .nan, (-0.0625 + 0.171875) / 2, .nan, .nan, .nan, .nan, .nan, (191.8125 + 43.609375) / 2]
        data.interpolateInplaceSolarBackwards(time: time, grid: grid, locationRange: 0..<1, missingValuesAreBackwardsAveraged: true)
        #expect(arraysEqual(Array(data[79..<181]), [0.028364176, 13.041756, 34.859566, 134.21664, 178.85152, 213.6897, 404.96976, 419.67096, 409.43738, 326.924, 277.87677, 213.35542, 84.955376, 36.644356, 0.8612166, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0006319527, 0.5141044, 1.4071387, 2.347784, 3.135881, 3.750709, 0.86153764, 0.89279646, 0.87066567, 1.7825711, 1.5126762, 1.1578774, 0.016408836, 0.006912922, 0.00011574036, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0009761292, 1.5452754, 4.336561, 137.7664, 184.45068, 220.85323, 149.73898, 155.16806, 151.25703, 48.903625, 41.429802, 31.611887, 13.85926, 5.693711, 0.0642173, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.012945863, 44.881058, 129.3178, 212.2596, 284.87958, 341.47708, 355.23352, 368.10202, 358.66547, 327.57886, 277.03818, 210.69453, 114.21773, 45.677307, 0.32371783, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.003431897, 30.256226, 89.64088, 148.07076, 199.2239, 239.0704], accuracy: 0.001))

        /// Immediately 3 hourly data. Note: the left-most values only rely on the clearness index of the first point
        data = [.nan, .nan, .nan, 320.9375, .nan, .nan, 246.95312, .nan, .nan, 2.578125, .nan, .nan, 0.0, .nan, .nan, 0.0]
        time = TimerangeDt(start: Timestamp(2022, 08, 16, 12), nTime: data.count, dtSeconds: 3600)
        data.interpolateInplaceSolarBackwards(time: time, grid: grid, locationRange: 0..<1, missingValuesAreBackwardsAveraged: true)
        #expect(arraysEqual(Array(data), [.nan, 315.8279, 327.29907, 319.68552, 294.5562, 251.5163, 194.78679, 5.21726, 2.3948448, 0.12226979, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0], accuracy: 0.001))

        /// Assuming the value afterwards is not averaged correctly
        data = [.nan, .nan, .nan, 304.3659, .nan, .nan, 101.99449, .nan, .nan, 0.0, .nan, .nan, 0.0, .nan, .nan, 0.0]
        time = TimerangeDt(start: Timestamp(2022, 08, 16, 12), nTime: data.count, dtSeconds: 3600)
        data.interpolateInplaceSolarBackwards(time: time, grid: grid, locationRange: 0..<1, missingValuesAreBackwardsAveraged: false)
        #expect(arraysEqual(Array(data), [.nan, 300.69318, 311.61465, 304.3659, 154.23589, 131.69928, 101.99449, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0], accuracy: 0.001))

        data = [321.95593, .nan, 247.148]
        time = TimerangeDt(start: Timestamp(2022, 08, 16, 14), nTime: data.count, dtSeconds: 3600)
        data.interpolateInplaceSolarBackwards(time: time, grid: grid, locationRange: 0..<1, missingValuesAreBackwardsAveraged: false)
        #expect(arraysEqual(Array(data), [321.95593, 269.18484, 247.148], accuracy: 0.001))

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

        #expect(arraysEqual(ghi, [.nan, 0.0, 0.0, 0.0, 0.0, 0.0, 2.0, 88.0, 266.0, 439.0, 571.0, 644.0, 653.0, 596.0, 479.0, 312.0, 128.0, 10.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 2.0, 89.0, 270.0, 444.0, 575.0, 649.0, 657.0, 598.0, 478.0, 313.0, 130.0, 10.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 2.0, 88.0, 266.0, 438.0, 570.0, 643.0, 652.0, 593.0, 471.0, 310.0, 128.0, 10.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 2.0, 89.0, 267.0, 442.0, 572.0, 645.0, 653.0, 594.0, 477.0, 313.0, 130.0, 10.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 101.103004, 283.7885, 440.1085, 595.25415, 662.9273, 670.8186, 600.52075, 494.6472, 341.8321, 147.38557, 2.6144283, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 103.34687, 287.9028, 445.75034, 592.57355, 659.78656, 667.63995, 593.8569, 489.4387, 338.70444, 144.23636, 2.763633, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 104.95462, 290.09595, 448.3669, 563.8451, 627.6381, 635.0993, 576.45105, 475.36105, 329.419, 151.63689, 3.1318693, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 106.0041, 290.62985, 448.37927, 563.4668, 627.0424, 634.47766, 577.8758, 476.8005, 330.87018, 153.05313, 3.400683, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 106.857346, 290.53503, 447.38937, 561.81055, 625.0122, 632.3956, 574.8059, 474.52576, 329.741, 153.2716, 3.65577, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 109.45149, 295.0519, 453.458, 568.9951, 632.8026, 640.2409, 580.7154, 479.66058, 333.75797, 155.88306, 3.9830585, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 111.872185, 298.951, 458.52524, 574.8939, 639.1457, 646.61176, 586.6114, 484.78336, 337.77115, 158.50462, 4.3295054, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 113.86286, 301.57016, 461.58206, 578.2475, 642.6434, 650.09406, 588.0227, 486.19836, 339.2014, 159.91762, 4.659879, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 115.657906, 303.5597, 463.6367, 580.32306, 644.7067, 652.1157, 589.43555, 487.6093, 340.62476, 161.3257, 5.0046334, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 117.75562, 306.2378, 466.70483, 583.6455, 648.14136, 655.51483, 593.0804, 490.86206, 343.3329, 163.34111, 5.3835177, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 119.906456, 308.94485, 469.7788, 586.9526, 651.5446, 658.8727, 598.9491, 495.9527, 347.32602, 165.97234, 5.7999253, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0], accuracy: 0.001))
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
