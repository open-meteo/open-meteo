import Foundation
import CHelper

/**
 Support routines to use the NREL Solar Posiition Altorithm SPA
 https://www.nrel.gov/docs/fy08osti/34302.pdf
 */
struct SolarPositionAlgorithm {
    static func sunPosition(timerange: TimerangeDt) -> (declination: [Float], equationOfTime: [Float]) {
        var declination = [Float]()
        var equationOfTime = [Float]()
        declination.reserveCapacity(timerange.count)
        equationOfTime.reserveCapacity(timerange.count)
        
        for time in timerange {
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
                longitude: 0, latitude: 0, elevation: 0, pressure: 1050, temperature: 20, slope: 0, azm_rotation: 0, atmos_refract: 0, function: 0, jd: 0, jc: 0, jde: 0, jce: 0, jme: 0, l: 0, b: 0, r: 0, theta: 0, beta: 0, x0: 0, x1: 0, x2: 0, x3: 0, x4: 0, del_psi: 0, del_epsilon: 0, epsilon0: 0, epsilon: 0, del_tau: 0, lamda: 0, nu0: 0, nu: 0, alpha: 0, delta: 0, h: 0, xi: 0, del_alpha: 0, delta_prime: 0, alpha_prime: 0, h_prime: 0, e0: 0, del_e: 0, e: 0, eot: 0, srha: 0, ssha: 0, sta: 0, zenith: 0, azimuth_astro: 0, azimuth: 0, incidence: 0, suntransit: 0, sunrise: 0, sunset: 0)
            
            spa_calculate(&a)
            declination.append(Float(a.delta))
            equationOfTime.append(Float(a.eot))
        }

        return (declination, equationOfTime)
    }
}

/**
 Fast lookup table for solar position
 */
struct SolarPositonFastLookup {
    let declination: [Float]
    let equationOfTime: [Float]
    
    static let referenceTime = TimerangeDt(start: Timestamp(1900), to: Timestamp(2100), dtSeconds: 86400)
    
    public init() {
        (declination, equationOfTime) = SolarPositionAlgorithm.sunPosition(timerange: Self.referenceTime)
    }
}
