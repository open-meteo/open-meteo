# Remote Data Access

Open-Meteo can read weather data directly from a remote backend instead of downloading complete datasets in advance. Set `REMOTE_DATA_DIRECTORY` to enable this cloud-native mode.

For Docker and Ubuntu installation instructions, see [Getting Started](./getting-started.md).

## Configuration

For the public Open-Meteo data distribution, use:

```ini
REMOTE_DATA_DIRECTORY=https://openmeteo.s3.amazonaws.com/data/
CACHE_SIZE=8GB
```

Pass these settings as container environment variables or add them to `/etc/default/openmeteo-api.env` for the Ubuntu package. Restart the service after changing settings.

The backend must support S3 directory listings and HTTP range requests. Remote directory URLs must end in `/data/`. You can also use your own [synchronized Open-Meteo servers](./sync-command.md).

## Local Cache

Remote reads fetch the required portions of compressed OM files and store them in a local block cache. Repeated requests reuse cached blocks. Concurrent readers share outstanding fetches, and adjacent queued blocks can be merged into larger reads within an 8 MiB range.

The cache uses a memory-mapped file with least-recently-used eviction. Keep its storage on a persistent volume to retain cached data across restarts. A larger cache helps workloads that access many models, variables, or historical periods.

| Environment variable | Description | Default |
|---|---|---|
| `REMOTE_DATA_DIRECTORY` | Remote data URL ending in `/data/`. See [Multiple Endpoints](#multiple-endpoints) for configuring more than one backend. | Unset; remote access disabled |
| `DATA_DIRECTORY` | Local weather-data directory. Must end with `/`. | `./data/` |
| `CACHE_FILE` | Path to the remote block-cache file. | `cache.bin` inside `DATA_DIRECTORY` |
| `CACHE_SIZE` | Size of the cache file, including block metadata. | `10GB` |
| `BLOCK_SIZE` | Size of each cached data block. | `64KB` |

## Fetch Concurrency and Queueing

The fetch limit applies across the shared cache coordinator. Once all concurrent fetch slots are occupied, additional jobs queue. Queue limits count backend jobs, which may contain multiple blocks and serve multiple readers.

Queued jobs are ordered by scheduling deadline. Demand reads normally take precedence over newly queued prefetches; older background work can move ahead as its deadline passes. These deadlines control ordering, not request timeouts. A full queue rejects new jobs, while readers can still share or merge into existing work.

| Environment variable | Description | Default |
|---|---|---|
| `REMOTE_DATA_MAX_CONCURRENT_FETCHES` | Number of concurrent backend fetches. | `12` |
| `REMOTE_DATA_MAX_PENDING_FETCHES` | Maximum number of queued fetches. | `65536` |
| `REMOTE_DATA_HTTP_CONNECTIONS` | HTTP/1.1 connection-pool soft limit per remote backend host. | `16` |

The shared HTTP/1.1 pool also handles listings, metadata requests and health checks, so allow headroom above `REMOTE_DATA_MAX_CONCURRENT_FETCHES`.

## Prefetching and File Updates

Multi-location API requests can prefetch upcoming locations while producing the current location's response. This lets backend reads overlap with response generation.

When inventory refreshes detect a changed file, Open-Meteo loads its new metadata and preloads recently accessed regions from the previous revision. Cached data from the old revision remains available to existing readers. Its blocks are marked for deletion when the old reader's final reference is released.

Inventory preloading is optional. It is skipped when the pending queue is more than 10% full, or when estimated queue occupancy after adding the preload would exceed 30%. The estimate assumes uncached ranges; these thresholds do not replace the overall queue limit.

| Environment variable | Description | Default |
|---|---|---|
| `REMOTE_DATA_PRELOAD_MAX_AGE_SECONDS` | When a remote file changes, preload data blocks accessed within the last N seconds. | `900` (15 minutes) |
| `PREFETCH_LOOK_AHEAD` | Number of locations prefetched ahead for multi-location API requests. Set to `0` to disable location prefetching. | `3` |

The concurrent-fetch, pending-fetch, and HTTP-connection limits must be positive integers. The preload age and location look-ahead may be zero.

## Multiple Endpoints

Multiple endpoints can be separated by commas in `REMOTE_DATA_DIRECTORY`:

```ini
REMOTE_DATA_DIRECTORY=https://backend-1.example.com/data/,https://backend-2.example.com/data/
```

Requests are distributed by object name, so all endpoints should serve the same dataset. Each URL must end in `/data/`. For setting up your own backends, see [Running Open-Meteo on Multiple Nodes](./sync-command.md).
