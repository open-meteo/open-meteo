
import Foundation
import Vapor
import AsyncHTTPClient
import OmFileFormat

/**
 https://opendatadocs.meteoswiss.ch/e-forecast-data/e2-e3-numerical-weather-forecasting-model?download-options=restapi
 
 TODO:
 - atmospheric levels integration
 */
struct MeteoSwissDownload: AsyncCommand {
    struct Signature: CommandSignature {
        @Argument(name: "domain")
        var domain: String
        
        @Option(name: "run")
        var run: String?
        
        @Flag(name: "create-netcdf")
        var createNetcdf: Bool
        
        @Option(name: "only-variables")
        var onlyVariables: String?
        
        @Option(name: "upload-s3-bucket", help: "Upload open-meteo database to an S3 bucket after processing")
        var uploadS3Bucket: String?
        
        @Option(name: "concurrent", short: "c", help: "Number of concurrent download/conversion jobs")
        var concurrent: Int?
        
        @Flag(name: "upload-s3-only-probabilities", help: "Only upload probabilities files to S3")
        var uploadS3OnlyProbabilities: Bool
    }
    
    var help: String {
        "Download MeteoSwiss ICON CH models"
    }

    func run(using context: CommandContext, signature: Signature) async throws {
        let start = DispatchTime.now()
        let logger = context.application.logger
        let domain = try MeteoSwissDomain.load(rawValue: signature.domain)

        let run = try signature.run.flatMap(Timestamp.fromRunHourOrYYYYMMDD) ?? domain.lastRun

        let variables = try MeteoSwissSurfaceVariable.load(commaSeparatedOptional: signature.onlyVariables) ?? MeteoSwissSurfaceVariable.allCases

        logger.info("Downloading domain '\(domain.rawValue)' run '\(run.iso8601_YYYY_MM_dd_HH_mm)'")

        let handles = try await download(application: context.application, domain: domain, variables: variables, run: run, uploadS3Bucket: signature.uploadS3Bucket)
        let nConcurrent = signature.concurrent ?? 1
        try await GenericVariableHandle.convert(logger: logger, domain: domain, createNetcdf: signature.createNetcdf, run: run, handles: handles, concurrent: nConcurrent, writeUpdateJson: true, uploadS3Bucket: signature.uploadS3Bucket, uploadS3OnlyProbabilities: signature.uploadS3OnlyProbabilities)
        logger.info("Finished in \(start.timeElapsedPretty())")
    }

