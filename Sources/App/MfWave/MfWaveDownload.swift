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
        
        @Option(name: "timeinterval", short: "t", help: "Timeinterval to download past forecasts. Format 20220101-20220131")
        var timeinterval: String?
    }

    var help: String {
        "Download a specified wave model run"
    }
    
    func run(using context: CommandContext, signature: Signature) async throws {
        let domain = try MfWaveDomain.load(rawValue: signature.domain)
        
        let nConcurrent = signature.concurrent ?? 1
        let logger = context.application.logger
        
        if let timeinterval = signature.timeinterval {
            // MF wave has 0z and 12z run
            // MF current only 0z
            let runs = try Timestamp.parseRange(yyyymmdd: timeinterval).toRange(dt: 24 * 3600).with(dtSeconds: domain.stepHoursPerFile * 3600)
            logger.info("Downloading runs \(runs.prettyString())")
            for year in runs.groupedPreservedOrder(by: {$0.toComponents().year}) {
                let handles = try await year.values.asyncFlatMap { run in
                    logger.info("Downloading domain '\(domain.rawValue)' run '\(run.iso8601_YYYY_MM_dd_HH_mm)'")
                    return try await download(application: context.application, domain: domain, run: run)
                }
                try await GenericVariableHandle.convert(logger: logger, domain: domain, createNetcdf: signature.createNetcdf, run: runs.range.lowerBound, handles: handles, concurrent: nConcurrent)
            }
            return
        }
        
        let run = try signature.run.flatMap(Timestamp.fromRunHourOrYYYYMMDD) ?? domain.lastRun
        logger.info("Downloading domain '\(domain.rawValue)' run '\(run.iso8601_YYYY_MM_dd_HH_mm)'")
        
        let handles = try await download(application: context.application, domain: domain, run: run)
        try await GenericVariableHandle.convert(logger: logger, domain: domain, createNetcdf: signature.createNetcdf, run: run, handles: handles, concurrent: nConcurrent)
        
        if let uploadS3Bucket = signature.uploadS3Bucket {
            let variables = handles.map { $0.variable }.uniqued(on: { $0.rawValue })
            try domain.domainRegistry.syncToS3(bucket: uploadS3Bucket, variables: variables)
        }
    }
    
    /// Download all timesteps and preliminarily covnert it to compressed files
    func download(application: Application, domain: MfWaveDomain, run: Timestamp) async throws -> [GenericVariableHandle] {
        let logger = application.logger
        try FileManager.default.createDirectory(atPath: domain.downloadDirectory, withIntermediateDirectories: true)
        
        Process.alarm(seconds: 6 * 3600)
        defer { Process.alarm(seconds: 0) }
        
        let curl = Curl(logger: logger, client: application.dedicatedHttpClient)
        let nLocationsPerChunk = OmFileSplitter(domain).nLocationsPerChunk
        let nx = domain.grid.nx
        let ny = domain.grid.ny
        let writer = OmFileWriter(dim0: 1, dim1: domain.grid.count, chunk0: 1, chunk1: nLocationsPerChunk)
        
        /// Only hindcast available after 12 hours
        let isOlderThan12Hours = run.add(hours: 23) < Timestamp.now()
        
        /// No data for `2023-10-31`
        if domain == .mfwave && [Timestamp(2023,11,1,0), Timestamp(2023,11,1,12)].contains(run) {
            logger.warning("Not data for \(run.format_YYYYMMddHH)")
            return []
        }
        if domain == .mfcurrents && [Timestamp(2022,11,30)].contains(run) {
            logger.warning("Skipping due to NRT change \(run.format_YYYYMMddHH)")
            return []
        }
        
        /// For MF Wave, runs before November 2023 only offer 12z runs instead of 0z+12z. Followed by 4 days of 24h offsets
        /// Figuring this out, drives you mad....
        let runDownload: Timestamp
        switch (domain, run) {
        case (.mfwave, Timestamp(2023,8,1,0)), (.mfwave, Timestamp(2023,8,1,12)):
            // 2023-07-31 uses different runs.....
            runDownload = run.add(hours: run.hour == 0 ? -12 : -24)
        case (.mfwave, ..<Timestamp(2023,11,2)):
            runDownload = run.add(hours: run.hour == 0 ? 12 : 0)
        case (.mfwave, ..<Timestamp(2023,11,8,0)):
            runDownload = run.add(hours: run.hour == 0 ? -12 : -24)
        case (.mfwave, ...Timestamp(2023,11,12,12)):
            runDownload = run.add(hours: -24)
        case (.mfcurrents, ...Timestamp(2022, 11, 23)):
            runDownload = run.add(hours: -24)
        default:
            runDownload = run
        }
        
        /// Dates before 22th November 2022 are not 7 day releases, but use run-1d
        let afterNRTSwitch = run > Timestamp(2022, 11, 23)
        
        // Every 7th run, the past 14 days are updated with hindcast data for 7 days
        let isNRTUpdateDate = domain == .mfcurrents && isOlderThan12Hours && afterNRTSwitch && (run.timeIntervalSince1970 / (24*3600)) % 7 == 6
        
        // Only NRT update days are kept on S3. Other runs can be ignored
        if domain == .mfcurrents && isOlderThan12Hours && !isNRTUpdateDate && afterNRTSwitch && isOlderThan12Hours {
            logger.warning("Not an NRT update date. Skipping run \(run.format_YYYYMMddHH)")
            return []
        }
        
        /// Each run contains data from 1 day back
        let startTime = run.add(days: isNRTUpdateDate ? -14 : -1)
        /// 10 days forecast. 12z run has one timestep less -> therefore floor to 24h
        let endTimeForecast = run.add(days: 10).floor(toNearestHour: 24)
        
        let endTimeHindcastOnly = run.add(days: isNRTUpdateDate ? (-7-1) : -1).add(hours: domain.stepHoursPerFile)

        if isOlderThan12Hours {
            logger.info("Run date is older than 23 hours. Downloading hindcast only.")
        }
        let downloadRange = TimerangeDt(
            start: startTime,
            to: isOlderThan12Hours ? endTimeHindcastOnly : endTimeForecast,
            dtSeconds: domain.stepHoursPerFile*3600
        )
        logger.info("Downloadig timerange \(downloadRange.prettyString())")
        
        // Iterate from d-1 to d+10 in 12 hour steps
        let handles = try await downloadRange.asyncMap { step -> [GenericVariableHandle] in
            logger.info("Downloading file with timestap \(step.iso8601_YYYY_MM_dd_HH_mm) from run \(runDownload.format_YYYYMMddHH)")
            
            let url = domain.getUrl(run: runDownload, step: step)
            let memory = try await curl.downloadInMemoryAsync(url: url, minSize: 1024*1024)
            return try memory.withUnsafeReadableBytes({ memory in
                guard let nc = try NetCDF.open(memory: memory) else {
                    fatalError("Could not open netcdf from memory")
                }
                // Converted from "hours since 1950-01-01"
                guard let timestamps = try nc.getVariable(name: "time")?
                    .asType(Int32.self)?
                    .read()
                    .map({ Timestamp(Int($0) * 3600 + Timestamp(1950,1,1).timeIntervalSince1970)}) ??
                        nc.getVariable(name: "time")?
                    .asType(Float.self)?
                    .read()
                    .map({ Timestamp(Int($0) * 3600 + Timestamp(1950,1,1).timeIntervalSince1970)})
                else {
                    fatalError("Could not read time array")
                }
                return try nc.getVariables().map { ncvar -> [GenericVariableHandle] in
                    guard let variable = ncvar.toMfVariable() else {
                        return []
                    }
                    
                    // Currents use floating point arrays
                    if let ncFloat = ncvar.asType(Float.self) {
                        return try timestamps.enumerated().map { (i,timestamp) -> GenericVariableHandle in
                            logger.info("Process variable \(variable) timestamp \(timestamp.iso8601_YYYY_MM_dd_HH_mm)")
                            let dimensions = ncvar.dimensions
                            // Maybe has 4 dimensions for depth
                            let data = dimensions.count > 3 ? try ncFloat.read(offset: [i,0,0,0], count: [1, 1, ny, nx]) : try ncFloat.read(offset: [i,0,0], count: [1, ny, nx])
                            if !FileManager.default.fileExists(atPath: domain.surfaceElevationFileOm.getFilePath()) {
                                // create land elevation file. 0=land, -999=sea
                                let elevation = data.map {
                                    return $0.isNaN ? Float(0) : -999
                                }
                                try domain.surfaceElevationFileOm.createDirectory()
                                try OmFileWriter(dim0: domain.grid.ny, dim1: domain.grid.nx, chunk0: 20, chunk1: 20).write(file: domain.surfaceElevationFileOm.getFilePath(), compressionType: .p4nzdec256, scalefactor: 1, all: elevation)
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
                    }
                    
                    // Wave model use Int16 with scalefactor
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
                        if !FileManager.default.fileExists(atPath: domain.surfaceElevationFileOm.getFilePath()) {
                            // create land elevation file. 0=land, -999=sea
                            let elevation = data.map {
                                return $0.isNaN ? Float(0) : -999
                            }
                            try domain.surfaceElevationFileOm.createDirectory()
                            try OmFileWriter(dim0: domain.grid.ny, dim1: domain.grid.nx, chunk0: 20, chunk1: 20).write(file: domain.surfaceElevationFileOm.getFilePath(), compressionType: .p4nzdec256, scalefactor: 1, all: elevation)
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

extension MfWaveDomain {
    func getUrl(run: Timestamp, step: Timestamp) -> String {
        let server = "https://s3.waw3-1.cloudferro.com/mdl-native-14/native/"
        let r = step.toComponents()
        let rMM = r.month.zeroPadded(len: 2)
        switch self {
        case .mfwave:
            // https://s3.waw3-1.cloudferro.com/mdl-native-14/native/GLOBAL_ANALYSISFORECAST_WAV_001_027/cmems_mod_glo_wav_anfc_0.083deg_PT3H-i_202311/2024/06/mfwamglocep_2024060500_R20240606_00H.nc
            
            return "\(server)GLOBAL_ANALYSISFORECAST_WAV_001_027/cmems_mod_glo_wav_anfc_0.083deg_PT3H-i_202311/\(r.year)/\(rMM)/mfwamglocep_\(step.format_YYYYMMddHH)_R\(run.format_YYYYMMdd)_\(run.hh)H.nc"
        case .mfcurrents:
            // https://s3.waw3-1.cloudferro.com/mdl-native-14/native/GLOBAL_ANALYSISFORECAST_PHY_001_024/cmems_mod_glo_phy_anfc_merged-uv_PT1H-i_202211/2024/06/SMOC_20240606_R20240607.nc
            return "\(server)GLOBAL_ANALYSISFORECAST_PHY_001_024/cmems_mod_glo_phy_anfc_merged-uv_PT1H-i_202211/\(r.year)/\(rMM)/SMOC_\(step.format_YYYYMMdd)_R\(run.format_YYYYMMdd).nc"
        }
    }
}

extension Variable {
    func toMfVariable() -> GenericVariable? {
        switch name {
        case "VHM0":
            return MfWaveVariable.wave_height
        case "VTM10":
            return MfWaveVariable.wave_period
        case "VMDR":
            return MfWaveVariable.wave_direction
        case "VHM0_WW":
            return MfWaveVariable.wind_wave_height
        case "VTM01_WW":
            return MfWaveVariable.wind_wave_period
        case "VMDR_WW":
            return MfWaveVariable.wind_wave_direction
        case "VHM0_SW1":
            return MfWaveVariable.swell_wave_height
        case "VTM01_SW1":
            return MfWaveVariable.swell_wave_period
        case "VMDR_SW1":
            return MfWaveVariable.swell_wave_direction
        case "utotal":
            return MfCurrentVariable.ocean_u_current
        case "vtotal":
            return MfCurrentVariable.ocean_v_current
        default:
            return nil
        }
    }
}
