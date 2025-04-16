import Foundation
import Vapor

/**
Download the open-meteo weather database from a S3 server.

Arguments:
           models Weather model domains separated by comma. E.g. 'cmc_gem_gdps,dwd_icon'
        variables Weather variables separated by comma. E.g. 'temperature_2m,relative_humidity_2m'

Options:
           apikey Sync API key for accessing Open-Meteo servers directly. Not required for AWS open-data.
           server Server base URL. Default 'https://openmeteo.s3.amazonaws.com/'
             rate Transfer rate in megabytes per second. Not applicable for AWS open-data.
        past-days Maximum age of synchronised files. Default 7 days.
  repeat-interval If set, check for new files every specified amount of minutes.

Example to download from a local endpoint
DATA_DIRECTORY=/Volumes/2TB_1GBs/data/ API_SYNC_APIKEYS=123 openmeteo-api
DATA_DIRECTORY=/Volumes/2TB_1GBs/data2/ openmeteo-api sync cmc_gem_gdps,dwd_icon_d2,dwd_icon temperature_2m --server http://127.0.0.1:8080/ --apikey 123 --past-days 30 --repeat-interval 5
*/
struct SyncCommand: AsyncCommand {
    var help: String {
        return "Download the open-meteo weather database from a S3 server."
    }

    struct Signature: CommandSignature {
        @Argument(name: "models", help: "Weather model domains separated by comma. E.g. 'cmc_gem_gdps,dwd_icon'")
        var models: String

        @Argument(name: "variables", help: "Weather variables separated by comma. E.g. 'temperature_2m,relative_humidity_2m'")
        var variables: String

        @Option(name: "apikey", help: "Sync API key for accessing Open-Meteo servers directly. Not required for AWS open-data.")
        var apikey: String?

        @Option(name: "server", help: "Server base URL. Default 'https://openmeteo.s3.amazonaws.com/'")
        var server: String?

        @Option(name: "rate", help: "Transfer rate in megabytes per second. Not applicable for AWS open-data.")
        var rate: Int?

        @Option(name: "past-days", help: "Maximum age of synchronised files. Default 7 days.")
        var pastDays: Int?

        @Option(name: "repeat-interval", help: "If set, check for new files every specified amount of minutes.")
        var repeatInterval: Int?

        @Option(name: "concurrent", short: "c", help: "Number of concurrent file download. Default 4")
        var concurrent: Int?

        @Option(name: "data-directory-max-size-gb", help: "Trim data directory to the speicfied target size in gigabyte GB")
        var dataDirectoryMaxSize: Int?

        @Option(name: "cache-directory-max-size-gb", help: "Trim cache directory to the speicfied target size in gigabyte GB")
        var cacheDirectoryMaxSize: Int?

        @Flag(name: "execute", help: "Actually perfom file delete on cleanup")
        var execute: Bool

        @Option(name: "year", help: "Download one year or a range of years (e.g. 2000-2005)")
        var year: String?
    }

    /// All weather variables that may be available for `previous days API`
    static var previousDayVariables = ["temperature_2m", "dew_point_2m", "relative_humidity_2m", "precipitation", "snowfall_water_equivalent", "snowfall", "frozen_precipitation_percent", "pressure_msl", "cloud_cover", "wind_u_component_10m", "wind_v_component_10m", "showers", "shortwave_radiation", "direct_radiation", "diffuse_radiation", "wind_gusts_10m", "wind_speed_10m", "wind_direction_10m", "weather_code", "cape", "lifted_index", "wind_speed_80m", "wind_direction_80m", "wind_speed_120m", "wind_direction_120m", "wind_speed_180m", "wind_direction_180m", "wind_u_component_70m", "wind_v_component_70m", "wind_u_component_80m", "wind_v_component_80m", "wind_u_component_100m", "wind_v_component_100m", "wind_u_component_120m", "wind_v_component_120m", "wind_u_component_180m", "wind_v_component_180m"]

