import Foundation
@testable import App
import Testing
import VaporTesting

@Suite struct ApiTests {
    /*func testVariableDecode() {
        XCTAssertEqual(api_result_VariableType.startsWith(s: "cloudcover_low_123")?.0, .cloudcoverLow)
    }*/
    @Test func timeSelection() throws {
        let current = Timestamp(2024, 02, 03, 12, 24)
        let a = try ApiQueryParameter.forecastTimeRange2(currentTime: current, utcOffset: 3600, pastSteps: nil, forecastSteps: 4, pastStepsMax: 10, forecastStepsMax: 10, forecastStepsDefault: 7, initialStep: nil, dtSeconds: 3600)
        #expect(a?.prettyString() == "2024-02-03T13:00 to 2024-02-03T16:00 (1-hourly)")

        let b = try ApiQueryParameter.forecastTimeRange2(currentTime: current, utcOffset: 3600, pastSteps: nil, forecastSteps: 4, pastStepsMax: 10, forecastStepsMax: 10, forecastStepsDefault: 7, initialStep: 0, dtSeconds: 3600)
        #expect(b?.prettyString() == "2024-02-03T00:00 to 2024-02-03T03:00 (1-hourly)")
    }

    func testParseApiParamsGET() async throws {
        try await withApp { app in
            let url = URI(string: "/forecast?latitude=52.52&longitude=13.41&start_date=2024-06-01&end_date=2024-06-07&bounding_box=50,10,55,15")
            let request = Request(
                application: app,
                method: .GET,
                url: url,
                on: app.eventLoopGroup.next()
            )

            let params = try request.parseApiParams()

            #expect(params.latitude == ["52.52"])
            #expect(params.longitude == ["13.41"])
            #expect(params.start_date == ["2024-06-01"])
            #expect(params.end_date == ["2024-06-07"])
            #expect(params.bounding_box == ["50,10,55,15"])
            #expect(params.current == nil)
            #expect(params.hourly == nil)
            #expect(params.daily == nil)
            #expect(params.elevation == nil)
            #expect(params.timezone == nil)
            #expect(params.temperature_unit == nil)
            #expect(params.wind_speed_unit == nil)
            #expect(params.precipitation_unit == nil)
            #expect(params.length_unit == nil)
            #expect(params.timeformat == nil)
            #expect(params.temporal_resolution == nil)
            #expect(params.past_days == nil)
            #expect(params.forecast_days == nil)
            #expect(params.past_hours == nil)
            #expect(params.forecast_hours == nil)
            #expect(params.initial_hours == nil)
            #expect(params.format == nil)
            #expect(params.models == nil)
            #expect(params.cell_selection == nil)
            #expect(params.apikey == nil)
            #expect(params.tilt == nil)
            #expect(params.azimuth == nil)
            #expect(params.disable_bias_correction == nil)
            #expect(params.six_hourly == nil)
            #expect(params.domains == nil)
            #expect(params.current_weather == nil)
        }
    }

    @Test
    func testParseApiParamsPOST() async throws {
        try await withApp { app in
            let body = """
            {
                "latitude": ["52.52"],
                "longitude": ["13.41"],
                "start_date": ["2024-06-01"],
                "end_date": ["2024-06-07"],
                "bounding_box": ["50,10,55,15"]
            }
            """
            var headers = HTTPHeaders()
            headers.add(name: .contentType, value: "application/json")
            let request = Request(
                application: app,
                method: .POST,
                url: URI(path: "/forecast"),
                headers: headers,
                collectedBody: .init(buffer: ByteBuffer(string: body)),
                on: app.eventLoopGroup.next()
            )

            let params = try request.parseApiParams()

            #expect(params.latitude == ["52.52"])
            #expect(params.longitude == ["13.41"])
            #expect(params.start_date == ["2024-06-01"])
            #expect(params.end_date == ["2024-06-07"])
            #expect(params.bounding_box == ["50,10,55,15"])
        }
    }
}
