import Foundation
import Vapor
import OmFileFormat
import AsyncHTTPClient
import NIOCore
import JWT

/**
 Skeleton downloader for Google DeepMind WeatherNext-2 ensemble data.

 Source layout:
 `gs://om-weathernext/output/{modelrun-in-iso8601}/{timestamp-in-iso8601}.om`

 Notes:
 - Input files are already preprocessed `.om` files.
 - Each source file is expected to contain one valid time.
 - Each variable has shape `64 x 721 x 1440` = `members x latitude x longitude`.
 - This file intentionally provides a clean integration skeleton only.
 - The actual upstream `.om` decoding and GCS transport still need to be implemented.
 */
struct DownloadWeatherNextCommand: AsyncCommand {
    struct Signature: CommandSignature {
        @Argument(name: "domain")
        var domain: String

        @Option(name: "run")
        var run: String?

        @Option(name: "server", help: "Root path. Default: gs://om-weathernext/output/")
        var server: String?

        @Option(name: "concurrent", short: "c", help: "Number of concurrent download/conversion jobs")
        var concurrent: Int?

        @Flag(name: "create-netcdf")
        var createNetcdf: Bool

        @Flag(name: "skip-existing", help: "ONLY FOR TESTING! Do not use in production. May update the database with stale data")
        var skipExisting: Bool

        @Option(name: "upload-s3-bucket", help: "Upload open-meteo database to an S3 bucket after processing")
        var uploadS3Bucket: String?

        @Flag(name: "upload-s3-only-probabilities", help: "Only upload probabilities files to S3")
        var uploadS3OnlyProbabilities: Bool
    }

    var help: String {
        "Download a specified WeatherNext-2 model run"
    }

    func run(using context: CommandContext, signature: Signature) async throws {
        disableIdleSleep()

        let domain = try WeatherNextDomain.load(rawValue: signature.domain)
        let run = try signature.run.flatMap(Timestamp.fromRunHourOrYYYYMMDD) ?? domain.lastRun
        let logger = context.application.logger

        logger.info("Downloading domain \(domain) run '\(run.iso8601_YYYY_MM_dd_HH_mm)'")

        let server = signature.server ?? "gs://om-weathernext/output/"

        let nConcurrent = signature.concurrent ?? 1
        let generateFullRun = false

        try FileManager.default.createDirectory(atPath: domain.downloadDirectory, withIntermediateDirectories: true)
        try await prepareStaticFilesIfRequired(application: context.application, domain: domain, server: server, run: run)

        let handles = try await download(
            application: context.application,
            domain: domain,
            run: run,
            server: server,
            concurrent: nConcurrent,
            skipFilesIfExisting: signature.skipExisting,
            uploadS3Bucket: signature.uploadS3Bucket
        )

        try await GenericVariableHandle.convert(
            logger: logger,
            domain: domain,
            createNetcdf: signature.createNetcdf,
            run: run,
            handles: handles,
            concurrent: nConcurrent,
            writeUpdateJson: true,
            uploadS3Bucket: signature.uploadS3Bucket,
            uploadS3OnlyProbabilities: signature.uploadS3OnlyProbabilities,
            generateFullRun: generateFullRun
        )
    }

    /// Placeholder for future static assets such as elevation or land/sea masks.
    func prepareStaticFilesIfRequired(
        application: Application,
        domain: WeatherNextDomain,
        server: String,
        run: Timestamp
    ) async throws {
        let logger = application.logger
        _ = server
        _ = run
        logger.info("Static file preparation for \(domain) is currently a no-op")
    }

