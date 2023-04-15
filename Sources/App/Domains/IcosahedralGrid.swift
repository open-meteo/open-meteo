import Foundation

/**
 Icosahedral grid definition from ICON model
 
 https://www.dwd.de/DWD/forschung/nwv/fepub/icon_database_main.pdf
 https://esrl.noaa.gov/gsd/nim/references/geometric_properties_of_the_icosahedral_hexagonal_grid_on_the_two_sphere.pdf
 */
struct IcosahedralGrid {
    /// Earth radius used in ICON in meters
    let earthRadius = 6.371229e6
    
    /// Initial root division into `n` sections
    let n: Int
    
    /// `k` bisection steps
    let k: Int
    
    /// Average grid resolution in meters
    var gridResolutionMeters: Float {
        5050e3 / (Float(n) * powf(2, Float(k)))
    }
    
    /// Number of grid cells
    var count: Int {
        20 * n*n * Int(pow(4,Double(k)))
    }
    
    public init(n: Int, k: Int) {
        self.n = n
        self.k = k
    }
}
