import Foundation
import AsyncHTTPClient
import SwiftEccodes
import NIOCore

enum CdsApiError: Error {
    case jobAborted
    case error(message: String, reason: String)
}

fileprivate enum CdsState: String, Decodable {
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
        //try await cleanupCdsApiJob(job: job, apikey: apikey)
        return result
    }
    
    /// Start a new job using POST
    fileprivate func startCdsApiJob(dataset: String, query: any Encodable, apikey: String, server: String) async throws -> CdsApiResponse {
        var request = HTTPClientRequest(url: "\(server)/\(dataset)")
        request.method = .POST
        request.headers.add(name: "Authorization", value: "Basic \(apikey.base64String())")
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
            guard let job = try await response.readJSONDecodable(CdsApiResponse.self) else {
                let error = try await response.readStringImmutable() ?? ""
                fatalError("Could not decode \(error)")
            }
            logger.info("Submitted job \(job)")
            return job
        }
        logger.error("Could not start job. Exiting")
        fatalError()
    }
    
    /// Wait for josb to finish and return download URL
    fileprivate func waitForCdsJob(job: CdsApiResponse, apikey: String, server: String) async throws -> String {
        var job = job
        while true {
            logger.info("Status: \(job) ")
            switch job.state {
            case .queued, .running:
                break
            case .failed:
                throw CdsApiError.error(message: job.error!.message, reason: job.error!.reason)
            case .completed:
                return job.location!
            }
            
            try await Task.sleep(nanoseconds: UInt64(1e+9)) // 1s
            
            var request = HTTPClientRequest(url: "\(server)/tasks/\(job.request_id)")
            request.headers.add(name: "Authorization", value: "Basic \(apikey.base64String())")
            let response = try await client.execute(request, timeout: .seconds(10))
            guard (200..<300).contains(response.status.code) else {
                let error = try await response.readStringImmutable() ?? ""
                logger.error("Could not read \(error)")
                try await Task.sleep(nanoseconds: UInt64(1e+9)) // 1s
                continue
            }
            guard let jobNext = try await response.readJSONDecodable(CdsApiResponse.self) else {
                let error = try await response.readStringImmutable() ?? ""
                fatalError("Could not decode \(error)")
            }
            job = jobNext
        }
    }
}
