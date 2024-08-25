import Foundation
import CHelper

/**
 Solar position calculation based on the NREL Solar Position Algorithm SPA
 https://www.nrel.gov/docs/fy08osti/34302.pdf
 
 Only solar declination and equation of time are calculated.
 The Swift version is approx 5 times faster than C by skipping unnecessary calculations.
 Calculation of 50 years hourly solar position requires roughly 700ms.
 */
struct SolarPositionAlgorithm {
    /// Calculate solar position for a given timerange
    static func sunPosition(timerange: TimerangeDt) -> (declination: [Float], equationOfTime: [Float]) {
        var declination = [Float]()
        var equationOfTime = [Float]()
        declination.reserveCapacity(timerange.count)
        equationOfTime.reserveCapacity(timerange.count)
        
        let spa = SolarPositionAlgorithm()
        
        for time in timerange {
            /*let date = time.toComponents()
            var a = spa_data(
                year: Int32(date.year),
                month: Int32(date.month),
                day: Int32(date.day),
                hour: Int32(time.hour),
                minute: Int32(time.minute),
                second: Double(time.second),
                delta_ut1: 0,
                delta_t: 60,
                timezone: 0,
                longitude: 0, latitude: 0, elevation: 0, pressure: 1050, temperature: 20,
                slope: 0, azm_rotation: 0, atmos_refract: 0.5667, function: Int32(SPA_ZA_RTS),
                jd: 0, jc: 0, jde: 0, jce: 0, jme: 0, l: 0, b: 0, r: 0, theta: 0, beta: 0,
                x0: 0, x1: 0, x2: 0, x3: 0, x4: 0, del_psi: 0, del_epsilon: 0, epsilon0: 0,
                epsilon: 0, del_tau: 0, lamda: 0, nu0: 0, nu: 0, alpha: 0, delta: 0, h: 0, xi: 0,
                del_alpha: 0, delta_prime: 0, alpha_prime: 0, h_prime: 0, e0: 0, del_e: 0, e: 0,
                eot: 0, srha: 0, ssha: 0, sta: 0, zenith: 0, azimuth_astro: 0, azimuth: 0, incidence: 0,
                suntransit: 0, sunrise: 0, sunset: 0)
            
            guard spa_calculate(&a) == 0 else {
                fatalError("SPA failed")
            }*/
            
            let a = spa.calculate(julianDate: time.julianDate)
            
            declination.append(Float(a.delta))
            equationOfTime.append(Float(a.eot))
        }
        
        return (declination, equationOfTime)
    }
    
    /*static func zenith(lat: Float, lon: Float, time: Timestamp) -> Float {
     let date = time.toComponents()
     var a = spa_data(
     year: Int32(date.year),
     month: Int32(date.month),
     day: Int32(date.day),
     hour: Int32(time.hour),
     minute: Int32(time.minute),
     second: Double(time.second),
     delta_ut1: 0,
     delta_t: 60,
     timezone: 0,
     longitude: Double(lon), latitude: Double(lat), elevation: 0, pressure: 1050, temperature: 20,
     slope: 0, azm_rotation: 0, atmos_refract: 0.5667, function: Int32(SPA_ZA), jd: 0, jc: 0, jde: 0,
     jce: 0, jme: 0, l: 0, b: 0, r: 0, theta: 0, beta: 0, x0: 0, x1: 0, x2: 0, x3: 0, x4: 0, del_psi: 0,
     del_epsilon: 0, epsilon0: 0, epsilon: 0, del_tau: 0, lamda: 0, nu0: 0, nu: 0, alpha: 0, delta: 0,
     h: 0, xi: 0, del_alpha: 0, delta_prime: 0, alpha_prime: 0, h_prime: 0, e0: 0, del_e: 0, e: 0, eot: 0,
     srha: 0, ssha: 0, sta: 0, zenith: 0, azimuth_astro: 0, azimuth: 0, incidence: 0, suntransit: 0, sunrise: 0,
     sunset: 0)
     
     guard spa_calculate(&a) == 0 else {
     fatalError("SPA failed")
     }
     print(a)
     return Float(a.zenith)
     }*/
    
