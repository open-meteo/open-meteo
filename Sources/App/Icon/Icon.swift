import Foundation
import NIOConcurrencyHelpers
import SwiftPFor2D


/// Singleton class to keep state for icon domains. E.g. keep files open for fast access.
/*final class IconDomain {
    static let icon = IconDomain(.icon)
    static let iconEu = IconDomain(.iconEu)
    static let iconD2 = IconDomain(.iconD2)
    
    let domain: IconDomains
    
    public let elevationFile: OmFileReader
    
    private let inittimeLock = Lock()
    private var inittime = 0
    private var inittimeUpdate: TimeInterval = 0
    
    private init(_ domain: IconDomains) {
        self.domain = domain
        self.elevationFile = try! OmFileReader(file: domain.surfaceElevationFileOm)
    }
    
    /// The last updated init time as unix timestamp. Read from init file. Updated every 10 seconds.
    func getInitTime() -> Int {
        inittimeLock.withLock {
            let now = Date().timeIntervalSince1970
            if inittimeUpdate + 10 >= now {
                return inittime
            }
            let timeString = try! String(contentsOfFile: domain.initFileNameOm, encoding: .utf8).replacingOccurrences(of: "\n", with: "")
            inittime = Int(timeString)!
            inittimeUpdate = now
            return inittime
        }
    }
    
    /// Get the start and end time of the current run
    func getInitTimerange() -> Range<Timestamp> {
        let initTime = getInitTime()
        let run = initTime / 3600 % 24
        var nHours = domain.nForecastHours(run: run)
        if domain == .icon && nHours == 121 {
            // 6z und 12z icon runs are only 120 instead of 180 fcst hours
            nHours += 60 - 6
        }
        let end = initTime + nHours * 3600
        let start = end - (domain.omFileLength + 24) * 3600
        return Timestamp(start) ..< Timestamp(end)
    }
}*/

/// Static information about a domain
enum IconDomains: String, CaseIterable, GenericDomain {
    /// hourly data until forecast hour 78, then 3 h until 180
    case icon
    case iconEu = "icon-eu"
    case iconD2 = "icon-d2"
    
    
    private static var iconElevataion = try? OmFileReader(file: Self.icon.surfaceElevationFileOm)
    private static var iconD2Elevataion = try? OmFileReader(file: Self.iconD2.surfaceElevationFileOm)
    private static var iconEuElevataion = try? OmFileReader(file: Self.iconEu.surfaceElevationFileOm)
    
    var dtSeconds: Int {
        return 3600
    }
    
    var elevationFile: OmFileReader? {
        switch self {
        case .icon:
            return Self.iconElevataion
        case .iconEu:
            return Self.iconEuElevataion
        case .iconD2:
            return Self.iconD2Elevataion
        }
    }

    var omfileDirectory: String {
        return "./data/omfile-\(rawValue)/"
    }
    var downloadDirectory: String {
        return "./data/\(rawValue)/"
    }
    
    /// Filename of the surface elevation file
    var surfaceElevationFileOm: String {
        "\(omfileDirectory)HSURF.om"
    }
    
    /// How many hourly timesteps to keep in each compressed chunk
    var omFileLength: Int {
        // icon-d2 120
        // eu 192
        // global 253
        nForecastHours(run: 0) + 3*24
    }
    
    /// Number  of forecast hours per run
    func nForecastHours(run: Int) -> Int {
        switch self {
        case .icon:
            if  run == 6 || run == 18 {
                return 120+1
            } else {
                return 180+1
            }
        case .iconEu: return 120+1
        case .iconD2: return 48+1
        }
    }
    
    /// Numer of avaialble forecast steps differs from run
    /// E.g. icon global 0z has 180 as a last value, but 6z only 120
    func getDownloadForecastSteps(run: Int) -> [Int] {
        switch self {
        case .icon:
            if  run == 6 || run == 18  {
                // only up to 120
                return Array(0...78) + Array(stride(from: 81, through: 120, by: 3))
            } else {
                // full 180
                return Array(0...78) + Array(stride(from: 81, through: 180, by: 3))
            }
        case .iconEu: return Array(0...78) + Array(stride(from: 81, through: 120, by: 3))
        case .iconD2: return Array(0...48)
        }
    }

