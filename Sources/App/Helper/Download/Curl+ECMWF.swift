import Foundation
import AsyncHTTPClient
import SwiftEccodes
import NIOCore

enum EcmwfApiError: Error {
    case jobAborted
    case jobStartFailed(error: String)
    case restrictedAccessToValidData
}

extension Curl {
    /**
     Get GRIB data from the ECMWF API
     Important: http client must be configured to disallow redirects!
     */
    func withEcmwfApi<T>(query: any Encodable, email: String, apikey: String, body: (AnyAsyncSequence<GribMessage>) async throws -> (T)) async throws -> T {
        
        let job = try await startEcmwfApiJob(query: query, email: email, apikey: apikey)
        let gribUrl = try await waitForEcmwfJob(job: job, email: email, apikey: apikey)
        let result = try await withGribStream(url: gribUrl, bzip2Decode: false, body: body)
        try await cleanupEcmwfApiJob(job: job, email: email, apikey: apikey)
        return result
    }
    
    fileprivate struct EcmwfApiResponse: Decodable {
        let status: String
        let code: Int
        let name: String
        let messages: [String]
        let error: String?
    }
    
    /// Start a new job using POST
    fileprivate func startEcmwfApiJob(query: any Encodable, email: String, apikey: String) async throws -> EcmwfApiResponse {
        var request = HTTPClientRequest(url: "https://api.ecmwf.int/v1/services/mars/requests")
        request.method = .POST
        request.headers.add(name: "From", value: email)
        request.headers.add(name: "X-ECMWF-KEY", value: apikey)
        request.headers.add(name: "content-type", value: "application/json")
        request.body = .bytes(ByteBuffer(data: try JSONEncoder().encode(query)))
        
        for i in 0..<10 {
            let response = try await client.execute(request, timeout: .seconds(10))
            if (400..<500).contains(response.status.code) {
                let error = try await response.readStringImmutable() ?? ""
                throw EcmwfApiError.jobStartFailed(error: error)
            }
            guard (200..<300).contains(response.status.code) else {
                let error = try await response.readStringImmutable() ?? ""
                logger.error("Job start failed, retry. \(error)")
                try await Task.sleep(nanoseconds: UInt64(1e+9) * UInt64(i)) // 1s
                continue
            }
            guard let job = try await response.readJSONDecodable(EcmwfApiResponse.self) else {
                let error = try await response.readStringImmutable() ?? ""
                fatalError("Could not decode \(error)")
            }
            logger.info("Submitted job \(job)")
            return job
        }
        logger.error("Could not start job. Exiting")
        fatalError()
    }
    
    /// Delete result after download
    fileprivate func cleanupEcmwfApiJob(job: EcmwfApiResponse, email: String, apikey: String) async throws {
        var request = HTTPClientRequest(url: "https://api.ecmwf.int/v1/services/mars/requests/\(job.name)")
        request.method = .DELETE
        request.headers.add(name: "From", value: email)
        request.headers.add(name: "X-ECMWF-KEY", value: apikey)
        let _ = try await client.execute(request, timeout: .seconds(10))
    }
    
    /// Wait for josb to finish and return download URL
    fileprivate func waitForEcmwfJob(job: EcmwfApiResponse, email: String, apikey: String) async throws -> String {
        while true {
            var offset = 0
            var request = HTTPClientRequest(url: "https://api.ecmwf.int/v1/services/mars/requests/\(job.name)?offset=\(offset)&limit=500")
            request.headers.add(name: "From", value: email)
            request.headers.add(name: "X-ECMWF-KEY", value: apikey)
            let response = try await client.execute(request, timeout: .seconds(10))
            if (300..<400).contains(response.status.code) {
                guard let location = response.headers.first(name: "Location") else {
                    fatalError("No location header set")
                }
                logger.info("Grib file at: \(location)")
                return location
            }
            guard (200..<500).contains(response.status.code) else {
                let error = try await response.readStringImmutable() ?? ""
                logger.error("Could not read \(error)")
                try await Task.sleep(nanoseconds: UInt64(1e+9)) // 1s
                continue
            }
            guard let status = try await response.readJSONDecodable(EcmwfApiResponse.self) else {
                let error = try await response.readStringImmutable() ?? ""
                fatalError("Could not decode \(error)")
            }
            
            logger.info("Status: \(status.status)")
            var isRestrictedAccessError = false
            for message in status.messages {
                if message.contains("restricted access to valid data") {
                    isRestrictedAccessError = true
                }
                logger.info("\(message)")
            }
            offset += status.messages.count
            
            if status.status == "aborted" {
                if isRestrictedAccessError {
                    throw EcmwfApiError.restrictedAccessToValidData
                }
                throw EcmwfApiError.jobAborted
            }
            
            try await Task.sleep(nanoseconds: UInt64(1e+9)) // 1s
        }
    }
}

extension HTTPClientResponse {
    public func readJSONDecodable<T: Decodable>(_ type: T.Type) async throws -> T? {
        var a = try await self.body.collect(upTo: 1024*1024)
        return try a.readJSONDecodable(type, length: a.readableBytes)
    }
    
    public func readStringImmutable() async throws -> String? {
        var b = try await self.body.collect(upTo: 1024*1024)
        return b.readString(length: b.readableBytes)
    }
}
