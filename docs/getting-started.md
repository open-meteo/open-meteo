# Getting started

This tutorial provides instructions on setting up your weather API using either Docker or prebuilt packages for Ubuntu 22.04 Jammy. It presupposes a solid understanding of Linux server administration and familiarity with weather models.

## System Architecture
Open-Meteo comprises three key components:
1. An HTTP API server, which mirrors the API available on open-meteo.com. Developed using the Swift Vapor framework, this server compiles into a single binary, prioritizing fast access to weather data.
2. A file-based database responsible for managing all downloaded datasets, stored in the `./data` directory. The weather database files use a proprietary binary format, optimizing time-series data compression for efficiency.
3. Download commands tailored for various weather models. Users have the option to retrieve weather model data either through the [open-data distribution on AWS S3](https://github.com/open-meteo/open-data) or by directly downloading the original weather models.

Hardware Requirements:
- A relatively modern CPU with SIMD (or Intel® AVX2) instructions. `x86-64` and `Arm®` are supported.
- A minimum of 8 GB of memory, with 16 GB recommended for optimal performance.
- For comprehensive forecast data access, it is advised to have at least 150 GB of disk space, preferably on NVMe SSDs with high IOPS for enhanced performance. If only a limited selection of weather variables is employed, a few gigabytes (32 - 48 GB) will suffice.

## Running the API
Different options exist for deploying Open-Meteo: either through Docker or by using prebuilt packages designed for Ubuntu 22.04 (Jammy Jellyfish).

### Running on Docker
For a rapid deployment of Open-Meteo, Docker can be used. It launches a container that makes the Open-Meteo API accessible at `http://127.0.0.1:8080``. Subsequently, weather datasets can be downloaded from the AWS Open-Data distribution.

```bash
# Get the latest image
docker pull ghcr.io/open-meteo/open-meteo

# Create a Docker volume to store weather data
docker volume create --name open-meteo-data

# Start the API service on http://127.0.0.1:8080
docker run -d --rm -v open-meteo-data:/app/data -p 8080:8080 ghcr.io/open-meteo/open-meteo

# Download the latest ECMWF IFS 0.4° open-data forecast for temperature (50 MB)
docker run -it --rm -v open-meteo-data:/app/data ghcr.io/open-meteo/open-meteo sync ecmwf_ifs04 temperature_2m

# Get your forecast
curl "http://127.0.0.1:8080/v1/forecast?latitude=47.1&longitude=8.4&models=ecmwf_ifs04&hourly=temperature_2m"
```

### Using prebuilt Ubuntu Jammy Jellyfish packages
If you're operating on Ubuntu 22.04 Jammy Jellyfish, you have the option to utilize prebuilt binaries, which can be installed through APT with the following command:

```bash
sudo gpg --keyserver hkps://keys.openpgp.org --no-default-keyring --keyring /usr/share/keyrings/openmeteo-archive-keyring.gpg  --recv-keys E6D9BD390F8226AE
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/openmeteo-archive-keyring.gpg] https://apt.open-meteo.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/openmeteo-api.list

sudo apt update
sudo apt install openmeteo-api

# Download the latest ECMWF IFS 0.4° open-data forecast for temperature (50 MB)
sudo chown -R $(id -u):$(id -g) /var/lib/openmeteo-api
cd /var/lib/openmeteo-api
openmeteo-api sync ecmwf_ifs04 temperature_2m

# Get your forecast
curl "http://127.0.0.1:8080/v1/forecast?latitude=47.1&longitude=8.4&models=ecmwf_ifs04&hourly=temperature_2m"
```

This will automatically install and initiate an API instance at `http://127.0.0.1:8080`. You can verify this by using:
```bash
sudo systemctl status openmeteo-api
sudo systemctl restart openmeteo-api
sudo journalctl -u openmeteo-api.service
```

By default, port 8080 is bound to 127.0.0.1 and is **not** accessible from the network. To expose the service, you can configure `API_BIND="0.0.0.0:8080"` in `/etc/default/openmeteo-api.env` and restart the service. Nevertheless, it is advisable to use a proxy, such as nginx.


## Downloading Weather Models
Open-Meteo fetches raw weather data from national weather services and transforms it into a highly optimized time-series database. The Open-Meteo database is distributed as open-data through an [AWS Open-Data Sponsorship](https://github.com/open-meteo/open-data). For details on downloading raw weather forecasts from national weather services, refer to the [downloading datasets documentation](./downloading-datasets.md).

As illustrated earlier, the `sync` command enables the direct download of the Open-Meteo weather database from AWS S3. It requires two arguments:
1. One or more weather model, such as `ecmwf_ifs04` or `dwd_icon,dwd_icon_eu,dwd_icon_d2`
2. A list of weather variables, for example, `temperature_2m,relative_humidity_2m,wind_u_component_10m,wind_v_component_10m`

Please refer to the [Weather API tutorial](https://github.com/open-meteo/open-data/tree/main/tutorial_weather_api) for more more information.


### Automatic Data Synchronization  

The prebuilt Ubuntu images automatically install a synchronization service. Modify the configuration in /etc/default/openmeteo-api.env:
```
[...]

SYNC_ENABLED=true
SYNC_APIKEY=
SYNC_SERVER=
SYNC_PAST_DAYS=3
SYNC_DOMAINS=dwd_icon,ncep_gfs013,...
SYNC_VARIABLES=temperature_2m,dew_point_2m,relative_humidity_2m,...
SYNC_REPEAT_INTERVAL=5
```

Restart and monitor the sync service with:
```bash
sudo systemctl status openmeteo-sync
sudo systemctl restart openmeteo-sync
sudo journalctl -u openmeteo-sync.service
```

To automate the removal of older data, use the following cronjobs:

```
# Remove pressure level data after 10 days
0 * * * * find /var/lib/openmeteo-api/data/ -type f -name "chunk_*" -wholename "*hPa*" -mtime +10 -delete

# Remove surface level data after 90 days
5 * * * * find /var/lib/openmeteo-api/data/ -type f -name "chunk_*" -mtime +90 -delete
```

For further questions, please use [GitHub Discussions](https://github.com/open-meteo/open-meteo/discussions).