    var grid: RegularGrid {
        switch self {
        case .icon: return RegularGrid(nx: 2879, ny: 1441, latMin: -90, lonMin: -180, dx: 0.125, dy: 0.125)
        case .iconEu: return RegularGrid(nx: 1097, ny: 657, latMin: 29.5, lonMin: -23.5, dx: 0.0625, dy: 0.0625)
        case .iconD2: return RegularGrid(nx: 1215, ny: 746, latMin: 43.18, lonMin: -3.94, dx: 0.02, dy: 0.02)
        }
    }
    
    /// name in the filenames
    var region: String {
        switch self {
        case .icon: return "global"
        case .iconEu: return "europe"
        case .iconD2: return "germany"
        }
    }
    
    var variables: [IconVariable] {
        return IconVariable.allCases
    }
    
    var initFileNameOm: String {
        return "\(omfileDirectory)init.txt"
    }
    
    /// model level standard heights, full levels
    /// icon wind level 1-90 88=98m, 87-174m
    /// icon-eu 1-60 58,57
    /// icon-d2 1-65.... 63=78m, 62=126m
    var numberOfModelFullLevels: Int {
        switch self {
        case .icon:
            return 90
        case .iconEu:
            return 60
        case .iconD2:
            return 65
        }
    }
}

enum IconVariable: String, CaseIterable, Codable, GenericVariable {
    case temperature_2m
    case cloudcover // cloudcover total
    case cloudcover_low
    case cloudcover_mid
    case cloudcover_high
    
    /// pressure reduced to sea level
    case pressure_msl

    case relativehumidity_2m
    
    /// Total precipitation accumulated sinve model start. First hour is always 0.
    case precipitation

    /// weather interpretation (WMO) https://www.dwd.de/DWD/forschung/nwv/fepub/icon_database_main.pdf page 47
    /// Significant weather of the last hour. The predicted weather will be diagnosed hourly at each model grid point and coded as a key number. The latter is called ww-code and represents weather phenomena within the last hour. The interpretation of such weather phenomena from raw model output relies on an independent post-processing method. This technique applies a number of thresholding processes based on WMO criteria. Therefore, a couple of ww-codes may differ from the direct model output (e.g. ww-category snow vs. SNOW_GSP/SNOW_CON). Due to limitations in temporal and spatial resolution, not all ww-codes as defined by the WMO criteria can be determined. However, the simulated ww-code is able to take the following values: no significant weather/ cloud cover (0, 1, 2, 3), fog (45, 48), drizzle (51, 53, 55, 56, 57), rain (61, 63, 65, 66, 67), solid precip not in showers (71, 73, 75, 77), showery precip (liquid & solid) (80, 81, 82, 85, 86), thunderstorm (95, 96, 99 (only ICON- D2)) (see also Table 7.1).
    case weathercode

    case v_10m

    case u_10m
    
    case v_80m
    case u_80m
    case v_120m
    case u_120m
    case v_180m
    case u_180m
    
    /// Soil temperature
    case soil_temperature_0cm
    case soil_temperature_6cm
    case soil_temperature_18cm
    case soil_temperature_54cm
    
    /// Soil moisture
    /// The model soil moisture data was converted from kg/m2 to m3/m3 by using the formula SM[m3/m3] = SM[kg/m2] * 0.001 * 1/d, where d is the thickness of the soil layer in meters. The factor 0.001 is due to the assumption that 1kg of water represents 1000cm3, which is 0.001m3.
    case soil_moisture_0_1cm
    case soil_moisture_1_3cm
    case soil_moisture_3_9cm
    case soil_moisture_9_27cm
    case soil_moisture_27_81cm
    
    /// snow depth in meters
    case snow_depth
    
    /// TODO add support for only icon-eu/d2 variables. https://github.com/open-meteo/open-meteo/issues/50 
    //case SNOWLMT
    
    /// Ceiling is that height above MSL (in m), where the large scale cloud coverage (more precise: scale and sub-scale, but without the convective contribution) first exceeds 50% when starting from ground.
    //case ceiling // not in global
    
    /// Sensible heat net flux at surface (average since model start)
    case sensible_heatflux
    
    /// Latent heat net flux at surface (average since model start)
    case latent_heatflux
    
    /// Convective rain in mm
    case showers
    