    @inlinable
    func julian_ephemeris_day(jd: Double, deltaT: Double) -> Double {
        return jd + deltaT / 86400.0
    }
    
    @inlinable
    func julian_ephemeris_century(jde: Double) -> Double {
        return (jde - 2451545.0) / 36525.0
    }
    
    @inlinable
    func julian_ephemeris_millennium(jce: Double) -> Double {
        return jce / 10.0
    }
    
    @inlinable
    func limit_degrees(degrees: Double) -> Double {
        let degrees = degrees / 360.0
        var limited = 360.0*(degrees-floor(degrees))
        if (limited < 0) { limited += 360.0 }
        return limited
    }
    
    func limit_minutes(minutes: Double) -> Double {
        var limited=minutes
        
        if      (limited < -20.0) { limited += 1440.0 }
        else if (limited >  20.0) { limited -= 1440.0 }
        
        return limited
    }
    
    func earth_periodic_term_summation(terms: [[(Double, Double, Double)]], jme: Double) -> Double {
        return terms.enumerated().reduce(0, {
            $0 + $1.element.reduce(0, { $0 + $1.0 * cos($1.2 * jme + $1.1) }) *
            pow(jme, Double($1.offset))
        }) / 1.0e8
    }
    
    func earth_heliocentric_longitude(jme: Double) -> Double {
        let sum = earth_periodic_term_summation(terms: L_TERMS, jme: jme)
        return limit_degrees(degrees: sum.rad2deg)
    }
    
    func earth_heliocentric_latitude(jme: Double) -> Double {
        let sum = earth_periodic_term_summation(terms: B_TERMS, jme: jme)
        return sum.rad2deg
    }
    
    func earth_radius_vector(jme: Double) -> Double {
        let sum = earth_periodic_term_summation(terms: R_TERMS, jme: jme)
        return sum
    }
    
    @inlinable
    func geocentric_longitude(l: Double) -> Double {
        let theta = l + 180.0
        if (theta >= 360.0) {
            return theta - 360.0
        }
        return theta
    }
    
    @inlinable
    func geocentric_latitude(b: Double) -> Double {
        return -b
    }
    
    @inlinable
    func third_order_polynomial(_ a: Double, _ b: Double, _ c: Double, _ d: Double, _ x: Double) -> Double {
        let a2 = x * a + b
        let a1 = x * a2 + c
        return x * a1 + d
    }
    
    func mean_elongation_moon_sun(jce: Double) -> Double {
        return third_order_polynomial(1.0/189474.0, -0.0019142, 445267.11148, 297.85036, jce)
    }
    
    func mean_anomaly_sun(jce: Double) -> Double {
        return third_order_polynomial(-1.0/300000.0, -0.0001603, 35999.05034, 357.52772, jce)
    }
    
    func mean_anomaly_moon(jce: Double) -> Double {
        return third_order_polynomial(1.0/56250.0, 0.0086972, 477198.867398, 134.96298, jce)
    }
    
    func argument_latitude_moon(jce: Double) -> Double {
        return third_order_polynomial(1.0/327270.0, -0.0036825, 483202.017538, 93.27191, jce)
    }
    
    func ascending_longitude_moon(jce: Double) -> Double {
        return third_order_polynomial(1.0/450000.0, 0.0020708, -1934.136261, 125.04452, jce)
    }
    
