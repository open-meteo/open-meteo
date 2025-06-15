# Open Meteo API Reference

This document provides detailed information about the endpoints, parameters, and usage examples for Open Meteo's Weather API.

## Base URL

https://api.open-meteo.com/v1/

Use this base URL to access all weather endpoints.

---

## Available Endpoints

### 1. Forecast

Returns weather forecasts for specific latitude and longitude.

**Endpoint:**  
https://api.open-meteo.com/v1/forecast


---

## Required Parameters

| Parameter       | Type     | Description                                        |
|----------------|----------|----------------------------------------------------|
| `latitude`      | Float    | Latitude of the location (e.g., 35.6895)           |
| `longitude`     | Float    | Longitude of the location (e.g., 139.6917)         |
| `hourly`        | String   | Comma-separated weather variables (e.g., `temperature_2m`) |

---

## Optional Parameters

| Parameter       | Type     | Description                                        |
|----------------|----------|----------------------------------------------------|
| `start_date`    | Date     | Start date in YYYY-MM-DD format                    |
| `end_date`      | Date     | End date in YYYY-MM-DD format                      |
| `timezone`      | String   | Timezone identifier (e.g., `Asia/Kolkata`)         |

---

## Example Request

```http
GET https://api.open-meteo.com/v1/forecast?latitude=35.6895&longitude=139.6917&hourly=temperature_2m
```

## Example Response
```
{
  "latitude": 35.6895,
  "longitude": 139.6917,
  "generationtime_ms": 0.315,
  "hourly_units": {
    "temperature_2m": "°C"
  },
  "hourly": {
    "time": ["2024-06-01T00:00", "2024-06-01T01:00", "..."],
    "temperature_2m": [21.5, 21.1, "..."]
  }
}

```
## Notes
- The API does not require authentication or API keys.
- Make sure the `hourly` parameter contains valid weather variables as defined in the [Meteo documentation](https://open-meteo.com/en/docs).

