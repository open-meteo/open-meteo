import Foundation
import Vapor
import SwiftNetCDF
import SwiftPFor2D

/// Download CAMS Europe and Global air quality forecasts
struct DownloadCamsCommand: AsyncCommand {
    struct Signature: CommandSignature {
        @Argument(name: "domain")
        var domain: String

        @Option(name: "run")
        var run: String?

        @Flag(name: "skip-existing", help: "ONLY FOR TESTING! Do not use in production. May update the database with stale data")
        var skipExisting: Bool
        
        @Option(name: "only-variables")
        var onlyVariables: String?
        
        @Option(name: "cdskey", short: "k", help: "CDS API user and key like: 123456:8ec08f...")
        var cdskey: String?
        
        @Option(name: "ftpuser", short: "u", help: "Username for the ECMWF CAMS FTP server")
        var ftpuser: String?
        
        @Option(name: "ftppassword", short: "p", help: "Password for the ECMWF CAMS FTP server")
        var ftppassword: String?
        
        @Option(name: "upload-s3-bucket", help: "Upload open-meteo database to an S3 bucket after processing")
        var uploadS3Bucket: String?
    }

    var help: String {
        "Download global and european CAMS air quality forecasts"
    }
    
    func run(using context: CommandContext, signature: Signature) async throws {
        let domain = try CamsDomain.load(rawValue: signature.domain)
        
        let run = try signature.run.flatMap(Timestamp.fromRunHourOrYYYYMMDD) ?? domain.lastRun
        
        let onlyVariables = try CamsVariable.load(commaSeparatedOptional: signature.onlyVariables)
        
        let logger = context.application.logger
        logger.info("Downloading domain '\(domain.rawValue)' run '\(run.iso8601_YYYY_MM_dd_HH_mm)'")
        
        let variables = onlyVariables ?? CamsVariable.allCases
        switch domain {
        case .cams_global:
            guard let ftpuser = signature.ftpuser else {
                fatalError("ftpuser is required")
            }
            guard let ftppassword = signature.ftppassword else {
                fatalError("ftppassword is required")
            }
            try await downloadCamsGlobal(application: context.application, domain: domain, run: run, skipFilesIfExisting: signature.skipExisting, variables: variables, user: ftpuser, password: ftppassword)
            try convertCamsGlobal(logger: logger, domain: domain, run: run, variables: variables)
        case .cams_europe:
            guard let cdskey = signature.cdskey else {
                fatalError("cds key is required")
            }
            try await downloadCamsEurope(application: context.application, domain: domain, run: run, skipFilesIfExisting: signature.skipExisting, variables: variables, cdskey: cdskey)
            try convertCamsEurope(logger: logger, domain: domain, run: run, variables: variables)
        }
        
        if let uploadS3Bucket = signature.uploadS3Bucket {
            try domain.domainRegistry.syncToS3(bucket: uploadS3Bucket, variables: variables)
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
        
        let curl = Curl(logger: logger, client: application.dedicatedHttpClient)
        Process.alarm(seconds: 6 * 3600)
        defer { Process.alarm(seconds: 0) }
        
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
                try await curl.download(url: remoteFile, toFile: tempNc, bzip2Decode: false)
                
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
        await curl.printStatistics()
    }
    
    /// Assemble a time-series and update operational files
    func convertCamsGlobal(logger: Logger, domain: CamsDomain, run: Timestamp, variables: [CamsVariable]) throws {
        let om = OmFileSplitter(domain)
        
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
                data2d[0..<data2d.nLocations, hour / domain.dtHours] = d
            }
            
            // Multi level has only 3h data, interpolate to 1h using hermite interpolation
            if meta.isMultiLevel {
                data2d.data.interpolateInplaceHermite(nTime: domain.forecastHours, bounds: 0...Float.infinity)
            }
            
            logger.info("Create om file")
            let startOm = DispatchTime.now()
            let time = TimerangeDt(start: run, nTime: data2d.nTime, dtSeconds: domain.dtSeconds)
            //try data2d.transpose().writeNetcdf(filename: "\(domain.downloadDirectory)\(variable.rawValue).nc", nx: domain.grid.nx, ny: domain.grid.ny)
            try om.updateFromTimeOriented(variable: variable.rawValue, array2d: data2d, time: time, skipFirst: 0, scalefactor: variable.scalefactor, storePreviousForecast: variable.storePreviousForecast)
            logger.info("Update om finished in \(startOm.timeElapsedPretty())")
        }
        
    }
    
    struct CamsEuropeQuery: Encodable {
        let model = "ensemble"
        let date: String
        let type = "forecast"
        let format = "netcdf"
        let variable: [String]
        let level = "0"
        let time: String
        let leadtime_hour: [String]
    }
    
    /// Download all timesteps and preliminarily covnert it to compressed files
    func downloadCamsEurope(application: Application, domain: CamsDomain, run: Timestamp, skipFilesIfExisting: Bool, variables: [CamsVariable], cdskey: String) async throws {
        
        let logger = application.logger
        
        try FileManager.default.createDirectory(atPath: domain.downloadDirectory, withIntermediateDirectories: true)
        let downloadFile = "\(domain.downloadDirectory)download.nc"
        
        if skipFilesIfExisting && FileManager.default.fileExists(atPath: downloadFile) {
            return
        }
        
        let date = run.iso8601_YYYY_MM_dd
        let query = CamsEuropeQuery(
            date: "\(date)/\(date)",
            variable: variables.compactMap { $0.getCamsEuMeta()?.apiName },
            time: "\(run.hour.zeroPadded(len: 2)):00",
            leadtime_hour: (0..<domain.forecastHours).map(String.init)
        )
        
        let curl = Curl(logger: logger, client: application.dedicatedHttpClient, deadLineHours: 24)
        
        do {
            try await curl.downloadCdsApi(
                dataset: "cams-europe-air-quality-forecasts",
                query: query,
                apikey: cdskey,
                server: "https://ads.atmosphere.copernicus.eu/api/v2",
                destinationFile: downloadFile
            )
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
        let om = OmFileSplitter(domain)
        
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
            let time = TimerangeDt(start: run, nTime: data2d.nTime, dtSeconds: domain.dtSeconds)
            try om.updateFromTimeOriented(variable: variable.rawValue, array2d: data2d, time: time, skipFirst: 0,  scalefactor: variable.scalefactor, storePreviousForecast: variable.storePreviousForecast)
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