    /// Large scale rain in mm
    case rain
    
    /// convective snowfall
    case snowfall_convective_water_equivalent
    
    /// largescale snowfall
    case snowfall_water_equivalent
    
    /// Convective available potential energy
    //case cape_con
    //case tke

    /// vmax has no timstep 0
    /// Maximum wind gust at 10m above ground. It is diagnosed from the turbulence state in the atmospheric boundary layer, including a potential enhancement by the SSO parameterization over mountainous terrain.
    /// In the presence of deep convection, it contains an additional contribution due to convective gusts.
    /// Maxima are collected over hourly intervals on all domains. (Prior to 2015-07-07 maxima were collected over 3-hourly intervals on the global grid.)
    case windgusts_10m
    
    /// Height of snow fall limit above MSL. It is defined as the height where the wet bulb temperature Tw first exceeds 1.3◦C (scanning mode from top to bottom).
    /// If this threshold is never reached within the entire atmospheric column, SNOWLMT is undefined (GRIB2 bitmap).
    // case snowlmt not in icon global
    
    /// Height of the 0◦ C isotherm above MSL. In case of multiple 0◦ C isotherms, HZEROCL contains the uppermost one.
    /// If the temperature is below 0◦ C throughout the entire atmospheric column, HZEROCL is set equal to the topography height (fill value).
    case freezinglevel_height
    
    /// Dew point temperature at 2m above ground, i.e. the temperature to which the air must be cooled, keeping its vapour pressure e constant, such that e equals the saturation (or equilibrium) vapour pressure es.
    ///        es(Td) = e
    case dewpoint_2m
    
    /// Downward solar diffuse radiation flux at the surface, averaged over forecast time.
    case diffuse_radiation
    
    /// Downward solar direct radiation flux at the surface, averaged over forecast time. This quantity is not directly provided by the radiation scheme.
    /// Diffuse + direct it still valid as the total shortwave radiation
    case direct_radiation
    
    /// Vmax and precip always are empty in the first hour. Weather codes differ a lot in hour 0.
    var skipHour0: Bool {
        switch self {
        case .precipitation: return true
        case .windgusts_10m: return true
        case .sensible_heatflux: return true
        case .latent_heatflux: return true
        case .direct_radiation: return true
        case .diffuse_radiation: return true
        case .weathercode: return true
        default: return false
        }
    }
    
    var scalefactor: Float {
        switch self {
        case .temperature_2m: return 20
        case .cloudcover: return 1
        case .cloudcover_low: return 1
        case .cloudcover_mid: return 1
        case .cloudcover_high: return 1
        case .relativehumidity_2m: return 1
        case .precipitation: return 10
        case .weathercode: return 1
        case .v_10m: return 10
        case .u_10m: return 10
        case .v_80m: return 10
        case .u_80m: return 10
        case .v_120m: return 10
        case .u_120m: return 10
        case .v_180m: return 10
        case .u_180m: return 10
        case .soil_temperature_0cm: return 20
        case .soil_temperature_6cm: return 20
        case .soil_temperature_18cm: return 20
        case .soil_temperature_54cm: return 20
        case .soil_moisture_0_1cm: return 1000
        case .soil_moisture_1_3cm: return 1000
        case .soil_moisture_3_9cm: return 1000
        case .soil_moisture_9_27cm: return 1000
        case .soil_moisture_27_81cm: return 1000
        case .snow_depth: return 100 // 1cm res
        case .sensible_heatflux: return 0.144
        case .latent_heatflux: return 0.144 // round watts to 7.. results in 0.01 resolution in evpotrans
        case .windgusts_10m: return 10
        case .freezinglevel_height:  return 0.1 // zero height 10 meter resolution
        case .dewpoint_2m: return 20
        case .diffuse_radiation: return 1
        case .direct_radiation: return 1
        case .showers: return 10
        case .rain: return 10
        case .pressure_msl: return 10
        case .snowfall_convective_water_equivalent: return 10
        case .snowfall_water_equivalent: return 10
        }
    }
    
