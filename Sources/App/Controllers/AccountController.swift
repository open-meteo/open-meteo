import Foundation
import Vapor
import Stripe



struct AccountController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        guard Environment.get("STRIPE_API_KEY") != nil else {
            return
        }
        routes.post("stripewebhook", use: stripewebhook)
        routes.get("test", use: test)
    }
    
    func test(req: Request) async throws -> Response {
        let subid = "sub_1MJwQbLNZMSyEuRUs5PHNkTL"// "sub_sched_1MKQVzLNZMSyEuRUqrBHemvw"
        let sub = try await req.stripe.subscriptions.retrieve(id: subid, expand: ["customer", "items.data.price.product"]).get()
        let email = sub.$customer?.email
        let end = sub.currentPeriodEnd
        let prod = sub.items?.data?.forEach({
            let monthly = $0.price?.$product?.metadata?["calls_monthly"]
            let quantity = $0.quantity
        })
        print(sub)
        return Response(status: .ok)
    }
    
    func stripewebhook(req: Request) async throws -> Response {
        guard let signature = req.headers["Stripe-Signature"].first else {
            throw Abort(.badRequest, reason: "Missing signature")
        }
        guard let payload = try await req.body.collect(max: 64*1024*1024).get() else {
            throw Abort(.badRequest, reason: "Payload empty")
        }
        guard let secret = Environment.get("STRIPE_SECRET") else {
            fatalError("No stripe secret defined")
        }
        try StripeClient.verifySignature(payload: Data(payload.readableBytesView), header: signature, secret: secret)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        print(payload.readStringImmutable())
        
        let event = try decoder.decode(StripeEvent.self, from: payload)
        req.logger.info("Event \(event.type?.rawValue ?? "unknown")")
        
        switch (event.type, event.data?.object) {
        case (.customerSubscriptionCreated, .subscription(let subscription)):
            print("customerSubscriptionCreated: \(subscription)")
            print("Email:", subscription.$customer)
            // get email
            // get product / amount / calls per day
            // has history access
            let enddate = subscription.currentPeriodEnd
            
            /// "active"
            let status = subscription.status
            
            // generate API keys
            
            
            req.stripe.subscriptions.retrieve(id: subscription.id, expand: ["customer.email"])
            
            return Response(status: .ok)
        case (.paymentIntentSucceeded, .paymentIntent(let paymentIntent)):
            print("Payment capture method: \(paymentIntent.captureMethod!.rawValue)")
            return Response(status: .ok)
            
        default: return Response(status: .ok)
        }
    }
}

extension StripeError: AbortError {
    public var status: NIOHTTP1.HTTPResponseStatus {
        .badRequest
    }
    public var reason: String {
        if let error {
            return "\(error.type?.rawValue ?? "") \(error.message ?? "") \(error.code?.rawValue ?? "")"
        }
        return "StripeError"
    }
}