    /**
     Main skeleton pipeline:
     1. determine valid times for the run
     2. fetch one upstream `.om` file per valid time
     3. decode all raw variables for all members
     4. write raw variables into spatial timestep files
     5. derive selected variables during ingest
     */
    func download(
        application: Application,
        domain: WeatherNextDomain,
        run: Timestamp,
        server: String,
        concurrent: Int,
        skipFilesIfExisting: Bool,
        uploadS3Bucket: String?
    ) async throws -> [GenericVariableHandle] {
        let logger = application.logger
        _ = concurrent

        let writer = OmSpatialMultistepWriter(
            domain: domain,
            run: run,
            storeOnDisk: false,
            realm: nil,
            logger: logger,
            ensembleMeanDomain: domain.ensembleMeanDomain
        )

        let timestamps = (0..<domain.omFileLength).map { run.add(($0 + 1) * domain.dtSeconds) }
        logger.info("Processing \(timestamps.count) WeatherNext timesteps")

        for timestamp in timestamps {
            let source = WeatherNextSourcePath(server: server, run: run, validTime: timestamp)
            let localFile = "\(domain.downloadDirectory)\(timestamp.iso8601_YYYY_MM_dd_HHmm).om"

            logger.info("Processing \(source.remotePath)")

            if !skipFilesIfExisting || !FileManager.default.fileExists(atPath: localFile) {
                try await fetchSourceFile(
                    application: application,
                    remotePath: source.remotePath,
                    localFile: localFile
                )
            }

            let decoded = try decodeWeatherNextFile(
                application: application,
                domain: domain,
                file: localFile,
                run: run,
                validTime: timestamp
            )

            try await writeDecodedTimestep(
                application: application,
                domain: domain,
                writer: writer,
                decoded: decoded
            )
        }

        return try await writer.finalise(
            completed: true,
            validTimes: timestamps,
            uploadS3Bucket: uploadS3Bucket
        )
    }

    /**
     Download a private GCS object using authenticated HTTP only.

     Authentication source:
     1. service account JSON pointed to by `GOOGLE_APPLICATION_CREDENTIALS`

     The `server` argument is still expected in `gs://bucket/prefix/` form, but the actual
     transfer is performed against the authenticated GCS JSON media endpoint.
     */
    func fetchSourceFile(
        application: Application,
        remotePath: String,
        localFile: String
    ) async throws {
        let logger = application.logger
        logger.info("Fetching \(remotePath) -> \(localFile)")

        let token = try await WeatherNextGoogleAuthTokenProvider(
            client: application.dedicatedHttpClient,
            logger: logger
        ).getAccessToken()

        let url = try WeatherNextGcsPath(remotePath).authenticatedDownloadUrl
        var request = HTTPClientRequest(url: url)
        request.method = .GET
        request.headers.add(name: "Authorization", value: "Bearer \(token)")

        let response = try await application.dedicatedHttpClient.execute(request, timeout: .seconds(300))
        guard response.status == .ok else {
            let error = try await response.readStringImmutable() ?? ""
            throw WeatherNextDownloaderError.httpError(
                status: Int(response.status.code),
                message: "Could not download \(remotePath): \(error)"
            )
        }

        try FileManager.default.createDirectory(
            atPath: URL(fileURLWithPath: localFile).deletingLastPathComponent().path,
            withIntermediateDirectories: true
        )

        let fileHandle = try FileHandle.createNewFile(file: localFile, overwrite: true, temporary: true)
        do {
            for try await chunk in response.body {
                try Task.checkCancellation()
                try fileHandle.write(contentsOf: Data(buffer: chunk))
            }
            try fileHandle.linkTemporary(file: localFile)
        } catch {
            try? fileHandle.close()
            throw error
        }
        try fileHandle.close()
    }

    /**
     Decode one upstream WeatherNext `.om` file into member-wise arrays.

     Expected upstream payload:
     - one valid time per file
     - all variables present
     - dimensions `[member, lat, lon]`

     This is the main integration point once the upstream OM payload details are known.
     */
    func decodeWeatherNextFile(
        application: Application,
        domain: WeatherNextDomain,
        file: String,
        run: Timestamp,
        validTime: Timestamp
    ) throws -> WeatherNextDecodedTimestep {
        _ = application
        _ = domain
        _ = file
        _ = run

        throw WeatherNextDownloaderError.notImplemented(
            "WeatherNext upstream OM decoding is not implemented yet for \(validTime.iso8601_YYYY_MM_dd_HH_mm)"
        )
    }

    func writeDecodedTimestep(
        application: Application,
        domain: WeatherNextDomain,
        writer: OmSpatialMultistepWriter,
        decoded: WeatherNextDecodedTimestep
    ) async throws {
        let logger = application.logger
        logger.info("Writing decoded timestep \(decoded.validTime.iso8601_YYYY_MM_dd_HH_mm)")

        for member in 0..<domain.countEnsembleMember {
            for variable in WeatherNextVariable.rawVariables {
                guard let data = decoded.data[WeatherNextMemberVariable(member: member, variable: variable)] else {
                    continue
                }
                try await writer.write(time: decoded.validTime, member: member, variable: variable, data: data)
            }

            try await deriveSurfaceWind(writer: writer, decoded: decoded, member: member)
            try await derivePressureLevelWind(writer: writer, decoded: decoded, member: member)
            try await deriveCloudCover(writer: writer, decoded: decoded, member: member)
        }
    }

