import Foundation
import AsyncHTTPClient
import SwiftEccodes
import NIOCore

enum EcmwfApiError: Error {
    case jobAborted
    case jobStartFailed(error: String)
    case restrictedAccessToValidData
    case waiting(status: String)
    case errorResponse(code: UInt, message: String?)
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

    /**
     Get GRIB data from the ECMWF API and download to file
     Important: http client must be configured to disallow redirects!
     */
    func downloadEcmwfApi(query: any Encodable, email: String, apikey: String, destinationFile: String) async throws {
        let job = try await startEcmwfApiJob(query: query, email: email, apikey: apikey)
        let gribUrl = try await waitForEcmwfJob(job: job, email: email, apikey: apikey)
        try await download(url: gribUrl, toFile: destinationFile, bzip2Decode: false)
        try await cleanupEcmwfApiJob(job: job, email: email, apikey: apikey)
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

        let response = try await client.executeRetry(request, logger: logger, deadline: .hours(6))
        guard let job = try await response.checkCode200AndReadJSONDecodable(EcmwfApiResponse.self) else {
            let error = try await response.readStringImmutable() ?? ""
            fatalError("Could not decode \(error)")
        }
        logger.info("Submitted job \(job)")
        return job
    }

    /// Delete result after download
    fileprivate func cleanupEcmwfApiJob(job: EcmwfApiResponse, email: String, apikey: String) async throws {
        var request = HTTPClientRequest(url: "https://api.ecmwf.int/v1/services/mars/requests/\(job.name)")
        request.method = .DELETE
        request.headers.add(name: "From", value: email)
        request.headers.add(name: "X-ECMWF-KEY", value: apikey)
        _ = try await client.executeRetry(request, logger: logger)
    }

    /// Wait for josb to finish and return download URL
    fileprivate func waitForEcmwfJob(job: EcmwfApiResponse, email: String, apikey: String) async throws -> String {
        let timeout = TimeoutTracker(logger: self.logger, deadline: .hours(24))
        while true {
            var offset = 0
            var request = HTTPClientRequest(url: "https://api.ecmwf.int/v1/services/mars/requests/\(job.name)?offset=\(offset)&limit=500")
            request.headers.add(name: "From", value: email)
            request.headers.add(name: "X-ECMWF-KEY", value: apikey)
            let response = try await client.executeRetry(request, logger: logger, backoffMaximum: .seconds(1))

            if (300..<400).contains(response.status.code) {
                guard let location = response.headers.first(name: "Location") else {
                    fatalError("No location header set")
                }
                logger.info("Grib file at: \(location)")
                return location
            }
            guard let status = try await response.readJSONDecodable(EcmwfApiResponse.self) else {
                let error = try await response.readStringImmutable() ?? ""
                fatalError("Could not decode \(error)")
            }

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

            try await timeout.check(error: EcmwfApiError.waiting(status: status.status), delay: 1)
        }
    }
}

extension HTTPClientResponse {
    public func checkCode200AndReadJSONDecodable<T: Decodable>(_ type: T.Type, upTo: Int = 1024 * 1024) async throws -> T? {
        guard (200..<300).contains(status.code) else {
            let error = try await readStringImmutable()
            fatalError("ERROR: Response code \(status.code) \(error ?? "")")
        }
        return try await readJSONDecodable(type, upTo: upTo)
    }

    public func readJSONDecodable<T: Decodable>(_ type: T.Type, upTo: Int = 1024 * 1024) async throws -> T? {
        var a = try await self.body.collect(upTo: upTo)
        if a.readableBytes == upTo {
            fatalError("Response size too large")
        }
        return try a.readJSONDecodable(type, length: a.readableBytes)
    }

    public func readStringImmutable(upTo: Int = 1024 * 1024) async throws -> String? {
        var b = try await self.body.collect(upTo: upTo)
        if b.readableBytes == upTo {
            fatalError("Response size too large")
        }
        return b.readString(length: b.readableBytes)
    }
}
