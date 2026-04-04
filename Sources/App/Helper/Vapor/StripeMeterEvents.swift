import AsyncHTTPClient
import Logging
import NIOCore

public struct StripeMeterEvents {
    let apikey: String
    let client: HTTPClient
    let logger: Logger

    func getAuthenticationToken() async throws -> StripeMeterSession {
        var request = HTTPClientRequest(url: "https://api.stripe.com/v2/billing/meter_event_session")
        request.method = .POST
        request.headers.add(name: "Authorization", value: "Bearer \(apikey)")
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

public protocol StripeEventMetered {
    var stripeCustomerId: String { get }
    var value: Int { get }
}

public struct StripeMeterSession {
    let token: String
    let client: HTTPClient
    let logger: Logger

    /// Submit events to stripe. Uses batches of 100 events
    func submitEvents<T: Collection>(eventName: String, events: T) async throws where T.Element: StripeEventMetered {
        for chunk in events.evenlyChunked(in: 100) {
            let eventsJson = events.map {
                "{\"event_name\":\"\(eventName)\",\"payload\":{\"stripe_customer_id\":\"\($0.stripeCustomerId)\",\"value\":\"\($0.value)\"}}"
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