    /// Derive wind speed / direction from 10m and 100m U/V components.
    func deriveSurfaceWind(
        writer: OmSpatialMultistepWriter,
        decoded: WeatherNextDecodedTimestep,
        member: Int
    ) async throws {
        let pairs: [(u: WeatherNextVariable, v: WeatherNextVariable, speed: WeatherNextVariable, direction: WeatherNextVariable)] = [
            (WeatherNextVariable.wind_u_component_10m, WeatherNextVariable.wind_v_component_10m, WeatherNextVariable.wind_speed_10m, WeatherNextVariable.wind_direction_10m),
            (WeatherNextVariable.wind_u_component_100m, WeatherNextVariable.wind_v_component_100m, WeatherNextVariable.wind_speed_100m, WeatherNextVariable.wind_direction_100m)
        ]

        for pair in pairs {
            guard
                let u = decoded.data[WeatherNextMemberVariable(member: member, variable: pair.u)],
                let v = decoded.data[WeatherNextMemberVariable(member: member, variable: pair.v)]
            else {
                continue
            }

            let speed = zip(u, v).map(Meteorology.windspeed)
            let direction = Meteorology.windirectionFast(u: u, v: v)

            try await writer.write(time: decoded.validTime, member: member, variable: pair.speed, data: speed)
            try await writer.write(time: decoded.validTime, member: member, variable: pair.direction, data: direction)
        }
    }

    /// Derive wind speed / direction for pressure levels from U/V components.
    func derivePressureLevelWind(
        writer: OmSpatialMultistepWriter,
        decoded: WeatherNextDecodedTimestep,
        member: Int
    ) async throws {
        for level in WeatherNextPressureLevel.allCases {
            guard
                let u = decoded.data[WeatherNextMemberVariable(member: member, variable: WeatherNextVariable.windU(level: level))],
                let v = decoded.data[WeatherNextMemberVariable(member: member, variable: WeatherNextVariable.windV(level: level))]
            else {
                continue
            }

            let speed = zip(u, v).map(Meteorology.windspeed)
            let direction = Meteorology.windirectionFast(u: u, v: v)

            try await writer.write(time: decoded.validTime, member: member, variable: WeatherNextVariable.windSpeed(level: level), data: speed)
            try await writer.write(time: decoded.validTime, member: member, variable: WeatherNextVariable.windDirection(level: level), data: direction)
        }
    }

