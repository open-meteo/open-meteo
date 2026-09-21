import Foundation
import MCP
import Vapor

/// Model Context Protocol endpoint (`POST /mcp`), the stateless form of MCP Streamable HTTP: every
/// POST carries one JSON-RPC message and receives its answer in the same response. There is no
/// session id and no server-initiated stream, so any API node can answer any request. Tool calls
/// run through the same access checks, rate limits and controllers as the REST routes.
struct McpController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        routes.on(.POST, "mcp", body: .collect(maxSize: "128kb"), use: post)
        routes.get("mcp", use: methodNotAllowed)
        routes.delete("mcp", use: methodNotAllowed)
    }

    /// GET opens the server-to-client stream and DELETE ends a session; both exist only with the
    /// stateful transport. The spec expects 405 with `Allow` from a server offering neither.
    @Sendable func methodNotAllowed(_ req: Vapor.Request) -> Vapor.Response {
        Vapor.Response(status: .methodNotAllowed, headers: ["Allow": "POST"])
    }

    @Sendable func post(_ req: Vapor.Request) async throws -> Vapor.Response {
        // One server per request: the stateless transport matches replies to waiting requests by
        // JSON-RPC id, which unrelated clients reuse freely, and the tool handler needs this
        // request for the access checks and rate limiting.
        let server = Server(
            name: "open-meteo",
            version: BuildInfo.gitTag ?? BuildInfo.gitSHA,
            instructions: McpTools.instructions,
            capabilities: .init(tools: .init())
        )
        let tools = McpTools(request: req)
        await server.withMethodHandler(ListTools.self) { _ in
            .init(tools: McpTools.definitions)
        }
        await server.withMethodHandler(CallTool.self) { params in
            try await tools.call(params)
        }
        // The REST API answers browsers from any origin (CORS allows all), so the transport's
        // default localhost-only origin check is left out; Accept, Content-Type and the protocol
        // version header are still validated.
        let transport = StatelessHTTPServerTransport(validationPipeline: StandardValidationPipeline(validators: [
            AcceptHeaderValidator(mode: .jsonOnly),
            ContentTypeValidator(),
            ProtocolVersionValidator(),
        ]))
        try await server.start(transport: transport)
        let response = await transport.handleRequest(MCP.HTTPRequest(req))
        await server.stop()
        return Vapor.Response(response)
    }
}

extension MCP.HTTPRequest {
    init(_ req: Vapor.Request) {
        var headers = [String: String]()
        for (name, value) in req.headers {
            headers[name] = value
        }
        // A bare curl sends `Accept: */*` and some clients send no Accept at all. Both imply the
        // `application/json` the SDK insists on, so it is filled in rather than answered with 406.
        let accept = req.headers[.accept].joined(separator: ",")
        if accept.isEmpty || accept.contains("*/*") {
            headers = headers.filter { $0.key.lowercased() != "accept" }
            headers["Accept"] = "application/json"
        }
        self.init(
            method: req.method.rawValue,
            headers: headers,
            body: req.body.data.map { Data(buffer: $0) },
            path: req.url.path
        )
    }
}

extension Vapor.Response {
    convenience init(_ response: MCP.HTTPResponse) {
        var headers = HTTPHeaders()
        for (name, value) in response.headers {
            headers.add(name: name, value: value)
        }
        // `.stream` cannot occur with the stateless transport; it would carry no body here.
        let body: Vapor.Response.Body = response.bodyData.map { .init(data: $0) } ?? .empty
        self.init(status: .init(statusCode: response.statusCode), headers: headers, body: body)
    }
}

/// The tools offered over MCP. Each maps onto an API controller and takes the REST query parameter
/// names as arguments, so the API documentation applies unchanged.
struct McpTools {
    let request: Vapor.Request

    static let instructions = """
        Open-Meteo weather and geo data. Coordinates are WGS84 decimal degrees. All tools are \
        read-only and free to call repeatedly.
        """

    static let definitions: [Tool] = [elevation]

