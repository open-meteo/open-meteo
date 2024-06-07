import Foundation
import Vapor
import SwiftPFor2D
import SwiftNetCDF

/**
 Download MeteoFrance wave model from Marine Data Store
 
 Wave: https://data.marine.copernicus.eu/product/GLOBAL_ANALYSISFORECAST_WAV_001_027/description
 Currents: https://data.marine.copernicus.eu/product/GLOBAL_ANALYSISFORECAST_PHY_001_024/description
 */
struct MfWaveDownload: AsyncCommand {
    struct Signature: CommandSignature {
        @Argument(name: "domain")
        var domain: String

        @Option(name: "run")
        var run: String?
        
        @Flag(name: "create-netcdf")
        var createNetcdf: Bool
        
        @Option(name: "concurrent", short: "c", help: "Numer of concurrent download/conversion jobs")
        var concurrent: Int?
        
        @Option(name: "upload-s3-bucket", help: "Upload open-meteo database to an S3 bucket after processing")
        var uploadS3Bucket: String?
    }

    var help: String {
        "Download a specified wave model run"
    }
    
    func run(using context: CommandContext, signature: Signature) async throws {
        let domain = try MfWaveDomain.load(rawValue: signature.domain)
        
        let run = try signature.run.flatMap(Timestamp.fromRunHourOrYYYYMMDD) ?? domain.lastRun
        
        let nConcurrent = signature.concurrent ?? 1
                
        let logger = context.application.logger
        logger.info("Downloading domain '\(domain.rawValue)' run '\(run.iso8601_YYYY_MM_dd_HH_mm)'")
        
        let handles = try await download(application: context.application, domain: domain, run: run)
        try await GenericVariableHandle.convert(logger: logger, domain: domain, createNetcdf: signature.createNetcdf, run: run, handles: handles, concurrent: nConcurrent)
        
        if let uploadS3Bucket = signature.uploadS3Bucket {
            //try domain.domainRegistry.syncToS3(bucket: uploadS3Bucket, variables: variables)
        }
    }
    
    /// Download all timesteps and preliminarily covnert it to compressed files
    func download(application: Application, domain: MfWaveDomain, run: Timestamp) async throws -> [GenericVariableHandle] {
        // https://s3.waw3-1.cloudferro.com/mdl-native-14/native/GLOBAL_ANALYSISFORECAST_WAV_001_027/cmems_mod_glo_wav_anfc_0.083deg_PT3H-i_202311/2024/06/mfwamglocep_2024060500_R20240606_00H.nc
        // https://s3.waw3-1.cloudferro.com/mdl-native-14/native/GLOBAL_ANALYSISFORECAST_WAV_001_027/cmems_mod_wav_anfc_0.083deg_static_202211/GLO-MFC_001_027_bathy.nc
        let logger = application.logger
        try FileManager.default.createDirectory(atPath: domain.downloadDirectory, withIntermediateDirectories: true)
        
        Process.alarm(seconds: 6 * 3600)
        defer { Process.alarm(seconds: 0) }
        
        let curl = Curl(logger: logger, client: application.dedicatedHttpClient)
        let nLocationsPerChunk = OmFileSplitter(domain).nLocationsPerChunk
        let nx = domain.grid.nx
        let ny = domain.grid.ny
        
        let writer = OmFileWriter(dim0: 1, dim1: domain.grid.count, chunk0: 1, chunk1: nLocationsPerChunk)
                
        let server = "https://s3.waw3-1.cloudferro.com/mdl-native-14/native/GLOBAL_ANALYSISFORECAST_WAV_001_027/cmems_mod_glo_wav_anfc_0.083deg_PT3H-i_202311/"
        
        // Iterate from d-1 to d+10 in 12 hour steps
        let handles = try await stride(from: run.add(days: -1), to: run.add(days: 10), by: 12*3600).asyncMap { step -> [GenericVariableHandle] in
            logger.info("Downloading file with timestap \(step)")
            
            let r = run.toComponents()
            let url = "\(server)\(r.year)/\(r.month.zeroPadded(len: 2))/mfwamglocep_\(step.format_YYYYMMddHH)_R\(run.format_YYYYMMdd)_\(run.hh)H.nc"
            let memory = try await curl.downloadInMemoryAsync(url: url, minSize: 1024*1024)
            return try memory.withUnsafeReadableBytes({ memory in
                guard let nc = try NetCDF.open(memory: memory) else {
                    fatalError("Could not open netcdf from memory")
                }
                // Converted from "hours since 1950-01-01"
                guard let timestamps = try nc.getVariable(name: "time")?
                    .asType(Int32.self)?
                    .read()
                    .map({ Timestamp(Int($0) * 3600 + Timestamp(1950,1,1).timeIntervalSince1970)})
                else {
                    fatalError("Could not read time array")
                }
                return try nc.getVariables().map { ncvar -> [GenericVariableHandle] in
                    guard let variable = ncvar.toMfVariable() else {
                        return []
                    }
                    guard let ncInt16 = ncvar.asType(Int16.self) else {
                        fatalError("Variable \(variable) is not Int16 type")
                    }
                    guard let scaleFactor: Float = try ncvar.getAttribute("scale_factor")?.read() else {
                        fatalError("Could not get scalefactor")
                    }
                    guard let missingValue: Int16 = try ncvar.getAttribute("missing_value")?.read() else {
                        fatalError("Could not get scalefactor")
                    }
                    return try timestamps.enumerated().map { (i,timestamp) -> GenericVariableHandle in
                        logger.info("Process variable \(variable) timestamp \(timestamp.iso8601_YYYY_MM_dd_HH_mm)")
                        let data = try ncInt16.read(offset: [i,0,0], count: [1, ny, nx]).map {
                            if $0 == missingValue {
                                return Float.nan
                            }
                            return Float($0) * scaleFactor
                        }
                        let fn = try writer.writeTemporary(compressionType: .p4nzdec256, scalefactor: variable.scalefactor, all: data)
                        // Note: skipHour0 needs still to be set for solar interpolation
                        return GenericVariableHandle(
                            variable: variable,
                            time: timestamp,
                            member: 0,
                            fn: fn,
                            skipHour0: false
                        )
                    }
                }.flatMap({$0})
            })
        }.flatMap({$0})
        await curl.printStatistics()
        return handles
    }
}

extension Variable {
    func toMfVariable() -> MfWaveVariable? {
        switch name {
        case "VHM0":
            return .wave_height
        case "VTM10":
            return .wave_period
        case "VMDR":
            return .wave_direction
        case "VHM0_WW":
            return .wind_wave_height
        case "VTM01_WW":
            return .wind_wave_period
        case "VMDR_WW":
            return .wind_wave_direction
        case "VHM0_SW1":
            return .swell_wave_height
        case "VTM01_SW1":
            return .swell_wave_period
        case "VMDR_SW1":
            return .swell_wave_direction
        default:
            return nil
        }
    }
}