    func nutation_longitude_and_obliquity(jce: Double, x: (Double, Double, Double, Double, Double)) -> (del_psi: Double, del_epsilon: Double) {
        var sum_psi: Double = 0
        var sum_epsilon: Double = 0
        
        for i in 0..<Y_TERMS.count {
            let a0 = x.0 * Y_TERMS[i].0
            let a1 = x.1 * Y_TERMS[i].1 + a0
            let a2 = x.2 * Y_TERMS[i].2 + a1
            let a3 = x.3 * Y_TERMS[i].3 + a2
            let a4 = x.4 * Y_TERMS[i].4 + a3
            let xy_term_sum = a4.deg2rad
            sum_psi     = (jce * PE_TERMS[i].1 + PE_TERMS[i].0) * sin(xy_term_sum) + sum_psi
            sum_epsilon = (jce * PE_TERMS[i].3 + PE_TERMS[i].2) * cos(xy_term_sum) + sum_epsilon
        }
        
        let del_psi     = sum_psi     / 36000000.0
        let del_epsilon = sum_epsilon / 36000000.0
        return (del_psi, del_epsilon)
    }
    
    func ecliptic_mean_obliquity(jme: Double) -> Double {
        let u = jme/10.0
        let a9 = u * 2.45 + 5.79
        let a8 = u * a9 + 27.87
        let a7 = u * a8 + 7.12
        let a6 = u * a7 + -39.05
        let a5 = u * a6 + -249.67
        let a4 = u * a5 + -51.38
        let a3 = u * a4 + 1999.25
        let a2 = u * a3 + -1.55
        let a1 = u * a2 + -4680.93
        return u * a1 + 84381.448
    }
    
    @inlinable
    func ecliptic_true_obliquity(delta_epsilon: Double, epsilon0: Double) -> Double {
        return delta_epsilon + epsilon0/3600.0
    }
    
    @inlinable
    func aberration_correction(r: Double) -> Double {
        return -20.4898 / (3600.0*r)
    }
    
    @inlinable
    func apparent_sun_longitude(theta: Double, delta_psi: Double, delta_tau: Double) -> Double {
        return theta + delta_psi + delta_tau
    }
    
    func geocentric_right_ascension(lamda: Double, epsilon: Double, beta: Double) -> Double {
        let lamda_rad   = lamda.deg2rad
        let epsilon_rad = epsilon.deg2rad
        
        return limit_degrees(degrees: atan2(sin(lamda_rad)*cos(epsilon_rad) - tan(beta.deg2rad)*sin(epsilon_rad), cos(lamda_rad)).rad2deg)
    }
    
    func geocentric_declination(beta: Double, epsilon: Double, lamda: Double) -> Double {
        let beta_rad    = (beta.deg2rad)
        let epsilon_rad = (epsilon.deg2rad)
        
        return (asin(sin(beta_rad)*cos(epsilon_rad) + cos(beta_rad)*sin(epsilon_rad)*sin(lamda.deg2rad))).rad2deg
    }
    
    func sun_mean_longitude(jme: Double) -> Double {
        let a4 = jme * -1/2000000.0 + -1/15300.0
        let a3 = jme * a4 + 1/49931.0
        let a2 = jme * a3 + 0.03032028
        let a1 = jme * a2 + 360007.6982779
        return limit_degrees(degrees: jme * a1 + 280.4664567)
    }
    
