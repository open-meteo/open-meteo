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
        routes.get("en", "docs", "gfs-api", use: gfsApiHandler)
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
        let context = ContextWithLevels(title: "Docs", levels: IconDomains.apiLevels, variables: [
            ContextWithLevels.PressureVariable(label: "Temperature", name: "temperature"),
            ContextWithLevels.PressureVariable(label: "Dewpoint", name: "dewpoint"),
            ContextWithLevels.PressureVariable(label: "Relative Humidity", name: "relativehumidity"),
            ContextWithLevels.PressureVariable(label: "Cloudcover", name: "cloudcover"),
            ContextWithLevels.PressureVariable(label: "Wind Speed", name: "windspeed"),
            ContextWithLevels.PressureVariable(label: "Wind Direction", name: "winddirection"),
            ContextWithLevels.PressureVariable(label: "Geopotential Height", name: "geopotential_height"),
        ])
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
    func gfsApiHandler(_ req: Request) -> EventLoopFuture<View> {
        if req.headers[.host].contains(where: { $0.contains("api") }) {
            return req.eventLoop.makeFailedFuture(Abort.init(.notFound))
        }
        let context = ContextWithLevels(title: "GFS & HRRR Forecast API", levels: GfsDomain.gfs025.levels, variables: [
            ContextWithLevels.PressureVariable(label: "Temperature", name: "temperature"),
            ContextWithLevels.PressureVariable(label: "Dewpoint", name: "dewpoint"),
            ContextWithLevels.PressureVariable(label: "Relative Humidity", name: "relativehumidity"),
            ContextWithLevels.PressureVariable(label: "Cloudcover", name: "cloudcover"),
            ContextWithLevels.PressureVariable(label: "Wind Speed", name: "windspeed"),
            ContextWithLevels.PressureVariable(label: "Wind Direction", name: "winddirection"),
            ContextWithLevels.PressureVariable(label: "Geopotential Height", name: "geopotential_height"),
        ])
        return req.view.render("docs-gfs-api", context)
    }
}

struct IndexContext: Encodable {
    let title: String
}

struct ContextWithLevels: Encodable {
    let title: String
    let pressureVariables: [PressureVariable]
    let levels: [PressureLevel]
    
    
    struct PressureVariable: Encodable {
        let label: String
        let name: String
    }
    struct PressureLevel: Encodable {
        let level: Int
        let altitude: String
    }
    
    public init(title: String, levels: [Int], variables: [PressureVariable]) {
        self.title = title
        self.pressureVariables = variables
        self.levels = levels.reversed().map {
            let altitude = Meteorology.altitudeAboveSeaLevelMeters(pressureLevelHpA: Float($0))
            var str: String
            switch altitude {
            case ...3000:
                // round to 0.1 km
                str = "\(((altitude/100).rounded()/10))"
            case ...10000:
                // round to 0.5 km
                str = "\(((altitude/500).rounded()*500/1000))"
            default:
                str = "\(Int((altitude/1000).rounded()))"
            }
            return PressureLevel(level: $0, altitude: str)
        }
    }
}