    /// Process each variable and update time-series optimised files
    func download(application: Application, domain: MeteoSwissDomain, variables: [MeteoSwissSurfaceVariable], run: Timestamp, uploadS3Bucket: String?) async throws -> [GenericVariableHandle] {
        Process.alarm(seconds: 3 * 3600)
        defer { Process.alarm(seconds: 0) }
        let logger = application.logger
        let client = application.http.client.shared
        let curl = Curl(logger: logger, client: client)
        let deaverager = GribDeaverager()
        let grid = domain.grid
        let nx = grid.nx
        let ny = grid.ny
        let collection = domain.collection
        let storeOnDisk = domain.countEnsembleMember <= 1
        
        let directory = (domain.domainRegistryStatic ?? domain.domainRegistry).directory
        try FileManager.default.createDirectory(atPath: "\(directory)static", withIntermediateDirectories: true)
        let weightsFile = "\(directory)static/nn_weights.om"
        if !FileManager.default.fileExists(atPath: weightsFile) {
            let (latitudes, longitudes, landmask, elevation) = try await fetchCoordinates(logger: logger, client: client, collection: collection)
            logger.info("Calculating NN mapping")
            let mapping = await calculateNNMapping(latitudes: latitudes, longitudes: longitudes, grid: grid)
            try OmFileWriter.write(file: weightsFile, data: mapping)
            
            logger.info("Generate elevation file")
            var elevationRemapped = mapping.map { elevation[$0] }
            let landmaskRemapped = mapping.map { landmask[$0] }
            for i in elevationRemapped.indices {
                if landmaskRemapped[i] < 0.5 {
                    elevationRemapped[i] = -999
                }
            }
            try elevationRemapped.writeOmFile2D(file: domain.surfaceElevationFileOm.getFilePath(), grid: domain.grid, createNetCdf: false)
        }
        let mapping: [Int] = try await OmFileReader(mmapFile: weightsFile).expectArray(of: Int.self).read()
        //try Array2D(data: mapping.map(Float.init), nx: nx, ny: ny).writeNetcdf(filename: "\((domain.domainRegistryStatic ?? domain.domainRegistry ).directory)static/nn_weights.nc")
        
        let timestamps = (0...domain.forecastLength).map { run.add(hours: $0) }
        
        /// Domain elevation field. Used to calculate sea level pressure from surface level pressure in ICON EPS and ICON EU EPS
        let domainElevation = await {
            guard let elevation = try? await domain.getStaticFile(type: .elevation, httpClient: client, logger: logger)?.read(range: nil) else {
                fatalError("cannot read elevation for domain \(domain)")
            }
            return elevation
        }()
        
        let handles: [GenericVariableHandle] = try await timestamps.enumerated().asyncFlatMap { (i,timestamp) -> [GenericVariableHandle] in
            let hour = (timestamp.timeIntervalSince1970 - run.timeIntervalSince1970) / 3600
            logger.info("Downloading hour \(hour)")
            let storage = VariablePerMemberStorage<MeteoSwissSurfaceVariable>()
            let rhCalculator = RelativeHumidityCalculator(outVariable: MeteoSwissSurfaceVariable.relative_humidity_2m)
            
            let writerProbabilities = domain.countEnsembleMember > 1 ? OmSpatialTimestepWriter(domain: domain, run: run, time: timestamp, storeOnDisk: true, realm: nil) : nil
            let writer = OmSpatialTimestepWriter(domain: domain, run: run, time: timestamp, storeOnDisk: storeOnDisk, realm: nil)
            
            try await variables.foreachConcurrent(nConcurrent: 4) { variable in
                let storagePrecipitation = VariablePerMemberStorage<MeteoSwissSurfaceVariable>()
                var urls = [try await client.resolveMeteoSwissDownloadURL(
                    logger: logger,
                    collection: collection,
                    forecastReferenceDatetime: run,
                    forecastVariable: variable.gribName,
                    forecastPerturbed: false,
                    forecastHorizon: "P0DT\(hour.zeroPadded(len: 2))H00M00S"
                )]
                if domain.countEnsembleMember > 1 {
                    urls.append(try await client.resolveMeteoSwissDownloadURL(
                        logger: logger,
                        collection: collection,
                        forecastReferenceDatetime: run,
                        forecastVariable: variable.gribName,
                        forecastPerturbed: true,
                        forecastHorizon: "P0DT\(hour.zeroPadded(len: 2))H00M00S"
                    ))
                }
                for url in urls {
                    for message in try await curl.downloadGrib(url: url) {
                        let stepRange = try message.getOrThrow(attribute: "stepRange")
                        let stepType = try message.getOrThrow(attribute: "stepType")
                        let rawData = try message.getFloats()
                        let member = message.getLong(attribute: "perturbationNumber") ?? 0
                        var array2d = Array2D(data: mapping.map { rawData[$0] }, nx: nx, ny: ny)
                        if let fma = variable.multiplyAdd {
                            array2d.data.multiplyAdd(multiply: fma.scalefactor, add: fma.offset)
                        }
                        guard await deaverager.deaccumulateIfRequired(variable: variable, member: member, stepType: stepType, stepRange: stepRange, array2d: &array2d) else {
                            continue
                        }
                        if variable == .precipitation {
                            await storagePrecipitation.set(variable: variable, timestamp: timestamp, member: member, data: array2d)
                        }
                        /// CIN is set to -1000 for missing data. This is really bad for compression. Typical ranges 0...250. Set it to -1 to mark missing data.
                        if variable == .convective_inhibition {
                            for i in array2d.data.indices {
                                if array2d.data[i] <= -999 {
                                    array2d.data[i] = -1
                                }
                            }
                        }
                        
                        if variable == .temperature_2m {
                            try await rhCalculator.ingest(.temperature(array2d), member: member, writer: writer)
                        }
                        if variable == .relative_humidity_2m {
                            try await rhCalculator.ingest(.dewpoint(array2d), member: member, writer: writer)
                            continue
                        }
                        
                        if [MeteoSwissSurfaceVariable.direct_radiation, .temperature_2m, .freezing_level_height, .snowfall_height, .shortwave_radiation].contains(variable) {
                            await storage.set(variable: variable, timestamp: timestamp, member: member, data: array2d)
                            
                            try await storage.correctIconSnowfallHeight(snowfallHeight: .snowfall_height, temperature2m: .temperature_2m, domainElevation: domainElevation, writer: writer)
                            try await storage.correctIconSnowfallHeight(snowfallHeight: .freezing_level_height, temperature2m: .temperature_2m, domainElevation: domainElevation, writer: writer)
                            
                            /// Calculate global shortwave radiation from diffuse and direct components
                            try await storage.sumUpRemovingBoth(var1: MeteoSwissSurfaceVariable.shortwave_radiation, var2: MeteoSwissSurfaceVariable.direct_radiation, outVariable: MeteoSwissSurfaceVariable.shortwave_radiation, writer: writer)
                        }
                        
                        if [MeteoSwissSurfaceVariable.freezing_level_height, .snowfall_height, .shortwave_radiation].contains(variable) {
                            continue
                        }
                        
                        logger.info("Processing \(variable) for \(timestamp.format_YYYYMMddHH) member \(member)")
                        try await writer.write(member: member, variable: variable, data: array2d.data)
                    }
                }
                if variable == .precipitation, let writerProbabilities {
                    logger.info("Calculating precipitation probability")
                    
                    try await storagePrecipitation.calculatePrecipitationProbability(
                        precipitationVariable: .precipitation,
                        dtHoursOfCurrentStep: domain.dtHours,
                        writer: writerProbabilities
                    )
                }
            }
            
            let completed = i == timestamps.count - 1
            let handles = try await writer.finalise(completed: completed, validTimes: Array(timestamps[0...i]), uploadS3Bucket: uploadS3Bucket) + (writerProbabilities?.finalise(completed: completed, validTimes: Array(timestamps[0...i]), uploadS3Bucket: uploadS3Bucket) ?? [])
            return handles
        }
        await curl.printStatistics()
        return handles
    }
    
