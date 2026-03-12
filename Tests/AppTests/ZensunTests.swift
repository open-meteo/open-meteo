import Foundation
@testable import App
import Testing

@Suite struct ZensunTests {
    @Test func isDaylightTime() {
        let time = TimerangeDt(start: Timestamp(2023, 04, 06), nTime: 48, dtSeconds: 3600)
        let isDay = Zensun.calculateIsDay(timeRange: time, lat: 52.52, lon: 13.42)
        #expect(isDay == [0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
    }

    @Test func sunRiseSetLosAngeles() {
        // https://www.timeanddate.com/sun/usa/los-angeles?month=11&year=2021
        let utcOffsetSeconds = -25200
       // let currentTime = Timestamp(1636199223) // UTC 2021-11-06T11:47:03+00:00
        let time = Timestamp(1636182000) ..< Timestamp(1636268400)

        // vancouver: lat: 49.25, lon: -123.12
        let times = Zensun.calculateSunRiseSet(timeRange: time, lat: 34.05223, lon: -118.24368, utcOffsetSeconds: utcOffsetSeconds)
        #expect(times.rise[0] == Timestamp(1636208261))
        #expect(times.set[0] == Timestamp(1636246534))
        let sunset = times.set.map({ $0.add(utcOffsetSeconds) }).iso8601_YYYYMMddHHmm
        let sunrise = times.rise.map({ $0.add(utcOffsetSeconds) }).iso8601_YYYYMMddHHmm
        #expect(sunrise[0] == "2021-11-06T07:17") // supposed to be 07:17
        #expect(sunset[0] == "2021-11-06T17:55") // supposed to be 17:55
    }

    @Test func sunRiseSetPolar() {
        // https://www.timeanddate.com/sun/usa/los-angeles?month=11&year=2021
        let utcOffsetSeconds = -25200
       // let currentTime = Timestamp(1636199223) // UTC 2021-11-06T11:47:03+00:00
        let time = Timestamp(1636182000) ..< Timestamp(1636268400)

        let times = Zensun.calculateSunRiseSet(timeRange: time, lat: 85.05223, lon: -118.24368, utcOffsetSeconds: utcOffsetSeconds)
        #expect(times.rise[0] == Timestamp(1636182000))
        #expect(times.set[0] == Timestamp(1636182000))
        let sunset = times.set.map({ $0.add(utcOffsetSeconds) }).iso8601_YYYYMMddHHmm
        let sunrise = times.rise.map({ $0.add(utcOffsetSeconds) }).iso8601_YYYYMMddHHmm
        #expect(sunrise[0] == "2021-11-06T00:00") // polar night -> 0h length // polar night -> 0h length
        #expect(sunset[0] == "2021-11-06T00:00") // //

        let times2 = Zensun.calculateSunRiseSet(timeRange: time, lat: -85.05223, lon: -118.24368, utcOffsetSeconds: utcOffsetSeconds)
        #expect(times2.rise[0] == Timestamp(1636182000))
        #expect(times2.set[0] == Timestamp(1636268400))
        let sunset2 = times2.set.map({ $0.add(utcOffsetSeconds) }).iso8601_YYYYMMddHHmm
        let sunrise2 = times2.rise.map({ $0.add(utcOffsetSeconds) }).iso8601_YYYYMMddHHmm
        #expect(sunrise2[0] == "2021-11-06T00:00") // polar day -> 24h length // polar day -> 24h length
        #expect(sunset2[0] == "2021-11-07T00:00") // //
    }

    @Test func sunRiseSetVancouver() {
        // https://www.timeanddate.com/sun/canada/vancouver?month=11&year=2021
        let utcOffsetSeconds = -25200
       // let currentTime = Timestamp(1636199223) // UTC 2021-11-06T11:47:03+00:00
        let time = Timestamp(1636182000) ..< Timestamp(1636268400)

        let times = Zensun.calculateSunRiseSet(timeRange: time, lat: 49.25, lon: -123.12, utcOffsetSeconds: utcOffsetSeconds)
        #expect(times.rise[0] == Timestamp(1636211364))
        #expect(times.set[0] == Timestamp(1636245772))
        let sunset = times.set.map({ $0.add(utcOffsetSeconds) }).iso8601_YYYYMMddHHmm
        let sunrise = times.rise.map({ $0.add(utcOffsetSeconds) }).iso8601_YYYYMMddHHmm
        #expect(sunset[0] == "2021-11-06T17:42") // supposed to be 17:42
        #expect(sunrise[0] == "2021-11-06T08:09") // supposed to be 08:09
    }

    @Test func extraTerrestrialRadiation() {
        // jaunary 3rd sun is closest to earth
        #expect(Zensun.extraTerrestrialRadiationBackwards(latitude: -23.5, longitude: 0, timerange: TimerangeDt(start: Timestamp(2020, 12, 26, 12), nTime: 1, dtSeconds: 3600))[0] == 1400.073)
        // on jyuly 4rd the sun is the farthest away from earth
        #expect(Zensun.extraTerrestrialRadiationBackwards(latitude: 23.5, longitude: 0, timerange: TimerangeDt(start: Timestamp(2020, 6, 26, 12), nTime: 1, dtSeconds: 3600))[0] == 1308.9365)
    }

    /*func testZenith() {
        let z2 = SolarPositionAlgorithm.zenith(lat: 23.5, lon: 2, time: Timestamp(1636211364))
        let z = Zensun.calculateZenithInstant(lat: 23.5, lon: 2, time: Timestamp(1636211364))

        #expect(z == z2)
        // 65.556435 vs 65.53193
    }*/

    @Test func sunRadius() {
        #expect(Timestamp(2009, 12, 31).getSunRadius() == 0.9833197)
        #expect(Timestamp(2010, 1, 2).getSunRadius() == 0.9832899)
        #expect(Timestamp(2010, 1, 3).getSunRadius() == 0.98328245)
        #expect(Timestamp(2010, 1, 4).getSunRadius() == 0.98328) // NASA 0.983297
        #expect(Timestamp(2010, 1, 5).getSunRadius() == 0.98328245)
        #expect(Timestamp(2010, 1, 6).getSunRadius() == 0.9832899)
        #expect(Timestamp(2010, 7, 4).getSunRadius() == 1.0167135) // NASA 1.016705
        #expect(Zensun.solarConstant * powf(0.9832855, 2) == 1322.3612) // should 1321
        #expect(Zensun.solarConstant * powf(1.0167282, 2) == 1413.8408) // should 1412
    }