    func eot(m: Double, alpha: Double, del_psi: Double, epsilon: Double) -> Double {
        return limit_minutes(minutes: 4.0*(m - 0.0057183 - alpha + del_psi*cos(epsilon.deg2rad)))
    }
    
    
    func calculate(julianDate jd: Double) -> (delta: Double, eot: Double) {
        //double x[TERM_X_COUNT]
        let delta_t: Double = 60
        //spa->jc = julian_century(spa->jd)
        
        let jde = julian_ephemeris_day(jd: jd, deltaT: delta_t)
        let jce = julian_ephemeris_century(jde: jde)
        let jme = julian_ephemeris_millennium(jce: jce)
        
        let l = earth_heliocentric_longitude(jme: jme)
        let b = earth_heliocentric_latitude(jme: jme)
        let r = earth_radius_vector(jme: jme)
        
        let theta = geocentric_longitude(l: l)
        let beta  = geocentric_latitude(b: b)
        
        let x0 = mean_elongation_moon_sun(jce: jce)
        let x1 = mean_anomaly_sun(jce: jce)
        let x2 = mean_anomaly_moon(jce: jce)
        let x3 = argument_latitude_moon(jce: jce)
        let x4 = ascending_longitude_moon(jce: jce)
        
        let (del_psi, del_epsilon) = nutation_longitude_and_obliquity(jce: jce, x: (x0,x1,x2,x3,x4))
        
        let epsilon0 = ecliptic_mean_obliquity(jme: jme)
        let epsilon  = ecliptic_true_obliquity(delta_epsilon: del_epsilon, epsilon0: epsilon0)
        
        let del_tau  = aberration_correction(r: r)
        let lamda    = apparent_sun_longitude(theta: theta, delta_psi: del_psi, delta_tau: del_tau)
        //spa->nu0       = greenwich_mean_sidereal_time (spa->jd, spa->jc)
        //spa->nu        = greenwich_sidereal_time (spa->nu0, spa->del_psi, spa->epsilon)
        
        let alpha = geocentric_right_ascension(lamda: lamda, epsilon: epsilon, beta: beta)
        let delta = geocentric_declination(beta: beta, epsilon: epsilon, lamda: lamda)
        
        let m   = sun_mean_longitude(jme: jme)
        let eot = eot(m: m, alpha: alpha, del_psi: del_psi, epsilon: epsilon)
        
        return (delta, eot)
    }
    
    
    let L_TERMS: [[(Double, Double, Double)]] = [
        [
            (175347046.0,0,0),
            (3341656.0,4.6692568,6283.07585),
            (34894.0,4.6261,12566.1517),
            (3497.0,2.7441,5753.3849),
            (3418.0,2.8289,3.5231),
            (3136.0,3.6277,77713.7715),
            (2676.0,4.4181,7860.4194),
            (2343.0,6.1352,3930.2097),
            (1324.0,0.7425,11506.7698),
            (1273.0,2.0371,529.691),
            (1199.0,1.1096,1577.3435),
            (990,5.233,5884.927),
            (902,2.045,26.298),
            (857,3.508,398.149),
            (780,1.179,5223.694),
            (753,2.533,5507.553),
            (505,4.583,18849.228),
            (492,4.205,775.523),
            (357,2.92,0.067),
            (317,5.849,11790.629),
            (284,1.899,796.298),
            (271,0.315,10977.079),
            (243,0.345,5486.778),
            (206,4.806,2544.314),
            (205,1.869,5573.143),
            (202,2.458,6069.777),
            (156,0.833,213.299),
            (132,3.411,2942.463),
            (126,1.083,20.775),
            (115,0.645,0.98),
            (103,0.636,4694.003),
            (102,0.976,15720.839),
            (102,4.267,7.114),
            (99,6.21,2146.17),
            (98,0.68,155.42),
            (86,5.98,161000.69),
            (85,1.3,6275.96),
            (85,3.67,71430.7),
            (80,1.81,17260.15),
            (79,3.04,12036.46),
            (75,1.76,5088.63),
            (74,3.5,3154.69),
            (74,4.68,801.82),
            (70,0.83,9437.76),
            (62,3.98,8827.39),
            (61,1.82,7084.9),
            (57,2.78,6286.6),
            (56,4.39,14143.5),
            (56,3.47,6279.55),
            (52,0.19,12139.55),
            (52,1.33,1748.02),
            (51,0.28,5856.48),
            (49,0.49,1194.45),
            (41,5.37,8429.24),
            (41,2.4,19651.05),
            (39,6.17,10447.39),
            (37,6.04,10213.29),
            (37,2.57,1059.38),
            (36,1.71,2352.87),
            (36,1.78,6812.77),
            (33,0.59,17789.85),
            (30,0.44,83996.85),
            (30,2.74,1349.87),
            (25,3.16,4690.48)
        ],
        [
            (628331966747.0,0,0),
            (206059.0,2.678235,6283.07585),
            (4303.0,2.6351,12566.1517),
            (425.0,1.59,3.523),
            (119.0,5.796,26.298),
            (109.0,2.966,1577.344),
            (93,2.59,18849.23),
            (72,1.14,529.69),
            (68,1.87,398.15),
            (67,4.41,5507.55),
            (59,2.89,5223.69),
            (56,2.17,155.42),
            (45,0.4,796.3),
            (36,0.47,775.52),
            (29,2.65,7.11),
            (21,5.34,0.98),
            (19,1.85,5486.78),
            (19,4.97,213.3),
            (17,2.99,6275.96),
            (16,0.03,2544.31),
            (16,1.43,2146.17),
            (15,1.21,10977.08),
            (12,2.83,1748.02),
            (12,3.26,5088.63),
            (12,5.27,1194.45),
            (12,2.08,4694),
            (11,0.77,553.57),
            (10,1.3,6286.6),
            (10,4.24,1349.87),
            (9,2.7,242.73),
            (9,5.64,951.72),
            (8,5.3,2352.87),
            (6,2.65,9437.76),
            (6,4.67,4690.48)
        ],
        [
            (52919.0,0,0),
            (8720.0,1.0721,6283.0758),
            (309.0,0.867,12566.152),
            (27,0.05,3.52),
            (16,5.19,26.3),
            (16,3.68,155.42),
            (10,0.76,18849.23),
            (9,2.06,77713.77),
            (7,0.83,775.52),
            (5,4.66,1577.34),
            (4,1.03,7.11),
            (4,3.44,5573.14),
            (3,5.14,796.3),
            (3,6.05,5507.55),
            (3,1.19,242.73),
            (3,6.12,529.69),
            (3,0.31,398.15),
            (3,2.28,553.57),
            (2,4.38,5223.69),
            (2,3.75,0.98)
        ],
        [
            (289.0,5.844,6283.076),
            (35,0,0),
            (17,5.49,12566.15),
            (3,5.2,155.42),
            (1,4.72,3.52),
            (1,5.3,18849.23),
            (1,5.97,242.73)
        ],
        [
            (114.0,3.142,0),
            (8,4.13,6283.08),
            (1,3.84,12566.15)
        ],
        [
            (1,3.14,0)
        ]
    ]
    
