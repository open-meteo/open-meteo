import Vapor

struct WebsiteController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        routes.get("robots.txt", use: robotsTxtHandler)
        routes.get("test_backtrace", use: testBacktrace)
    }
    
    func robotsTxtHandler(_ req: Request) -> String {
        return "User-agent: *\nDisallow: /"
    }
    
    func testBacktrace(_ req: Request) -> String {
        let array = [0,1,2]
        return String(array[10])
    }
}
