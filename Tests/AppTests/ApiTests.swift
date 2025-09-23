import Foundation
@testable import App
import Testing
import VaporTesting

@Suite struct ApiTests {
    /*@Test func generateS3SyncCommands() throws {
        for domain in DomainRegistry.allCases {
            let d = domain.rawValue
            //print("aws s3 sync --profile hetzner --exclude \"*~\" /var/lib/openmeteo-api/data/\(d) s3://openmeteo-\(domain.bucketName)/data/\(d)")
            print("find /var/lib/openmeteo-api/data/\(d) ! -name '*~' -mtime +4 -print0 | sed -z 's/^/--include=/' | xargs -0 aws s3 sync --profile hetzner /var/lib/openmeteo-api/data/\(d) s3://openmeteo-\(domain.bucketName)/data/\(d) --exclude '*'")
        }
        return
    }*/
    
    @Test func parseFlatBufferVariable() throws {
        let t2m = FlatBufferVariable(rawValue: "temperature_2m_minimum_previous_day4")
        #expect(t2m == FlatBufferVariable(variable: .altitude(variable: .temperature, altitude: 2), previousDay: 4, aggregation: .minimum))
    }

    @Test func timeSelection() throws {
        let current = Timestamp(2024, 02, 03, 12, 24)
        let a = try ApiQueryParameter.forecastTimeRange2(currentTime: current, utcOffset: 3600, pastSteps: nil, forecastSteps: 4, pastStepsMax: 10, forecastStepsMax: 10, forecastStepsDefault: 7, initialStep: nil, dtSeconds: 3600)
        #expect(a?.prettyString() == "2024-02-03T13:00 to 2024-02-03T16:00 (1-hourly)")

        let b = try ApiQueryParameter.forecastTimeRange2(currentTime: current, utcOffset: 3600, pastSteps: nil, forecastSteps: 4, pastStepsMax: 10, forecastStepsMax: 10, forecastStepsDefault: 7, initialStep: 0, dtSeconds: 3600)
        #expect(b?.prettyString() == "2024-02-03T00:00 to 2024-02-03T03:00 (1-hourly)")
    }

    @Test func parseApiParamsGET() async throws {
        try await withApp { app in
            let url = URI(string: "/forecast?latitude=52.52&longitude=13.41&timezone=auto")
            let request = Request(
                application: app,
                method: .GET,
                url: url,
                on: app.eventLoopGroup.next()
            )

            let params = try request.parseApiParams()

            #expect(params.latitude == [52.52])
            #expect(params.longitude == [13.41])
            #expect(params.start_date == [])
            #expect(params.end_date == [])
            #expect(params.bounding_box == [])
            #expect(params.start_hour == [])
            #expect(params.timezone == [.auto])
            #expect(params.end_hour == [])
            #expect(params.start_minutely_15 == [])
            #expect(params.end_minutely_15 == [])

            let url2 = URI(string: "/forecast?latitude=52.52,45.1&longitude=13.41,14.2&elevation=23%2C45")
            let request2 = Request(
                application: app,
                method: .GET,
                url: url2,
                on: app.eventLoopGroup.next()
            )

            let params2 = try request2.parseApiParams()
            #expect(params2.latitude == [52.52, 45.1])
            #expect(params2.longitude == [13.41, 14.2])
            #expect(params2.elevation == [23.0, 45.0])
        }
    }

    @Test func parseApiParamsPOST() async throws {
        try await withApp { app in
            let body = """
            {
                "latitude": ["52.52"],
                "longitude": ["13.41"],
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

            #expect(params.latitude == [52.52])
            #expect(params.longitude == [13.41])
            #expect(params.start_date == [])
            #expect(params.end_date == [])
            #expect(params.bounding_box == [])
            #expect(params.start_hour == [])
            #expect(params.end_hour == [])
            #expect(params.start_minutely_15 == [])
            #expect(params.end_minutely_15 == [])
        }
        try await withApp { app in
            let body = """
            {
                "latitude": [52.52],
                "longitude": [13.41],
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

            #expect(params.latitude == [52.52])
            #expect(params.longitude == [13.41])
            #expect(params.start_date == [])
            #expect(params.end_date == [])
            #expect(params.bounding_box == [])
            #expect(params.start_hour == [])
            #expect(params.end_hour == [])
            #expect(params.start_minutely_15 == [])
            #expect(params.end_minutely_15 == [])
        }
    }
}