    func run(using context: CommandContext, signature: Signature) async throws {
        let logger = context.application.logger

        disableIdleSleep()

        let serverSet = (signature.server ?? "https://openmeteo.s3.amazonaws.com/").split(separator: ";").map(String.init)
        for server in serverSet {
            guard server.last == "/" else {
                fatalError("Server name must include http and end with a trailing slash.")
            }
        }
        let modelsSet = try signature.models.split(separator: ";").map({
            try DomainRegistry.load(commaSeparated: String($0))
        })
        guard Curl.cacheDirectory == nil else {
            fatalError("HTTP_CACHE enabled")
        }

        guard serverSet.count == modelsSet.count else {
           fatalError("Number of servers and models sets must be the same")
        }

        let variablesSetA = signature.variables.split(separator: ";").map {
            $0.split(separator: ",").map(String.init) + ["static"]
        }
        if variablesSetA.count > 1 && variablesSetA.count != serverSet.count {
            fatalError("Number of servers and variables sets must be the same")
        }
        let variablesSet = variablesSetA.count != serverSet.count ? [[String]](repeating: variablesSetA[0], count: serverSet.count) : variablesSetA

        let pastDays = signature.pastDays ?? 7
        let concurrent = signature.concurrent ?? 4

        /// Select all files that contain data within a range of years
        let yearRange = signature.year.map { yearStr in
            if yearStr.contains("-") {
                let split = yearStr.split(separator: "-")
                guard split.count == 2, split[0].count == 4, split[1].count == 4, let start = Int(split[0]), let end = Int(split[1]), start >= 1800, start <= 2200, end >= 1800, end <= 2200 else {
                    fatalError("year invalid")
                }
                return Timestamp(start, 1, 1) ..< Timestamp(end + 1, 1, 1)
            }
            guard yearStr.count == 4, let year = Int(yearStr), year >= 1800, year <= 2200 else {
                fatalError("year invalid")
            }
            return Timestamp(year, 1, 1) ..< Timestamp(year + 1, 1, 1)
        }

        /// Download from each server concurrently
        await zip(serverSet, zip(modelsSet, variablesSet)).foreachConcurrent(nConcurrent: serverSet.count) { server, arg1 in
            let (models, variablesSig) = arg1
            /// Undocumented switch to download all weather variables. This can generate immense traffic!
            let downloadAllVariables = variablesSig.contains("really_download_all_variables")
            let downloadAllButPressureOncePerDay = variablesSig.contains("really_download_all_but_pressure_once_per_day")
            let downloadAllPreviousDay = variablesSig.contains("really_download_all_previous_day")
            let downloadAllPressureLevel = variablesSig.contains("really_download_all_pressure_levels")
            let downloadAllSurface = variablesSig.contains("really_download_all_surface_levels")
            let variables = downloadAllPreviousDay ? Self.previousDayVariables : variablesSig

            let curl = Curl(logger: logger, client: context.application.dedicatedHttpClient, retryError4xx: false)
            var lastPressureDownloadDate = Timestamp.now().with(hour: 0).add(days: -1)

            while true {
                /// Used for `really_download_all_but_pressure_once_per_day` to download pressure data only once per day
                let downloadPressureNow = lastPressureDownloadDate != Timestamp.now().with(hour: 0)
                do {
                    if let yearRange {
                        let start = yearRange.lowerBound.toComponents().year
                        let end = yearRange.upperBound.toComponents().year - 1
                        logger.info("Checking for files within year \(start)-\(end)")
                    } else {
                        logger.info("Checking for files to with more than \(pastDays) past days data")
                    }

                    let timeRange = yearRange ?? Timestamp.now().add(-24 * 3600 * pastDays) ..< Timestamp(2200, 1, 1)

                    /// Get a list of all variables from all models
                    let remotes: [(DomainRegistry, String)] = try await models.mapConcurrent(nConcurrent: concurrent) { model -> [(DomainRegistry, String)] in
                        let remoteDirectories = try await curl.s3list(server: server, prefix: "data/\(model.rawValue)/", apikey: signature.apikey, deadLineHours: 0.1).directories
                        return remoteDirectories.map {
                            return (model, $0)
                        }
                    }.flatMap({ $0 })

                    /// Filter variables to download
                    let toDownload: [S3DataController.S3ListV2File] = try await remotes.mapConcurrent(nConcurrent: concurrent) { model, remoteDirectory -> [S3DataController.S3ListV2File] in
                        guard let variablePos = remoteDirectory.dropLast().lastIndex(of: "/") else {
                            fatalError("could not get variable from string")
                        }
                        let variable = remoteDirectory[remoteDirectory.index(after: variablePos)..<remoteDirectory.index(before: remoteDirectory.endIndex)]
                        let isPreviousDay = variable.contains("_previous_day")
                        let isPressureLevel = variable.contains("hPa")
                        let isSurface = !isPressureLevel && !variable.contains("_previous_day")
                        guard downloadAllVariables ||
                                (downloadAllButPressureOncePerDay && (!isPressureLevel || downloadPressureNow)) ||
                                (downloadAllPressureLevel && isPressureLevel) ||
                                (downloadAllSurface && isSurface) ||
                                (downloadAllPreviousDay && isPreviousDay) ||
                                variables.contains(where: { $0 == variable }) else {
                            return []
                        }
                        let remote = try await curl.s3list(server: server, prefix: remoteDirectory, apikey: signature.apikey, deadLineHours: 0.1)
                        let filtered = remote.files.includeFiles(timeRange: timeRange, domain: model).includeFiles(compareLocalDirectory: OpenMeteo.dataDirectory)
                        return Array(filtered)
                    }.flatMap({ $0 })

                    /// Download all files
                    let totalBytes = toDownload.reduce(0, { $0 + $1.fileSize })
                    logger.info("Downloading \(toDownload.count) files (\(totalBytes.bytesHumanReadable))")
                    let progress = TransferAmountTrackerActor(logger: logger, totalSize: totalBytes)
                    let curlStartBytes = await curl.totalBytesTransfered.bytes
                    try await toDownload.foreachConcurrent(nConcurrent: concurrent) { download in
                        var client = ClientRequest(url: URI("\(server)\(download.name)"))
                        if signature.apikey != nil || signature.rate != nil {
                            try client.query.encode(S3DataController.DownloadParams(apikey: signature.apikey, rate: signature.rate))
                        }
                        let pathNoData = download.name[download.name.index(download.name.startIndex, offsetBy: 5)..<download.name.endIndex]
                        let localFile = "\(OpenMeteo.dataDirectory)/\(pathNoData)"
                        let localDir = String(localFile[localFile.startIndex ..< localFile.lastIndex(of: "/")!])
                        try FileManager.default.createDirectory(atPath: localDir, withIntermediateDirectories: true)
                        // Another process might be updating this file right now. E.g. Second sync operation
                        FileManager.default.waitIfFileWasRecentlyModified(at: "\(localFile)~", waitTimeMinutes: 1)
                        if localFile.hasSuffix("/meta.json") {
                            /// Update the `last_run_availability_time` within meta.json
                            try await curl
                                .downloadInMemoryAsync(url: client.url.string, minSize: nil, deadLineHours: 0.1)
                                .readJSONDecodable(ModelUpdateMetaJson.self)?
                                .with(last_run_availability_time: .now())
                                .writeTo(path: localFile)
                        } else {
                            try await curl.download(url: client.url.string, toFile: localFile, bzip2Decode: false, deadLineHours: 0.5)
                        }
                        /*if let cacheDirectory = OpenMeteo.cacheDirectory {
                            // Delete cached file, in case cache is active
                            let cacheFile = "\(cacheDirectory)/\(pathNoData)"
                            try FileManager.default.removeItemIfExists(at: cacheFile)
                        }*/
                        await progress.set(curl.totalBytesTransfered.bytes - curlStartBytes)
                    }
                    await progress.finish()

                    guard let repeatInterval = signature.repeatInterval else {
                        break
                    }

                    if let dataDirectoryMaxSize = signature.dataDirectoryMaxSize, dataDirectoryMaxSize > 0 {
                        try cacheDirectoryCleanup(logger: logger, cacheDirectory: OpenMeteo.dataDirectory, maxSize: dataDirectoryMaxSize * 1 << 30, execute: signature.execute)
                    }
                    /*if let cacheDirectoryMaxSize = signature.cacheDirectoryMaxSize, cacheDirectoryMaxSize > 0, let cacheDirectory = OpenMeteo.cacheDirectory {
                        try cacheDirectoryCleanup(logger: logger, cacheDirectory: cacheDirectory, maxSize: cacheDirectoryMaxSize * 1<<30, execute: signature.execute)
                    }*/

                    logger.info("Repeat in \(repeatInterval) minutes")
                    try await Task.sleep(nanoseconds: UInt64(repeatInterval * 60_000_000_000))
                } catch {
                    logger.critical("Error during sync \(error)")
                    fatalError()
                }
                if downloadPressureNow {
                    lastPressureDownloadDate = Timestamp.now().with(hour: 0)
                }
            }
            await curl.printStatistics()
        }
    }

