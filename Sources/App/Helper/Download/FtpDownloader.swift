import curl_swift
import Vapor

/// Simple helper to download files from a FTP server using CURL
struct FtpDownloader {
    let shared = CURLSH()
    
    public init() {}
    
    public func get(logger: Logger, url: String, deadLineHours: Double = 1) async throws -> Data? {
        let cacheFile = Curl.cacheDirectory.map { "\($0)/\(url.sha256))" }
        if let cacheFile, FileManager.default.fileExists(atPath: cacheFile) {
            logger.info("Using cached file for \(url.stripHttpPassword())")
            return try Data(contentsOf: URL(fileURLWithPath: cacheFile))
        }
        logger.info("Downloading \(url.stripHttpPassword())")
        let req = CURL(method: "GET", url: url, verbose: false)
        req.connectTimeout = 60
        req.resourceTimeout = 300
        let progress = TimeoutTracker(logger: logger, deadline: Date().addingTimeInterval(deadLineHours*3600))
        while true {
            do {
                let response = try shared.perform(curl: req)
                let data = response.body
                if let cacheFile {
                    try data.write(to: URL(fileURLWithPath: cacheFile), options: .atomic)
                }
                return data
            } catch CURLError.internal(code: let code, str: let str) {
                if code == 78 && str == "Remote file not found" {
                    return nil
                }
                if code == 9 && str == "Access denied to remote resource" {
                    return nil // directory does not exist
                }
                logger.warning("CURLError \(code): \(str)")
                let error = CURLError.internal(code: code, str: str)
                try await progress.check(error: error, delay: 5)
            } catch {
                try await progress.check(error: error, delay: 5)
            }
        }
    }
}

extension String {
    /// Remove the auth part from a HTTP or FTP resource
    func stripHttpPassword() -> String {
        guard contains("://") && contains("@") else {
            return self
        }
        return split(separator: "/")[0] + "//" + split(separator: "@")[1]
    }
}
