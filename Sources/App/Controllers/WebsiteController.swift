import Vapor


struct WebsiteController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        routes.get() { req in
            req.redirect(to: "/en")
        }
        routes.get("en", use: indexHandler)
        routes.get("en", "docs", use: docsHandler)
        routes.get("en", "docs", "geocoding-api", use: docsGeocodingHandler)
        routes.get("en", "docs", "ecmwf-api", use: ecmwfApiHandler)
        routes.get("en", "docs", "historical-weather-api", use: historicalWeatherApiHandler)
        routes.get("en", "docs", "elevation-api", use: elevationApiHandler)
        routes.get("en", "docs", "marine-weather-api", use: marineApiHandler)
        routes.get("en", "docs", "air-quality-api", use: airQualityApiHandler)
        routes.get("en", "docs", "seasonal-forecast-api", use: seasonalForecastApiHandler)
        routes.get("en", "features", use: featuresHandler)
        routes.get("demo-api", use: apiDemoHandler)
    }
    
    func indexHandler(_ req: Request) -> EventLoopFuture<View> {
        if req.headers[.host].contains(where: { $0.contains("api") || $0.contains("h2978162") }) {
            return req.eventLoop.makeFailedFuture(Abort.init(.notFound))
        }
        let context = IndexContext(title: "Home page")
        return req.view.render("index", context)
    }
    
    func featuresHandler(_ req: Request) -> EventLoopFuture<View> {
        if req.headers[.host].contains(where: { $0.contains("api") || $0.contains("h2978162") }) {
            return req.eventLoop.makeFailedFuture(Abort.init(.notFound))
        }
        let context = IndexContext(title: "Features")
        return req.view.render("features", context)
    }
    
    func docsHandler(_ req: Request) -> EventLoopFuture<View> {
        if req.headers[.host].contains(where: { $0.contains("api") || $0.contains("h2978162") }) {
            return req.eventLoop.makeFailedFuture(Abort.init(.notFound))
        }
        let context = IndexContext(title: "Docs")
        return req.view.render("docs", context)
    }
    func docsGeocodingHandler(_ req: Request) -> EventLoopFuture<View> {
        if req.headers[.host].contains(where: { $0.contains("api") || $0.contains("h2978162") }) {
            return req.eventLoop.makeFailedFuture(Abort.init(.notFound))
        }
        let context = IndexContext(title: "Geocoding API")
        return req.view.render("docs-geocoding-api", context)
    }
    func ecmwfApiHandler(_ req: Request) -> EventLoopFuture<View> {
        if req.headers[.host].contains(where: { $0.contains("api") || $0.contains("h2978162") }) {
            return req.eventLoop.makeFailedFuture(Abort.init(.notFound))
        }
        let context = IndexContext(title: "ECMWF Weather Forecast API")
        return req.view.render("docs-ecmwf-api", context)
    }
    func marineApiHandler(_ req: Request) -> EventLoopFuture<View> {
        if req.headers[.host].contains(where: { $0.contains("api") || $0.contains("h2978162") }) {
            return req.eventLoop.makeFailedFuture(Abort.init(.notFound))
        }
        let context = IndexContext(title: "Marine Weather API")
        return req.view.render("docs-marine-api", context)
    }
    func airQualityApiHandler(_ req: Request) -> EventLoopFuture<View> {
        if req.headers[.host].contains(where: { $0.contains("api") || $0.contains("h2978162") }) {
            return req.eventLoop.makeFailedFuture(Abort.init(.notFound))
        }
        let context = IndexContext(title: "Air Quality API")
        return req.view.render("docs-air-quality-api", context)
    }
    func historicalWeatherApiHandler(_ req: Request) -> EventLoopFuture<View> {
        if req.headers[.host].contains(where: { $0.contains("api") || $0.contains("h2978162") }) {
            return req.eventLoop.makeFailedFuture(Abort.init(.notFound))
        }
        let context = IndexContext(title: "Historical Weather API")
        return req.view.render("docs-era5-api", context)
    }
    func apiDemoHandler(_ req: Request) -> EventLoopFuture<View> {
        if req.headers[.host].contains(where: { $0.contains("api") }) {
            return req.eventLoop.makeFailedFuture(Abort.init(.notFound))
        }
        let context = IndexContext(title: "Historical Weather API")
        return req.view.render("demo-api", context)
    }
    
    func elevationApiHandler(_ req: Request) -> EventLoopFuture<View> {
        if req.headers[.host].contains(where: { $0.contains("api") }) {
            return req.eventLoop.makeFailedFuture(Abort.init(.notFound))
        }
        let context = IndexContext(title: "Elevation API")
        return req.view.render("docs-elevation-api", context)
    }
    func seasonalForecastApiHandler(_ req: Request) -> EventLoopFuture<View> {
        if req.headers[.host].contains(where: { $0.contains("api") }) {
            return req.eventLoop.makeFailedFuture(Abort.init(.notFound))
        }
        let context = IndexContext(title: "Seasonal Forecast API")
        return req.view.render("docs-seasonal-forecast-api", context)
    }
}

struct IndexContext: Encodable {
    let title: String
}