    let B_TERMS: [[(Double, Double, Double)]] = [
        [
            (280.0,3.199,84334.662),
            (102.0,5.422,5507.553),
            (80,3.88,5223.69),
            (44,3.7,2352.87),
            (32,4,1577.34)
        ],
        [
            (9,3.9,5507.55),
            (6,1.73,5223.69)
        ]
    ]
    
    let R_TERMS: [[(Double, Double, Double)]] = [
        [
            (100013989.0,0,0),
            (1670700.0,3.0984635,6283.07585),
            (13956.0,3.05525,12566.1517),
            (3084.0,5.1985,77713.7715),
            (1628.0,1.1739,5753.3849),
            (1576.0,2.8469,7860.4194),
            (925.0,5.453,11506.77),
            (542.0,4.564,3930.21),
            (472.0,3.661,5884.927),
            (346.0,0.964,5507.553),
            (329.0,5.9,5223.694),
            (307.0,0.299,5573.143),
            (243.0,4.273,11790.629),
            (212.0,5.847,1577.344),
            (186.0,5.022,10977.079),
            (175.0,3.012,18849.228),
            (110.0,5.055,5486.778),
            (98,0.89,6069.78),
            (86,5.69,15720.84),
            (86,1.27,161000.69),
            (65,0.27,17260.15),
            (63,0.92,529.69),
            (57,2.01,83996.85),
            (56,5.24,71430.7),
            (49,3.25,2544.31),
            (47,2.58,775.52),
            (45,5.54,9437.76),
            (43,6.01,6275.96),
            (39,5.36,4694),
            (38,2.39,8827.39),
            (37,0.83,19651.05),
            (37,4.9,12139.55),
            (36,1.67,12036.46),
            (35,1.84,2942.46),
            (33,0.24,7084.9),
            (32,0.18,5088.63),
            (32,1.78,398.15),
            (28,1.21,6286.6),
            (28,1.9,6279.55),
            (26,4.59,10447.39)
        ],
        [
            (103019.0,1.10749,6283.07585),
            (1721.0,1.0644,12566.1517),
            (702.0,3.142,0),
            (32,1.02,18849.23),
            (31,2.84,5507.55),
            (25,1.32,5223.69),
            (18,1.42,1577.34),
            (10,5.91,10977.08),
            (9,1.42,6275.96),
            (9,0.27,5486.78)
        ],
        [
            (4359.0,5.7846,6283.0758),
            (124.0,5.579,12566.152),
            (12,3.14,0),
            (9,3.63,77713.77),
            (6,1.87,5573.14),
            (3,5.47,18849.23)
        ],
        [
            (145.0,4.273,6283.076),
            (7,3.92,12566.15)
        ],
        [
            (4,2.56,6283.08)
        ]
    ]
    