    /**
     Delete old files to trim directory size
     */
    func cacheDirectoryCleanup(logger: Logger, cacheDirectory: String, maxSize: Int, execute: Bool) throws {
        logger.info("Checking directory size of '\(cacheDirectory)'. Target size \(maxSize.bytesHumanReadable)")
        if cacheDirectory.isEmpty, maxSize <= 0 {
            fatalError()
        }
        let resourceKeys: [URLResourceKey] = [.isRegularFileKey, .contentModificationDateKey]
        guard let enumerator = FileManager.default.enumerator(
            at: URL(fileURLWithPath: cacheDirectory),
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            fatalError("Could not get enumerator")
        }

        var files = [(file: URL, modifiedAt: Date, size: Int)]()
        var totalSize: Int = 0
        for case let fileURL as URL in enumerator {
            do {
                if fileURL.absoluteString.last == "~" {
                    continue
                }
                let fileAttributes = try fileURL.resourceValues(forKeys: Set(resourceKeys))
                guard fileAttributes.isRegularFile == true,
                        let modificationDate = fileAttributes.contentModificationDate else {
                    continue
                }
                let size = fileURL.getAllocatedSize()
                totalSize += size
                if !fileURL.absoluteString.contains(".om") || fileURL.absoluteString.contains("/static/") {
                    continue
                }
                files.append((fileURL, modificationDate, size))
            } catch {
                print(error, fileURL)
            }
        }
        if totalSize < maxSize {
            logger.info("OK, Total Size: \(totalSize.bytesHumanReadable)")
            return
        }
        logger.info("Cleanup, current size \(totalSize.bytesHumanReadable), deleting \((totalSize - maxSize).bytesHumanReadable)")

        // Sort by modification date
        files.sort(by: { $0.modifiedAt < $1.modifiedAt })
        for file in files {
            guard totalSize > maxSize else {
                break
            }
            if execute {
                logger.info("Remove file \(file.file), modified at \(file.modifiedAt), size \(file.size.bytesHumanReadable)")
                do {
                    try FileManager.default.removeItem(at: file.file)
                } catch {
                    print(error, file.file)
                }
            } else {
                logger.info("[DRY RUN] Would remove file \(file.file), modified at \(file.modifiedAt), size \(file.size.bytesHumanReadable)")
            }
            totalSize -= file.size
        }
        logger.info("New size \(totalSize.bytesHumanReadable)")
    }
}