    func calculateNNMapping(latitudes: [Float], longitudes: [Float], grid: any Gridable) async -> [Int] {
        let count = grid.count
        return await (0..<grid.count).mapConcurrent(nConcurrent: System.coreCount) { gridIndex in
            if gridIndex % 1000 == 0 {
                print("\(gridIndex)/\(count)")
            }
            let (gridLat, gridLon) = grid.getCoordinates(gridpoint: gridIndex)
            return zip(latitudes, longitudes).enumerated().min(by: { a, b in
                let d1 = pow(a.element.0 - gridLat, 2) + pow(a.element.1 - gridLon, 2)
                let d2 = pow(b.element.0 - gridLat, 2) + pow(b.element.1 - gridLon, 2)
                return d1 < d2
            })?.offset ?? 0
        }
    }
    
    /// Check latitude and
    func fetchCoordinates(logger: Logger, client: HTTPClient, collection: String) async throws -> (latitudes: [Float], longitudes: [Float], landmask: [Float], height: [Float]) {
        let assets = try await client.getMeteoSwissAssets(logger: logger, collection: collection)
        guard let horizontalConstantsUrl = assets.first(where: {$0.id.hasPrefix("horizontal_constants")  && $0.id.hasSuffix(".grib2")})?.href else {
            fatalError("Could not find horizontal constants URL in assets")
        }
        let curl = Curl(logger: logger, client: client)
        let horizontalConstants = try await curl.downloadGrib(url: horizontalConstantsUrl)
        var latitudes: [Float]? = nil
        var longitudes: [Float]? = nil
        var landmask: [Float]? = nil
        var height: [Float]? = nil
        for message in horizontalConstants {
            let name = try message.getOrThrow(attribute: "shortName")
            switch name {
            case "tlon":
                longitudes = try message.getFloats()
            case "tlat":
                latitudes = try message.getFloats()
            case "lsm":
                landmask = try message.getFloats()
            case "h":
                height = try message.getFloats()
            default:
                break
            }
        }
        guard let longitudes, let latitudes, let landmask, let height else {
            fatalError("Could not find latitudes or longitudes in horizontal constants")
        }
        return (latitudes, longitudes, landmask, height)
    }
}

