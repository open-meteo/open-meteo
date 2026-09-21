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

    /// Per-call ceilings. Weight is the API's own cost measure (variables × models × days relative
    /// to a 10-variable, 14-day request, summed over locations) and is known before any data is
    /// read; the character limit protects the calling model's context window.
    static let maximumWeight: Float = 20
    static let maximumCharacters = 60_000

    static let instructions = """
        Open-Meteo weather data for any location. Coordinates are WGS84 decimal degrees; several \
        locations can be passed as arrays. All tools are read-only. Request only the variables you \
        need: a result above \(maximumCharacters) characters, or a query that would read too much \
        data, is refused with a hint to narrow it. Set timezone to "auto" when asking for daily \
        values so days align with local midnight. To compare weather models, list several IDs in \
        `models` or make one call per model.
        """

    /// A tool backed by one of the endpoint controllers.
    struct WeatherTool {
        let definition: Tool
        let controller: WeatherApiController
        /// Passed explicitly: every tool shares the `/mcp` host, so the controller cannot read
        /// the endpoint semantics off the `Host` header as the REST routes do.
        let type: WeatherApiController.ApiType
        /// Data that a customer API key needs the professional tier for, as on its own host.
        let professional: Bool
    }

    static let weatherTools: [WeatherTool] = [forecast, historicalWeather, airQuality, marine, seasonal, flood, climate, ensemble]

    static let definitions: [Tool] = weatherTools.map(\.definition) + [elevation]

    private static let readOnly = Tool.Annotations(readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false)

    static let forecast = WeatherTool(
        definition: Tool(
            name: "weather_forecast",
            title: "Weather Forecast",
            description: "Weather forecast for a location, up to 16 days ahead, from the best-matching or a chosen numerical weather model. Hourly, daily, current and 15-minutely variables in one call; `past_days` adds recent history (up to 92 days). Set timezone to \"auto\" when requesting daily values.",
            inputSchema: weatherSchema(
                forecastDays: (max: 16, default: 7),
                hourly: "Hourly variables, e.g. temperature_2m, relative_humidity_2m, dew_point_2m, apparent_temperature, precipitation_probability, precipitation, rain, showers, snowfall, snow_depth, weather_code, pressure_msl, surface_pressure, cloud_cover, visibility, wind_speed_10m, wind_direction_10m, wind_gusts_10m, uv_index, is_day, sunshine_duration, shortwave_radiation, cape, soil_temperature_0cm, soil_moisture_0_to_1cm. Wind and temperature also at 80m, 120m and 180m; pressure-level variables as temperature_850hPa, wind_speed_500hPa, geopotential_height_500hPa (1000 down to 30 hPa). Full list: https://open-meteo.com/en/docs",
                daily: "Daily aggregates, e.g. weather_code, temperature_2m_max, temperature_2m_min, temperature_2m_mean, apparent_temperature_max, sunrise, sunset, daylight_duration, sunshine_duration, uv_index_max, precipitation_sum, rain_sum, snowfall_sum, precipitation_hours, precipitation_probability_max, wind_speed_10m_max, wind_gusts_10m_max, wind_direction_10m_dominant, shortwave_radiation_sum, et0_fao_evapotranspiration. Needs a timezone, use \"auto\".",
                current: "Current conditions: any hourly variable name, e.g. temperature_2m, weather_code, wind_speed_10m, is_day.",
                minutely15: "15-minutely variables: temperature_2m, precipitation, rain, snowfall, weather_code, wind_speed_10m, wind_direction_10m, wind_gusts_10m, shortwave_radiation, visibility, cape, lightning_potential, is_day. Native in Central Europe and North America, interpolated elsewhere.",
                models: "Weather models, default best_match (auto-selects the best model for the location). One or more IDs, e.g. ecmwf_ifs025, ecmwf_aifs025_single, gfs_seamless, ncep_hrrr_conus, icon_seamless, icon_d2, meteofrance_arome_france_hd, ukmo_uk_deterministic_2km, jma_msm, metno_nordic, gem_hrdps_continental, knmi_harmonie_arome_netherlands, dmi_harmonie_arome_europe, meteoswiss_icon_ch1, kma_ldps, bom_access_global, cma_grapes_global. With several models every variable is suffixed with the model name.",
                hourSteps: true,
                solar: true
            ),
            annotations: readOnly
        ),
        controller: .forecast,
        type: .forecast,
        professional: false
    )

    static let historicalWeather = WeatherTool(
        definition: Tool(
            name: "historical_weather",
            title: "Historical Weather",
            description: "Historical weather from reanalysis (ERA5 and others) for any date range from 1940 until a few days ago. For the last weeks, weather_forecast with past_days is fresher.",
            inputSchema: weatherSchema(
                forecastDays: nil,
                hourly: "Hourly variables as in weather_forecast, e.g. temperature_2m, relative_humidity_2m, precipitation, rain, snowfall, weather_code, pressure_msl, cloud_cover, wind_speed_10m, wind_direction_10m, wind_gusts_10m, shortwave_radiation, et0_fao_evapotranspiration; soil layers are soil_temperature_0_to_7cm and soil_moisture_0_to_7cm (7_to_28cm, 28_to_100cm, 100_to_255cm).",
                daily: "Daily aggregates as in weather_forecast, e.g. temperature_2m_max, temperature_2m_min, temperature_2m_mean, precipitation_sum, rain_sum, snowfall_sum, precipitation_hours, wind_speed_10m_max, wind_gusts_10m_max, sunrise, sunset, shortwave_radiation_sum. Needs a timezone, use \"auto\".",
                models: "Reanalysis dataset, default best_match: era5 (global, 25 km, hourly), era5_land (global, 10 km), era5_ensemble, cerra (Europe, 5 km, until 2021), ecmwf_ifs (9 km, since 2017), ecmwf_ifs_analysis_long_window.",
                datesRequired: true,
                solar: true
            ),
            annotations: readOnly
        ),
        controller: .archive,
        type: .archive,
        professional: true
    )

    static let airQuality = WeatherTool(
        definition: Tool(
            name: "air_quality",
            title: "Air Quality",
            description: "Air quality forecast from CAMS, up to 7 days ahead and 92 days back: particulate matter, gases, dust, aerosols, UV index, European and US air quality indices, and pollen in Europe.",
            inputSchema: weatherSchema(
                forecastDays: (max: 7, default: 5),
                hourly: "Hourly variables: pm10, pm2_5, carbon_monoxide, carbon_dioxide, nitrogen_dioxide, sulphur_dioxide, ozone, ammonia, methane, dust, aerosol_optical_depth, uv_index, uv_index_clear_sky, european_aqi, us_aqi (also per pollutant, e.g. european_aqi_pm2_5, us_aqi_ozone), and in Europe alder_pollen, birch_pollen, grass_pollen, mugwort_pollen, olive_pollen, ragweed_pollen.",
                current: "Current values of any hourly variable, e.g. european_aqi, pm2_5, uv_index.",
                models: "CAMS domain, default auto: cams_europe (11 km, Europe) or cams_global (40 km).",
                units: false,
                extra: ["domains": ["type": "string", "enum": ["auto", "cams_europe", "cams_global"], "description": "Alias for models."]]
            ),
            annotations: readOnly
        ),
        controller: .airQuality,
        type: .airQuality,
        professional: false
    )

    static let marine = WeatherTool(
        definition: Tool(
            name: "marine_weather",
            title: "Marine Weather",
            description: "Marine forecast up to 16 days: wind waves and swell, sea surface temperature, ocean currents and sea level height. Coordinates must be at sea; the nearest sea grid cell is used.",
            inputSchema: weatherSchema(
                forecastDays: (max: 16, default: 7),
                hourly: "Hourly variables: wave_height, wave_direction, wave_period, wave_peak_period, wind_wave_height, wind_wave_direction, wind_wave_period, wind_wave_peak_period, swell_wave_height, swell_wave_direction, swell_wave_period, swell_wave_peak_period, secondary_swell_wave_height, secondary_swell_wave_period, secondary_swell_wave_direction, sea_surface_temperature, ocean_current_velocity, ocean_current_direction, sea_level_height_msl, invert_barometer_height.",
                daily: "Daily aggregates: wave_height_max, wave_direction_dominant, wave_period_max, wind_wave_height_max, wind_wave_direction_dominant, wind_wave_period_max, wind_wave_peak_period_max, swell_wave_height_max, swell_wave_direction_dominant, swell_wave_period_max, swell_wave_peak_period_max.",
                current: "Current values of any hourly variable, e.g. wave_height, sea_surface_temperature.",
                minutely15: "15-minutely: ocean_current_velocity, ocean_current_direction, sea_level_height_msl.",
                models: "Wave and ocean models, default best_match: ecmwf_wam025, ecmwf_wam, meteofrance_wave, meteofrance_currents, dwd_gwam, dwd_ewam, ncep_gfswave025, era5_ocean (historical).",
                extra: ["length_unit": ["type": "string", "enum": ["metric", "imperial"], "description": "Metres (default) or feet for heights."]]
            ),
            annotations: readOnly
        ),
        controller: .marine,
        type: .marine,
        professional: false
    )

    static let seasonal = WeatherTool(
        definition: Tool(
            name: "seasonal_forecast",
            title: "Seasonal Forecast",
            description: "Seasonal outlook up to 7 months (217 days, default 183) from the ECMWF SEAS5 and 46-day extended-range ensembles. Weekly and monthly values are ensemble means and anomalies relative to climatology, the right level for month-ahead questions; hourly values are 6-hourly. Responses are large, request few variables.",
            inputSchema: weatherSchema(
                forecastDays: (max: 217, default: 183),
                hourly: "6-hourly variables: temperature_2m, temperature_2m_max, temperature_2m_min, dew_point_2m, relative_humidity_2m, apparent_temperature, pressure_msl, precipitation, rain, showers, snowfall, cloud_cover, wind_speed_10m, wind_direction_10m, wind_speed_100m, sea_surface_temperature, shortwave_radiation, soil_temperature_0_to_7cm, soil_moisture_0_to_7cm.",
                daily: "Daily: temperature_2m_max, temperature_2m_min, temperature_2m_mean, precipitation_sum, rain_sum, precipitation_hours, wind_speed_10m_max, wind_direction_10m_dominant, shortwave_radiation_sum, sunshine_duration, cloud_cover_mean, pressure_msl_mean, sea_surface_temperature_mean, snow_depth_mean.",
                weekly: "Weekly: temperature_2m_mean, temperature_2m_anomaly, precipitation_mean, precipitation_anomaly, wind_speed_10m_mean, wind_speed_10m_anomaly, sea_surface_temperature_mean, snowfall_mean, cloud_cover_mean, sunshine_duration_mean, probabilities such as temperature_2m_anomaly_gt0, temperature_2m_anomaly_gt2, precipitation_anomaly_gt0, and extreme forecast indices temperature_2m_efi, precipitation_efi, temperature_2m_sot90.",
                monthly: "Monthly: temperature_2m_mean, temperature_2m_anomaly, precipitation_mean, precipitation_anomaly, wind_speed_10m_mean, sea_surface_temperature_mean, sea_surface_temperature_anomaly, shortwave_radiation_mean, cloud_cover_mean, sunshine_duration_mean, snowfall_mean, snow_depth_mean, soil_moisture_0_to_7cm_mean, evapotranspiration_mean, sea_ice_cover_mean, each also as _anomaly.",
                models: "Default best_match. ecmwf_seasonal_seamless, ecmwf_seas5, ecmwf_ec46 return every ensemble member; ecmwf_seasonal_ensemble_mean_seamless, ecmwf_seas5_ensemble_mean, ecmwf_ec46_ensemble_mean return the mean only."
            ),
            annotations: readOnly
        ),
        controller: .seasonal,
        type: .seasonal,
        professional: true
    )

    static let flood = WeatherTool(
        definition: Tool(
            name: "flood_forecast",
            title: "Flood Forecast",
            description: "River discharge in m³/s from the Global Flood Awareness System (GloFAS), up to 366 days ahead (default 92) and back to 1984. Daily values only; the nearest river grid cell (5 km) is used, so small streams are not resolved.",
            inputSchema: weatherSchema(
                forecastDays: (max: 366, default: 92),
                daily: "Daily: river_discharge, and across the ensemble river_discharge_mean, river_discharge_median, river_discharge_max, river_discharge_min, river_discharge_p25, river_discharge_p75.",
                models: "Default seamless_v4: forecast_v4, consolidated_v4 (reanalysis), seamless_v3, forecast_v3, consolidated_v3.",
                units: false,
                extra: ["ensemble": ["type": "boolean", "description": "Return every ensemble member as a separate series."]]
            ),
            annotations: readOnly
        ),
        controller: .flood,
        type: .flood,
        professional: false
    )

    static let climate = WeatherTool(
        definition: Tool(
            name: "climate_projection",
            title: "Climate Projection",
            description: "Daily climate projections from 1950 to 2050 from seven CMIP6 HighResMIP models, bias-corrected to ERA5-Land by default. Requires start_date and end_date; for climatological questions request several models and compare.",
            inputSchema: weatherSchema(
                forecastDays: nil,
                daily: "Daily: temperature_2m_max, temperature_2m_min, temperature_2m_mean, cloud_cover_mean, relative_humidity_2m_max, relative_humidity_2m_min, relative_humidity_2m_mean, precipitation_sum, rain_sum, snowfall_sum, wind_speed_10m_mean, wind_speed_10m_max, wind_gusts_10m_mean, wind_gusts_10m_max, pressure_msl_mean, shortwave_radiation_sum, et0_fao_evapotranspiration_sum, vapour_pressure_deficit_max, dew_point_2m_mean, soil_moisture_0_to_10cm_mean.",
                models: "One or more of CMCC_CM2_VHR4, FGOALS_f3_H, HiRAM_SIT_HR, MRI_AGCM3_2_S (default), EC_Earth3P_HR, MPI_ESM1_2_XR, NICAM16_8S.",
                datesRequired: true,
                extra: ["disable_bias_correction": ["type": "boolean", "description": "Return raw model output instead of values bias-corrected to ERA5-Land."]]
            ),
            annotations: readOnly
        ),
        controller: .climate,
        type: .climate,
        professional: true
    )

    static let ensemble = WeatherTool(
        definition: Tool(
            name: "ensemble_forecast",
            title: "Ensemble Forecast",
            description: "Every member of an ensemble weather model as a separate series (temperature_2m, temperature_2m_member01, ...), up to 36 days, to quantify forecast uncertainty. Responses are large: request one or two variables and few days, or use a *_ensemble_mean model for one averaged series.",
            inputSchema: weatherSchema(
                forecastDays: (max: 36, default: 7),
                hourly: "Hourly variables as in weather_forecast, e.g. temperature_2m, relative_humidity_2m, precipitation, rain, snowfall, weather_code, pressure_msl, cloud_cover, wind_speed_10m, wind_direction_10m, wind_gusts_10m, shortwave_radiation, cape, plus pressure levels such as temperature_850hPa.",
                daily: "Daily aggregates, e.g. temperature_2m_max, temperature_2m_min, temperature_2m_mean, precipitation_sum, rain_sum, snowfall_sum, wind_speed_10m_max, wind_gusts_10m_max, cape_max. Needs a timezone, use \"auto\".",
                models: "Default ncep_gefs_seamless. One or more of ncep_gefs025, ncep_gefs05, ncep_aigefs025, ecmwf_ifs025_ensemble, ecmwf_aifs025_ensemble, ecmwf_ifs_europe_ensemble, icon_seamless_eps, icon_global_eps, icon_eu_eps, icon_d2_eps, gem_global_ensemble, bom_access_global_ensemble, ukmo_global_ensemble_20km, ukmo_uk_ensemble_2km, meteoswiss_icon_ch1_ensemble, google_weathernext2_ensemble. Each has an *_ensemble_mean variant returning one averaged series.",
                hourSteps: true,
                solar: true
            ),
            annotations: readOnly
        ),
        controller: .ensemble,
        type: .ensemble,
        professional: true
    )

    static let elevation = Tool(
        name: "elevation",
        title: "Elevation",
        description: "Terrain elevation in metres above sea level for one or more WGS84 coordinates, from the 90 m Copernicus digital elevation model. Pass equal-length arrays to look up to 100 points in one call.",
        inputSchema: [
            "type": "object",
            "properties": [
                "latitude": coordinate("Latitude in decimal degrees, -90 to 90.", min: -90, max: 90),
                "longitude": coordinate("Longitude in decimal degrees, -180 to 180, one per latitude.", min: -180, max: 180),
            ],
            "required": ["latitude", "longitude"],
            "additionalProperties": false,
        ],
        annotations: readOnly
    )

    /// One number or a list of up to 100, which is how the API takes coordinates.
    private static func coordinate(_ description: String, min: Int, max: Int) -> Value {
        let number: Value = ["type": "number", "minimum": .int(min), "maximum": .int(max)]
        return [
            "description": .string(description),
            "anyOf": [number, ["type": "array", "items": number, "minItems": 1, "maxItems": 100]],
        ]
    }

    private static func variableList(_ description: String) -> Value {
        ["type": "array", "items": ["type": "string"], "minItems": 1, "description": .string(description)]
    }

    /// JSON schema shared by the weather tools. Only what the endpoint understands is published:
    /// the REST API ignores parameters it does not know, but a tool call rejects them (see
    /// `rejectUnknownArguments`), so the published set has to match the endpoint.
    private static func weatherSchema(
        forecastDays: (max: Int, default: Int)?,
        hourly: String? = nil,
        daily: String? = nil,
        current: String? = nil,
        minutely15: String? = nil,
        weekly: String? = nil,
        monthly: String? = nil,
        models: String,
        datesRequired: Bool = false,
        hourSteps: Bool = false,
        units: Bool = true,
        solar: Bool = false,
        extra: [String: Value] = [:]
    ) -> Value {
        var properties: [String: Value] = [
            "latitude": coordinate("Latitude in decimal degrees, -90 to 90.", min: -90, max: 90),
            "longitude": coordinate("Longitude in decimal degrees, -180 to 180, one per latitude.", min: -180, max: 180),
            "elevation": ["type": "number", "description": "Elevation in metres for statistical downscaling; default from a 90 m digital elevation model."],
            "models": ["type": "array", "items": ["type": "string"], "description": .string(models)],
            "timezone": ["type": "string", "description": "IANA time zone name such as Europe/Berlin, or \"auto\" to use the location's zone. Default GMT."],
            "timeformat": ["type": "string", "enum": ["iso8601", "unixtime"], "description": "Default iso8601 (local time, no offset)."],
            "cell_selection": ["type": "string", "enum": ["land", "sea", "nearest"], "description": "Which grid cell to pick near coastlines. Default land (sea for marine data)."],
            "start_date": ["type": "string", "pattern": "^\\d{4}-\\d{2}-\\d{2}$", "description": "First day as YYYY-MM-DD. With end_date replaces forecast_days and past_days."],
            "end_date": ["type": "string", "pattern": "^\\d{4}-\\d{2}-\\d{2}$", "description": "Last day (inclusive) as YYYY-MM-DD."],
        ]
        if let hourly {
            properties["hourly"] = variableList(hourly)
            properties["temporal_resolution"] = ["type": "string", "enum": ["native", "hourly", "hourly_3", "hourly_6"], "description": "Thin the hourly series to every 3 or 6 hours to shrink the response."]
        }
        if let daily { properties["daily"] = variableList(daily) }
        if let current { properties["current"] = variableList(current) }
        if let minutely15 { properties["minutely_15"] = variableList(minutely15) }
        if let weekly { properties["weekly"] = variableList(weekly) }
        if let monthly { properties["monthly"] = variableList(monthly) }
        if let forecastDays {
            properties["forecast_days"] = ["type": "integer", "minimum": 0, "maximum": .int(forecastDays.max), "description": .string("Days ahead including today, default \(forecastDays.default).")]
            properties["past_days"] = ["type": "integer", "minimum": 0, "maximum": 92, "description": "Days before today to include as well."]
        }
        if hourSteps {
            properties["forecast_hours"] = ["type": "integer", "minimum": 0, "description": "Hours ahead from the current hour; an alternative to forecast_days."]
            properties["past_hours"] = ["type": "integer", "minimum": 0, "description": "Hours before the current hour; an alternative to past_days."]
        }
        if units {
            properties["temperature_unit"] = ["type": "string", "enum": ["celsius", "fahrenheit"]]
            properties["wind_speed_unit"] = ["type": "string", "enum": ["kmh", "ms", "mph", "kn"]]
            properties["precipitation_unit"] = ["type": "string", "enum": ["mm", "inch"]]
        }
        if solar {
            properties["tilt"] = ["type": "number", "minimum": 0, "maximum": 90, "description": "Solar panel tilt in degrees from horizontal, for global_tilted_irradiance."]
            properties["azimuth"] = ["type": "number", "minimum": -180, "maximum": 180, "description": "Solar panel azimuth in degrees, 0 south, -90 east, 90 west, for global_tilted_irradiance."]
        }
        for (key, value) in extra {
            properties[key] = value
        }
        var required: [Value] = ["latitude", "longitude"]
        if datesRequired {
            required += ["start_date", "end_date"]
        }
        return [
            "type": "object",
            "properties": .object(properties),
            "required": .array(required),
            "additionalProperties": false,
        ]
    }

    func call(_ params: CallTool.Parameters) async throws -> CallTool.Result {
        let arguments = params.arguments ?? [:]
        do {
            let response: Vapor.Response
            if params.name == Self.elevation.name {
                try Self.rejectUnknownArguments(arguments, schema: Self.elevation.inputSchema)
                let query = try ApiQueryParameter(mcpArguments: arguments)
                response = try await request.withApiAccess("api", parse: { query }) { _, params in
                    try DemController().run(params: params, logger: request.logger, httpClient: request.application.http.client.shared)
                }
            } else if let tool = Self.weatherTools.first(where: { $0.definition.name == params.name }) {
                try Self.rejectUnknownArguments(arguments, schema: tool.definition.inputSchema)
                let query = try ApiQueryParameter(mcpArguments: arguments)
                response = try await request.withApiAccess("api", requiresProfessional: tool.professional, parse: { query }) { info, params in
                    let result = try await tool.controller.run(params: params, info: info, type: tool.type, logger: request.logger, httpClient: request.application.http.client.shared)
                    try Self.check(weight: result.calculateQueryWeight())
                    return result
                }
            } else {
                throw MCPError.invalidParams("Unknown tool '\(params.name)'")
            }
            // The free API answers a request carrying an API key with a redirect to the customer
            // host. A tool call cannot follow it, so say where the key belongs instead.
            if (300..<400).contains(response.status.code) {
                let host = request.headers[.host].first ?? "api.open-meteo.com"
                return .init(content: [.text("API keys are accepted on the customer endpoint only. Send the key as X-Api-Key header to https://customer-\(host)/mcp")], isError: true)
            }
            let text = try await text(of: response)
            try Self.check(characters: text.count)
            return .init(content: [.text(text)], isError: false)
        } catch let error as MCPError {
            throw error
        } catch {
            // Data and validation errors are tool results, not protocol errors: the model reads
            // the same reason text the REST error middleware sends and can correct its call.
            return .init(content: [.text(Self.message(for: error, environment: request.application.environment))], isError: true)
        }
    }

    static func check(weight: Float) throws {
        guard weight <= maximumWeight else {
            throw ForecastApiError.generic(message: "This call would read too much data (weight \(Int(weight.rounded())), limit \(Int(maximumWeight))). Request fewer variables, models, days or locations.")
        }
    }

    static func check(characters: Int) throws {
        guard characters <= maximumCharacters else {
            throw ForecastApiError.generic(message: "The result is \(characters) characters, above the \(maximumCharacters)-character limit for a tool result. Request fewer variables, days, models or locations.")
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
