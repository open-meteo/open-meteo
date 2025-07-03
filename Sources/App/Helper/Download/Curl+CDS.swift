import Foundation
import AsyncHTTPClient
@preconcurrency import SwiftEccodes
import NIOCore

/**
 CDS APIv2 flow:
 
 Submit request
 
 curl --request POST \
   --url https://cds-beta.climate.copernicus.eu/api/retrieve/v1/processes/reanalysis-era5-single-levels/execute \
   --header 'PRIVATE-TOKEN: 169d504d-3axxxxxxxxxxxxxxxx" \
   --data '{"inputs":
 {
     "product_type": ["reanalysis"],
     "variable": ["2m_temperature"],
     "year": ["2024"],
     "month": ["08"],
     "day": ["01"],
     "time": ["00:00"],
     "data_format": "grib",
     "download_format": "unarchived"
 }
 }'
 RETURNS:
 {
   "processID": "reanalysis-era5-single-levels",
   "type": "process",
   "jobID": "b4498619-24a9-41d4-9c7f-2a4fb00a4704",
   "status": "accepted",
   "created": "2024-08-29T09:51:47.098588",
   "updated": "2024-08-29T09:51:47.098588",
   "links": [
     {
       "href": "https://cds-beta.climate.copernicus.eu/api/retrieve/v1/processes/reanalysis-era5-single-levels/execute",
       "rel": "self"
     },
     {
       "href": "https://cds-beta.climate.copernicus.eu/api/retrieve/v1/jobs/b4498619-24a9-41d4-9c7f-2a4fb00a4704",
       "rel": "monitor",
       "type": "application/json",
       "title": "job status info"
     }
   ],
   "metadata": {
     "datasetMetadata": {
       "messages": []
     }
   }
 }
 
 Check status at: https://cds-beta.climate.copernicus.eu/api/retrieve/v1/jobs/b4498619-24a9-41d4-9c7f-2a4fb00a4704
 RETURNS
 {
   "processID": "reanalysis-era5-single-levels",
   "type": "process",
   "jobID": "b4498619-24a9-41d4-9c7f-2a4fb00a4704",
   "status": "accepted",
   "created": "2024-08-29T09:51:47.098588",
   "updated": "2024-08-29T09:51:47.098588",
   "links": [
     {
       "href": "https://cds-beta.climate.copernicus.eu/api/retrieve/v1/jobs/b4498619-24a9-41d4-9c7f-2a4fb00a4704",
       "rel": "self",
       "type": "application/json"
     }
   ]
 }
 
 Once finished:
 {
   "processID": "reanalysis-era5-single-levels",
   "type": "process",
   "jobID": "22e43b24-f036-41ba-a6d8-c7567926b69f",
   "status": "successful",
   "created": "2024-08-29T09:46:44.706285",
   "started": "2024-08-29T09:46:47.428596",
   "finished": "2024-08-29T09:46:52.303671",
   "updated": "2024-08-29T09:46:52.303671",
   "links": [
     {
       "href": "https://cds-beta.climate.copernicus.eu/api/retrieve/v1/jobs/22e43b24-f036-41ba-a6d8-c7567926b69f",
       "rel": "self",
       "type": "application/json"
     },
     {
       "href": "https://cds-beta.climate.copernicus.eu/api/retrieve/v1/jobs/22e43b24-f036-41ba-a6d8-c7567926b69f/results",
       "rel": "results"
     }
   ]
 }
 
 Result can be fetched here:
 https://cds-beta.climate.copernicus.eu/api/retrieve/v1/jobs/22e43b24-f036-41ba-a6d8-c7567926b69f/results
 RETURNS:
 {
   "asset": {
     "value": {
       "type": "application/x-grib",
       "href": "https://object-store.os-api.cci2.ecmwf.int:443/cci2-prod-cache/1ba8b427bbe3033b92f33aef06adc471.grib",
       "file:checksum": "f41af2fd14a83e191ef3097c5f3c1a0c",
       "file:size": 2076588,
       "file:local_path": "s3://cci2-prod-cache/1ba8b427bbe3033b92f33aef06adc471.grib"
     }
   }
 }
 */

enum CdsApiError: Error {
    case jobAborted
    case startError(code: Int, message: String)
    case error(message: String, reason: String)
    case waiting(status: CdsState)
    case restrictedAccessToValidData
    case invalidCombinationOfValues
}

enum CdsState: String, Decodable {
    case accepted
    case failed
    case successful
    case running
}

fileprivate struct CdsApiResponse: Decodable {
    /// E.g. `reanalysis-era5-single-levels`
    let processID: String
    let status: CdsState
    let jobID: String
}

fileprivate struct CdsApiErrorResponse: Decodable {
    /// E.g. `invalid request`
    let type: String

    /// E.g. `invalid request`
    let title: String

    /// E.g. `Request has not produced a valid combination of values, please check your selection.\n{'variable': ['formaldehyde'], 'type': ['validated_reanalysis'], 'level': ['0'], 'month': ['01'], 'year': ['2018'], 'model': ['ensemble']}`
    let detail: String
}

fileprivate struct CdsApiResults: Decodable {
    let asset: Asset

    struct Asset: Decodable {
        let value: Value
    }
    struct Value: Decodable {
        /// application/x-grib
        let type: String
        let href: String
        let checksum: String
        let size: Int
        let local_path: String

        enum CodingKeys: String, CodingKey {
            case type
            case href
            case checksum = "file:checksum"
            case size = "file:size"
            case local_path = "file:local_path"
        }
    }
}