    @Test func daylightDuration() {
        // https://www.timeanddate.com/sun/usa/los-angeles?month=11&year=2021
        // should be length 10:46:48 -> 10.78
        let duration = Zensun.calculateDaylightDuration(utcMidnight: Timestamp(2021, 11, 01) ..< Timestamp(2021, 11, 02), lat: 34.05223, lon: -118.24368)
        #expect((duration[0] / 3600).isApproximatelyEqual(to: 10.78, absoluteTolerance: 0.002))

        // https://www.timeanddate.com/sun/@3027582?month=1&year=2021
        // should be 9:04:53 -> 9.08138888889
        let duration2 = Zensun.calculateDaylightDuration(utcMidnight: Timestamp(2021, 1, 01) ..< Timestamp(2021, 1, 02), lat: 43, lon: 2)
        #expect((duration2[0] / 3600).isApproximatelyEqual(to: 9.0787735, absoluteTolerance: 0.002))
    }

    @Test func zensunDate() {
        // https://en.wikipedia.org/wiki/June_solstice
        #expect(Timestamp(2018, 03, 20, 16, 15).getSunDeclination().isApproximatelyEqual(to: 0, absoluteTolerance: 0.02))
        #expect((Timestamp(2018, 06, 21, 10, 07).getSunDeclination() - 23.44).isApproximatelyEqual(to: 0, absoluteTolerance: 0.02))
        #expect(Timestamp(2018, 09, 23, 01, 54).getSunDeclination().isApproximatelyEqual(to: 0, absoluteTolerance: 0.02))
        #expect((Timestamp(2018, 12, 21, 22, 22).getSunDeclination() + 23.44).isApproximatelyEqual(to: 0, absoluteTolerance: 0.02))

        #expect(Timestamp(2019, 03, 20, 21, 58).getSunDeclination().isApproximatelyEqual(to: 0, absoluteTolerance: 0.02))
        #expect((Timestamp(2019, 06, 21, 15, 54).getSunDeclination() - 23.44).isApproximatelyEqual(to: 0, absoluteTolerance: 0.02))
        #expect(Timestamp(2019, 09, 23, 07, 50).getSunDeclination().isApproximatelyEqual(to: 0, absoluteTolerance: 0.02))
        #expect((Timestamp(2019, 12, 22, 04, 19).getSunDeclination() + 23.44).isApproximatelyEqual(to: 0, absoluteTolerance: 0.02))

        #expect(Timestamp(2020, 03, 20, 03, 50).getSunDeclination().isApproximatelyEqual(to: 0, absoluteTolerance: 0.02))
        #expect((Timestamp(2020, 06, 20, 21, 43).getSunDeclination() - 23.44).isApproximatelyEqual(to: 0, absoluteTolerance: 0.02))
        #expect(Timestamp(2020, 09, 22, 13, 31).getSunDeclination().isApproximatelyEqual(to: 0, absoluteTolerance: 0.02))
        #expect((Timestamp(2020, 12, 21, 10, 03).getSunDeclination() + 23.44).isApproximatelyEqual(to: 0, absoluteTolerance: 0.02))

        #expect(Timestamp(2021, 03, 20, 09, 37).getSunDeclination().isApproximatelyEqual(to: 0, absoluteTolerance: 0.02))
        #expect((Timestamp(2021, 06, 21, 03, 32).getSunDeclination() - 23.44).isApproximatelyEqual(to: 0, absoluteTolerance: 0.02))
        #expect(Timestamp(2021, 09, 22, 19, 21).getSunDeclination().isApproximatelyEqual(to: 0, absoluteTolerance: 0.02))
        #expect((Timestamp(2021, 12, 21, 15, 59).getSunDeclination() + 23.44).isApproximatelyEqual(to: 0, absoluteTolerance: 0.02))

        #expect(Timestamp(2023, 3, 20, 12, 25).getSunDeclination().isApproximatelyEqual(to: -0.1483404, absoluteTolerance: 0.01))

        // reference https://gml.noaa.gov/grad/solcalc/azel.html
        let p = Timestamp(2022, 1, 1, 12).getSunDeclination()
        let e = Timestamp(2022, 1, 1, 12).getSunEquationOfTime()
        #expect(p.isApproximatelyEqual(to: -22.977999, absoluteTolerance: 0.02))
        #expect((e * 60).isApproximatelyEqual(to: -3.5339856, absoluteTolerance: 0.05))

        let p2 = Timestamp(2024, 1, 1, 12).getSunDeclination()
        let e2 = Timestamp(2024, 1, 1, 12).getSunEquationOfTime()
        #expect(p2.isApproximatelyEqual(to: -23.018219, absoluteTolerance: 0.02))
        #expect((e2 * 60).isApproximatelyEqual(to: -3.3114738, absoluteTolerance: 0.05))

        let p3 = Timestamp(2022, 7, 1, 12).getSunDeclination()
        let e3 = Timestamp(2022, 7, 1, 12).getSunEquationOfTime()
        #expect(p3.isApproximatelyEqual(to: 23.08617, absoluteTolerance: 0.001))
        #expect((e3 * 60).isApproximatelyEqual(to: -3.9086208, absoluteTolerance: 0.02))
    }

