
import Foundation
import Vapor
import AsyncHTTPClient
import OmFileFormat


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

        let handles = try await download(application: context.application, domain: domain, variables: variables, run: run)
        let nConcurrent = signature.concurrent ?? 1
        try await GenericVariableHandle.convert(logger: logger, domain: domain, createNetcdf: signature.createNetcdf, run: run, handles: handles, concurrent: nConcurrent, writeUpdateJson: true, uploadS3Bucket: signature.uploadS3Bucket, uploadS3OnlyProbabilities: false)
        
        if let uploadS3Bucket = signature.uploadS3Bucket {
            let timesteps = Array(handles.map { $0.time }.uniqued().sorted())
            try domain.domainRegistry.syncToS3Spatial(bucket: uploadS3Bucket, timesteps: timesteps)
        }

        logger.info("Finished in \(start.timeElapsedPretty())")
    }

    /// Process each variable and update time-series optimised files
    func download(application: Application, domain: MeteoSwissDomain, variables: [MeteoSwissSurfaceVariable], run: Timestamp) async throws -> [GenericVariableHandle] {
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
        let writer = OmRunSpatialWriter(domain: domain, run: run, storeOnDisk: true)
        
        try FileManager.default.createDirectory(atPath: "\((domain.domainRegistryStatic ?? domain.domainRegistry ).directory)static", withIntermediateDirectories: true)
        let weightsFile = "\((domain.domainRegistryStatic ?? domain.domainRegistry ).directory)static/nn_weights.om"
        if !FileManager.default.fileExists(atPath: weightsFile) {
            let (latitudes, longitudes) = try await fetchCoordinates(logger: logger, client: client, collection: collection)
            logger.info("Calculating NN mapping")
            let mapping = await calculateNNMapping(latitudes: latitudes, longitudes: longitudes, grid: grid)
            try OmFileWriter.write(file: weightsFile, data: mapping)
        }
        let mapping: [Int] = try await OmFileReader.read(file: weightsFile)!
        
        return try await (0...domain.forecastLength).asyncFlatMap { hour -> [GenericVariableHandle] in
            logger.info("Downloading hour \(hour)")
            return try await variables.mapConcurrent(nConcurrent: 4) { variable -> GenericVariableHandle?in
                let member = 0
                let timestamp = run.add(hours: hour)
                let url = try await client.resolveMeteoSwissDownloadURL(
                    logger: logger,
                    collection: collection,
                    forecastReferenceDatetime: run,
                    forecastVariable: variable.gribName,
                    forecastPerturbed: false,
                    forecastHorizon: "P0DT\(hour.zeroPadded(len: 2))H00M00S"
                )
                let message = try await curl.downloadGrib(url: url, bzip2Decode: false)[0]
                let stepRange = try message.getOrThrow(attribute: "stepRange")
                let stepType = try message.getOrThrow(attribute: "stepType")
                let rawData = try message.getFloats()
                var array2d = Array2D(data: mapping.map { rawData[$0] }, nx: nx, ny: ny)
                if let fma = variable.multiplyAdd {
                    array2d.data.multiplyAdd(multiply: fma.scalefactor, add: fma.offset)
                }
                guard await deaverager.deaccumulateIfRequired(variable: variable, member: 0, stepType: stepType, stepRange: stepRange, array2d: &array2d) else {
                    return nil
                }
                return try writer.write(time: timestamp, member: member, variable: variable, data: array2d.data)
            }.asyncCompactMap({$0})
        }
    }
    
    func calculateNNMapping(latitudes: [Float], longitudes: [Float], grid: Gridable) async -> [Int] {
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
    func fetchCoordinates(logger: Logger, client: HTTPClient, collection: String) async throws -> (latitudes: [Float], longitudes: [Float]) {
        let assets = try await client.getMeteoSwissAssets(logger: logger, collection: collection)
        guard let horizontalConstantsUrl = assets.first(where: {$0.id.hasPrefix("horizontal_constants")  && $0.id.hasSuffix(".grib2")})?.href else {
            fatalError("Could not find horizontal constants URL in assets")
        }
        let curl = Curl(logger: logger, client: client)
        let horizontalConstants = try await curl.downloadGrib(url: horizontalConstantsUrl, bzip2Decode: false)
        var latitudes: [Float]? = nil
        var longitudes: [Float]? = nil
        for message in horizontalConstants {
            let name = try message.getOrThrow(attribute: "shortName")
            switch name {
            case "tlon":
                longitudes = try message.getFloats()
            case "tlat":
                latitudes = try message.getFloats()
            default:
                break
            }
        }
        guard let longitudes, let latitudes else {
            fatalError("Could not find latitudes or longitudes in horizontal constants")
        }
        return (latitudes, longitudes)
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
        let response = try await executeRetry(req, logger: logger, timeoutPerRequest: .seconds(5))
        guard let result = try await response.checkCode200AndReadJSONDecodable(FeatureCollection.self) else {
            let error = try await response.readStringImmutable() ?? ""
            fatalError("Could not decode \(error)")
        }
        guard let url = result.features.first?.assets.first?.value.href else {
            throw CurlError.fileNotFound
        }
        return url
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

extension OmFileReader where Backend == MmapFile {
    static func read<D: OmFileArrayDataTypeProtocol>(file: String) async throws -> [D]? {
        let readfile = try await OmFileReader(mmapFile: file)
        guard let reader = readfile.asArray(of: D.self) else {
            return nil
        }
        return try await reader.read(range: nil)
    }
}