    ////////////////////////////////////////////////////////////////
    ///  Periodic Terms for the nutation in longitude and obliquity
    ////////////////////////////////////////////////////////////////
    
    let Y_TERMS: [(Double, Double, Double, Double, Double)] = [
        (0,0,0,0,1),
        (-2,0,0,2,2),
        (0,0,0,2,2),
        (0,0,0,0,2),
        (0,1,0,0,0),
        (0,0,1,0,0),
        (-2,1,0,2,2),
        (0,0,0,2,1),
        (0,0,1,2,2),
        (-2,-1,0,2,2),
        (-2,0,1,0,0),
        (-2,0,0,2,1),
        (0,0,-1,2,2),
        (2,0,0,0,0),
        (0,0,1,0,1),
        (2,0,-1,2,2),
        (0,0,-1,0,1),
        (0,0,1,2,1),
        (-2,0,2,0,0),
        (0,0,-2,2,1),
        (2,0,0,2,2),
        (0,0,2,2,2),
        (0,0,2,0,0),
        (-2,0,1,2,2),
        (0,0,0,2,0),
        (-2,0,0,2,0),
        (0,0,-1,2,1),
        (0,2,0,0,0),
        (2,0,-1,0,1),
        (-2,2,0,2,2),
        (0,1,0,0,1),
        (-2,0,1,0,1),
        (0,-1,0,0,1),
        (0,0,2,-2,0),
        (2,0,-1,2,1),
        (2,0,1,2,2),
        (0,1,0,2,2),
        (-2,1,1,0,0),
        (0,-1,0,2,2),
        (2,0,0,2,1),
        (2,0,1,0,0),
        (-2,0,2,2,2),
        (-2,0,1,2,1),
        (2,0,-2,0,1),
        (2,0,0,0,1),
        (0,-1,1,0,0),
        (-2,-1,0,2,1),
        (-2,0,0,0,1),
        (0,0,2,2,1),
        (-2,0,2,0,1),
        (-2,1,0,2,1),
        (0,0,1,-2,0),
        (-1,0,1,0,0),
        (-2,1,0,0,0),
        (1,0,0,0,0),
        (0,0,1,2,0),
        (0,0,-2,2,2),
        (-1,-1,1,0,0),
        (0,1,1,0,0),
        (0,-1,1,2,2),
        (2,-1,-1,2,2),
        (0,0,3,2,2),
        (2,-1,0,2,2),
    ]
    
