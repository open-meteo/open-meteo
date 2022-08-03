import Foundation
import Vapor


enum CamsDomain: String {
    case cams_global
    case cams_european
    
    /// count of forecast hours
    var forecastHours: Int {
        switch self {
        case .cams_global:
            return 121
        case .cams_european:
            return 97
        }
    }
    
    var lastRun: Int {
        return 0
    }
    
    var omfileDirectory: String {
        return "./data/omfile-\(rawValue)/"
    }
    var downloadDirectory: String {
        return "./data/\(rawValue)/"
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
        case .cams_global:
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
        case .cams_european:
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
        
        @Option(name: "cdskey", short: "k", help: "CDS API user and key like: 123456:8ec08f...")
        var cdskey: String?
    }

    var help: String {
        "Download global and european CAMS air quality forecasts"
    }
    
    func run(using context: CommandContext, signature: Signature) throws {
        guard let cdskey = signature.cdskey else {
            fatalError("cds key is required")
        }
        
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
        try download(logger: logger, domain: domain, run: date, skipFilesIfExisting: signature.skipExisting, variables: variables, cdskey: cdskey)
        try convert(logger: logger, domain: domain, run: date, variables: variables)
    }
    
    /// Download all timesteps and preliminarily covnert it to compressed files
    func download(logger: Logger, domain: CamsDomain, run: Timestamp, skipFilesIfExisting: Bool, variables: [CamsVariable], cdskey: String) throws {
        let apiRequest: String
        
        try FileManager.default.createDirectory(atPath: domain.downloadDirectory, withIntermediateDirectories: true)
        
        /// loop over each day, download data and convert it
        let tempPythonFile = "\(domain.downloadDirectory)download.py"
        
        let date = run.iso8601_YYYY_MM_dd
        
        switch domain {
        case .cams_global:
            apiRequest = """
                'cams-europe-air-quality-forecasts',
                    {
                        'model': 'ensemble',
                        'date': '\(date)/\(date)',
                        'format': 'netcdf',
                        'variable': [
                            'alder_pollen', 'birch_pollen', 'carbon_monoxide',
                            'dust', 'grass_pollen', 'mugwort_pollen',
                            'nitrogen_dioxide', 'olive_pollen', 'ozone',
                            'particulate_matter_10um', 'particulate_matter_2.5um', 'ragweed_pollen',
                            'sulphur_dioxide',
                        ],
                        'level': '0',
                        'type': 'forecast',
                        'time': '\(run.hour.zeroPadded(len: 2)):00',
                        'leadtime_hour': [\((0..<domain.forecastHours).map{"'\($0)',"})],
                    },
                    '\(domain.downloadDirectory)download.nc'
                """
        case .cams_european:
            apiRequest = """
                'cams-global-atmospheric-composition-forecasts',
                    {
                        'date': '\(date)/\(date)',
                        'type': 'forecast',
                        'format': 'grib',
                        'variable': [
                            'dust_aerosol_optical_depth_550nm', 'particulate_matter_10um', 'particulate_matter_1um',
                            'particulate_matter_2.5um', 'total_column_carbon_monoxide', 'total_column_nitrogen_dioxide',
                            'total_column_ozone', 'total_column_sulphur_dioxide', 'uv_biologically_effective_dose',
                        ],
                        'time': '\(run.hour.zeroPadded(len: 2)):00',
                        'leadtime_hour': [\((0..<domain.forecastHours).map{"'\($0)',"})],
                    },
                    '\(domain.downloadDirectory)download.grib'
                """
        }
        let pyCode = """
            import cdsapi

            c = cdsapi.Client(url="https://ads.atmosphere.copernicus.eu/api/v2", key="\(cdskey)", verify=True)
            try:
                c.retrieve(\(apiRequest))
            except Exception as e:
                if "Please, check that your date selection is valid" in str(e):
                    exit(70)
                raise e
            """
        
        try pyCode.write(toFile: tempPythonFile, atomically: true, encoding: .utf8)
        do {
            try Process.spawnOrDie(cmd: "python3", args: [tempPythonFile])
        } catch SpawnError.commandFailed(cmd: let cmd, returnCode: let code, args: let args) {
            if code == 70 {
                logger.info("Timestep \(timestamp.iso8601_YYYY_MM_dd) seems to be unavailable")
                fatalError()
            } else {
                throw SpawnError.commandFailed(cmd: cmd, returnCode: code, args: args)
            }
        }
    }
    
    /// Process each variable and update time-series optimised files
    func convert(logger: Logger, domain: CamsDomain, run: Timestamp, variables: [CamsVariable]) throws {
        
    }
}
