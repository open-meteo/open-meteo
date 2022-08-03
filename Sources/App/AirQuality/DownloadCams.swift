import Foundation
import Vapor


enum CamsDomain: String {
    case global
    case european
    
    /// count of forecast hours
    var forecastHours: Int {
        switch self {
        case .global:
            return 121
        case .european:
            return 97
        }
    }
    
    var lastRun: Int {
        return 0
    }
}

enum CamsVariable: String, CaseIterable {
    case pm10
    case pm2_5
    case pm1
    case dust
    case carbon_monoxide
    case nitrogen_dioxide
    case ozone
    case sulphur_dioxide
    case uv
    case alder_pollen
    case birch_pollen
    case grass_pollen
    case mugwort_pollen
    case olive_pollen
    case ragweed_pollen
    
    /// Name of the variable in the CDS API, if available
    func getApiName(domain: CamsDomain) -> String? {
        switch domain {
        case .global:
            switch self {
            case .pm10:
                return "particulate_matter_10um"
            case .pm2_5:
                return "particulate_matter_2.5um"
            case .pm1:
                return "particulate_matter_1um"
            case .dust:
                return "dust_aerosol_optical_depth_550nm"
            case .carbon_monoxide:
                return "total_column_carbon_monoxide"
            case .nitrogen_dioxide:
                return "total_column_nitrogen_dioxide"
            case .ozone:
                return "total_column_ozone"
            case .sulphur_dioxide:
                return "total_column_sulphur_dioxide"
            case .uv:
                return "uv_biologically_effective_dose"
            case .alder_pollen:
                return nil
            case .birch_pollen:
                return nil
            case .grass_pollen:
                return nil
            case .mugwort_pollen:
                return nil
            case .olive_pollen:
                return nil
            case .ragweed_pollen:
                return nil
            }
        case .european:
            switch self {
            case .pm10:
                return "particulate_matter_10um"
            case .pm2_5:
                return "particulate_matter_2.5um"
            case .pm1:
                return "particulate_matter_1um"
            case .dust:
                return rawValue
            case .carbon_monoxide:
                return rawValue
            case .nitrogen_dioxide:
                return rawValue
            case .ozone:
                return rawValue
            case .sulphur_dioxide:
                return rawValue
            case .uv:
                return nil
            case .alder_pollen:
                return rawValue
            case .birch_pollen:
                return rawValue
            case .grass_pollen:
                return rawValue
            case .mugwort_pollen:
                return rawValue
            case .olive_pollen:
                return rawValue
            case .ragweed_pollen:
                return rawValue
            }
        }
    }
}


struct DownloadCamsCommand: Command {
    struct Signature: CommandSignature {
        @Argument(name: "domain")
        var domain: String

        @Option(name: "run")
        var run: String?

        @Flag(name: "skip-existing")
        var skipExisting: Bool
        
        @Option(name: "only-variables")
        var onlyVariables: String?
    }

    var help: String {
        "Download global and european CAMS air quality forecasts"
    }
    
    func run(using context: CommandContext, signature: Signature) throws {
        guard let domain = CamsDomain.init(rawValue: signature.domain) else {
            fatalError("Invalid domain '\(signature.domain)'")
        }
        
        let run = signature.run.map {
            guard let run = Int($0) else {
                fatalError("Invalid run '\($0)'")
            }
            return run
        } ?? domain.lastRun
        
        let onlyVariables: [CamsVariable]? = signature.onlyVariables.map {
            $0.split(separator: ",").map {
                guard let variable = CamsVariable(rawValue: String($0)) else {
                    fatalError("Invalid variable '\($0)'")
                }
                return variable
            }
        }
        
        let logger = context.application.logger
        let date = Timestamp.now().with(hour: run)
        logger.info("Downloading domain '\(domain.rawValue)' run '\(date.iso8601_YYYY_MM_dd_HH_mm)'")
        
        let variables = onlyVariables ?? CamsVariable.allCases
        try download(logger: logger, domain: domain, run: date, skipFilesIfExisting: signature.skipExisting, variables: variables)
        try convert(logger: logger, domain: domain, run: date, variables: variables)
    }
    
    /// Download all timesteps and preliminarily covnert it to compressed files
    func download(logger: Logger, domain: CamsDomain, run: Timestamp, skipFilesIfExisting: Bool, variables: [CamsVariable]) throws {
        
    }
    
    /// Process each variable and update time-series optimised files
    func convert(logger: Logger, domain: CamsDomain, run: Timestamp, variables: [CamsVariable]) throws {
        
    }
}
