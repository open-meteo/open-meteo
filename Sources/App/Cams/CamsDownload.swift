import Foundation
import Vapor
import SwiftNetCDF
import SwiftPFor2D

/// Download CAMS Europe and Global air quality forecasts
struct DownloadCamsCommand: AsyncCommandFix {
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
    
    func run(using context: CommandContext, signature: Signature) async throws {
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
            try await downloadCamsGlobal(application: context.application, domain: domain, run: date, skipFilesIfExisting: signature.skipExisting, variables: variables, user: ftpuser, password: ftppassword)
            try convertCamsGlobal(logger: logger, domain: domain, run: date, variables: variables)
        case .cams_europe:
            guard let cdskey = signature.cdskey else {
                fatalError("cds key is required")
            }
            try downloadCamsEurope(logger: logger, domain: domain, run: date, skipFilesIfExisting: signature.skipExisting, variables: variables, cdskey: cdskey)
            try convertCamsEurope(logger: logger, domain: domain, run: date, variables: variables)
        }
    }
    
    /// Download from the ECMWF CAMS ftp/http server
    /// This data is also available via the ADC API, but queue times are 4 hours!
    func downloadCamsGlobal(application: Application, domain: CamsDomain, run: Timestamp, skipFilesIfExisting: Bool, variables: [CamsVariable], user: String, password: String) async throws {
        
        try FileManager.default.createDirectory(atPath: domain.downloadDirectory, withIntermediateDirectories: true)
        let logger = application.logger
        
        let nx = domain.grid.nx
        let ny = domain.grid.ny
        
        let writer = OmFileWriter(dim0: nx, dim1: ny, chunk0: nx, chunk1: ny)
        
        let curl = Curl(logger: logger)
        let dateRun = run.format_YYYYMMddHH
        let remoteDir = "https://\(user):\(password)@aux.ecmwf.int/ecpds/data/file/CAMS_GLOBAL/\(dateRun)/"
        /// The surface level of multi-level files is available in the `CAMS_GLOBAL_ADDITIONAL` directory
        let remoteDirAdditional = "https://\(user):\(password)@aux.ecmwf.int/ecpds/data/file/CAMS_GLOBAL_ADDITIONAL/\(dateRun)/"
        
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
                
                /// Multi level name `z_cams_c_ecmf_20220811120000_prod_fc_ml137_000_aermr03.nc`
                /// Surface level name `z_cams_c_ecmf_20220803000000_prod_fc_sfc_012_uvbed.nc`
                let levelType = meta.isMultiLevel ? "ml137" : "sfc"
                let dir = meta.isMultiLevel ? remoteDirAdditional : remoteDir
                let remoteFile = "\(dir)z_cams_c_ecmf_\(dateRun)0000_prod_fc_\(levelType)_\(hour.zeroPadded(len: 3))_\(meta.gribname).nc"
                let tempNc = "\(domain.downloadDirectory)/temp.nc"
                try await curl.download(url: remoteFile, toFile: tempNc, bzip2Decode: false, client: application.dedicatedHttpClient)
                
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
                
                //let data2d = Array2DFastSpace(data: data, nLocations: domain.grid.count, nTime: 1)
                //try data2d.writeNetcdf(filename: "\(domain.downloadDirectory)/\(variable).nc", nx: nx, ny: ny)
                try FileManager.default.removeItemIfExists(at: filenameDest)
                // Store as compressed float array
                try writer.write(file: filenameDest, compressionType: .p4nzdec256, scalefactor: variable.scalefactor, all: data)
            }
        }
        curl.printStatistics()
    }
    
    /// Assemble a time-series and update operational files
    func convertCamsGlobal(logger: Logger, domain: CamsDomain, run: Timestamp, variables: [CamsVariable]) throws {
        try FileManager.default.createDirectory(atPath: domain.omfileDirectory, withIntermediateDirectories: true)
        let om = OmFileSplitter(basePath: domain.omfileDirectory, nLocations: domain.grid.count, nTimePerFile: domain.omFileLength, yearlyArchivePath: nil)
        
        for variable in variables {
            guard let meta = variable.getCamsGlobalMeta()else {
                continue
            }
            logger.info("Converting \(variable)")
            
            /// Prepare data as time series optimisied array. It is wrapped in a closure to release memory.
            var data2d = Array2DFastTime(nLocations: domain.grid.count, nTime: domain.forecastHours)
                
            for hour in 0..<domain.forecastHours {
                if meta.isMultiLevel && hour % 3 != 0 {
                    continue // multi level variables are only 3 hour
                }
                let d = try OmFileReader(file: "\(domain.downloadDirectory)\(variable)_\(hour).om").readAll()
                data2d[0..<data2d.nLocations, hour] = d
            }
            
            // Multi level has only 3h data, interpolate to 1h using hermite interpolation
            if meta.isMultiLevel {
                let forecastStepsToInterpolate = (0..<domain.forecastHours).compactMap { hour in
                    hour % 3 == 1 ? hour : nil
                }
                data2d.interpolate2StepsHermite(positions: forecastStepsToInterpolate, bounds: 0...Float.infinity)
            }
            
            logger.info("Create om file")
            let startOm = DispatchTime.now()
            let timeIndexStart = run.timeIntervalSince1970 / domain.dtSeconds
            let timeIndices = timeIndexStart ..< timeIndexStart + data2d.nTime
            //try data2d.transpose().writeNetcdf(filename: "\(domain.downloadDirectory)\(variable.rawValue).nc", nx: domain.grid.nx, ny: domain.grid.ny)
            try om.updateFromTimeOriented(variable: variable.rawValue, array2d: data2d, ringtime: timeIndices, skipFirst: 0, smooth: 0, skipLast: 0, scalefactor: variable.scalefactor)
            logger.info("Update om finished in \(startOm.timeElapsedPretty())")
        }
        
    }
    
    /// Download all timesteps and preliminarily covnert it to compressed files
    func downloadCamsEurope(logger: Logger, domain: CamsDomain, run: Timestamp, skipFilesIfExisting: Bool, variables: [CamsVariable], cdskey: String) throws {
        
        try FileManager.default.createDirectory(atPath: domain.downloadDirectory, withIntermediateDirectories: true)
        
        let tempPythonFile = "\(domain.downloadDirectory)download.py"
        let downloadFile = "\(domain.downloadDirectory)download.nc"
        
        if skipFilesIfExisting && FileManager.default.fileExists(atPath: downloadFile) {
            return
        }
        
        let date = run.iso8601_YYYY_MM_dd
        let variableNames = variables.compactMap { $0.getCamsEuMeta()?.apiName }.map{"'\($0)'"}.joined(separator: ",")
        let leadtimeHours = (0..<domain.forecastHours).map{"'\($0)'"}.joined(separator: ",")
        
        let pyCode = """
            import cdsapi

            c = cdsapi.Client(url="https://ads.atmosphere.copernicus.eu/api/v2", key="\(cdskey)", verify=True)
            try:
                c.retrieve('cams-europe-air-quality-forecasts',
                {
                    'model': 'ensemble',
                    'date': '\(date)/\(date)',
                    'type': 'forecast',
                    'format': 'netcdf',
                    'variable': [\(variableNames)],
                    'level': '0',
                    'time': '\(run.hour.zeroPadded(len: 2)):00',
                    'leadtime_hour': [\(leadtimeHours)],
                },
                '\(downloadFile)')
            except Exception as e:
                if "Please, check that your date selection is valid" in str(e):
                    exit(70)
                raise e
            """
        
        try pyCode.write(toFile: tempPythonFile, atomically: true, encoding: .utf8)
        do {
            try Process.spawn(cmd: "python3", args: [tempPythonFile])
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
    func convertCamsEurope(logger: Logger, domain: CamsDomain, run: Timestamp, variables: [CamsVariable]) throws {
        try FileManager.default.createDirectory(atPath: domain.omfileDirectory, withIntermediateDirectories: true)
        let om = OmFileSplitter(basePath: domain.omfileDirectory, nLocations: domain.grid.count, nTimePerFile: domain.omFileLength, yearlyArchivePath: nil)
        
        guard let ncFile = try NetCDF.open(path: "\(domain.downloadDirectory)download.nc", allowUpdate: false) else {
            fatalError("Could not open '\(domain.downloadDirectory)download.nc'")
        }
        
        for variable in variables {
            guard let meta = variable.getCamsEuMeta() else {
                continue
            }
            logger.info("Converting \(variable)")
            guard let ncVar = ncFile.getVariable(name: meta.gribName) else {
                fatalError("Could not open variable \(meta.gribName)")
            }
            guard let ncFloat = ncVar.asType(Float.self) else {
                fatalError("Could not open float variable \(meta.gribName)")
            }
            var data2d = Array2DFastSpace(data: try ncFloat.read(), nLocations: domain.grid.count, nTime: domain.forecastHours).transpose()
            for i in data2d.data.indices {
                if data2d.data[i] <= -999 {
                    data2d.data[i] = .nan
                }
            }
            
            logger.info("Create om file")
            let startOm = DispatchTime.now()
            let timeIndexStart = run.timeIntervalSince1970 / domain.dtSeconds
            let timeIndices = timeIndexStart ..< timeIndexStart + data2d.nTime
            try om.updateFromTimeOriented(variable: variable.rawValue, array2d: data2d, ringtime: timeIndices, skipFirst: 0, smooth: 0, skipLast: 0, scalefactor: variable.scalefactor)
            logger.info("Update om finished in \(startOm.timeElapsedPretty())")
        }
    }
}

fileprivate extension Variable {
    func readLevel() throws -> [Float] {
        /// m137 files are double... for whatever reason
        if let ncDouble = self.asType(Double.self) {
            guard dimensions.count == 3,
                    dimensions[0].length == 1,
                    dimensions[1].length == 451,
                    dimensions[2].length == 900 else {
                fatalError("Wrong dimensions. Got \(dimensions)")
            }
            return try ncDouble.read().map(Float.init)
        }
        
        guard let ncFloat = self.asType(Float.self) else {
            fatalError("Not a float nc variable")
        }
        if dimensions.count == 2 {
            // surface file
            guard dimensions.count == 2,
                    dimensions[0].length == 451,
                    dimensions[1].length == 900 else {
                fatalError("Wrong dimensions. Got \(dimensions)")
            }
            return try ncFloat.read()
        }
        if dimensions.count == 3 {
            // surface file, but with time inside...
            guard dimensions.count == 3,
                    dimensions[0].length == 1,
                    dimensions[1].length == 451,
                    dimensions[2].length == 900 else {
                fatalError("Wrong dimensions. Got \(dimensions)")
            }
            return try ncFloat.read(offset: [0,0,0], count: [1, dimensions[1].length, dimensions[2].length])
        }
        /*if dimensions.count == 4 {
            // pressure level file -> read `last` level e.g. 10 meter above ground
            // dimensions time, level, lat, lon
            precondition(dimensions[0].length == 0)
            precondition(dimensions[1].length > 10)
            precondition(dimensions[2].length > 200)
            precondition(dimensions[3].length > 200)
            return try ncFloat.read(offset: [0, dimensions[1].length-1,0,0], count: [1, 1, dimensions[2].length, dimensions[3].length])
        }*/
        fatalError("Wrong dimensions \(dimensionsFlat)")
    }
}