    @Test func solarInterpolation() {
        let samples = 4
        let directRadiation = [Float(0.0), 0.0, 0.0, 0.0, 0.0, 0.0, 7.0, 116.0, 305.0, 485.0, 615.0, 680.0, 681.0, 579.0, 428.0, 272.0, 87.0, 3.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
        let time = TimerangeDt(start: Timestamp(2022, 7, 31), nTime: 24, dtSeconds: 3600)
        let dtNew = time.dtSeconds / samples
        let timeNew = time.range.add(-time.dtSeconds + dtNew).range(dtSeconds: dtNew)
        #expect(timeNew.range.lowerBound.iso8601_YYYY_MM_dd_HH_mm == "2022-07-30T23:15")

        // test coefficients
        /*let position = RegularGrid(nx: 1, ny: 1, latMin: -22.5, lonMin: 17, dx: 1, dy: 1)
        let solarLow = Zensun.calculateRadiationBackwardsAveraged(grid: position, locationRange: 0..<1, timerange: time).data
        let solar = Zensun.calculateRadiationBackwardsAveraged(grid: position, locationRange: 0..<1, timerange: timeNew).data
        let solb = solar.mean(by: samples)
        // very small differences at sunrise/set
        #expect(arraysEqual(solb, solarLow, accuracy: 0.0001))*/

        let interpolated = directRadiation.interpolateSolarBackwards(timeOld: time, timeNew: timeNew, latitude: -22.5, longitude: 17, scalefactor: 1000)
        print(interpolated)
        let averaged = interpolated.mean(by: samples)

        // Todo: interpolation needs to preserve averages coorectly
        #expect(arraysEqual(averaged, [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 9.0395, 118.7305, 305.30826, 484.58725, 614.3557, 680.2457, 677.99426, 578.955, 430.63425, 270.04575, 91.09175, 4.719, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0], accuracy: 0.01))
    }
    
    @Test func solarFactorBackwardsIntegral() {
        let samples = 4
        let time = TimerangeDt(start: Timestamp(2022, 7, 31, 1), nTime: 24, dtSeconds: 3600)
        let time3h = TimerangeDt(start: Timestamp(2022, 7, 31, 3), nTime: 24/3, dtSeconds: 3*3600)
        let time15m = TimerangeDt(start: Timestamp(2022, 7, 31, 0, 15), nTime: 24*4, dtSeconds: 3600/4)

        let grid = RegularGrid(nx: 1, ny: 1, latMin: 40.4751129, lonMin: -7.5, dx: 1, dy: 1)
        let solar3hourly = Zensun.calculateRadiationBackwardsAveraged(grid: grid, locationRange: 0..<1, timerange: time3h).data.map {$0 * Zensun.solarConstant}
        let solar1hourly = Zensun.calculateRadiationBackwardsAveraged(grid: grid, locationRange: 0..<1, timerange: time).data.map {$0 * Zensun.solarConstant}
        let solar15min = Zensun.calculateRadiationBackwardsAveraged(grid: grid, locationRange: 0..<1, timerange: time15m).data.map {$0 * Zensun.solarConstant}
        
        let solarAggregated = solar15min.mean(by: samples)
        
        #expect(arraysEqual(solar3hourly, [0.0, 9.483822, 486.09094, 1065.2064, 1178.0295, 757.9968, 117.25071, 0.0], accuracy: 0.001))
        
        /// Aggregate 1h to 3h
        let solar1hourlyTo3h = solar1hourly.mean(by: 3)
        #expect(arraysEqual(solar1hourlyTo3h, [0.0, 9.483827, 486.22403, 1065.297, 1178.1105, 758.1069, 117.393105, 0.0], accuracy: 0.001))
        
        /// Diff 3h calculated vs aggregated
        let difference3gh = zip(solar3hourly, solar1hourlyTo3h).map(-)
        #expect(arraysEqual(difference3gh, [0.0, -4.7683716e-06, -0.13308716, -0.09057617, -0.08093262, -0.11004639, -0.14240265, 0.0], accuracy: 0.001))
        
        #expect(arraysEqual(solar1hourly, [0.0, 0.0, 0.0, 0.0, 0.0, 28.45148, 243.09027, 491.24808, 724.3337, 926.44653, 1083.7981, 1185.6466, 1225.0326, 1199.253, 1110.0457, 963.4721, 769.5037, 541.34467, 294.53146, 57.647854, 0.0, 0.0, 0.0, 0.0], accuracy: 0.001))
        
        #expect(arraysEqual(solar15min, [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 26.427395, 87.41708, 149.32352, 211.74786, 274.4251, 337.0804, 399.45273, 461.27002, 522.27045, 582.1894, 640.77167, 697.7684, 752.93036, 806.0263, 856.82416, 905.1096, 950.6733, 993.32153, 1032.8684, 1069.1508, 1102.0052, 1131.2949, 1156.8943, 1178.6906, 1196.595, 1210.526, 1220.4258, 1226.2511, 1227.9769, 1225.5953, 1219.1165, 1208.5676, 1193.9934, 1175.4568, 1153.0374, 1126.8274, 1096.9445, 1063.51, 1026.6696, 986.5837, 943.42017, 897.36536, 848.61365, 797.37494, 743.87067, 688.3282, 630.983, 572.0816, 511.8807, 450.63205, 388.59778, 326.04785, 263.247, 200.46379, 137.96501, 76.02444, 16.8495, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0], accuracy: 0.001))
        
        #expect(arraysEqual(solarAggregated, [0.0, 0.0, 0.0, 0.0, 0.0, 28.46112, 243.14423, 491.29565, 724.3742, 926.4822, 1083.8298, 1185.6765, 1225.0623, 1199.2836, 1110.0798, 963.50964, 769.5468, 541.39435, 294.5891, 57.709736, 0.0, 0.0, 0.0, 0.0], accuracy: 0.001))
        
        /// The differences are so small that in practice it does not make a difference
        let difference = zip(solar1hourly, solarAggregated).map(-)
        #expect(arraysEqual(difference, [0.0, 0.0, 0.0, 0.0, 0.0, -0.00963974, -0.053955078, -0.047576904, -0.040527344, -0.03564453, -0.03173828, -0.029907227, -0.029663086, -0.030517578, -0.034179688, -0.03753662, -0.04309082, -0.049682617, -0.057647705, -0.06188202, 0.0, 0.0, 0.0, 0.0]))
    }
    
    @Test func solarFactorBackwardsIntegral2() {
        // sunset 17:05
        let timeInstant = TimerangeDt(start: Timestamp(2025, 3, 1, 17), nTime: 1, dtSeconds: 3600)
        let time = TimerangeDt(start: Timestamp(2025, 3, 1, 18), nTime: 1, dtSeconds: 3600)
        let time3h = TimerangeDt(start: Timestamp(2025, 3, 1, 20), nTime: 1, dtSeconds: 3*3600)
        let time15m = TimerangeDt(start: Timestamp(2025, 3, 1, 17, 15), nTime: 1, dtSeconds: 3600/4)
        let time5m = TimerangeDt(start: Timestamp(2025, 3, 1, 17, 0), nTime: 3, dtSeconds: 60*5)
        let time1m = TimerangeDt(start: Timestamp(2025, 3, 1, 17, 1), nTime: 3, dtSeconds: 60)

        let grid = RegularGrid(nx: 1, ny: 1, latMin: 30, lonMin: 13.44, dx: 1, dy: 1)
        
        let solarInstant = Zensun.calculateRadiationInstant(grid: grid, timerange: timeInstant).map {$0 * Zensun.solarConstant}
        #expect(arraysEqual(solarInstant, [7.540143], accuracy: 0.001))
        
        let solar1hourly = Zensun.calculateRadiationBackwardsAveraged(grid: grid, locationRange: 0..<1, timerange: time).data.map {$0 * Zensun.solarConstant}
        #expect(arraysEqual(solar1hourly, [0.094545215], accuracy: 0.001))
        
        let solar3hourly = Zensun.calculateRadiationBackwardsAveraged(grid: grid, locationRange: 0..<1, timerange: time3h).data.map {$0 * Zensun.solarConstant}
        #expect(arraysEqual(solar3hourly, [0.034051836], accuracy: 0.001))
        
        let solar15min = Zensun.calculateRadiationBackwardsAveraged(grid: grid, locationRange: 0..<1, timerange: time15m).data.map {$0 * Zensun.solarConstant}
        #expect(arraysEqual(solar15min, [0.36803406], accuracy: 0.001))
        
        let solar5min = Zensun.calculateRadiationBackwardsAveraged(grid: grid, locationRange: 0..<1, timerange: time5m).data.map {$0 * Zensun.solarConstant}
        #expect(arraysEqual(solar5min, [20.547714, 1.0964854, 0.0], accuracy: 0.001))
        
        // Technically sunset is at 7:03, because the integral cannot not consider half disk angle
        let solar1min = Zensun.calculateRadiationBackwardsAveraged(grid: grid, locationRange: 0..<1, timerange: time1m).data.map {$0 * Zensun.solarConstant}
        #expect(arraysEqual(solar1min, [4.9304376, 0.5330346, 0.0], accuracy: 0.001))
    }
    
    /// Without proper bounding in solar factor calculations, would show radiation peaks
    @Test func solarInterpolation15min() {
        let samples = 4
        let directRadiation = [Float(0.0), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 7.0, 94.0, 226.0, 347.0, 447.0, 483.0, 409.0, 269.0, 162.0, 132.0, 114.0, 65.0, 12.0, 0.0, 0.0, 0.0, 0.0, 0.0]
        //timeIntervalSince1970    Int    1773360000
        let time = TimerangeDt(start: Timestamp(2026, 3, 12, 23), nTime: 26, dtSeconds: 3600)
        let dtNew = time.dtSeconds / samples
        let timeNew = time.range.add(-time.dtSeconds + dtNew).range(dtSeconds: dtNew)

        let solar = Zensun.calculateRadiationBackwardsAveraged(grid: RegularGrid(nx: 1, ny: 1, latMin: 40.4751129, lonMin: -7.5, dx: 1, dy: 1), locationRange: 0..<1, timerange: timeNew).data
//        print(solar)
        #expect(arraysEqual(solar, [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.012618701, 0.060688883, 0.1104959, 0.15968691, 0.20805171, 0.2553846, 0.30148143, 0.34614527, 0.38918778, 0.4304188, 0.46966717, 0.5067633, 0.5415477, 0.57387257, 0.6036, 0.63060194, 0.6547628, 0.6759796, 0.69416225, 0.7092324, 0.72112566, 0.72979206, 0.73519385, 0.73730874, 0.7361272, 0.7316551, 0.7239114, 0.71292967, 0.69875735, 0.681455, 0.66109824, 0.63777256, 0.61157876, 0.58262956, 0.55104864, 0.5169739, 0.48054716, 0.44192877, 0.4012807, 0.35878098, 0.31460992, 0.2689582, 0.22201985, 0.17399698, 0.1250954, 0.075524434, 0.025497437, 1.8446293e-06, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0], accuracy: 0.0001))
        
        let interpolated = directRadiation.interpolateSolarBackwards(timeOld: time, timeNew: timeNew, latitude: 40.4751129, longitude: -7.5, scalefactor: 1)
        print(interpolated)
        #expect(interpolated == [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 9.0, 42.0, 77.0, 111.0, 145.0, 178.0, 211.0, 242.0, 274.0, 304.0, 334.0, 362.0, 390.0, 416.0, 439.0, 457.0, 472.0, 482.0, 485.0, 481.0, 468.0, 448.0, 424.0, 395.0, 361.0, 323.0, 286.0, 254.0, 223.0, 195.0, 171.0, 155.0, 145.0, 139.0, 135.0, 130.0, 127.0, 124.0, 118.0, 109.0, 97.0, 84.0, 71.0, 60.0, 48.0, 32.0, 12.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
    }
    
    @Test func solarInterpolationNegative() {
        let samples = 4
        // 7 watts at noon is completely unrealistic, but this case may trigger negative values
        let directRadiation = [Float(0.0), 0.0, 0.0, 0.0, 0.0, 0.0, 7.0, 116.0, 305.0, 485.0, 615.0, 180.0, 7, 579.0, 428.0, 272.0, 87.0, 3.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
        let time = TimerangeDt(start: Timestamp(2022, 7, 31), nTime: 24, dtSeconds: 3600)
        let dtNew = time.dtSeconds / samples
        let timeNew = time.range.add(-time.dtSeconds + dtNew).range(dtSeconds: dtNew)
        #expect(timeNew.range.lowerBound.iso8601_YYYY_MM_dd_HH_mm == "2022-07-30T23:15")
        let interpolated = directRadiation.interpolateSolarBackwards(timeOld: time, timeNew: timeNew, latitude: -22.5, longitude: 17, scalefactor: 10000)

        #expect(arraysEqual(interpolated, [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0013, 7.7605, 28.3973, 58.1777, 95.9556, 137.6713, 183.1169, 231.455, 281.1669, 330.5519, 378.0594, 423.2058, 465.9643, 509.0662, 561.2819, 607.3815, 625.6637, 590.578, 490.2144, 356.3862, 228.8483, 138.9229, 57.8111, 72.6886, 28.7999, 51.3999, 208.9345, 396.2716, 542.8802, 593.0821, 570.3606, 513.2369, 452.6649, 410.4361, 374.5105, 337.432, 295.9325, 248.5307, 198.2883, 149.7824, 106.4073, 69.642, 38.5355, 16.0494, 2.8271, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0], accuracy: 0.01))
        
        let time2 = TimerangeDt(start: Timestamp(2006, 5, 18), nTime: 24 * 2, dtSeconds: 1800)
        let grid = RegularGrid(nx: 1, ny: 1, latMin: 52.25, lonMin: 21, dx: 1, dy: 1)
        /// Artificial radiation drop just before and after missing values
        var rad = [0.0, 0.0, 0.0, 1.0, 4.0, 23.0, 113.0, 190.0, 284.0, 287.0, 407.0, 568.0, 638.0, 691.0, 706.0, 738.0, 692.0, 559.0, 361.0, 380.0, 420.0, 700.0, 631.0, 659.0, 302.0, 10.1, Float.nan, .nan, .nan, .nan, .nan, .nan, 11.0, 44.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
        rad.interpolateInplaceSolarBackwards(time: time2, grid: grid, locationRange: 0..<1, missingValuesAreBackwardsAveraged: false)
        #expect(arraysEqual(rad, [0.0, 0.0, 0.0, 1.0, 4.0, 23.0, 113.0, 190.0, 284.0, 287.0, 407.0, 568.0, 638.0, 691.0, 706.0, 738.0, 692.0, 559.0, 361.0, 380.0, 420.0, 700.0, 631.0, 659.0, 302.0, 10.1, 11.30978, 12.209529, 12.758652, 12.926316, 6.1488514, 10.5652075, 11.0, 44.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0], accuracy: 0.01))
    }

    @Test func solarGapfilling() {
        let time = TimerangeDt(start: Timestamp(2020, 12, 26, 0), nTime: 48, dtSeconds: 3600)
        let position = RegularGrid(nx: 1, ny: 1, latMin: 47.5, lonMin: 7, dx: 1, dy: 1)
        /// 60% ex rad
        let reference = Zensun.extraTerrestrialRadiationBackwards(latitude: position.latMin, longitude: position.lonMin, timerange: time).map { $0 * 0.6 }
        var averagedWithNaNs = reference
        for i in 0..<20 {
            averagedWithNaNs[7 + i * 2 + 1] = averagedWithNaNs[7 + i * 2..<9 + i * 2].mean()
            averagedWithNaNs[7 + i * 2] = .nan
        }
        averagedWithNaNs.interpolateInplaceSolarBackwards(time: time, grid: position, locationRange: 0..<1, missingValuesAreBackwardsAveraged: true)
        #expect(arraysEqual(reference, averagedWithNaNs, accuracy: 0.001))

        averagedWithNaNs = reference
        for i in 0..<13 {
            averagedWithNaNs[7 + i * 3 + 2] = averagedWithNaNs[7 + i * 3..<10 + i * 3].mean()
            averagedWithNaNs[7 + i * 3 + 1] = .nan
            averagedWithNaNs[7 + i * 3] = .nan
        }
        print(averagedWithNaNs)
        averagedWithNaNs.interpolateInplaceSolarBackwards(time: time, grid: position, locationRange: 0..<1, missingValuesAreBackwardsAveraged: true)
        #expect(arraysEqual(reference, averagedWithNaNs, accuracy: 0.01))
    }

    @Test func dNI() {
        let directRadiation = [Float(0.0), 0.0, 0.0, 0.0, 0.0, 0.0, 7.0, 116.0, 305.0, 485.0, 615.0, 680.0, 681.0, 579.0, 428.0, 272.0, 87.0, 3.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
        let time = TimerangeDt(start: Timestamp(2022, 7, 31), nTime: 24, dtSeconds: 3600)
        let dni = Zensun.calculateBackwardsDNISupersampled(directRadiation: directRadiation, latitude: -22.5, longitude: 17, timerange: time, samples: 4)
        // At low sample counts, DNI is not calculated correctly, but we keep tests simple
        #expect(arraysEqual(dni, [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 150.55544, 518.34283, 725.5642, 836.6179, 888.55334, 908.3525, 907.0859, 842.14484, 752.32007, 655.0936, 410.60168, 47.573414, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0], accuracy: 0.01))

        /// Analytical solution is fairly close to supersampled solution. Smaller difference at sun rise/set
        let dni2 = Zensun.calculateBackwardsDNI(directRadiation: directRadiation, latitude: -22.5, longitude: 17, timerange: time)
        #expect(arraysEqual(dni2, [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 88.22421, 525.6257, 730.035, 838.7038, 889.7469, 908.00757, 911.16675, 843.0275, 749.2078, 665.61414, 414.24954, 40.669086, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0], accuracy: 0.01))
        
        let dniInstant = Zensun.calculateBackwardsDNI(directRadiation: directRadiation, latitude: -22.5, longitude: 17, timerange: time, convertToInstant: true)
        #expect(arraysEqual(dniInstant, [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 348.99603, 772.2604, 882.58014, 933.1149, 939.24207, 919.1415, 885.91315, 782.6327, 651.7093, 511.8239, 201.10855, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0], accuracy: 0.01))
    }
    
    /// Make sure DNI it limited to 87° zenith angle, otherwise it would show peaks at sunset
    @Test func dniCloseToSunset() {
        let directRadiation = [Float(32), 11, 1]
        let time = TimerangeDt(start: Timestamp(2026, 3, 13, 18, 0), nTime: 3, dtSeconds: 900)
        let dni = Zensun.calculateBackwardsDNI(directRadiation: directRadiation, latitude: 36.5, longitude: -4.875, timerange: time)
        #expect(arraysEqual(dni, [324.32886, 191.8275, 0.0], accuracy: 0.01))
    }

    @Test func gTI() {
        let directRadiation = [Float(0.0), 0.0, 0.0, 0.0, 0.0, 0.0, 7.0, 116.0, 305.0, 485.0, 615.0, 680.0, 681.0, 579.0, 428.0, 272.0, 87.0, 3.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
        let diffuseRadiation = [Float(0.0), 0.0, 0.0, 0.0, 0.0, 0.0, 2.0, 130.0, 118.0, 224.0, 315.0, 316.0, 318.0, 280.0, 215.0, 139.0, 40.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
        let time = TimerangeDt(start: Timestamp(2022, 7, 31), nTime: 24, dtSeconds: 3600)
        let gti = Zensun.calculateTiltedIrradiance(directRadiation: directRadiation, diffuseRadiation: diffuseRadiation, tilt: 45, azimuth: 0, latitude: -22.5, longitude: 17, timerange: time, convertBackwardsToInstant: false)
        #expect(arraysEqual(gti, [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.9707108, 118.167114, 113.10868, 211.9621, 336.0515, 361.00406, 362.58548, 300.82724, 202.34702, 130.68182, 37.861877, 0.9707107, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0], accuracy: 0.01))

        let gtiInstant = Zensun.calculateTiltedIrradiance(directRadiation: directRadiation, diffuseRadiation: diffuseRadiation, tilt: 45, azimuth: 0, latitude: -22.5, longitude: 17, timerange: time, convertBackwardsToInstant: true)
        #expect(arraysEqual(gtiInstant, [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 7.795708, 173.61362, 136.74342, 235.82225, 354.7455, 365.43063, 352.53616, 279.27585, 176.0145, 100.48777, 18.381063, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0], accuracy: 0.01))

        let gtiTrackHorizontal = Zensun.calculateTiltedIrradiance(directRadiation: directRadiation, diffuseRadiation: diffuseRadiation, tilt: 45, azimuth: .nan, latitude: -22.5, longitude: 17, timerange: time, convertBackwardsToInstant: false)
        #expect(arraysEqual(gtiTrackHorizontal, [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 69.10773, 562.70105, 797.77844, 1038.7473, 1185.6353, 1205.2142, 1210.2856, 1106.8444, 939.80383, 752.5834, 385.76602, 31.77107, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0], accuracy: 0.01))

        let gtiTrackVertical = Zensun.calculateTiltedIrradiance(directRadiation: directRadiation, diffuseRadiation: diffuseRadiation, tilt: .nan, azimuth: 0, latitude: -22.5, longitude: 17, timerange: time, convertBackwardsToInstant: false)
        #expect(arraysEqual(gtiTrackVertical, [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.9056834, 98.515854, 108.27706, 206.66702, 316.56372, 418.15967, 417.75742, 277.57715, 196.47887, 122.20553, 34.23313, 0.90512145, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0], accuracy: 0.01))

        let gtiBiAxialTracking = Zensun.calculateTiltedIrradiance(directRadiation: directRadiation, diffuseRadiation: diffuseRadiation, tilt: .nan, azimuth: .nan, latitude: -22.5, longitude: 17, timerange: time, convertBackwardsToInstant: false)
        #expect(arraysEqual(gtiBiAxialTracking, [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 90.13215, 624.1415, 838.312, 1045.3708, 1184.8297, 1209.3428, 1214.2375, 1106.0839, 945.6867, 787.81964, 448.48267, 41.57647, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0], accuracy: 0.01))
    }

    @Test func diffuseRadiation() {
        let directRadiation = [Float(0.0), 0.0, 0.0, 0.0, 0.0, 0.0, 7.0, 116.0, 305.0, 485.0, 615.0, 680.0, 681.0, 579.0, 428.0, 272.0, 87.0, 3.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
        let diffuseRadiation = [Float(0.0), 0.0, 0.0, 0.0, 0.0, 0.0, 2.0, 130.0, 118.0, 224.0, 315.0, 316.0, 318.0, 280.0, 215.0, 139.0, 40.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
        let swrad = zip(directRadiation, diffuseRadiation).map(+)
        let time = TimerangeDt(start: Timestamp(2022, 7, 31), nTime: 24, dtSeconds: 3600)
        let diff = Zensun.calculateDiffuseRadiationBackwards(shortwaveRadiation: swrad, latitude: -22.5, longitude: 17, timerange: time)
        // Note: Differences to the actual diffuse radiation are expected!
        #expect(arraysEqual(diff, [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 9.0, 116.9848, 133.84239, 166.59798, 219.15633, 200.51555, 205.13588, 167.13881, 146.30597, 132.74532, 84.49708, 4.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0], accuracy: 0.01))
    }

    @Test func sarahInterpolation() {
        let time = TimerangeDt(start: Timestamp(2006, 5, 18), nTime: 24 * 2, dtSeconds: 1800)
        let grid = RegularGrid(nx: 1, ny: 1, latMin: 52.25, lonMin: 21, dx: 1, dy: 1)
        var rad = [0.0, 0.0, 0.0, 1.0, 4.0, 23.0, 113.0, 190.0, 284.0, 287.0, 407.0, 568.0, 638.0, 691.0, 706.0, 738.0, 692.0, 559.0, 361.0, 380.0, 420.0, 700.0, 631.0, 659.0, 502.0, 464.0, Float.nan, .nan, .nan, .nan, .nan, .nan, 62.0, 34.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
        rad.interpolateInplaceSolarBackwards(time: time, grid: grid, locationRange: 0..<1, missingValuesAreBackwardsAveraged: false)
        #expect(arraysEqual(rad, [0.0, 0.0, 0.0, 1.0, 4.0, 23.0, 113.0, 190.0, 284.0, 287.0, 407.0, 568.0, 638.0, 691.0, 706.0, 738.0, 692.0, 559.0, 361.0, 380.0, 420.0, 700.0, 631.0, 659.0, 502.0, 464.0, 415.3082, 348.894, 275.25363, 203.68459, 141.54568, 93.67375, 62.0, 34.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0], accuracy: 0.01))
    }

    @Test func _3to6HourlyInterpolation() {
        // data contains 2 locations times 2 members. 4 series in total
        // First step is NaN as usual for model data
        var rad: [Float] = [Float.nan, 0.0, 0.0, 0.0, 210.0, 504.0, 336.0, 51.0, 0.0, 0.0, 0.0, 0.0, 197.0, 564.0, 441.0, 50.0, 0.0, 0.0, 0.0, 0.0, 215.0, 567.0, 442.0, 45.0, 0.0, 0.0, 0.0, 0.0, 189.0, 474.0, 330.0, 34.0, 0.0, 0.0, 0.0, 0.0, 153.0, 481.0, 336.0, 39.0, 0.0, 0.0, 0.0, 0.0, 191.0, 520.0, 402.0, 42.0, 0.0, .nan, 0.0, .nan, 63.0, .nan, 347.0, .nan, 20.0, .nan, 0.0, .nan, 95.0, .nan, 422.0, .nan, 20.0, .nan, 0.0, .nan, 91.0, .nan, 336.0, .nan, 14.0, .nan, 0.0, .nan, 81.0, .nan, 338.0, .nan, 10.0, .nan, 0.0, .nan, 94.0, .nan, 465.0, .nan, 19.0, .nan, 0.0, .nan, 87.0, .nan, 405.0, .nan, 17.0, .nan, 0.0, .nan, 66.0, .nan, 347.0, .nan, 15.0, .nan, 0.0, .nan, 49.0, .nan, 306.0, .nan, 14.0, .nan, 0.0, .nan, 86.0, .nan, 407.0, .nan, 14.0, .nan, 0.0, 0.0, 0.0, 210.0, 504.0, 336.0, 51.0, 0.0, 0.0, 0.0, 0.0, 197.0, 564.0, 441.0, 50.0, 0.0, 0.0, 0.0, 0.0, 215.0, 567.0, 442.0, 45.0, 0.0, 0.0, 0.0, 0.0, 189.0, 474.0, 330.0, 34.0, 0.0, 0.0, 0.0, 0.0, 153.0, 481.0, 336.0, 39.0, 0.0, 0.0, 0.0, 0.0, 191.0, 520.0, 402.0, 42.0, 0.0, .nan, 0.0, .nan, 63.0, .nan, 347.0, .nan, 20.0, .nan, 0.0, .nan, 95.0, .nan, 422.0, .nan, 20.0, .nan, 0.0, .nan, 91.0, .nan, 336.0, .nan, 14.0, .nan, 0.0, .nan, 81.0, .nan, 338.0, .nan, 10.0, .nan, 0.0, .nan, 94.0, .nan, 465.0, .nan, 19.0, .nan, 0.0, .nan, 87.0, .nan, 405.0, .nan, 17.0, .nan, 0.0, .nan, 66.0, .nan, 347.0, .nan, 15.0, .nan, 0.0, .nan, 49.0, .nan, 306.0, .nan, 14.0, .nan, 0.0, .nan, 86.0, .nan, 407.0, .nan, 14.0,.nan, 0.0, 0.0, 0.0, 215.0, 501.0, 333.0, 49.0, 0.0, 0.0, 0.0, 0.0, 212.0, 565.0, 439.0, 48.0, 0.0, 0.0, 0.0, 0.0, 218.0, 568.0, 441.0, 46.0, 0.0, 0.0, 0.0, 0.0, 196.0, 513.0, 339.0, 29.0, 0.0, 0.0, 0.0, 0.0, 162.0, 484.0, 325.0, 39.0, 0.0, 0.0, 0.0, 0.0, 190.0, 515.0, 398.0, 41.0, 0.0, .nan, 0.0, .nan, 68.0, .nan, 310.0, .nan, 17.0, .nan, 0.0, .nan, 96.0, .nan, 419.0, .nan, 19.0, .nan, 0.0, .nan, 93.0, .nan, 333.0, .nan, 13.0, .nan, 0.0, .nan, 61.0, .nan, 314.0, .nan, 8.0, .nan, 0.0, .nan, 96.0, .nan, 459.0, .nan, 18.0, .nan, 0.0, .nan, 87.0, .nan, 404.0, .nan, 16.0, .nan, 0.0, .nan, 61.0, .nan, 332.0, .nan, 15.0, .nan, 0.0, .nan, 39.0, .nan, 279.0, .nan, 14.0, .nan, 0.0, .nan, 87.0, .nan, 380.0, .nan, 12.0, .nan, 0.0, 0.0, 0.0, 215.0, 501.0, 333.0, 49.0, 0.0, 0.0, 0.0, 0.0, 212.0, 565.0, 439.0, 48.0, 0.0, 0.0, 0.0, 0.0, 218.0, 568.0, 441.0, 46.0, 0.0, 0.0, 0.0, 0.0, 196.0, 513.0, 339.0, 29.0, 0.0, 0.0, 0.0, 0.0, 162.0, 484.0, 325.0, 39.0, 0.0, 0.0, 0.0, 0.0, 190.0, 515.0, 398.0, 41.0, 0.0, .nan, 0.0, .nan, 68.0, .nan, 310.0, .nan, 17.0, .nan, 0.0, .nan, 96.0, .nan, 419.0, .nan, 19.0, .nan, 0.0, .nan, 93.0, .nan, 333.0, .nan, 13.0, .nan, 0.0, .nan, 61.0, .nan, 314.0, .nan, 8.0, .nan, 0.0, .nan, 96.0, .nan, 459.0, .nan, 18.0, .nan, 0.0, .nan, 87.0, .nan, 404.0, .nan, 16.0, .nan, 0.0, .nan, 61.0, .nan, 332.0, .nan, 15.0, .nan, 0.0, .nan, 39.0, .nan, 279.0, .nan, 14.0, .nan, 0.0, .nan, 87.0, .nan, 380.0, .nan, 12.0]
        let time = TimerangeDt(start: Timestamp(2025, 4, 30, 12), nTime: 121, dtSeconds: 3*3600)
        /// ifs025 grid, 302260..<302262
        let grid = RegularGrid(nx: 1440, ny: 721, latMin: -90, lonMin: -180, dx: 360 / 1440, dy: 180 / (721 - 1))
        let range: any RandomAccessCollection<Int> = RegularGridSlice(grid: grid, yRange: 209..<209+1, xRange: 1300..<1300+2)
        #expect(range.map{$0} == [302260, 302261])
        rad.interpolateInplaceSolarBackwards(time: time, grid: grid, locationRange: range, missingValuesAreBackwardsAveraged: true)
        #expect(arraysEqual(rad, [.nan, 0.0, 0.0, 0.0, 210.0, 504.0, 336.0, 51.0, 0.0, 0.0, 0.0, 0.0, 197.0, 564.0, 441.0, 50.0, 0.0, 0.0, 0.0, 0.0, 215.0, 567.0, 442.0, 45.0, 0.0, 0.0, 0.0, 0.0, 189.0, 474.0, 330.0, 34.0, 0.0, 0.0, 0.0, 0.0, 153.0, 481.0, 336.0, 39.0, 0.0, 0.0, 0.0, 0.0, 191.0, 520.0, 402.0, 42.0, 0.0, 0.0, 0.0, 0.0, 126.0, 342.34003, 309.25827, 40.89545, 0.0, 0.0, 0.0, 0.0, 190.0, 466.23596, 375.76132, 44.353786, 0.0, 0.0, 0.0, 0.0, 182.0, 411.44446, 298.92218, 32.547844, 0.0, 0.0, 0.0, 0.0, 162.0, 394.73068, 300.4463, 28.616186, 0.0, 0.0, 0.0, 0.0, 188.0, 495.49594, 412.99677, 44.643055, 0.0, 0.0, 0.0, 0.0, 174.0, 444.61868, 359.42184, 38.76558, 0.0, 0.0, 0.0, 0.0, 132.0, 360.277, 307.71442, 33.550816, 0.0, 0.0, 0.0, 0.0, 98.0, 294.54755, 271.1577, 30.32507, 0.0, 0.0, 0.0, 0.0, 172.0, 450.98923, 360.40485, 34.60132, 0.0, .nan, 0.0, 0.0, 0.0, 210.0, 504.0, 336.0, 51.0, 0.0, 0.0, 0.0, 0.0, 197.0, 564.0, 441.0, 50.0, 0.0, 0.0, 0.0, 0.0, 215.0, 567.0, 442.0, 45.0, 0.0, 0.0, 0.0, 0.0, 189.0, 474.0, 330.0, 34.0, 0.0, 0.0, 0.0, 0.0, 153.0, 481.0, 336.0, 39.0, 0.0, 0.0, 0.0, 0.0, 191.0, 520.0, 402.0, 42.0, 0.0, 0.0, 0.0, 0.0, 126.0, 342.34003, 309.25827, 40.89545, 0.0, 0.0, 0.0, 0.0, 190.0, 466.23596, 375.76132, 44.353786, 0.0, 0.0, 0.0, 0.0, 182.0, 411.44446, 298.92218, 32.547844, 0.0, 0.0, 0.0, 0.0, 162.0, 394.73068, 300.4463, 28.616186, 0.0, 0.0, 0.0, 0.0, 188.0, 495.49594, 412.99677, 44.643055, 0.0, 0.0, 0.0, 0.0, 174.0, 444.61868, 359.42184, 38.76558, 0.0, 0.0, 0.0, 0.0, 132.0, 360.277, 307.71442, 33.550816, 0.0, 0.0, 0.0, 0.0, 98.0, 294.54755, 271.1577, 30.32507, 0.0, 0.0, 0.0, 0.0, 172.0, 450.98923, 360.40485, 34.60132, 0.0, .nan, 0.0, 0.0, 0.0, 215.0, 501.0, 333.0, 49.0, 0.0, 0.0, 0.0, 0.0, 212.0, 565.0, 439.0, 48.0, 0.0, 0.0, 0.0, 0.0, 218.0, 568.0, 441.0, 46.0, 0.0, 0.0, 0.0, 0.0, 196.0, 513.0, 339.0, 29.0, 0.0, 0.0, 0.0, 0.0, 162.0, 484.0, 325.0, 39.0, 0.0, 0.0, 0.0, 0.0, 190.0, 515.0, 398.0, 41.0, 0.0, 0.0, 0.0, 0.0, 136.0, 333.07123, 275.48016, 34.913036, 0.0, 0.0, 0.0, 0.0, 192.0, 465.766, 371.99835, 42.6139, 0.0, 0.0, 0.0, 0.0, 186.0, 413.51102, 295.37994, 30.907837, 0.0, 0.0, 0.0, 0.0, 122.0, 332.59763, 278.284, 25.331936, 0.0, 0.0, 0.0, 0.0, 192.0, 495.66803, 406.4484, 42.654514, 0.0, 0.0, 0.0, 0.0, 174.0, 443.2333, 357.45435, 37.216923, 0.0, 0.0, 0.0, 0.0, 122.0, 337.00745, 293.5196, 32.401485, 0.0, 0.0, 0.0, 0.0, 78.0, 251.71968, 246.47684, 28.692657, 0.0, 0.0, 0.0, 0.0, 174.0, 437.25235, 335.4611, 30.758059, 0.0, .nan, 0.0, 0.0, 0.0, 215.0, 501.0, 333.0, 49.0, 0.0, 0.0, 0.0, 0.0, 212.0, 565.0, 439.0, 48.0, 0.0, 0.0, 0.0, 0.0, 218.0, 568.0, 441.0, 46.0, 0.0, 0.0, 0.0, 0.0, 196.0, 513.0, 339.0, 29.0, 0.0, 0.0, 0.0, 0.0, 162.0, 484.0, 325.0, 39.0, 0.0, 0.0, 0.0, 0.0, 190.0, 515.0, 398.0, 41.0, 0.0, 0.0, 0.0, 0.0, 136.0, 333.07123, 275.48016, 34.913036, 0.0, 0.0, 0.0, 0.0, 192.0, 465.766, 371.99835, 42.6139, 0.0, 0.0, 0.0, 0.0, 186.0, 413.51102, 295.37994, 30.907837, 0.0, 0.0, 0.0, 0.0, 122.0, 332.59763, 278.284, 25.331936, 0.0, 0.0, 0.0, 0.0, 192.0, 495.66803, 406.4484, 42.654514, 0.0, 0.0, 0.0, 0.0, 174.0, 443.2333, 357.45435, 37.216923, 0.0, 0.0, 0.0, 0.0, 122.0, 337.00745, 293.5196, 32.401485, 0.0, 0.0, 0.0, 0.0, 78.0, 251.71968, 246.47684, 28.692657, 0.0, 0.0, 0.0, 0.0, 174.0, 437.25235, 335.4611, 30.758059, 0.0], accuracy: 0.01))
    }

    @Test func diffuseRadiationAtLowAngles() {
        // https://github.com/open-meteo/open-meteo/issues/1355
        let ghi = [Float(0.0), 0.0, 0.0, 1.0, 21.0, 39.0, 152.0, 422.0, 560.0, 682.0, 701.0, 614.0, 723.0, 654.0, 421.0, 602.0, 106.0, 332.0, 194.0, 52.0, 31.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 10.0, 55.0, 103.0, 202.0, 253.0, 337.0, 228.0, 147.0, 97.0, 50.0, 53.0, 41.0, 41.0, 27.0, 16.0, 6.0, 22.0, 16.0, 0.0, 0.0, 0.0]
        let diff = Zensun.calculateDiffuseRadiationBackwards(shortwaveRadiation: ghi, latitude: 60.51212 , longitude: 10.296539, timerange: TimerangeDt(range: Timestamp(1748217600)..<Timestamp(1748390400), dtSeconds: 3600))
        #expect(arraysEqual(diff, [0.0, 0.0, 0.0, 1.0, 21.0, 37.865845, 115.975784, 143.00925, 152.07257, 157.71788, 190.1775, 259.68018, 217.3301, 230.59657, 261.28595, 162.74396, 99.54726, 140.1013, 111.50852, 47.536858, 25.951817, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 9.610471, 44.42759, 80.45889, 128.00555, 165.56154, 206.4257, 197.42627, 142.96873, 97.0, 50.0, 53.0, 40.953423, 40.619843, 26.552896, 15.716867, 5.9554276, 22.0, 15.935498, 0.0, 0.0, 0.0], accuracy: 0.01))
    }
}
