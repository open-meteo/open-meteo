# API rate limiting

The free API limits **weighted API calls**, not just the number of HTTP requests. A request for more data can consume several API-call units. Check the response headers to see its cost and your remaining quota.

## Free API quotas

The default limits are:

| Window | API-call units |
| --- | ---: |
| Minute | 600 |
| Hour | 5,000 |
| Day | 10,000 |

All three limits apply together. Each request's weight counts toward all three quotas. A minute reset does not restore your hourly or daily quota.

Usage is generally shared by requests from the same public IP address, so applications using the same outgoing connection can share a quota. Cloudflare Worker traffic may be grouped by Worker identity instead. In the future, we may also identify individual applications hosted on providers such as Netlify, Render, Vercel, Railway, Fly.io, Heroku, and DigitalOcean App Platform. For many providers, however, we cannot distinguish applications sharing an outgoing IP address. Your application may therefore be rate-limited even when its own usage is low, because other applications have consumed the shared quota.

Use the response headers for the limits and reset times that apply to your requests. Resets can occur slightly after the start of a minute, hour, or UTC day; do not assume that quota becomes available exactly at a clock boundary. Customer API quotas depend on your subscription and are separate from these free API limits.

## Customer API limits

Use the customer endpoint for your API, such as `customer-api.open-meteo.com`, with your API key. Customer subscriptions have a monthly allowance of **weighted API-call units** and do not use the free API's minute, hour, or day quotas. The request-weight calculation below also applies to customer requests.

Provide your API key using either the `apikey` query parameter or the `x-api-key` HTTP header:

```http
x-api-key: YOUR_API_KEY
```

Header names are case-insensitive, so `X-Api-Key` also works. If both the header and query parameter are supplied, the header takes precedence.

Monthly allowance and concurrency are separate limits:

| Plan | Billing quantity | Monthly allowance | Requests processing at once |
| --- | ---: | ---: | ---: |
| API Standard (1 million calls) | — | 1 million units | 2 |
| API Professional (5 million calls) | — | 5 million units | 2 |
| API Professional (10 million calls) | 1 | 10 million units | 2 |
| API Professional (10 million calls) | 2 | 20 million units | 4 |
| API Professional (10 million calls) | 3 | 30 million units | 6 |
| API Professional (10 million calls) | 5 | 50 million units | 10 |
| API Professional (10 million calls) | 10 | 100 million units | 20 |

For **API Professional (10 million calls)**, each billing quantity adds 10 million weighted API-call units to the monthly allowance. For example, **quantity 3 provides 30 million units per month**. The plan name stays the same when the quantity changes. Each additional 10 million units adds two requests that can process at once, subject to the endpoint's total pending-request limit. A larger monthly allowance does not mean that all those requests can run simultaneously.

On standard customer endpoints, **more than 256 concurrent requests per API key results in HTTP `429 Too Many Requests`**. This total includes requests being processed and requests waiting in the queue.

The maximum number of locations in one request is **10,000**. Each location still contributes to the request's weight.

API Standard does not include the historical weather, historical forecast, previous runs, single runs, climate, ensemble, seasonal, or satellite radiation customer APIs. These require API Professional or higher.

Customer responses report the request's weight in `X-RateLimit-Cost`. The free API quota headers do not report your remaining monthly subscription allowance. If access is restricted for exceeding your allowance, the response is `403 Forbidden` with the reason `Your API key is over quota.`; this is different from a temporary concurrency rejection. Review your usage and subscription rather than repeatedly retrying that error.

## Cost of one HTTP request

For weather-data requests, calculate the weight for each location, then add the location weights:

```text
location weight = max(1, (V / 10) × max(1, D / 14))
HTTP request weight = sum of all location weights
```

- **V** is the effective number of requested variables, including models as described below.
- **D** is the number of days covered by that location's data range, including past and forecast days. Use the endpoint's default date range if you do not specify one.
- Each location costs at least **1 unit**. Weights above this minimum can be fractional; they are not rounded up to whole calls.

For ordinary, non-ensemble models, add the variables requested in `current`, `minutely_15`, `hourly`, `daily`, `weekly`, and `monthly`, then multiply by the number of selected models. A variable requested in both `current` and `hourly` counts twice. For example, ten variables from two models give **V = 20**.

For locations with the same date range, multiply the location weight by the number of locations. If date ranges differ, calculate each location separately. Putting multiple locations into one HTTP request does not make them count as one location.

### Examples