    /// Derive cloud cover from pressure-level relative humidity using the same grouping as ECMWF.
    func deriveCloudCover(
        writer: OmSpatialMultistepWriter,
        decoded: WeatherNextDecodedTimestep,
        member: Int
    ) async throws {
        guard
            let rh1000 = decoded.data[WeatherNextMemberVariable(member: member, variable: WeatherNextVariable.relative_humidity_1000hPa)],
            let rh925 = decoded.data[WeatherNextMemberVariable(member: member, variable: WeatherNextVariable.relative_humidity_925hPa)],
            let rh850 = decoded.data[WeatherNextMemberVariable(member: member, variable: WeatherNextVariable.relative_humidity_850hPa)],
            let rh700 = decoded.data[WeatherNextMemberVariable(member: member, variable: WeatherNextVariable.relative_humidity_700hPa)],
            let rh600 = decoded.data[WeatherNextMemberVariable(member: member, variable: WeatherNextVariable.relative_humidity_600hPa)],
            let rh500 = decoded.data[WeatherNextMemberVariable(member: member, variable: WeatherNextVariable.relative_humidity_500hPa)],
            let rh400 = decoded.data[WeatherNextMemberVariable(member: member, variable: WeatherNextVariable.relative_humidity_400hPa)],
            let rh300 = decoded.data[WeatherNextMemberVariable(member: member, variable: WeatherNextVariable.relative_humidity_300hPa)],
            let rh250 = decoded.data[WeatherNextMemberVariable(member: member, variable: WeatherNextVariable.relative_humidity_250hPa)],
            let rh200 = decoded.data[WeatherNextMemberVariable(member: member, variable: WeatherNextVariable.relative_humidity_200hPa)],
            let rh150 = decoded.data[WeatherNextMemberVariable(member: member, variable: WeatherNextVariable.relative_humidity_150hPa)],
            let rh100 = decoded.data[WeatherNextMemberVariable(member: member, variable: WeatherNextVariable.relative_humidity_100hPa)],
            let rh50 = decoded.data[WeatherNextMemberVariable(member: member, variable: WeatherNextVariable.relative_humidity_50hPa)]
        else {
            return
        }

        let cloudcoverLow = zip(rh1000, zip(rh925, rh850)).map {
            max(
                Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0.0, pressureHPa: 1000),
                max(
                    Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0.1.0, pressureHPa: 925),
                    Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0.1.1, pressureHPa: 850)
                )
            )
        }

        let cloudcoverMid = zip(zip(rh700, rh600), zip(rh500, rh400)).map {
            max(
                Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0.0.0, pressureHPa: 700),
                max(
                    Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0.0.1, pressureHPa: 600),
                    max(
                        Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0.1.0, pressureHPa: 500),
                        Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0.1.1, pressureHPa: 400)
                    )
                )
            )
        }

        let cloudcoverHigh = zip(zip(rh300, rh250), zip(zip(rh200, rh150), zip(rh100, rh50))).map {
            max(
                Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0.0.0, pressureHPa: 300),
                max(
                    Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0.0.1, pressureHPa: 250),
                    max(
                        Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0.1.0.0, pressureHPa: 200),
                        max(
                            Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0.1.0.1, pressureHPa: 150),
                            max(
                                Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0.1.1.0, pressureHPa: 100),
                                Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0.1.1.1, pressureHPa: 50)
                            )
                        )
                    )
                )
            )
        }

        let cloudcover = Meteorology.cloudCoverTotal(low: cloudcoverLow, mid: cloudcoverMid, high: cloudcoverHigh)

        try await writer.write(time: decoded.validTime, member: member, variable: WeatherNextVariable.cloud_cover_low, data: cloudcoverLow)
        try await writer.write(time: decoded.validTime, member: member, variable: WeatherNextVariable.cloud_cover_mid, data: cloudcoverMid)
        try await writer.write(time: decoded.validTime, member: member, variable: WeatherNextVariable.cloud_cover_high, data: cloudcoverHigh)
        try await writer.write(time: decoded.validTime, member: member, variable: WeatherNextVariable.cloud_cover, data: cloudcover)
    }
}

enum WeatherNextDownloaderError: Error {
    case notImplemented(String)
    case invalidGcsPath(String)
    case missingGoogleCredentials(String)
    case invalidGoogleCredentials(String)
    case httpError(status: Int, message: String)
}

struct WeatherNextSourcePath {
    let server: String
    let run: Timestamp
    let validTime: Timestamp

    var remotePath: String {
        let base = server.hasSuffix("/") ? server : "\(server)/"
        return "\(base)\(run.iso8601_YYYY_MM_dd_HH_mm_ssZ)/\(validTime.iso8601_YYYY_MM_dd_HH_mm_ssZ).om"
    }
}

private struct WeatherNextGcsPath {
    let bucket: String
    let object: String

    init(_ gsPath: String) throws {
        guard gsPath.hasPrefix("gs://") else {
            throw WeatherNextDownloaderError.invalidGcsPath("Expected gs:// path, got \(gsPath)")
        }
        let withoutScheme = String(gsPath.dropFirst("gs://".count))
        let parts = withoutScheme.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false)
        guard let bucket = parts.first, !bucket.isEmpty else {
            throw WeatherNextDownloaderError.invalidGcsPath("Missing bucket in \(gsPath)")
        }
        self.bucket = String(bucket)
        self.object = parts.count > 1 ? String(parts[1]) : ""
    }

    var authenticatedDownloadUrl: String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        let encodedObject = object.addingPercentEncoding(withAllowedCharacters: allowed) ?? object
        return "https://storage.googleapis.com/download/storage/v1/b/\(bucket)/o/\(encodedObject)?alt=media"
    }
}

