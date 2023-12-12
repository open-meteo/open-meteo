import Foundation
import Vapor

struct SyncCommand: AsyncCommand {
    var help: String {
        return "Synchronise weather database from a remote server"
    }
    
    struct Signature: CommandSignature {
        @Argument(name: "models", help: "Weather model domains separated by comma. Supports multiple servers separated by semicolon;")
        var models: String
        
        @Argument(name: "variables", help: "Weather variables, separated by comma")
        var variables: String
        
        @Option(name: "apikey", help: "Sync API key for accessing direct Open-Meteo servers")
        var apikey: String?
        
        @Option(name: "server", help: "Server base URL. Default 'https://openmeteo.s3.amazonaws.com/'")
        var server: String?
        
        @Option(name: "rate", help: "Transferrate in megabytes per second")
        var rate: Int?
        
        @Option(name: "past-days", help: "Maximum age of synchronised files. Default 7 days.")
        var pastDays: Int?
        
        @Option(name: "repeat-interval", help: "If set, check for new files every specified amount of seconds.")
        var repeatInterval: Int?
        
        // delete old files (case pressure levels)
    }
    
    func run(using context: CommandContext, signature: Signature) async throws {
        let logger = context.application.logger
        
        disableIdleSleep()
        
        let server = signature.server ?? "https://openmeteo.s3.amazonaws.com/"
        let pastDays = signature.pastDays ?? 7
        let rate = signature.rate
        let models = try DomainRegistry.load(commaSeparated: signature.models)
        let variables = signature.variables.split(separator: ",")
        
        let curl = Curl(logger: logger, client: context.application.dedicatedHttpClient, retryError4xx: false)
        
        while true {
            logger.info("Checking for files to download newer than \(pastDays) days")
            let newerThan = Timestamp.now().add(-24 * 3600 * pastDays)
            
            /// E.g. `data/ncep_gfs025/temperature_2m/chunk_1234.om`
            var toDownload = [(file: String, fileSize: Int)]()
            
            for model in models {
                // always add static
                // always download linear bias files if available
                for variable in variables {
                    let remote = try await curl.s3list(server: server, prefix: "data/\(model.rawValue)/\(variable)/", apikey: signature.apikey)
                    
                    // calculate timerange for each file
                    // download if in timerange and newer
                }
            }
            
            let totalBytes = toDownload.reduce(0, {$0 + $1.fileSize})
            logger.info("Downloading \(toDownload.count) files (\(totalBytes.bytesHumanReadable))")
            let progress = TransferAmountTracker(logger: logger, totalSize: totalBytes)
            for download in toDownload {
                curl.setDeadlineIn(minutes: 30)
                let startBytes = curl.totalBytesTransfered
                var client = ClientRequest(url: URI("\(server)\(download.file)"))
                try client.query.encode(S3DataController.DownloadParams(apikey: signature.apikey, rate: signature.rate))
                let pathNoData = download.file[download.file.index(download.file.startIndex, offsetBy: 5)..<download.file.endIndex]
                let localFile = "\(OpenMeteo.dataDirectory)/\(pathNoData)"
                let localDir = String(localFile[localFile.startIndex ..< localFile.lastIndex(of: "/")!])
                try FileManager.default.createDirectory(atPath: localDir, withIntermediateDirectories: true)
                try await curl.download(url: client.url.string, toFile: localFile, bzip2Decode: false)
                progress.add(curl.totalBytesTransfered - startBytes)
            }
            
            guard let repeatInterval = signature.repeatInterval else {
                break
            }
            try await Task.sleep(nanoseconds: UInt64(repeatInterval * 1_000_000_000))
        }
        curl.printStatistics()
    }
}

fileprivate extension Array where Element == S3DataController.S3ListV2File {
    /// Only include files with data newer than a given timestamp. This is based on evaluating the time-chunk in the filename and is not based on the modification time
    func includeFiles(newerThan: Timestamp, domain: DomainRegistry) -> [Element] {
        let omFileLength = domain.getDomain().omFileLength
        return self.filter({ file in
            let name = file.name
            if name.starts(with: "master_") || name.starts(with: "linear_bias_seasonal") {
                return true
            }
            if name.starts(with: "year_"), let year = Int(name[name.index(name.startIndex, offsetBy: 5)..<name.endIndex]) {
                let end = Timestamp(year+1, 1, 1)
                return end > newerThan
            }
            if name.starts(with: "chunk_"), let chunk = Int(name[name.index(name.startIndex, offsetBy: 6)..<name.endIndex]) {
                let end = Timestamp((chunk + 1) * omFileLength)
                return end > newerThan
            }
            return false
        })
    }
}

extension StringProtocol {
    /// Interprete the given string as XML and iteraterate over a list of keys
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
    
    /// Interprete the given string as XML and get the first key
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
