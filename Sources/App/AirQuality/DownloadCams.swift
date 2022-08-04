import Foundation
import Vapor
import SwiftNetCDF
import SwiftPFor2D


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
    
    var grid: RegularGrid {
        switch self {
        case .cams_global:
            return RegularGrid(nx: 900, ny: 451, latMin: -180, lonMin: -90, dx: 0.4, dy: 0.4)
        case .cams_european:
            return RegularGrid(nx: 700, ny: 400, latMin: 30.05, lonMin: -24.95, dx: 0.1, dy: 0.1)
        }
    }
}

enum CamsVariable: String, CaseIterable {
    case pm10
    case pm2_5
    case pm1
    case dust
    case aerosol_optical_depth
    case carbon_monoxide
    case nitrogen_dioxide
    case ozone
    case sulphur_dioxide
    case uv_index
    case alder_pollen
    case birch_pollen
    case grass_pollen
    case mugwort_pollen
    case olive_pollen
    case ragweed_pollen
    
    var unit: SiUnit {
        switch self {
        case .pm10:
            return .microgramsPerQuibicMeter
        case .pm2_5:
            return .microgramsPerQuibicMeter
        case .pm1:
            return .microgramsPerQuibicMeter
        case .dust:
            return .microgramsPerQuibicMeter
        case .aerosol_optical_depth:
            return .dimensionless
        case .carbon_monoxide:
            return .microgramsPerQuibicMeter
        case .nitrogen_dioxide:
            return .microgramsPerQuibicMeter
        case .ozone:
            return .microgramsPerQuibicMeter
        case .sulphur_dioxide:
            return .microgramsPerQuibicMeter
        case .uv_index:
            return .wattPerSquareMeter
        case .alder_pollen:
            return .microgramsPerQuibicMeter
        case .birch_pollen:
            return .microgramsPerQuibicMeter
        case .grass_pollen:
            return .microgramsPerQuibicMeter
        case .mugwort_pollen:
            return .microgramsPerQuibicMeter
        case .olive_pollen:
            return .microgramsPerQuibicMeter
        case .ragweed_pollen:
            return .microgramsPerQuibicMeter
        }
    }
    
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
            case .uv_index:
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
            case .aerosol_optical_depth:
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
            case .uv_index:
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
            case .aerosol_optical_depth:
                return nil
            case .ragweed_pollen:
                return rawValue
            }
        }
    }
    
    var scalefactor: Float {
        switch self {
        case .pm10:
            return 1
        case .pm2_5:
            return 1
        case .pm1:
            return 1
        case .dust:
            return 1
        case .aerosol_optical_depth:
            return 100
        case .carbon_monoxide:
            return 1
        case .nitrogen_dioxide:
            return 20
        case .ozone:
            return 1
        case .sulphur_dioxide:
            return 20
        case .uv_index:
            return 20
        case .alder_pollen:
            fatalError()
        case .birch_pollen:
            fatalError()
        case .grass_pollen:
            fatalError()
        case .mugwort_pollen:
            fatalError()
        case .olive_pollen:
            fatalError()
        case .ragweed_pollen:
            fatalError()
        }
    }
    
    func getCamsGlobalMeta() -> (gribname: String, isMultiLevel: Bool, scalefactor: Float)? {
        /// Air density on surface level. See https://confluence.ecmwf.int/display/UDOC/L60+model+level+definitions
        /// 1013.25/(288.09*287)*100
        let airDensitySurface: Float = 1.223803
        let massMixingToUgm3 = airDensitySurface * 1e9
        
        switch self {
        case .pm10:
            return ("pm10", false, 1e9)
        case .pm2_5:
            return ("pm2p5", false, 1e9)
        case .pm1:
            return ("pm1", false, 1e9)
        case .dust:
            return ("aermr06", true, massMixingToUgm3)
        case .carbon_monoxide:
            return ("co", true, massMixingToUgm3)
        case .nitrogen_dioxide:
            return ("no2", true, massMixingToUgm3)
        case .ozone:
            return ("go3", true, massMixingToUgm3)
        case .sulphur_dioxide:
            return ("so2", true, massMixingToUgm3)
        case .uv_index:
            return ("uvbed", false, 40)
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
        case .aerosol_optical_depth:
            return ("aod550", false, 1)
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
        
        @Option(name: "ftpuser", short: "u", help: "Username for the ECMWF CAMS FTP server")
        var ftpuser: String?
        
        @Option(name: "ftppassword", short: "p", help: "Password for the ECMWF CAMS FTP server")
        var ftppassword: String?
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
        
        // todo dust multi level
        
        let variables = onlyVariables ?? CamsVariable.allCases
        switch domain {
        case .cams_global:
            guard let ftpuser = signature.ftpuser else {
                fatalError("ftpuser is required")
            }
            guard let ftppassword = signature.ftppassword else {
                fatalError("ftppassword is required")
            }
            try downloadCamsGlobal(logger: logger, domain: domain, run: date, skipFilesIfExisting: signature.skipExisting, variables: variables, user: ftpuser, password: ftppassword)
        case .cams_european:
            guard let cdskey = signature.cdskey else {
                fatalError("cds key is required")
            }
            fatalError()
        }
        try convert(logger: logger, domain: domain, run: date, variables: variables)
    }
    
    /// Download from the ECMWF CAMS ftp server
    /// This data is also available via the ADC API, but queue times are 4 hours!
    func downloadCamsGlobal(logger: Logger, domain: CamsDomain, run: Timestamp, skipFilesIfExisting: Bool, variables: [CamsVariable], user: String, password: String) throws {
        
        try FileManager.default.createDirectory(atPath: domain.downloadDirectory, withIntermediateDirectories: true)
        
        let nx = domain.grid.nx
        let ny = domain.grid.ny
        
        let curl = Curl(logger: logger)
        let dateRun = run.format_YYYYMMddHH
        let ftpDir = "ftp://\(user):\(password)@dissemination.ecmwf.int/DATA/CAMS_NREALTIME/\(dateRun)/"
        
        for hour in 0..<domain.forecastHours {
            logger.info("Downloading hour \(hour)")
            
            for variable in variables {
                guard let meta = variable.getCamsGlobalMeta()else {
                    continue
                }
                if meta.isMultiLevel && hour % 3 != 0 {
                    continue // multi level variables are only 3 hour
                }
                let filenameDest = "\(domain.downloadDirectory)\(variable)_\(hour).om"
                if skipFilesIfExisting && FileManager.default.fileExists(atPath: filenameDest) {
                    continue
                }
                
                /// Multi level name `z_cams_c_ecmf_20220803000000_prod_fc_pl_000_co.nc`
                /// Surface level name `z_cams_c_ecmf_20220803000000_prod_fc_sfc_012_uvbed.nc`
                let levelType = meta.isMultiLevel ? "pl" : "sfc"
                let ftpFile = "\(ftpDir)z_cams_c_ecmf_\(dateRun)0000_prod_fc_\(levelType)_\(hour.zeroPadded(len: 3))_\(meta.gribname).nc"
                let tempNc = "\(domain.downloadDirectory)/temp.nc"
                try curl.download(url: ftpFile, to: tempNc)
                
                guard let ncFile = try NetCDF.open(path: tempNc, allowUpdate: false) else {
                    fatalError("Could not open nc file for \(variable)")
                }
                guard let ncVar = ncFile.getVariable(name: meta.gribname) else {
                    fatalError("Could not open nc variable for \(meta.gribname)")
                }
                
                var data = try ncVar.readLevel()
                data.shift180LongitudeAndFlipLatitude(nt: 1, ny: ny, nx: nx)
                
                for i in data.indices {
                    data[i] *= meta.scalefactor
                }
                
                let data2d = Array2DFastSpace(data: data, nLocations: domain.grid.count, nTime: 1)
                try data2d.writeNetcdf(filename: "\(domain.downloadDirectory)/\(variable).nc", nx: nx, ny: ny)
                try FileManager.default.removeItemIfExists(at: filenameDest)
                // Store as compressed float array
                try OmFileWriter.write(file: filenameDest, compressionType: .p4nzdec256, scalefactor: variable.scalefactor, dim0: nx, dim1: ny, chunk0: nx, chunk1: ny, all: data)
                
            }
            fatalError("OK")
        }
        
    }
    
    func convertCamsGlobal(logger: Logger, domain: CamsDomain, run: Timestamp, skipFilesIfExisting: Bool, variables: [CamsVariable], user: String, password: String) throws {
                
        
        
    }
    
    /// Download all timesteps and preliminarily covnert it to compressed files
    func downloadCamsEurope(logger: Logger, domain: CamsDomain, run: Timestamp, skipFilesIfExisting: Bool, variables: [CamsVariable], cdskey: String) throws {
        
        try FileManager.default.createDirectory(atPath: domain.downloadDirectory, withIntermediateDirectories: true)
        
        /// loop over each day, download data and convert it
        let tempPythonFile = "\(domain.downloadDirectory)download.py"
        
        let date = run.iso8601_YYYY_MM_dd
        
        let apiRequest = """
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
                logger.info("Timestep \(run.iso8601_YYYY_MM_dd) seems to be unavailable")
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

fileprivate extension Variable {
    func readLevel() throws -> [Float] {
        guard let ncFloat = self.asType(Float.self) else {
            fatalError("Not a float nc variable")
        }
        if dimensions.count == 2 {
            // surface file
            precondition(dimensions[0].length > 200)
            precondition(dimensions[1].length > 200)
            return try ncFloat.read(offset: [0,0], count: [dimensions[0].length, dimensions[1].length])
        }
        if dimensions.count == 3 {
            // surface file, but with time inside...
            precondition(dimensions[0].length == 0)
            precondition(dimensions[1].length > 200)
            precondition(dimensions[2].length > 200)
            return try ncFloat.read(offset: [0,0,0], count: [1, dimensions[1].length, dimensions[2].length])
        }
        if dimensions.count == 4 {
            // pressure level file -> read `last` level e.g. 10 meter above ground
            // dimensions time, level, lat, lon
            precondition(dimensions[0].length == 0)
            precondition(dimensions[1].length > 10)
            precondition(dimensions[2].length > 200)
            precondition(dimensions[3].length > 200)
            return try ncFloat.read(offset: [0, dimensions[1].length-1,0,0], count: [1, 1, dimensions[2].length, dimensions[3].length])
        }
        fatalError("Wrong dimensions \(dimensionsFlat)")
    }
}