    let PE_TERMS: [(Double, Double, Double, Double)] = [
        (-171996,-174.2,92025,8.9),
        (-13187,-1.6,5736,-3.1),
        (-2274,-0.2,977,-0.5),
        (2062,0.2,-895,0.5),
        (1426,-3.4,54,-0.1),
        (712,0.1,-7,0),
        (-517,1.2,224,-0.6),
        (-386,-0.4,200,0),
        (-301,0,129,-0.1),
        (217,-0.5,-95,0.3),
        (-158,0,0,0),
        (129,0.1,-70,0),
        (123,0,-53,0),
        (63,0,0,0),
        (63,0.1,-33,0),
        (-59,0,26,0),
        (-58,-0.1,32,0),
        (-51,0,27,0),
        (48,0,0,0),
        (46,0,-24,0),
        (-38,0,16,0),
        (-31,0,13,0),
        (29,0,0,0),
        (29,0,-12,0),
        (26,0,0,0),
        (-22,0,0,0),
        (21,0,-10,0),
        (17,-0.1,0,0),
        (16,0,-8,0),
        (-16,0.1,7,0),
        (-15,0,9,0),
        (-13,0,7,0),
        (-12,0,6,0),
        (11,0,0,0),
        (-10,0,5,0),
        (-8,0,3,0),
        (7,0,-3,0),
        (-7,0,0,0),
        (-7,0,3,0),
        (-7,0,3,0),
        (6,0,0,0),
        (6,0,-3,0),
        (6,0,-3,0),
        (-6,0,3,0),
        (-6,0,3,0),
        (5,0,0,0),
        (-5,0,3,0),
        (-5,0,3,0),
        (-5,0,3,0),
        (4,0,0,0),
        (4,0,0,0),
        (4,0,0,0),
        (-4,0,0,0),
        (-4,0,0,0),
        (-4,0,0,0),
        (3,0,0,0),
        (-3,0,0,0),
        (-3,0,0,0),
        (-3,0,0,0),
        (-3,0,0,0),
        (-3,0,0,0),
        (-3,0,0,0),
        (-3,0,0,0),
    ]
}

/**
 Fast lookup table for solar position
 */
public struct SolarPositonFastLookup {
    let declination: [Float]
    let equationOfTime: [Float]
    
    /// Sample solar declination every 20 days over 200 years. With hermite interpolation, the error is less than a second in sunrise/set
    /// Around 14k memory for each array
    static let referenceTime = TimerangeDt(start: Timestamp(1950,1,1), to: Timestamp(2050,1,1), dtSeconds: 86400*20)
    
    public init() {
        (declination, equationOfTime) = SolarPositionAlgorithm.sunPosition(timerange: Self.referenceTime)
    }
    
    /// Calculate position of timestamp in refreence time
    private func pos(_ time: Timestamp) -> (quotient: Int, fraction: Float) {
        let start = Self.referenceTime.range.lowerBound.timeIntervalSince1970
        let dt = Self.referenceTime.dtSeconds
        let count = Self.referenceTime.range.count
        let t = time.timeIntervalSince1970
        return (t - start).moduloPositive(count).moduloFraction(dt)
    }
    
    /// Get sun declination for a given time in DEGREE
    public func getDeclination(_ time: Timestamp) -> Float {
        let (index, fraction) = pos(time)
        return declination.interpolateHermiteRing(index, fraction)
    }
    
    /// Get sun equation of time for a given time in MINUTES
    public func getEquationOfTime(_ time: Timestamp) -> Float {
        let (index, fraction) = pos(time)
        return equationOfTime.interpolateHermiteRing(index, fraction)
    }
}

extension Double {
    @inlinable
    var rad2deg: Double {
        return (180.0 / .pi)*self
    }
    
    @inlinable
    var deg2rad: Double
    {
        return (.pi / 180.0)*self
    }
}

extension Timestamp {
    var julianDate: Double {
        return Double(timeIntervalSince1970) / 86400.0  + 2440587.5;
    }
}
