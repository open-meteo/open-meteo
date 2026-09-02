# Getting Started

This guide explains how to self-host the Open-Meteo Weather API using either Docker or the prebuilt packages for Ubuntu 22.04 (Jammy Jellyfish). It assumes familiarity with Linux server administration and weather models.

## System Architecture

Open-Meteo has three key components:

1. An HTTP API server, which provides the same API as available on open-meteo.com. The server is developed in Swift and compiles into a single binary.
2. A file-based database for storing weather data, stored in the `./data` directory. We use a custom, but open-source, binary format, optimized for time-series data compression. See [OM-File-Format](https://github.com/open-meteo/om-file-format).
3. Download routines for various weather models. You can obtain model data from the [Open-Meteo data distribution on AWS S3](https://github.com/open-meteo/open-data) or download it directly from the original providers. The API server also supports cloud-native access to the database on AWS.

### Hardware Requirements

- A relatively modern CPU with SIMD (like Intel® AVX2) instructions. `x86-64` and `Arm®` are supported.
- A minimum of 8 GB of memory, with 16 GB recommended for optimal performance.
- At least 100 GB of storage for small to medium deployments. Prefer an NVMe SSD with high IOPS because the storage is also used as a cache.

## Running with Docker

Docker is the quickest way to run Open-Meteo. The container exposes the API at `http://127.0.0.1:8080`, fetches current forecasts from the [Open-Meteo data distribution on AWS S3](https://github.com/open-meteo/open-data), and caches downloaded data locally. Images are available from the [GitHub Container Registry](https://github.com/open-meteo/open-meteo/pkgs/container/open-meteo) and [AWS ECR Public Gallery](https://gallery.ecr.aws/w5w8t1y7/openmeteo).

```bash
# Create a Docker volume to store weather data and cache
docker volume create --name open-meteo-data

# Start the API service on http://127.0.0.1:8080
docker run -d --rm \
  --name open-meteo \
  -v open-meteo-data:/app/data \
  -e REMOTE_DATA_DIRECTORY=https://openmeteo.s3.amazonaws.com/data/ \
  -e CACHE_SIZE=8GB \
  -p 127.0.0.1:8080:8080 \
  ghcr.io/open-meteo/open-meteo

# Get your forecast. The first call will take a couple of seconds.
curl "http://127.0.0.1:8080/v1/forecast?latitude=47.1&longitude=8.4&models=ecmwf_ifs025&hourly=temperature_2m"
```

### Running with Docker Compose

The same setup as a `docker-compose.yml` file:

```yaml
volumes:
  open-meteo-data:

services:
  open-meteo:
    image: ghcr.io/open-meteo/open-meteo
    container_name: open-meteo
    volumes:
      - open-meteo-data:/app/data
    environment:
      REMOTE_DATA_DIRECTORY: https://openmeteo.s3.amazonaws.com/data/
    ports:
      - '127.0.0.1:8080:8080'
    restart: always
```

```bash
# Start the API service on http://127.0.0.1:8080
docker compose up -d

# Get your forecast. The first call will take a couple of seconds.
curl "http://127.0.0.1:8080/v1/forecast?latitude=47.1&longitude=8.4&models=ecmwf_ifs025&hourly=temperature_2m"
```


## Installing the Ubuntu Package

On Ubuntu 22.04 (Jammy Jellyfish), you can install the prebuilt package through APT:

```bash
sudo gpg --keyserver hkps://keys.openpgp.org --no-default-keyring --keyring /usr/share/keyrings/openmeteo-archive-keyring.gpg  --recv-keys E6D9BD390F8226AE
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/openmeteo-archive-keyring.gpg] https://apt.open-meteo.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/openmeteo-api.list

sudo apt update
sudo apt install openmeteo-api

# Edit /etc/default/openmeteo-api.env and uncomment
# REMOTE_DATA_DIRECTORY=https://openmeteo.s3.amazonaws.com/data/
# CACHE_SIZE=8GB

# Restart for the changes to take effect
sudo systemctl restart openmeteo-api

# Get your forecast
curl "http://127.0.0.1:8080/v1/forecast?latitude=47.1&longitude=8.4&models=ecmwf_ifs025&hourly=temperature_2m"
```

The package installs and starts an API instance at `http://127.0.0.1:8080`. Use the following commands to inspect or restart it:

```bash
sudo systemctl status openmeteo-api
sudo systemctl restart openmeteo-api
sudo journalctl -u openmeteo-api.service
```

By default, port 8080 is bound to `127.0.0.1` and is **not** accessible from other hosts. To expose it directly, set `API_BIND="0.0.0.0:8080"` in `/etc/default/openmeteo-api.env` and restart the service. For production deployments, use a reverse proxy such as nginx to provide TLS and access controls.

> [!NOTE]
> The Open-Meteo APT repository currently supports Ubuntu 22.04 only.

## Performance

Although the Docker image supports cloud-native data access and local caching, a self-hosted instance is generally slower than the free Open-Meteo API. Producing a forecast requires reading small portions of compressed data from hundreds of files. This can involve several megabytes of data and take a few seconds, especially while the cache is cold. Self-hosting is therefore most useful for workloads with enough repeated API calls to benefit from caching, rather than for a single user.

Data fetched from the [Open-Meteo data distribution on AWS S3](https://github.com/open-meteo/open-data) is stored in a local least-recently-used (LRU) cache. Increase `CACHE_SIZE` when retrieving many variables or large amounts of historical data; caches of multiple terabytes are supported. The API checks S3 for forecast updates roughly every two minutes and preloads changes. Repeated requests and requests for nearby coordinates are typically faster.

Storage latency is important. For AWS deployments, running EC2 or Fargate in the same `us-west-2` region as the public data provides reasonable self-hosting performance.

## Downloading Weather Models

To download datasets directly from national weather services, see [Downloading Weather Models](./downloading-datasets.md). For multi-node deployments that synchronize a prepared database, see [Running Open-Meteo on Multiple Nodes](./sync-command.md).

## License

Self-hosting is available for non-commercial and commercial use. Weather data is provided under `CC-BY-4.0`, which requires attribution. The Open-Meteo API source code and Docker image are provided under the `AGPL-3.0` license, with the following terms:

- Network Use is Distribution: If you modify AGPL-3.0 software and run it as a service over a network (like a cloud app or SaaS), you must provide the complete modified source code to the users of that service.
- Same License (Share-Alike): Any derivative works or larger works incorporating the code must also be licensed under AGPL-3.0.
- Notice Preservation: You must keep all original copyright and license notices intact, and document changes made to the code.
- Patent Grant: Contributors provide an express grant of patent rights.

## Support

For commercial support options, you can contact us via email. Please note that we do not support small deployments.

For further questions and community support, please use [GitHub Discussions](https://github.com/open-meteo/open-meteo/discussions).
