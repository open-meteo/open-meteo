import Foundation
@testable import App
import Testing
import VaporTesting

@Suite struct ApiTests {
    private func makeRequest(application: Application, url: String) -> Request {
        Request(
            application: application,
            method: .GET,
            url: URI(string: url),
            on: application.eventLoopGroup.next()
        )
    }

    private func collectBody(_ response: Response, application: Application) async throws -> Data {
        let collected = try await response.body.collect(on: application.eventLoopGroup.next()).get()
        var buffer = try #require(collected)
        let body = buffer.readData(length: buffer.readableBytes)
        return try #require(body)
    }

    private func bodyString(_ response: Response, application: Application) async throws -> String {
        let body = try await collectBody(response, application: application)
        return try #require(String(data: body, encoding: .utf8))
    }

    private func nullArray(variable: String, count: Int) -> String {
        "\"\(variable)\":[\(Array(repeating: "null", count: count).joined(separator: ","))]"
    }

    private func occurrences(of substring: String, in string: String) -> Int {
        string.components(separatedBy: substring).count - 1
    }

    /*@Test func generateS3SyncCommands() throws {
        for domain in DomainRegistry.allCases {
            let d = domain.rawValue
            //print("aws s3 sync --profile hetzner --exclude \"*~\" /var/lib/openmeteo-api/data/\(d) s3://openmeteo-\(domain.bucketName)/data/\(d)")
            print("find /var/lib/openmeteo-api/data/\(d) ! -name '*~' -mtime +4 -print0 | sed -z 's/^/--include=/' | xargs -0 aws s3 sync --profile hetzner /var/lib/openmeteo-api/data/\(d) s3://openmeteo-\(domain.bucketName)/data/\(d) --exclude '*'")
        }
        return
    }*/
    
    /*@Test func parseFlatBufferVariable() throws {
        let t2m = FlatBufferVariable(rawValue: "temperature_2m_minimum_previous_day4")
        #expect(t2m == FlatBufferVariable(variable: .altitude(variable: .temperature, altitude: 2), previousDay: 4, aggregation: .minimum))
    }*/

    @Test func timeSelection() throws {
        let current = Timestamp(2024, 02, 03, 12, 24)
        let a = try ApiQueryParameter.forecastTimeRange2(currentTime: current, utcOffset: 3600, pastSteps: nil, forecastSteps: 4, pastStepsMax: 10, forecastStepsMax: 10, forecastStepsDefault: 7, initialStep: nil, dtSeconds: 3600)
        #expect(a?.prettyString() == "2024-02-03T13:00 to 2024-02-03T16:00 (1-hourly)")

        let b = try ApiQueryParameter.forecastTimeRange2(currentTime: current, utcOffset: 3600, pastSteps: nil, forecastSteps: 4, pastStepsMax: 10, forecastStepsMax: 10, forecastStepsDefault: 7, initialStep: 0, dtSeconds: 3600)
        #expect(b?.prettyString() == "2024-02-03T00:00 to 2024-02-03T03:00 (1-hourly)")
    }