    static let elevation = Tool(
        name: "elevation",
        title: "Elevation",
        description: "Terrain elevation in metres above sea level for one or more WGS84 coordinates, from the 90 m Copernicus digital elevation model. Pass equal-length arrays to look up to 100 points in one call.",
        inputSchema: [
            "type": "object",
            "properties": [
                "latitude": coordinateList(min: -90, max: 90, description: "Latitudes in decimal degrees, -90 to 90."),
                "longitude": coordinateList(min: -180, max: 180, description: "Longitudes in decimal degrees, -180 to 180, one per latitude."),
            ],
            "required": ["latitude", "longitude"],
            "additionalProperties": false,
        ],
        annotations: .init(readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false)
    )

    private static func coordinateList(min: Int, max: Int, description: String) -> Value {
        [
            "type": "array",
            "items": ["type": "number", "minimum": .int(min), "maximum": .int(max)],
            "minItems": 1,
            "maxItems": 100,
            "description": .string(description),
        ]
    }

    func call(_ params: CallTool.Parameters) async throws -> CallTool.Result {
        guard let tool = Self.definitions.first(where: { $0.name == params.name }) else {
            throw MCPError.invalidParams("Unknown tool '\(params.name)'")
        }
        let arguments = params.arguments ?? [:]
        do {
            try Self.rejectUnknownArguments(arguments, schema: tool.inputSchema)
            let query = try ApiQueryParameter(mcpArguments: arguments)
            let response: Vapor.Response
            switch tool.name {
            case Self.elevation.name:
                response = try await request.withApiAccess("api", parse: { query }) { _, params in
                    try DemController().run(params: params, logger: request.logger, httpClient: request.application.http.client.shared)
                }
            default:
                throw MCPError.invalidParams("Unknown tool '\(params.name)'")
            }
            // The free API answers a request carrying an API key with a redirect to the customer
            // host. A tool call cannot follow it, so say where the key belongs instead.
            if (300..<400).contains(response.status.code) {
                let host = request.headers[.host].first ?? "api.open-meteo.com"
                return .init(content: [.text("API keys are accepted on the customer endpoint only. Send the key as X-Api-Key header to https://customer-\(host)/mcp")], isError: true)
            }
            return .init(content: [.text(try await text(of: response))], isError: false)
        } catch let error as MCPError {
            throw error
        } catch {
            // Data and validation errors are tool results, not protocol errors: the model reads
            // the same reason text the REST error middleware sends and can correct its call.
            return .init(content: [.text(Self.message(for: error, environment: request.application.environment))], isError: true)
        }
    }

    private func text(of response: Vapor.Response) async throws -> String {
        guard let buffer = try await response.body.collect(on: request.eventLoop).get() else {
            return ""
        }
        return String(buffer: buffer)
    }

    /// The REST API ignores unknown query parameters. A model is better served by an error naming
    /// the parameter, so it corrects the call instead of silently receiving default data.
    private static func rejectUnknownArguments(_ arguments: [String: Value], schema: Value) throws {
        let properties = schema.objectValue?["properties"]?.objectValue ?? [:]
        let unknown = arguments.keys.filter { properties[$0] == nil }.sorted()
        guard unknown.isEmpty else {
            throw ForecastApiError.generic(message: "Unknown parameter: \(unknown.joined(separator: ", "))")
        }
    }

    static func message(for error: Error, environment: Environment) -> String {
        switch error {
        case let error as DecodingError:
            return error.readableDescription
        case let error as AbortError:
            return error.reason
        case let error as DebuggableError:
            return error.reason
        default:
            return environment.isRelease ? "Something went wrong." : String(describing: error)
        }
    }
}

extension ApiQueryParameter {
    /// Parameters the decoder reads as arrays. A tool call naturally passes a single value for
    /// most of them (`"latitude": 48.85`), which the JSON decoder would reject, so single values
    /// are wrapped. Comma-separated strings pass through: the loaders split them anyway.
    private static let listParameters: Set<String> = [
        "latitude", "longitude", "elevation", "location_id", "timezone", "bounding_box",
        "start_date", "end_date", "start_hour", "end_hour", "start_minutely_15", "end_minutely_15",
        "hourly", "daily", "current", "minutely_15", "weekly", "monthly", "six_hourly", "models",
    ]

    init(mcpArguments arguments: [String: Value]) throws {
        var normalised = arguments
        for (key, value) in arguments where Self.listParameters.contains(key) {
            if case .array = value {
                continue
            }
            normalised[key] = .array([value])
        }
        let data = try JSONEncoder().encode(Value.object(normalised))
        self = try JSONDecoder().decode(ApiQueryParameter.self, from: data)
    }
}
