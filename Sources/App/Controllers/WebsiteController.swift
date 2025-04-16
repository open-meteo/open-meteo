import Vapor

struct WebsiteController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        routes.get("robots.txt", use: robotsTxtHandler)
    }

    func robotsTxtHandler(_ req: Request) -> String {
        return "User-agent: *\nDisallow: /"
    }
}
