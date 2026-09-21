@testable import App
import Foundation
import Testing
import Vapor
import VaporTesting

@Suite struct McpTests {
    private static let headers: HTTPHeaders = ["Content-Type": "application/json", "Accept": "application/json"]

    private func withMcpApp(_ test: (TestingApplicationTester) async throws -> Void) async throws {
        try await withApp(configure: { app in
            try app.register(collection: McpController())
        }) { app in
            try await test(try app.testing())
        }
    }

    private func rpc(_ method: String, params: String = "{}") -> ByteBuffer {
        ByteBuffer(string: #"{"jsonrpc":"2.0","id":1,"method":"\#(method)","params":\#(params)}"#)
    }

    private func json(_ res: TestingHTTPResponse) throws -> [String: Any] {
        try #require(JSONSerialization.jsonObject(with: Data(buffer: res.body)) as? [String: Any])
    }

    private func toolText(_ body: [String: Any]) throws -> (text: String, isError: Bool) {
        let result = try #require(body["result"] as? [String: Any])
        let content = try #require(result["content"] as? [[String: Any]])
        let text = try #require(content.first?["text"] as? String)
        return (text, result["isError"] as? Bool ?? false)
    }

    @Test func getAndDeleteAreNotAllowed() async throws {
        try await withMcpApp { app in
            try await app.test(.GET, "mcp") { res in
                #expect(res.status == .methodNotAllowed)
                #expect(res.headers.first(name: "Allow") == "POST")
            }
            try await app.test(.DELETE, "mcp") { res in
                #expect(res.status == .methodNotAllowed)
            }
        }
    }

    @Test func wildcardOrMissingAcceptIsTreatedAsJson() async throws {
        try await withMcpApp { app in
            for headers in [HTTPHeaders([("Content-Type", "application/json")]), HTTPHeaders([("Content-Type", "application/json"), ("Accept", "*/*")])] {
                try await app.test(.POST, "mcp", headers: headers, body: rpc("tools/list")) { res in
                    #expect(res.status == .ok)
                    let body = try json(res)
                    #expect(body["result"] != nil)
                }
            }
        }
    }

    @Test func initializeAnswersWithServerInfo() async throws {
        try await withMcpApp { app in
            let params = #"{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"test","version":"1"}}"#
            try await app.test(.POST, "mcp", headers: Self.headers, body: rpc("initialize", params: params)) { res in
                #expect(res.status == .ok)
                let body = try json(res)
                let result = try #require(body["result"] as? [String: Any])
                let serverInfo = try #require(result["serverInfo"] as? [String: Any])
                #expect(serverInfo["name"] as? String == "open-meteo")
                #expect(result["protocolVersion"] as? String == "2025-06-18")
                let capabilities = try #require(result["capabilities"] as? [String: Any])
                #expect(capabilities["tools"] != nil)
            }
        }
    }

    @Test func listsToolsWithCompleteSchemas() async throws {
        try await withMcpApp { app in
            try await app.test(.POST, "mcp", headers: Self.headers, body: rpc("tools/list")) { res in
                #expect(res.status == .ok)
                let result = try #require(try json(res)["result"] as? [String: Any])
                let tools = try #require(result["tools"] as? [[String: Any]])
                #expect(tools.map { $0["name"] as? String } == ["elevation"])
                for tool in tools {
                    let schema = try #require(tool["inputSchema"] as? [String: Any])
                    let properties = try #require(schema["properties"] as? [String: Any])
                    #expect(!properties.isEmpty)
                    let annotations = try #require(tool["annotations"] as? [String: Any])
                    #expect(annotations["readOnlyHint"] as? Bool == true)
                }
            }
        }
    }

    @Test func elevationValidatesCoordinatesAsToolError() async throws {
        try await withMcpApp { app in
            let params = #"{"name":"elevation","arguments":{"latitude":91,"longitude":2.35}}"#
            try await app.test(.POST, "mcp", headers: Self.headers, body: rpc("tools/call", params: params)) { res in
                #expect(res.status == .ok)
                let (text, isError) = try toolText(try json(res))
                #expect(isError)
                #expect(text.contains("Latitude must be in range of -90 to 90"))
            }
        }
    }

    @Test func elevationRejectsUnknownArguments() async throws {
        try await withMcpApp { app in
            let params = #"{"name":"elevation","arguments":{"latitude":48.85,"longitude":2.35,"altitude":1}}"#
            try await app.test(.POST, "mcp", headers: Self.headers, body: rpc("tools/call", params: params)) { res in
                let (text, isError) = try toolText(try json(res))
                #expect(isError)
                #expect(text == "Unknown parameter: altitude")
            }
        }
    }

    @Test func unknownToolIsAProtocolError() async throws {
        try await withMcpApp { app in
            let params = #"{"name":"nope","arguments":{}}"#
            try await app.test(.POST, "mcp", headers: Self.headers, body: rpc("tools/call", params: params)) { res in
                let error = try #require(try json(res)["error"] as? [String: Any])
                #expect(error["code"] as? Int == -32602)
            }
        }
    }

    @Test func singleValuesAreWrappedForListParameters() throws {
        let params = try ApiQueryParameter(mcpArguments: [
            "latitude": 48.85,
            "longitude": "2.35,2.4",
            "hourly": "temperature_2m",
            "forecast_days": 3,
        ])
        #expect(params.latitude == [48.85])
        #expect(params.longitude == [2.35, 2.4])
        #expect(params.hourly == ["temperature_2m"])
        #expect(params.forecast_days == 3)
    }
}
