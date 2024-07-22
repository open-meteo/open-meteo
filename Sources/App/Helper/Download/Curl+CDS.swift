import Foundation
import AsyncHTTPClient
import SwiftEccodes
import NIOCore

enum CdsApiError: Error {
    case jobAborted
    case startError(code: Int, message: String)
    case error(message: String, reason: String)
    case waiting(status: CdsState)
    case restrictedAccessToValidData
}

enum CdsState: String, Decodable {
    case queued
    case failed
    case completed
    case running
}

fileprivate struct CdsApiResponse: Decodable {
    let state: CdsState
    let request_id: String
    let error: Error?
    
    /// if completed
    let location: String?
    let content_length: Int?
    let content_type: String?
    
    struct Error: Decodable {
        let message: String
        let url: String
        let reason: String
    }
}


extension Curl {
    /**
     Get GRIB data from the CDS API
     */
    func withCdsApi<T>(dataset: String, query: any Encodable, apikey: String, server: String = "https://cds.climate.copernicus.eu/api/v2", body: (AnyAsyncSequence<GribMessage>) async throws -> (T)) async throws -> T {
        
        let job = try await startCdsApiJob(dataset: dataset, query: query, apikey: apikey, server: server)
        let gribUrl = try await waitForCdsJob(job: job, apikey: apikey, server: server)
        let result = try await withGribStream(url: gribUrl, bzip2Decode: false, body: body)
        try await cleanupCdsApiJob(job: job, apikey: apikey, server: server)
        return result
    }
    
    /**
     Get GRIB data from the CDS API and store to file
     */
    func downloadCdsApi(dataset: String, query: any Encodable, apikey: String, server: String = "https://cds.climate.copernicus.eu/api/v2", destinationFile: String) async throws {
        
        let job = try await startCdsApiJob(dataset: dataset, query: query, apikey: apikey, server: server)
        let gribUrl = try await waitForCdsJob(job: job, apikey: apikey, server: server)
        try await download(url: gribUrl, toFile: destinationFile, bzip2Decode: false)
        try await cleanupCdsApiJob(job: job, apikey: apikey, server: server)
    }
    
    /// Start a new job using POST
    fileprivate func startCdsApiJob(dataset: String, query: any Encodable, apikey: String, server: String) async throws -> CdsApiResponse {
        var request = HTTPClientRequest(url: "\(server)/resources/\(dataset)")
        request.method = .POST
        request.headers.add(name: "Authorization", value: "Basic \(apikey.base64String())")
        request.headers.add(name: "content-type", value: "application/json")
        request.body = .bytes(ByteBuffer(data: try JSONEncoder().encode(query)))
        
        let response = try await client.executeRetry(request, logger: logger, deadline: .hours(6))
        guard let job = try await response.readJSONDecodable(CdsApiResponse.self) else {
            let error = try await response.readStringImmutable() ?? ""
            fatalError("Could not decode \(error)")
        }
        logger.info("Submitted job \(job)")
        return job
    }
    
    /// Wait for josb to finish and return download URL
    fileprivate func waitForCdsJob(job: CdsApiResponse, apikey: String, server: String) async throws -> String {
        let timeout = TimeoutTracker(logger: self.logger, deadline: .hours(24))
        var job = job
        while true {
            switch job.state {
            case .queued, .running:
                break
            case .failed:
                if job.error!.reason.contains("None of the data you have requested is available yet") {
                    throw CdsApiError.restrictedAccessToValidData
                }
                throw CdsApiError.error(message: job.error!.message, reason: job.error!.reason)
            case .completed:
                return job.location!
            }
            try await timeout.check(error: CdsApiError.waiting(status: job.state), delay: 1)
            
            var request = HTTPClientRequest(url: "\(server)/tasks/\(job.request_id)")
            request.headers.add(name: "Authorization", value: "Basic \(apikey.base64String())")
            let response = try await client.executeRetry(request, logger: logger, backoffMaximum: .seconds(1))
            guard let jobNext = try await response.readJSONDecodable(CdsApiResponse.self) else {
                let error = try await response.readStringImmutable() ?? ""
                fatalError("Could not decode \(error)")
            }
            job = jobNext
        }
    }
    
    fileprivate func cleanupCdsApiJob(job: CdsApiResponse, apikey: String, server: String) async throws {
        var request = HTTPClientRequest(url: "\(server)/tasks/\(job.request_id)")
        request.method = .DELETE
        request.headers.add(name: "Authorization", value: "Basic \(apikey.base64String())")
        let _ = try await client.executeRetry(request, logger: logger)
    }
}
