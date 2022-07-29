import Foundation
import Vapor

enum IconWaveDomain: String, Codable, LosslessStringConvertibleEnum {
    case gwam
    case ewam
    
    var dtSeconds: Int {
        switch self {
        case .gwam:
            return 3*3600
        case .ewam:
            return 3600
        }
    }
    
    var grid: RegularGrid {
        switch self {
        case .gwam:
            return RegularGrid(nx: 1440, ny: 699, latMin: -85.25, lonMin: -180, dx: 0.25, dy: 0.25)
        case .ewam:
            return RegularGrid(nx: 526, ny: 721, latMin: 30, lonMin: -10.5, dx: 0.1, dy: 0.05)
        }
    }
}

enum IconWaveVariable: String {
    case windspeed_10m
    case winddirection_10m
    case significant_wave_height
    case energy_wave_period
    case mean_wave_direction
    case wind_significant_wave_height
    case wind_wave_period
    case wind_wave_peak_period
    case wind_wave_direction
    case swell_significant_wave_height
    case swell_wave_period
    case swell_wave_peak_period
    case swell_wave_direction
    
    /// Name used on the dwd open data server
    var dwdName: String {
        switch self {
        case .windspeed_10m:
            return "sp_10m"
        case .winddirection_10m:
            return "dd_10m"
        case .significant_wave_height:
            return "swh"
        case .energy_wave_period:
            return "tm10"
        case .mean_wave_direction:
            return "mwd"
        case .wind_significant_wave_height:
            return "shww"
        case .wind_wave_period:
            return "mpww"
        case .wind_wave_peak_period:
            return "ppww"
        case .wind_wave_direction:
            return "mdww"
        case .swell_significant_wave_height:
            return "shts"
        case .swell_wave_period:
            return "mpts"
        case .swell_wave_peak_period:
            return "ppts"
        case .swell_wave_direction:
            return "mdts"
        }
    }
    
    /// Si unit
    var unit: SiUnit {
        switch self {
        case .windspeed_10m:
            return .ms
        case .winddirection_10m:
            return .degreeDirection
        case .significant_wave_height:
            return .meter
        case .energy_wave_period:
            return .second
        case .mean_wave_direction:
            return .degreeDirection
        case .wind_significant_wave_height:
            return .meter
        case .wind_wave_period:
            return .second
        case .wind_wave_peak_period:
            return .second
        case .wind_wave_direction:
            return .degreeDirection
        case .swell_significant_wave_height:
            return .meter
        case .swell_wave_period:
            return .second
        case .swell_wave_peak_period:
            return .second
        case .swell_wave_direction:
            return .degreeDirection
        }
    }
}

/**
 Download wave model form the german weather service
 https://www.dwd.de/DE/leistungen/opendata/help/modelle/legend_ICON_wave_EN_pdf.pdf?__blob=publicationFile&v=3
 */
struct DownloadIconWaveCommand: Command {
    struct Signature: CommandSignature {
        @Argument(name: "domain")
        var domain: IconWaveDomain

        @Argument(name: "run")
        var run: String

        @Flag(name: "skip-existing")
        var skipExisting: Bool
        
        @Option(name: "only-variable")
        var onlyVariable: String?
    }

    var help: String {
        "Download a specified wave model run"
    }
    
    func run(using context: CommandContext, signature: Signature) throws {
        
    }
    
    func download(logger: Logger, domain: IconWaveDomain, run: Timestamp, skipFilesIfExisting: Bool, variables: [IconWaveVariable]?) throws {
        
    }
}


