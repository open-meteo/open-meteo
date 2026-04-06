import AsyncHTTPClient
import Logging
import NIOCore

public struct StripeMeterEvents {
    let apiKey: String
    let client: HTTPClient
    let logger: Logger

    func getAuthenticationToken() async throws -> StripeMeterSession {
        var request = HTTPClientRequest(url: "https://api.stripe.com/v2/billing/meter_event_session")
        request.method = .POST
        request.headers.add(name: "Authorization", value: "Bearer \(apiKey)")
        request.headers.add(name: "Stripe-Version", value: "2026-03-25.dahlia")

        let response = try await client.executeRetry(request, logger: logger)
        guard let session = try await response.checkCode200AndReadJSONDecodable(StripeMeterEventSessionResponse.self) else {
            let error = try await response.readStringImmutable() ?? ""
            fatalError("Could not decode Stripe meter event session response: \(error)")
        }
        return StripeMeterSession(token: session.authentication_token, client: client, logger: logger)
    }
}

fileprivate struct StripeMeterEventSessionResponse: Decodable {
    let authentication_token: String
}

public struct StripeMeterSession {
    let token: String
    let client: HTTPClient
    let logger: Logger
    
    /// Submit events to stripe. Uses batches of 100 events
    /// Key is dictionary is used as customer id
    func submit(events: [String: (calls: Int32, weight: Float)]) async throws {
        /// Batch by 50 because we send 2 events at once
        for chunk in events.evenlyChunked(in: 50) {
            let eventsJson = chunk.map {
                "{\"event_name\":\"api_calls\",\"payload\":{\"stripe_customer_id\":\"\($0.key)\",\"value\":\"\(Int($0.value.weight))\"}},{\"event_name\":\"http_requests\",\"payload\":{\"stripe_customer_id\":\"\($0.key)\",\"value\":\"\(Int($0.value.calls))\"}}"
            }.joined(separator: ",")
            let json = "{\"events\":[\(eventsJson)]}"

            var request = HTTPClientRequest(url: "https://meter-events.stripe.com/v2/billing/meter_event_stream")
            request.method = .POST
            request.headers.add(name: "Authorization", value: "Bearer \(token)")
            request.headers.add(name: "Stripe-Version", value: "2026-03-25.dahlia")
            request.headers.add(name: "Content-Type", value: "application/json")
            request.body = .bytes(ByteBuffer(string: json))

            _ = try await client.executeRetry(request, logger: logger)
        }
    }
}