fileprivate extension URL {
    /// Get the allocated size on disk. Swift implementation reports incorrect sizes on Linx https://github.com/apple/swift-corelibs-foundation/issues/4885
    func getAllocatedSize() -> Int {
        return withUnsafeFileSystemRepresentation({ path in
            guard let path else {
                return 0
            }
            var stats = stat()
            guard lstat(path, &stats) != -1 else {
                let error = String(cString: strerror(errno))
                fatalError("lstat failed. Error \(errno) \(error)")
            }
            // must be 512 https://unix.stackexchange.com/questions/521151/why-is-st-blocks-always-reported-in-512-byte-blocks
            return Int(stats.st_blocks) * 512
        })
    }
}

fileprivate extension Array where Element == S3DataController.S3ListV2File {
    /// Only include files with data newer than a given timestamp. This is based on evaluating the time-chunk in the filename and is not based on the modification time
    func includeFiles(timeRange: Range<Timestamp>, domain registry: DomainRegistry) -> [Element] {
        guard let domain = registry.getDomain() else {
            return []
        }
        let omFileLength = domain.omFileLength
        let dtSeconds = domain.dtSeconds
        return self.filter({ file in
            if file.name.contains("/static/") {
                return true
            }
            let last = file.name.lastIndex(of: "/") ?? file.name.startIndex
            let name = file.name[file.name.index(after: last)..<file.name.endIndex]
            if name.starts(with: "master_") || name.starts(with: "linear_bias_seasonal") {
                return true
            }
            if name.starts(with: "year_"), let year = Int(name[name.index(name.startIndex, offsetBy: 5)..<(name.lastIndex(of: ".") ?? name.endIndex)]) {
                let fileTime = Timestamp(year, 1, 1) ..< Timestamp(year + 1, 1, 1)
                return timeRange.overlaps(fileTime)
            }
            if name.starts(with: "chunk_"), let chunk = Int(name[name.index(name.startIndex, offsetBy: 6)..<(name.lastIndex(of: ".") ?? name.endIndex)]) {
                let fileTime = Timestamp(chunk * omFileLength * dtSeconds) ..< Timestamp((chunk + 1) * omFileLength * dtSeconds)
                return timeRange.overlaps(fileTime)
            }
            return false
        })
    }

    /// Compare remote files to local files. Only keep files that are not available locally or older.
    func includeFiles(compareLocalDirectory: String) -> [Element] {
        let resourceKeys = Set<URLResourceKey>([.contentModificationDateKey, .fileSizeKey])
        return self.filter({ remoteFile in
            let pathNoData = remoteFile.name[remoteFile.name.index(remoteFile.name.startIndex, offsetBy: 5)..<remoteFile.name.endIndex]
            let fileURL = URL(fileURLWithPath: "\(compareLocalDirectory)\(pathNoData)")
            guard let resourceValues = try? fileURL.resourceValues(forKeys: resourceKeys),
                  let size = resourceValues.fileSize,
                  let modificationTime = resourceValues.contentModificationDate else {
                return true
            }
            if remoteFile.name.contains("meta.json") {
                /// meta.json is modified during sync to replace the `last_run_availability_time`.
                /// Size might be different. Only check for modification time.
                return remoteFile.modificationTime > modificationTime.addingTimeInterval(1)
            }
            // Add one seconds delay due to inaccuracy in timestamps
            return remoteFile.fileSize != size || remoteFile.modificationTime > modificationTime.addingTimeInterval(1)
        })
    }
}