fileprivate struct CdsApiResultsError: Decodable {
    let type: String
    let title: String
    let status: Int
    let traceback: String
}

extension Curl {
    /**
     Get GRIB data from the CDS API
     */
    func withCdsApi<Query: Encodable, T>(dataset: String, query: Query, apikey: String, server: String = "https://cds.climate.copernicus.eu/api", body: (AnyAsyncSequence<GribMessage>) async throws -> (T)) async throws -> T {
        let job = try await startCdsApiJob(dataset: dataset, query: query, apikey: apikey, server: server)
        let results = try await waitForCdsJob(job: job, apikey: apikey, server: server)
        let result = try await withGribStream(url: results.asset.value.href, bzip2Decode: false, body: body)
        try await cleanupCdsApiJob(job: job, apikey: apikey, server: server)
        return result
    }

    /**
     Get GRIB data from the CDS API and store to file
     */
    func downloadCdsApi<Query: Encodable>(dataset: String, query: Query, apikey: String, server: String = "https://cds.climate.copernicus.eu/api", destinationFile: String) async throws {
        let job = try await startCdsApiJob(dataset: dataset, query: query, apikey: apikey, server: server)
        let results = try await waitForCdsJob(job: job, apikey: apikey, server: server)
        try await download(url: results.asset.value.href, toFile: destinationFile, bzip2Decode: false, minSize: results.asset.value.size)
        try await cleanupCdsApiJob(job: job, apikey: apikey, server: server)
    }

    /// Start a new job using POST
    fileprivate func startCdsApiJob<Query: Encodable>(dataset: String, query: Query, apikey: String, server: String) async throws -> CdsApiResponse {
        // var request = HTTPClientRequest(url: "\(server)/resources/\(dataset)")
        var request = HTTPClientRequest(url: "\(server)/retrieve/v1/processes/\(dataset)/execute")

        request.method = .POST
        request.headers.add(name: "PRIVATE-TOKEN", value: apikey)
        request.headers.add(name: "content-type", value: "application/json")
        request.body = .bytes(ByteBuffer(data: try JSONEncoder().encode(["inputs": query])))

        let response = try await client.executeRetry(request, logger: logger, deadline: .hours(6))
        if response.status.code == 400, let errorJson = try await response.readJSONDecodable(CdsApiErrorResponse.self), errorJson.detail.contains("Request has not produced a valid combination of values") {
            throw CdsApiError.invalidCombinationOfValues
        }
        guard let job = try await response.checkCode200AndReadJSONDecodable(CdsApiResponse.self) else {
            let error = try await response.readStringImmutable() ?? ""
            fatalError("Could not decode \(error)")
        }
        logger.info("Submitted job \(job)")
        return job
    }

    /// Wait for josb to finish and return download URL
    fileprivate func waitForCdsJob(job: CdsApiResponse, apikey: String, server: String) async throws -> CdsApiResults {
        let timeout = TimeoutTracker(logger: self.logger, deadline: .hours(24))
        var job = job
        let backoff = ExponentialBackOff(maximum: .seconds(1))
        while true {
            switch job.status {
            case .accepted, .running:
                try await timeout.check(error: CdsApiError.waiting(status: job.status), delay: 1)

                var request = HTTPClientRequest(url: "\(server)/retrieve/v1/jobs/\(job.jobID)")
                request.headers.add(name: "PRIVATE-TOKEN", value: apikey)
                /// CDS may return error 404 from time to time......
                let response = try await client.executeRetry(request, logger: logger, backOffSettings: backoff)
                guard let jobNext = try await response.checkCode200AndReadJSONDecodable(CdsApiResponse.self) else {
                    let error = try await response.readStringImmutable() ?? ""
                    fatalError("Could not decode \(error)")
                }
                job = jobNext
            case .failed:
                var request = HTTPClientRequest(url: "\(server)/retrieve/v1/jobs/\(job.jobID)/results")
                request.headers.add(name: "PRIVATE-TOKEN", value: apikey)
                let response = try await client.executeRetry(request, logger: logger, backOffSettings: backoff)
                guard let results = try await response.readJSONDecodable(CdsApiResultsError.self) else {
                    let error = try await response.readStringImmutable() ?? ""
                    fatalError("Could not decode \(error)")
                }
                if results.traceback.contains("The job failed with: ValueError") {
                    throw CdsApiError.restrictedAccessToValidData
                }
                throw CdsApiError.error(message: results.title, reason: results.traceback)
            case .successful:
                var request = HTTPClientRequest(url: "\(server)/retrieve/v1/jobs/\(job.jobID)/results")
                request.headers.add(name: "PRIVATE-TOKEN", value: apikey)
                let response = try await client.executeRetry(request, logger: logger, backOffSettings: backoff)
                guard let results = try await response.checkCode200AndReadJSONDecodable(CdsApiResults.self) else {
                    let error = try await response.readStringImmutable() ?? ""
                    fatalError("Could not decode \(error)")
                }
                return results
            }
        }
    }

    fileprivate func cleanupCdsApiJob(job: CdsApiResponse, apikey: String, server: String) async throws {
        var request = HTTPClientRequest(url: "\(server)/retrieve/v1/jobs/\(job.jobID)")
        request.method = .DELETE
        request.headers.add(name: "PRIVATE-TOKEN", value: apikey)
        _ = try await client.executeRetry(request, logger: logger)
    }
}