These examples use non-ensemble models and the same date range for every location.

| Locations | Variables per model | Models | Days | HTTP request weight |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 5 | 1 | 7 | 1 |
| 1 | 15 | 1 | 7 | 1.5 |
| 3 | 15 | 1 | 7 | 4.5 |
| 1 | 10 | 1 | 28 | 2 |
| 1 | 1 | 1 | 28 | 1 |
| 1 | 10 | 2 | 7 | 2 |
| 2 | 10 | 2 | 28 | 8 |

The minimum applies to the combined calculation. A range longer than 14 days does not necessarily cost more than one unit if you request few variables.

### Special cases

- **Ensemble data:** Variables count once per ensemble member of each selected model.
- **Seasonal data:** The actual weight is reduced for monthly data
- **Elevation API:** Each requested location costs one unit; the weather-data formula does not apply.
- **Errors:** A free API request that starts processing but fails is charged one unit. Requests rejected because a quota is already exhausted are not charged again.

The HTTP response header `X-RateLimit-Cost` reports the actual weight charged for the response.

## Response headers

| Header | Meaning |
| --- | --- |
| `X-RateLimit-Cost` | API-call units charged for this HTTP request, such as `1.0` or `2.5`. |
| `X-RateLimit-Limit` | Total quota for the window identified by `X-RateLimit-Window`. |
| `X-RateLimit-Remaining` | The smallest remaining quota across the minute, hour, and day windows, after this request's charge. Never less than zero. |
| `X-RateLimit-Window` | The reported window's length in seconds: `60`, `3600`, or `86400`. |
| `X-RateLimit-Reset` | When the reported window resets, as a Unix timestamp in seconds, not a countdown. |
| `Retry-After` | How many seconds to wait before retrying a request rejected for an exhausted quota. |

The quota headers describe the window with the fewest units remaining. If windows have equal remaining quota, the one that resets latest is reported. This also applies when several windows are exhausted: the response tells you to wait for the latest reset. The reported window can change between requests; the other limits still apply.

Remaining quota is measured in **weighted units**, not HTTP requests. It is a snapshot, not a reservation for your next request. Not every response includes every header: a quota rejection, for example, can include quota headers and `Retry-After` without `X-RateLimit-Cost`.

## When a limit is reached

A quota rejection returns HTTP `429 Too Many Requests`, for example:

```http
HTTP/1.1 429 Too Many Requests
Content-Type: application/json
X-RateLimit-Limit: 600.0
X-RateLimit-Remaining: 0.0
X-RateLimit-Window: 60
X-RateLimit-Reset: 1800000060
Retry-After: 42

{"error":true,"reason":"Minutely API request limit exceeded. Please try again in one minute."}
```

Wait at least the number of seconds in `Retry-After`, then add a small random delay before retrying. Prefer this value over the general wording in the error message.

Do not repeatedly retry invalid requests: correct their parameters first.

To reduce usage, request only the variables, models, locations, and date ranges you need, cache responses where appropriate, and spread requests over time. Split an individual request that is rejected for requesting too much data into smaller requests.

## Concurrent requests and queuing

Concurrency limits control how many HTTP requests can be processed at the same time. They are separate from the weighted minute, hour, and day quotas: you can have quota remaining and still receive a concurrency rejection.

By default, the free API processes **one request at a time per client** and queues additional requests. **More than 5 concurrent requests per client results in HTTP `429 Too Many Requests`**, counting both processing and queued requests.

Queued requests start in arrival order as earlier requests finish processing. Their HTTP connections remain open while they wait, so queuing increases response time. Waiting does not add to a request's weight; a request rejected because the queue is full is not charged.

The free API queue is generally shared by requests from the same public IP address, or by Worker identity for identified Cloudflare Worker traffic. Other applications sharing that identity can therefore fill the queue. Customer API concurrency is shared per API key, with processing limits determined by the subscription.

A concurrency rejection has the reason `Too many concurrent requests`. It does not include a quota reset time or `Retry-After`, because it depends on pending requests finishing rather than a scheduled quota reset. The `X-RateLimit-Limit` and `X-RateLimit-Remaining` headers describe weighted quotas, not queue capacity or position.

For predictable response times, send free API requests sequentially. If you receive a concurrency rejection, reduce parallel requests and retry with increasing delays and a small random delay. Avoid immediately sending duplicate requests while earlier ones are still waiting. A temporarily overloaded service can also return HTTP `503 Service Unavailable`; retry those requests with increasing delays too.