fileprivate extension HTTPClient {
    struct FeatureCollection: Codable {
        let features: [Feature]
    }

    struct Feature: Codable {
        let assets: [String: Asset]
        struct Asset: Codable {
            let href: String
        }
    }
    
    struct Assets: Codable {
        let assets: [Asset]
        struct Asset: Codable {
            let id: String
            let href: String
        }
    }
    
    func resolveMeteoSwissDownloadURL(
        logger: Logger,
        collection: String,
        forecastReferenceDatetime: Timestamp,
        forecastVariable: String,
        forecastPerturbed: Bool,
        forecastHorizon: String
    ) async throws -> String {
        var req = HTTPClientRequest(url: "https://data.geo.admin.ch/api/stac/v1/search")
        req.method = .POST
        req.headers.add(name: "Content-Type", value: "application/json")
        let json = """
            {
                "collections": [
                    "\(collection)"
                ],
                "forecast:reference_datetime": "\(forecastReferenceDatetime.iso8601_YYYY_MM_dd_HH_mm)Z",
                "forecast:variable": "\(forecastVariable)",
                "forecast:perturbed": \(forecastPerturbed),
                "forecast:horizon": "\(forecastHorizon)"
            }
            """
        req.body = .bytes(ByteBufferAllocator().buffer(string: json))
        let backoff = ExponentialBackOff()
        let deadline = Date.hours(1)
        var n = 0
        while true {
            n += 1
            let response = try await executeRetry(req, logger: logger, timeoutPerRequest: .seconds(5))
            guard let result = try await response.checkCode200AndReadJSONDecodable(FeatureCollection.self) else {
                let error = try await response.readStringImmutable() ?? ""
                fatalError("Could not decode \(error)")
            }
            guard let url = result.features.first?.assets.first?.value.href else {
                if Date() > deadline {
                    throw CurlError.fileNotFound
                }
                if n == 1 {
                    logger.info("File missing, waiting up to 1 hour")
                }
                try await backoff.sleep(attempt: n)
                continue
            }
            return url
        }
    }
    
    func getMeteoSwissAssets(
        logger: Logger,
        collection: String
    ) async throws -> [Assets.Asset] {
        let url = "https://data.geo.admin.ch/api/stac/v1/collections/\(collection)/assets"
        let req = HTTPClientRequest(url: url)
        let response = try await executeRetry(req, logger: logger, timeoutPerRequest: .seconds(5))
        guard let result = try await response.checkCode200AndReadJSONDecodable(Assets.self) else {
            let error = try await response.readStringImmutable() ?? ""
            fatalError("Could not decode \(error)")
        }
        return result.assets
    }
}


extension OmFileWriter where FileHandle == Foundation.FileHandle {
    static func write<D: OmFileArrayDataTypeProtocol>(file: String, data: [D], scale_factor: Float = 1, add_offset: Float = 0) throws {
        let temporary = "\(file)~"
        let writeFn = try FileHandle.createNewFile(file: temporary)
        let fileWriter = OmFileWriter(fn: writeFn, initialCapacity: 1024 * 1024 * 10)
        let writer = try fileWriter.prepareArray(
            type: D.self,
            dimensions: [UInt64(data.count)],
            chunkDimensions: [UInt64(data.count)],
            compression: .pfor_delta2d,
            scale_factor: scale_factor,
            add_offset: add_offset
        )
        try writer.writeData(array: data)
        let variable = try fileWriter.write(
            array: try writer.finalise(),
            name: "",
            children: []
        )
        try fileWriter.writeTrailer(rootVariable: variable)
        try writeFn.close()
        try FileManager.default.moveItem(atPath: temporary, toPath: file)
    }
}
