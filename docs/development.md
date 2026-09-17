## Build From Source
To compile and build the Open-Meteo Docker image yourself, you can download the source code and run `docker build`.

Build Docker image from source:

```bash
# Get Source code
git clone https://github.com/open-meteo/open-meteo.git
cd open-meteo

# Build Docker image
docker build -t open-meteo .

# Create a Docker volume to store weather data
docker volume create --name open-meteo-data

# Start the API service on http://127.0.0.1:8080
docker run -d --rm -v open-meteo-data:/app/data -p 8080:8080 open-meteo

# Download the digital elevation model
docker run -it --rm -v open-meteo-data:/app/data open-meteo sync copernicus_dem90 static

# Download global temperature forecast from GFS 13 km resolution 
docker run -it --rm -v open-meteo-data:/app/data open-meteo sync ncep_gfs013 temperature_2m --past-days 3

# Get your forecast
curl "http://127.0.0.1:8080/v1/forecast?latitude=47.1&longitude=8.4&models=gfs_global&hourly=temperature_2m"
```

Note: If built from source, the image name is just `open-meteo` instead of `ghcr.io/open-meteo/open-meteo`


## Development
If you want to interactively develop on the Open-Meteo source code and rapidly test changes, you can build in debug mode.

Using docker helps to run Open-Meteo, but all changes require a new image build, which slows down development. The Vapor development guide for [macOS](https://docs.vapor.codes/install/macos/) and [linux](https://docs.vapor.codes/install/linux/) help to get started.

### Develop with Docker:
```bash
git clone https://github.com/open-meteo/open-meteo.git
cd open-meteo

# Create a Docker volume to store weather data
docker volume create --name open-meteo-data

# Install docker
docker build -f Dockerfile.development -t open-meteo-development .
docker run -it --security-opt seccomp=unconfined -p 8080:8080 -v ${PWD}:/app -v open-meteo-data:/app/data -t open-meteo-development /bin/bash
# Run commands inside docker container:
swift run
swift run openmeteo-api download-ecmwf --run 00
```

### Develop on macOS:
```bash
git clone https://github.com/open-meteo/open-meteo.git
cd open-meteo

# Install Xcode from the App store
# Install brew
brew install netcdf eccodes
open Package.swift
# `swift run` works as well
```


### Develop on Linux natively:

It is easiest to use ubuntu 22.04 since this is the only Linux where swift 5.8+ is supported natively.
```bash
git clone https://github.com/open-meteo/open-meteo.git
cd open-meteo

# Install the swift compiler as pointed out in the Vapor development guide
sudo apt install libnetcdf-dev libeccodes-dev libbz2-dev build-essential curl
sudo apt-get install binutils git gnupg2 libc6-dev libcurl4-openssl-dev libedit2 libgcc-9-dev libpython3.8 \
  libsqlite3-0 libstdc++-9-dev libxml2-dev libz3-dev pkg-config tzdata unzip zlib1g-dev
sudo apt install libbz2-dev libz-dev

wget https://download.swift.org/swift-5.8.1-release/ubuntu2204/swift-5.8.1-RELEASE/swift-5.8.1-RELEASE-ubuntu22.04.tar.gz
tar xvzf swift-5.8.1-RELEASE-ubuntu22.04.tar.gz
sudo mv swift-5.8.1-RELEASE-ubuntu22.04 /opt
ln -s /opt/swift-5.8.1-RELEASE-ubuntu22.04/ /opt/swift
echo 'export PATH=/opt/swift/usr/bin:$PATH' >> ~/.bashrc
source ~/.bashrc

# Test if swift is working
swift --version

swift run
swift run openmeteo-api download-ecmwf --run 00
```

Notes: 
- To restart `swift run` press `ctrl+c` and run `swift run` again
- Add `-c release` to swift run to switch to a faster release build

## Atomic block cache write and deletion diagnostics

The localhost-only `/metrics` endpoint exposes process-local counters for cache
writes and deletions. Diagnostics do not change the cache format, eviction
policy or read path, and do not require clearing existing cache files.

| Metric | Meaning |
| --- | --- |
| `om_block_cache_write_claims_total{path}` | Successful claims of empty slots, same-key replacements or LRU selections, including claims whose publication subsequently failed. |
| `om_block_cache_replacements_total{path,age}` | Committed entries selected for replacement, grouped by age of their previous timestamp. |
| `om_block_cache_inflight_replacements_total{path}` | Nonempty entries claimed while still marked as being written. |
| `om_block_cache_publication_conflicts_total` | Publication CAS failures after copying the payload. |
| `om_block_cache_deletions_total{age}` | Successful committed-entry deletions, grouped by age at deletion. |

Age buckets are non-overlapping: `lt_10ms`, `10ms_100ms`, `100ms_1s`,
`1s_5s` and `ge_5s`. Ages use wall-clock timestamps, clamped to zero if the
clock moves backwards. Keys, filenames and slots appear only in logs, not metric
labels. Existing metric names and labels remain unchanged.

Every qualifying event is logged, without throttling or sampling:

| Reason | Observation |
| --- | --- |
| `replaced_recent_entry` | A write claimed a committed entry accessed within five seconds. |
| `replaced_inflight_entry` | A write claimed a nonempty entry still marked in-flight, regardless of its age. |
| `publication_conflict` | After copying, the writer's publication CAS observed metadata different from its claim. |
| `deleted_recent_entry` | Deletion successfully cleared a committed entry accessed within five seconds. |

Logs identify the cache file, process, slot and previous key/state/timestamp.
Write events also include insertion path, attempted key, claim timestamp and
publication success. Failed publication includes the key/state/timestamp
observed by that CAS, not a later metadata load. Deletions include the requested
age threshold. Timestamp fields use nanoseconds with the state flag removed;
they are not unique writer IDs. A write may log both replacement and publication
failure. In-memory test caches default to the identifier `<memory>`.

These are risk indicators, not proof of overlapping payload access:

- Access timestamps change on insertion and prefetch/active-block lookups as
  well as reads. Recent access does not establish an outstanding reader.
- One coordinator serializes its writes. An in-flight marker may belong to an
  active writer in another process or to an interrupted writer. Age alone cannot
  establish whether a writer is alive.
- Deletion can expose outstanding reader pointers to subsequent reuse. That reuse
  looks like an ordinary empty-slot insertion and is not itself logged or linked
  to the deletion; no per-slot history is retained.
- Publication failure establishes that the claim changed, but does not establish
  the ordering of payload copies or the cause of a decoder failure.
- Absence of warnings does not establish safety. Readers are not tracked.

For recent replacements and deletions, inspect:

```promql
sum by (path) (rate(om_block_cache_replacements_total{age!="ge_5s"}[5m]))
```

```promql
sum(rate(om_block_cache_deletions_total{age!="ge_5s"}[5m]))
```

For claim interference, inspect increases in
`om_block_cache_inflight_replacements_total` and
`om_block_cache_publication_conflicts_total`. Correlate timestamps and slots with
file-aware decoder logs where possible; hashed block keys alone do not identify
source filenames. Scrape every process sharing a cache.

Bookkeeping is constant-size and independent of cache capacity. There are no
extra payload copies, checksums, reader-side checks or HTTP requests. Successful
deletions additionally capture a timestamp and update a counter. Unthrottled
logging can be expensive and affect scheduling when qualifying events are frequent.