extension StringProtocol {
    /// Interpret the given string as XML and iterate over a list of keys
    func xmlSection(_ section: String) -> AnySequence<SubSequence> {
        return AnySequence<SubSequence> { () -> AnyIterator<SubSequence> in
            var pos = startIndex
            return AnyIterator<SubSequence> {
                guard let start = range(of: "<\(section)>", range: pos..<endIndex) else {
                    return nil
                }
                guard let end = range(of: "</\(section)>", range: start.upperBound..<endIndex) else {
                    return nil
                }
                let substr = self[start.upperBound..<end.lowerBound]
                pos = end.upperBound
                return substr
            }
        }
    }

    /// Interpret the given string as XML and get the first key
    func xmlFirst(_ section: String) -> SubSequence? {
        guard let start = range(of: "<\(section)>", range: startIndex..<endIndex) else {
            return nil
        }
        guard let end = range(of: "</\(section)>", range: start.upperBound..<endIndex) else {
            return nil
        }
        return self[start.upperBound..<end.lowerBound]
    }
}

fileprivate extension Curl {
    /// Use the AWS ListObjectsV2 to list files and directories inside a bucket with a prefix. No support more than 1000 objects yet
    func s3list(server: String, prefix: String, apikey: String?, deadLineHours: Double) async throws -> (files: [S3DataController.S3ListV2File], directories: [String]) {
        var request = ClientRequest(method: .GET, url: URI("\(server)"))
        let params = S3DataController.S3ListV2(list_type: 2, delimiter: "/", prefix: prefix, apikey: apikey)
        try request.query.encode(params)
        var response = try await downloadInMemoryAsync(url: request.url.string, minSize: nil, deadLineHours: deadLineHours)
        guard let body = response.readString(length: response.readableBytes) else {
            return ([], [])
        }
        let files = body.xmlSection("Contents").map {
            guard let name = $0.xmlFirst("Key"),
                  let modificationTimeString = $0.xmlFirst("LastModified"),
                  let modificationTime = DateFormatter.awsS3DateTime.date(from: String(modificationTimeString)),
                  let fileSizeString = $0.xmlFirst("Size"),
                  let fileSize = Int(fileSizeString)
            else {
                fatalError()
            }
            return S3DataController.S3ListV2File(name: String(name), modificationTime: modificationTime, fileSize: fileSize)
        }
        let directories = body.xmlSection("CommonPrefixes").map {
            guard let prefix = $0.xmlFirst("Prefix") else {
                fatalError()
            }
            return String(prefix)
        }
        return (files, directories)
    }
}