private actor WeatherNextGoogleAuthTokenProvider {
    private let client: HTTPClient
    private let logger: Logger
    private var cachedToken: CachedToken?

    init(client: HTTPClient, logger: Logger) {
        self.client = client
        self.logger = logger
    }

    func getAccessToken() async throws -> String {
        if let cachedToken, cachedToken.expiry > Date().addingTimeInterval(60) {
            return cachedToken.token
        }

        let credentialsPath = try getCredentialsPath()
        let credentials = try readCredentials(path: credentialsPath)
        let jwt = try await makeSignedJwt(credentials: credentials)
        let token = try await exchangeJwtForAccessToken(jwt: jwt, tokenUri: credentials.token_uri)

        self.cachedToken = token
        return token.token
    }

    private func getCredentialsPath() throws -> String {
        guard let path = Environment.get("GOOGLE_APPLICATION_CREDENTIALS"), !path.isEmpty else {
            throw WeatherNextDownloaderError.missingGoogleCredentials(
                "Set GOOGLE_APPLICATION_CREDENTIALS to a Google service account JSON file"
            )
        }
        return path
    }

    private func readCredentials(path: String) throws -> ServiceAccountCredentials {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let decoder = JSONDecoder()
        let credentials = try decoder.decode(ServiceAccountCredentials.self, from: data)
        guard credentials.type == "service_account" else {
            throw WeatherNextDownloaderError.invalidGoogleCredentials(
                "GOOGLE_APPLICATION_CREDENTIALS must point to a service account JSON file"
            )
        }
        return credentials
    }

    private func makeSignedJwt(credentials: ServiceAccountCredentials) async throws -> String {
        let payload = GoogleServiceAccountPayload(
            iss: IssuerClaim(value: credentials.client_email),
            scope: "https://www.googleapis.com/auth/devstorage.read_only",
            aud: AudienceClaim(value: credentials.token_uri),
            exp: ExpirationClaim(value: Date().addingTimeInterval(3600)),
            iat: IssuedAtClaim(value: Date())
        )

        let key = try Insecure.RSA.PrivateKey(pem: credentials.private_key)
        let keys = JWTKeyCollection()
        await keys.add(rsa: key, digestAlgorithm: .sha256)

        return try await keys.sign(payload)
    }

    private func exchangeJwtForAccessToken(jwt: String, tokenUri: String) async throws -> CachedToken {
        var request = HTTPClientRequest(url: tokenUri)
        request.method = .POST
        request.headers.add(name: "Content-Type", value: "application/x-www-form-urlencoded")

        let body = "grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=\(jwt)"
        request.body = .bytes(ByteBuffer(string: body))

        let response = try await client.execute(request, timeout: .seconds(60))
        guard response.status == .ok else {
            let error = try await response.readStringImmutable() ?? ""
            throw WeatherNextDownloaderError.httpError(
                status: Int(response.status.code),
                message: "Could not obtain Google OAuth token: \(error)"
            )
        }

        guard let tokenResponse = try await response.readJSONDecodable(GoogleAccessTokenResponse.self) else {
            throw WeatherNextDownloaderError.invalidGoogleCredentials("Could not decode Google OAuth token response")
        }

        return CachedToken(
            token: tokenResponse.access_token,
            expiry: Date().addingTimeInterval(TimeInterval(tokenResponse.expires_in))
        )
    }

    private struct CachedToken {
        let token: String
        let expiry: Date
    }

    private struct ServiceAccountCredentials: Decodable {
        let type: String
        let private_key: String
        let client_email: String
        let token_uri: String
    }

    private struct GoogleAccessTokenResponse: Decodable {
        let access_token: String
        let expires_in: Int
        let token_type: String
    }

    private struct GoogleServiceAccountPayload: JWTPayload {
        let iss: IssuerClaim
        let scope: String
        let aud: AudienceClaim
        let exp: ExpirationClaim
        let iat: IssuedAtClaim

        func verify(using algorithm: some JWTAlgorithm) async throws {
            try exp.verifyNotExpired()
        }
    }
}

private extension Data {
    func base64UrlEncodedString() -> String {
        self.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

struct WeatherNextMemberVariable: Hashable {
    let member: Int
    let variable: WeatherNextVariable
}

struct WeatherNextDecodedTimestep {
    let run: Timestamp
    let validTime: Timestamp
    let data: [WeatherNextMemberVariable: [Float]]
}