    @Test func unavailableEnsemblePlaceholderPreservesColumnShapes() async throws {
        let params = try JSONDecoder().decode(
            ApiQueryParameter.self,
            from: Data(#"{"latitude":[48.8],"longitude":[2.3]}"#.utf8)
        )
        let hourly = TimerangeDt(start: Timestamp(2026, 8, 6), nTime: 4, dtSeconds: 3600)
        let daily = TimerangeDt(start: Timestamp(2026, 8, 6), nTime: 2, dtSeconds: 86400)
        let minutely15 = TimerangeDt(start: Timestamp(2026, 8, 6), nTime: 4, dtSeconds: 900)
        let time = ForecastApiTimeRange(dailyDisplay: daily, dailyRead: daily, hourlyDisplay: hourly, hourlyRead: hourly, minutely15: minutely15)
        let reader = MultiDomainsReader(
            domain: .ncep_aigefs025,
            readerHourly: nil,
            readerDaily: nil,
            readerWeekly: nil,
            readerMonthly: nil,
            params: params,
            run: nil,
            has15minutely: true,
            time: time,
            timezone: .gmt,
            currentTime: Timestamp(2026, 8, 6),
            temporalResolution: .hourly,
            unavailableModelLocation: .init(latitude: 48.8, longitude: 2.3, elevation: 35, modelDtSeconds: 3600)
        )

        let isDay: ForecastVariable = .surface(.init(.is_day, 0))
        let hourlySection = try #require(try await reader.hourly(variables: [isDay]))
        let minutelySection = try #require(try await reader.minutely15(variables: [isDay]))
        #expect(hourlySection.columns[0].variables.count == 1)
        #expect(minutelySection.columns[0].variables.count == 1)

        let dailySection = try #require(try await reader.daily(variables: [.temperature_2m_mean, .sunrise, .moon_phase, .daylight_duration]))
        #expect(dailySection.columns.map { $0.variables.count } == [
            MultiDomains.ncep_aigefs025.countEnsembleMember,
            1,
            1,
            1
        ])
        if case .timestamp(let values) = dailySection.columns[1].variables[0] {
            #expect(values.allSatisfy { !$0.isNoData })
        } else {
            Issue.record("Expected timestamp sunrise values")
        }
    }

    @Test(arguments: [
        MultiDomains.meteofrance_arome_france,
        MultiDomains.meteofrance_arome_seamless
    ])
    func allLocationsUnavailableThrowBadRequest(model: MultiDomains) async throws {
        try await withApp { app in
            let controller = WeatherApiController(defaultModel: model)
            let request = makeRequest(
                application: app,
                url: "/v1/forecast?latitude=-33.8,-34.0&longitude=151.2,150.9&elevation=0,0&models=\(model.rawValue)"
            )

            do {
                _ = try await controller.query(request)
                Issue.record("Expected \(model.rawValue) to be unavailable")
            } catch let error as ForecastApiError {
                #expect(error.status == .badRequest)
                #expect(error.reason == "No data is available for the requested locations")
            }
        }
    }

    @Test func mixedSingleAndMultipleDomainModelsProduceRectangularCsv() async throws {
        try await withApp { app in
            let controller = WeatherApiController(defaultModel: .icon_eu)
            let request = makeRequest(
                application: app,
                url: "/v1/forecast?latitude=-33.8,48.8&longitude=151.2,2.3&elevation=0,35&models=icon_eu,meteofrance_arome_seamless&hourly=temperature_2m&forecast_days=1&format=csv"
            )

            let response = try await controller.query(request)
            #expect(response.status == .ok)
            let body = try await collectBody(response, application: app)
            let csv = try #require(String(data: body, encoding: .utf8))
            let lines = csv.split(separator: "\n", omittingEmptySubsequences: false)
            let headerIndex = try #require(lines.firstIndex(where: { $0.hasPrefix("location_id,time,") }))
            let columnCount = lines[headerIndex].split(separator: ",", omittingEmptySubsequences: false).count

            #expect(lines[headerIndex].contains("temperature_2m_icon_eu"))
            #expect(lines[headerIndex].contains("temperature_2m_meteofrance_arome_seamless"))
            let rows = lines.dropFirst(headerIndex + 1).filter { !$0.isEmpty }
            #expect(rows.allSatisfy {
                $0.split(separator: ",", omittingEmptySubsequences: false).count == columnCount
            })
        }
    }

    @Test func mixedAvailabilityPreservesLegacyCompositeModelLocations() async throws {
        try await withApp { app in
            let controller = WeatherApiController(defaultModel: .satellite_radiation_seamless)
            let request = makeRequest(
                application: app,
                url: "/v1/forecast?latitude=-80,48.8&longitude=10,10&elevation=0,35&models=satellite_radiation_seamless&hourly=shortwave_radiation&temporal_resolution=native&forecast_days=1"
            )

            let response = try await controller.query(request)
            #expect(response.status == .ok)
            let json = try await bodyString(response, application: app)
            #expect(json.contains(#""latitude":-80"#))
            #expect(json.contains(#""location_id":1"#))
            #expect(json.contains(nullArray(variable: "shortwave_radiation", count: 144)))
        }
    }

    @Test func multiModelCurrentUsesFirstAvailableReader() async throws {
        try await withApp { app in
            let controller = WeatherApiController(defaultModel: .icon_eu)
            let request = makeRequest(
                application: app,
                url: "/v1/forecast?latitude=-33.8&longitude=151.2&elevation=0&models=icon_eu,icon_global&current=is_day"
            )

            let response = try await controller.query(request)
            #expect(response.status == .ok)
            let json = try await bodyString(response, application: app)
            #expect(json.contains(#""is_day":0"#) || json.contains(#""is_day":1"#))
            #expect(!json.contains(#""is_day_icon_global":"#))
        }
    }

    @Test func mixedAvailabilityPreservesLocations() async throws {
        try await withApp { app in
            let controller = WeatherApiController(defaultModel: .meteofrance_arome_france)
            let query = "/v1/forecast?latitude=-33.8,48.8&longitude=151.2,2.3&elevation=0,35&models=meteofrance_arome_france&hourly=temperature_2m&daily=sunrise,moon_phase,daylight_duration&forecast_days=1"
            let request = makeRequest(
                application: app,
                url: query
            )

            let response = try await controller.query(request)
            #expect(response.status == .ok)
            let json = try await bodyString(response, application: app)
            #expect(json.contains(#""latitude":-33.8"#))
            #expect(json.contains(#""longitude":151.2"#))
            #expect(json.contains(#""location_id":1"#))
            #expect(json.contains(nullArray(variable: "temperature_2m", count: 24)))
            for variable in ["sunrise", "moon_phase", "daylight_duration"] {
                #expect(occurrences(of: "\"\(variable)\":[", in: json) == 2)
                #expect(!json.contains(nullArray(variable: variable, count: 1)))
            }
        }
    }

    @Test func singleRunDailyRequiresLocalMidnight() throws {
        let timezone = TimezoneWithOffset(utcOffsetSeconds: -4 * 3600, identifier: "America/New_York", abbreviation: "GMT-4")
        let invalidDaily = try JSONDecoder().decode(ApiQueryParameter.self, from: Data("""
        {"run":"2026-06-01T00:00","daily":["temperature_2m_mean"]}
        """.utf8))

        #expect(throws: ForecastApiError.self) {
            try invalidDaily.validateSingleRunAggregationsAlignWithLocalPeriodStart(timezone: timezone)
        }

        let valid = try JSONDecoder().decode(ApiQueryParameter.self, from: Data("""
        {"run":"2026-06-01T04:00","forecast_days":3,"daily":["temperature_2m_mean"]}
        """.utf8))
        try valid.validateSingleRunAggregationsAlignWithLocalPeriodStart(timezone: timezone)

        let current = Timestamp(2026, 6, 24)
        let allowedRange = Timestamp(2023, 1, 1)..<Timestamp(2026, 7, 1)
        let time = try valid.getTimerange2(timezone: timezone, current: current, forecastDaysDefault: 7, forecastDaysMax: 16, startEndDate: nil, allowedRange: allowedRange, pastDaysMax: 3650)
        let dailyDates = Array(time.dailyDisplay.iterate(format: .iso8601, utc_offset_seconds: timezone.utcOffsetSeconds, quotedString: false, onlyDate: true))

        #expect(dailyDates == ["2026-06-01", "2026-06-02", "2026-06-03"])
        #expect(time.dailyRead.range.lowerBound == Timestamp(2026, 6, 1, 4))
        #expect(time.hourlyRead.range.lowerBound == Timestamp(2026, 6, 1, 4))
    }

    @Test func timeAlignmentMinutely15() throws {
        // Test that unaligned timestamps are properly rounded to 15-minute boundaries
        let start = Timestamp(2025, 12, 03, 0, 20)  // 00:20 should round down to 00:15
        let end = Timestamp(2025, 12, 03, 1, 42)    // 01:42 should round down to 01:30

        let range = (start...end)
        let timerangeDt = range.toRange(dt: 900)  // 900 seconds = 15 minutes

        // Start should be rounded to nearest 15-minute boundary (00:15)
        #expect(timerangeDt.range.lowerBound.hour == 0)
        #expect(timerangeDt.range.lowerBound.minute == 15)

        // Verify that all timestamps in the sequence are properly aligned
        let timestamps = Array(timerangeDt)
        for timestamp in timestamps {
            let minute = timestamp.minute
            #expect(minute % 15 == 0, "All timestamps should be aligned to 15-minute boundaries, got \(timestamp.iso8601_YYYY_MM_dd_HH_mm)")
        }
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