    /// unit stored on disk... or directly read by low level reads
    var unit: SiUnit {
        switch self {
        case .temperature_2m: return .celsius
        case .cloudcover: return .percent
        case .cloudcover_low: return .percent
        case .cloudcover_mid: return .percent
        case .cloudcover_high: return .percent
        case .relativehumidity_2m: return .percent
        case .precipitation: return .millimeter
        case .weathercode: return .wmoCode
        case .v_10m: return .ms
        case .u_10m: return .ms
        case .v_80m: return .ms
        case .u_80m: return .ms
        case .v_120m: return .ms
        case .u_120m: return .ms
        case .v_180m: return .ms
        case .u_180m: return .ms
        case .soil_temperature_0cm: return .celsius
        case .soil_temperature_6cm: return .celsius
        case .soil_temperature_18cm: return .celsius
        case .soil_temperature_54cm: return .celsius
        case .soil_moisture_0_1cm: return .qubicMeterPerQubicMeter
        case .soil_moisture_1_3cm: return .qubicMeterPerQubicMeter
        case .soil_moisture_3_9cm: return .qubicMeterPerQubicMeter
        case .soil_moisture_9_27cm: return .qubicMeterPerQubicMeter
        case .soil_moisture_27_81cm: return .qubicMeterPerQubicMeter
        case .snow_depth: return .meter
        case .sensible_heatflux: return .wattPerSquareMeter
        case .latent_heatflux: return .wattPerSquareMeter
        case .showers: return .millimeter
        case .rain: return .millimeter
        case .windgusts_10m: return .ms
        case .freezinglevel_height: return .meter
        case .dewpoint_2m: return .celsius
        case .diffuse_radiation: return .wattPerSquareMeter
        case .snowfall_convective_water_equivalent: return .millimeter
        case .snowfall_water_equivalent: return .millimeter
        case .direct_radiation: return .wattPerSquareMeter
        case .pressure_msl: return .hectoPascal
        }
    }
    
    var isAveragedOverForecastTime: Bool {
        switch self {
        case .diffuse_radiation: return true
        case .direct_radiation: return true
        case .sensible_heatflux: return true
        case .latent_heatflux: return true
        default: return false
        }
    }
    
    /// Soil moisture or snow depth are cumulative processes and have offests if mutliple models are mixed
    var requiresOffsetCorrectionForMixing: Bool {
        switch self {
        case .soil_moisture_0_1cm: return true
        case .soil_moisture_1_3cm: return true
        case .soil_moisture_3_9cm: return true
        case .soil_moisture_9_27cm: return true
        case .soil_moisture_27_81cm: return true
        case .snow_depth: return true
        default: return false
        }
    }
    
    var interpolationType: InterpolationType {
        switch self {
        case .temperature_2m: return .hermite
        case .cloudcover: return .linear
        case .cloudcover_low: return .linear
        case .cloudcover_mid: return .linear
        case .cloudcover_high: return .linear
        case .relativehumidity_2m: return .hermite
        case .precipitation: return .linear
        case .weathercode: return .nearest
        case .v_10m: return .hermite
        case .u_10m: return .hermite
        case .snow_depth: return .linear
        case .sensible_heatflux: return .hermite_backwards_averaged
        case .latent_heatflux: return .hermite_backwards_averaged
        case .windgusts_10m: return .linear
        case .freezinglevel_height: return .hermite
        case .dewpoint_2m: return .hermite
        case .diffuse_radiation: return .solar_backwards_averaged
        case .direct_radiation: return .solar_backwards_averaged
        case .soil_temperature_0cm: return .hermite
        case .soil_temperature_6cm: return .hermite
        case .soil_temperature_18cm: return .hermite
        case .soil_temperature_54cm: return .hermite
        case .soil_moisture_0_1cm: return .hermite
        case .soil_moisture_1_3cm: return .hermite
        case .soil_moisture_3_9cm: return .hermite
        case .soil_moisture_9_27cm: return .hermite
        case .soil_moisture_27_81cm: return .hermite
        case .v_80m: return .hermite
        case .u_80m: return .hermite
        case .v_120m: return .hermite
        case .u_120m: return .hermite
        case .v_180m: return .hermite
        case .snowfall_convective_water_equivalent: return .linear
        case .snowfall_water_equivalent: return .linear
        case .u_180m: return .hermite
        case .showers: return .linear
        case .pressure_msl: return .hermite
        case .rain: return .linear
        }
    }
    
