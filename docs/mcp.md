# Model Context Protocol (MCP) endpoint

The API speaks the [Model Context Protocol](https://modelcontextprotocol.io) at `POST /mcp`, so
AI assistants and agent frameworks can call Open-Meteo as tools instead of composing URLs. The
endpoint uses the stateless form of MCP Streamable HTTP: every POST carries one JSON-RPC message
and gets its answer in the same response. There is no session, no server-initiated stream, and
nothing to clean up, so any API node answers any request.

Public instance: `https://api.open-meteo.com/mcp` (free tier, same limits as the REST API) and
`https://customer-api.open-meteo.com/mcp` with an API key in the `X-Api-Key` header.

## Client configuration

Hosts with native Streamable HTTP support (Claude Code, Claude Desktop, Cursor, VS Code, the
official SDKs) take the URL directly:

```json
{
  "mcpServers": {
    "open-meteo": {
      "type": "http",
      "url": "https://api.open-meteo.com/mcp"
    }
  }
}
```

Hosts that only launch stdio servers can bridge with `mcp-remote`:

```json
{
  "mcpServers": {
    "open-meteo": {
      "command": "npx",
      "args": ["-y", "mcp-remote", "https://api.open-meteo.com/mcp"]
    }
  }
}
```

For a commercial subscription add the key header, for example
`"headers": {"X-Api-Key": "..."}` in hosts that support it, or
`--header "X-Api-Key: ..."` with `mcp-remote`.

## Tools

Every tool takes the same parameter names as the corresponding REST endpoint, so the
[API documentation](https://open-meteo.com/en/docs) applies unchanged. Unknown parameters are
rejected by name, and every error is returned as a tool result carrying the same reason text the
REST API sends, so an assistant can correct its own call.

| Tool | REST endpoint | Notes |
| --- | --- | --- |
| `geocoding` | `geocoding-api.open-meteo.com/v1/search` | Place name to coordinates. Proxied; self-hosters set `GEOCODING_API_URL`. |
| `weather_forecast` | `/v1/forecast` | Up to 16 days, any model via `models`; the provider-specific paths have no separate tools. |
| `historical_weather` | `archive-api.../v1/archive` | Reanalysis since 1940, `start_date` and `end_date` required. |
| `air_quality` | `air-quality-api.../v1/air-quality` | CAMS pollutants, AQI, pollen. |
| `marine_weather` | `marine-api.../v1/marine` | Waves, swell, currents, sea level. |
| `seasonal_forecast` | `seasonal-api.../v1/seasonal` | Up to 217 days, weekly and monthly anomalies. |
| `flood_forecast` | `flood-api.../v1/flood` | GloFAS river discharge, daily. |
| `climate_projection` | `climate-api.../v1/climate` | CMIP6 1950 to 2050, dates required. |
| `ensemble_forecast` | `ensemble-api.../v1/ensemble` | Every ensemble member as a series. |
| `elevation` | `/v1/elevation` | 90 m digital elevation model, up to 100 points. |

Tools that need the professional tier on their own host (historical, seasonal, climate, ensemble)
need it through MCP as well when called with an API key.

## Limits

Two ceilings apply per tool call, both reported to the assistant with a hint to narrow the request:

- the API's query weight (variables × models × days relative to a 10-variable, 14-day request,
  summed over locations) must not exceed 20, checked before any data is read;
- the result must not exceed 60,000 characters of compact JSON.

A single location with a handful of variables over a week is weight 1; the ceiling blocks bulk
extraction, not conversation-sized questions. Free-tier rate limits (per IP: 600 per minute,
5,000 per hour, 10,000 per day, weighted) apply as for the REST API.

## Protocol details

- Protocol versions 2025-11-25 down to 2024-11-05 are negotiated on `initialize`; an
  `MCP-Protocol-Version` header naming an unsupported version is answered with 400.
- `Content-Type: application/json` is required (415 otherwise). `Accept: application/json` is
  expected; a missing or `*/*` Accept header is treated the same way.
- `GET /mcp` and `DELETE /mcp` answer 405 with `Allow: POST`; they belong to the stateful
  transport, which this endpoint does not offer.
- `Origin` is not restricted, matching the REST API's CORS policy; the `MCP-Protocol-Version`
  and `MCP-Session-Id` headers are allowed for browser clients.

## Self-hosting

The endpoint is part of the API binary and needs no configuration. On a host name that is not an
`open-meteo.com` subdomain the API applies no rate limits, as for the REST routes. Set
`GEOCODING_API_URL` to your own geocoding instance if you run one; otherwise the `geocoding` tool
uses the public service.

## Trying it with curl

```bash
curl -s https://api.open-meteo.com/mcp \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"weather_forecast","arguments":{"latitude":52.52,"longitude":13.41,"current":["temperature_2m","weather_code"]}}}'
```
