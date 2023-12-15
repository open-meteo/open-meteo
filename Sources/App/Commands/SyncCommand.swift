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
    }
    
    func run(using context: CommandContext, signature: Signature) async throws {
        let logger = context.application.logger
        
        disableIdleSleep()
        
        let server = signature.server ?? "https://openmeteo.s3.amazonaws.com/"
        guard server.starts(with: "http"), server.last == "/" else {
            fatalError("Server name must include http and end with a trailing slash")
        }
        let pastDays = signature.pastDays ?? 7
        let models = try DomainRegistry.load(commaSeparated: signature.models)
        let variables = signature.variables.split(separator: ",")
        /// Undocumented switch to download all weather variables. This can generate immense traffic!
        let downloadAllVariables = signature.variables == "really_download_all_variables"
        
        let curl = Curl(logger: logger, client: context.application.dedicatedHttpClient, retryError4xx: false)
        
        while true {
            logger.info("Checking for files to download newer than \(pastDays) days")
            let newerThan = Timestamp.now().add(-24 * 3600 * pastDays)
            
            /// E.g. `data/ncep_gfs025/temperature_2m/chunk_1234.om`
            var toDownload = [S3DataController.S3ListV2File]()
            
            for model in models {
                let modelPrefix = "data/\(model.rawValue)/"
                let remoteDirectories = try await curl.s3list(server: server, prefix: modelPrefix, apikey: signature.apikey).directories
                print(remoteDirectories)
                
                if downloadAllVariables {
                    for variablePrefix in remoteDirectories {
                        let remote = try await curl.s3list(server: server, prefix: variablePrefix, apikey: signature.apikey)
                        let filtered = remote.files.includeFiles(newerThan: newerThan, domain: model).includeFiles(compareLocalDirectory: OpenMeteo.dataDirectory)
                        toDownload.append(contentsOf: filtered)
                    }
                } else {
                    if remoteDirectories.contains("\(modelPrefix)static/") {
                        toDownload.append(contentsOf: try await curl.s3list(server: server, prefix: "\(modelPrefix)static/", apikey: signature.apikey).files.includeFiles(compareLocalDirectory: OpenMeteo.dataDirectory))
                    }
                    // Check specified variables
                    for variable in variables {
                        let variablePrefix = "\(modelPrefix)\(variable)/"
                        guard remoteDirectories.contains(variablePrefix) else {
                            continue
                        }
                        let remote = try await curl.s3list(server: server, prefix: variablePrefix, apikey: signature.apikey)
                        let filtered = remote.files.includeFiles(newerThan: newerThan, domain: model).includeFiles(compareLocalDirectory: OpenMeteo.dataDirectory)
                        toDownload.append(contentsOf: filtered)
                    }
                }
            }
            
            let totalBytes = toDownload.reduce(0, {$0 + $1.fileSize})
            logger.info("Downloading \(toDownload.count) files (\(totalBytes.bytesHumanReadable))")
            let progress = TransferAmountTracker(logger: logger, totalSize: totalBytes)
            for download in toDownload {
                curl.setDeadlineIn(minutes: 30)
                let startBytes = curl.totalBytesTransfered
                var client = ClientRequest(url: URI("\(server)\(download.name)"))
                try client.query.encode(S3DataController.DownloadParams(apikey: signature.apikey, rate: signature.rate))
                let pathNoData = download.name[download.name.index(download.name.startIndex, offsetBy: 5)..<download.name.endIndex]
                let localFile = "\(OpenMeteo.dataDirectory)/\(pathNoData)"
                let localDir = String(localFile[localFile.startIndex ..< localFile.lastIndex(of: "/")!])
                try FileManager.default.createDirectory(atPath: localDir, withIntermediateDirectories: true)
                try await curl.download(url: client.url.string, toFile: localFile, bzip2Decode: false)
                progress.add(curl.totalBytesTransfered - startBytes)
            }
            progress.finish()
            
            guard let repeatInterval = signature.repeatInterval else {
                break
            }
            logger.info("Repeat in \(repeatInterval) minutes")
            try await Task.sleep(nanoseconds: UInt64(repeatInterval * 60_000_000_000))
        }
        curl.printStatistics()
    }
}

fileprivate extension Array where Element == S3DataController.S3ListV2File {
    /// Only include files with data newer than a given timestamp. This is based on evaluating the time-chunk in the filename and is not based on the modification time
    func includeFiles(newerThan: Timestamp, domain: DomainRegistry) -> [Element] {
        let omFileLength = domain.getDomain().omFileLength
        let dtSeconds = domain.getDomain().dtSeconds
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
                let end = Timestamp(year+1, 1, 1)
                return end > newerThan
            }
            if name.starts(with: "chunk_"), let chunk = Int(name[name.index(name.startIndex, offsetBy: 6)..<(name.lastIndex(of: ".") ?? name.endIndex)]) {
                let end = Timestamp((chunk + 1) * omFileLength * dtSeconds)
                return end > newerThan
            }
            return false
        })
    }
    
    /// Compare remote files to local files. Only keep files that are not available locally or older.
    func includeFiles(compareLocalDirectory: String) -> [Element] {
        let resourceKeys = Set<URLResourceKey>([.contentModificationDateKey, .fileSizeKey])
        return self.filter({ file in
            let pathNoData = file.name[file.name.index(file.name.startIndex, offsetBy: 5)..<file.name.endIndex]
            let fileURL = URL(fileURLWithPath: "\(compareLocalDirectory)\(pathNoData)")
            guard let resourceValues = try? fileURL.resourceValues(forKeys: resourceKeys),
                  let size = resourceValues.fileSize,
                  let modificationTime = resourceValues.contentModificationDate else {
                return true
            }
            return file.fileSize != size || modificationTime > file.modificationTime
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
    func s3list(server: String, prefix: String, apikey: String?) async throws -> (files: [S3DataController.S3ListV2File], directories: [String]) {
        var request = ClientRequest(method: .GET, url: URI("\(server)"))
        let params = S3DataController.S3ListV2(list_type: 2, delimiter: "/", prefix: prefix, apikey: apikey)
        try request.query.encode(params)
        var response = try await downloadInMemoryAsync(url: request.url.string, minSize: nil)
        guard let body = response.readString(length: response.readableBytes) else {
            return ([],[])
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