    var isAccumulatedSinceModelStart: Bool {
        switch self {
        case .snowfall_water_equivalent: fallthrough
        case .snowfall_convective_water_equivalent: fallthrough
        case .precipitation: fallthrough
        case .showers: fallthrough
        case .rain: return true
        default: return false
        }
    }
    
    func getVarAndLevel(domain: IconDomains) -> (variable: String, cat: String, level: Int?) {
        switch self {
        case .soil_temperature_0cm: return ("t_so", "soil-level", 0)
        case .soil_temperature_6cm: return ("t_so", "soil-level", 6)
        case .soil_temperature_18cm: return ("t_so", "soil-level", 18)
        case .soil_temperature_54cm: return ("t_so", "soil-level", 54)
        case .soil_moisture_0_1cm: return ("w_so", "soil-level", 0)
        case .soil_moisture_1_3cm: return ("w_so", "soil-level", 1)
        case .soil_moisture_3_9cm: return ("w_so", "soil-level", 3)
        case .soil_moisture_9_27cm: return ("w_so", "soil-level", 9)
        case .soil_moisture_27_81cm: return ("w_so", "soil-level", 27)
        case .u_80m: return ("u", "model-level", domain.numberOfModelFullLevels-2)
        case .v_80m: return ("v", "model-level", domain.numberOfModelFullLevels-2)
        case .u_120m: return ("u", "model-level", domain.numberOfModelFullLevels-3)
        case .v_120m: return ("v", "model-level", domain.numberOfModelFullLevels-3)
        case .u_180m: return ("u", "model-level", domain.numberOfModelFullLevels-4)
        case .v_180m: return ("v", "model-level", domain.numberOfModelFullLevels-4)
        default: return (omFileName, "single-level", nil)
        }
    }
    
    /// Name in dwd filenames
    var omFileName: String {
        switch self {
        case .temperature_2m: return "t_2m"
        case .cloudcover: return "clct"
        case .cloudcover_low: return "clcl"
        case .cloudcover_mid: return "clcm"
        case .cloudcover_high: return "clch"
        case .relativehumidity_2m: return "relhum_2m"
        case .precipitation: return "tot_prec"
        case .weathercode: return "ww"
        case .v_10m: return "v_10m"
        case .u_10m: return "u_10m"
        case .v_80m: return "v_80m"
        case .u_80m: return "u_80m"
        case .v_120m: return "v_120m"
        case .u_120m: return "u_120m"
        case .v_180m: return "v_180m"
        case .u_180m: return "u_180m"
        case .soil_temperature_0cm: return "t_so_0"
        case .soil_temperature_6cm: return "t_so_6"
        case .soil_temperature_18cm: return "t_so_18"
        case .soil_temperature_54cm: return "t_so_54"
        case .soil_moisture_0_1cm: return "w_so_0"
        case .soil_moisture_1_3cm: return "w_so_1"
        case .soil_moisture_3_9cm: return "w_so_3"
        case .soil_moisture_9_27cm: return "w_so_9"
        case .soil_moisture_27_81cm: return "w_so_27"
        case .snow_depth: return "h_snow"
        case .sensible_heatflux: return "ashfl_s"
        case .latent_heatflux: return "alhfl_s"
        case .showers: return "rain_con"
        case .rain: return "rain_gsp"
        case .windgusts_10m: return "vmax_10m"
        case .freezinglevel_height: return "hzerocl"
        case .dewpoint_2m: return "td_2m"
        case .pressure_msl: return "pmsl"
        case .diffuse_radiation: return "aswdifd_s"
        case .direct_radiation: return "aswdir_s"
        case .snowfall_convective_water_equivalent: return "snow_con"
        case .snowfall_water_equivalent: return "snow_gsp"
        }
    }
    
    var interpolation: ReaderInterpolation {
        fatalError("Icon interpolation not required for reader. Already 1h")
    }
    
    var isElevationCorrectable: Bool {
        return self == .temperature_2m || self == .dewpoint_2m
    }
}


enum InterpolationType {
    // Simple linear interpolation
    case linear
    // Just copy the next value
    case nearest
    // Use solar radiation interpolation
    case solar_backwards_averaged
    // Use hemite interpolation
    case hermite
    /// Hermite interpolation but for backward averaged data. Used for latent heat flux
    case hermite_backwards_averaged
}
