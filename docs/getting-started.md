# Getting started

This guide explains how you can run your own weather API using Docker or prebuilt Ubuntu 22.04 Jammy packages. This guide assumes fairly good knowledge of linux server administration and understanding of weather models.

## Architecture
Open-Meteo has 3 components:
1. An HTTP API server that serves the same API as offered on open-meteo.com. The API server is based on the Swift Vapor framework, compiles to a single binary and is designed to offer fast access to weather data.
2. A File-based database to store all downloaded datasets. Literally just the `./data` directory. The Open-Meteo weather database files use a custom binary format to efficiently compress data.
3. Download commands for various weather models and variables. You can either download weather model data from the [open-data distribution through AWS S3](https://github.com/open-meteo/open-data) or download the original weather models.

Hardware requirements:
- A relatively modern CPU with SIMD (or Intel® AVX2) instructions. Both `x86-64` and `Arm®` are supported.
- At least 8 GB of memory, 16 GB recommended.
- For all forecast data, 150 GB of disk space is recommended (for best performance, SSDs with high IOPS). If only a small selection for weather variables is used, just a couple of GB are fine (32 - 48 GB).

## Running the API
There are different option to run Open-Meteo: Docker or with prebuilt Ubuntu 22.04 (Jammy Jellyfish) packages.

### Running on Docker
To quickly run Open-Meteo, Docker can be used. It will run an container which exposes the Open-Meteo API to http://127.0.0.1:8080. Afterwards weather datasets can be downloaded. 

```bash
# Get the latest image
docker pull ghcr.io/open-meteo/open-meteo

# Create a local data directory
mkdir data
chmod o+w data

# Start the API service on http://127.0.0.1:8080
docker run -d --rm -v ${PWD}/data:/app/data -p 8080:8080 ghcr.io/open-meteo/open-meteo

# Download the latest ECMWF IFS 0.4° open-data forecast for temperature (50 MB)
docker run -it --rm -v ${PWD}/data:/app/data ghcr.io/open-meteo/open-meteo sync ecmwf_ifs04 temperature_2m

# Get your forecast
curl "http://127.0.0.1:8080/v1/forecast?latitude=47.1&longitude=8.4&models=ecmwf_ifs04&hourly=temperature_2m"
```

### Using prebuilt Ubuntu Jammy Jellyfish packages
If you are running Ubuntu 22.04 Jammy Jellyfish, you can use prebuilt binaries. They can be installed via APT:

```bash
curl -L https://apt.open-meteo.com/public.key | sudo gpg --dearmour -o /etc/apt/trusted.gpg.d/openmeteo.gpg
echo "deb [arch=amd64] https://apt.open-meteo.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/openmeteo-api.list
sudo apt update
sudo apt install openmeteo-api

# Download the latest ECMWF IFS 0.4° open-data forecast for temperature (50 MB)
sudo chown -R $(id -u):$(id -g) /var/lib/openmeteo-api
cd /var/lib/openmeteo-api
openmeteo-api sync ecmwf_ifs04 temperature_2m

# Get your forecast
curl "http://127.0.0.1:8080/v1/forecast?latitude=47.1&longitude=8.4&models=ecmwf_ifs04&hourly=temperature_2m"
```

This will automatically install and run an API instance at `http://127.0.0.1:8080`. It can be checked with:
```bash
sudo systemctl status openmeteo-api
sudo systemctl restart openmeteo-api
sudo journalctl -u openmeteo-api.service
```

Per default, port 8080 is bound to 127.0.0.1 and **not** exposed to the network. You can set `API_BIND="0.0.0.0:8080"` in `/etc/default/openmeteo-api.env` and restart the service to expose the service. However, it is recommended to use a proxy like nginx.


## Downloading weather models
Open-Meteo downloads raw weather data from national weather services and converts data into a highly optimized time-series database. The Open-Meteo database is distributed as open-data through an [AWS Open-Data Sponsorship](https://github.com/open-meteo/open-data). Information on downloading raw weather forecast from national weather services, is available [here](./downloading-datasets.md).

As shown above, the `sync` command downloads the Open-Meteo weather database directly from AWS S3. It accepts 2 arguments:
1. One or more weather model. E.g. `ecmwf_ifs04` or `dwd_icon,dwd_icon_eu,dwd_icon_d2`
2. A list of weather variables E.g. `temperature_2m,relative_humidity_2m,wind_u_component_10m,wind_v_component_10m`

The weather models and variables might be a bit unfamiliar, because the Open-Meteo weather API selects the most suitable weather model for each location automatically. A detailed list of all weather models is available on the documentation for the [open-data distribution](https://github.com/open-meteo/open-data).

The `sync` command accepts 2 optional parameter:
1. `--past-days <number>`: To specify how much past weather data should be downloaded. Per default 3 days. Please note: Because data is compressed by short time-intervals, 2-7 days of past data will always be present.
2. `--repeat-interval <number>`: If set, the API will continue to run indefinitely and check every N minutes for new data.

### Basic configuration
To run a general purpose weather API that provides the weather variables `temperature_2m,relative_humidity_2m,precipitation_probability,rain,snowfall,weather_code,cloud_cover,wind_speed_10m,wind_direction_10m`, the following configuration is recommended:

1. Download the digital elevation model once with `[..] sync copernicus_dem90 static`. This is required to perform down-scaling based on terrain elevation. 8 GB of storage are required.
2. Download the forecast data with `[..] sync dwd_icon,ncep_gfs013,ncep_gfs025,ncep_gefs025_probability temperature_2m,dew_point_2m,relative_humidity_2m,precipitation_probability,precipitation,rain,cloud_cover,snowfall_water_equivalent,snowfall_convective_water_equivalent,weather_code,wind_u_component_10m,wind_v_component_10m,cape,lifted_index`
3. Set-up a cronjob or background process to check for updates every couple of minutes

Notice how the list of weather variables is now significantly longer? The API requires additional data to compute certain weather variables on demand like `wind_speed_10m` from `wind_u_component_10m` and `wind_v_component_10m`. As a list of weather models, NCEP GFS and DWD ICON are used. They are global weather models and provide good forecast accuracy for most parts of the world. For GFS, the variants `gfs013` and `gfs025` are downloaded. Surface variables like temperature are available for GFS in 13 km resolution, some variables like `cape` are only available for GFS in 25 km resolution. This configuration of weather models and variables requires 12 GB storage. 

To further enhance the weather forecast, high resolution models for Europe and North America can be added. Namely the models `ncep_hrrr_conus` and `dwd_icon_eu,dwd_icon_d2` boost local accuracy and provide updates every 1 or 3 hours. Simply add them to the list of weather models `dwd_icon,ncep_gfs013,ncep_gfs025,ncep_gefs025_probability,ncep_hrrr_conus,dwd_icon_eu,dwd_icon_d2`. Adding local models, requires another 3 GB of storage.

The list of weather models and variables must to be carefully selected. Please refer to the [open-data documentation](https://github.com/open-meteo/open-data) to get a better understanding of available weather models and variables. 

### Automatic data synchronization  

The prebuilt Ubuntu images install a sync service automatically. Edit: `/etc/default/openmeteo-api.env`:
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

Restart and monitor the sync service with
```bash
sudo systemctl status openmeteo-sync
sudo systemctl restart openmeteo-sync
sudo journalctl -u openmeteo-sync.service
```

To automatically cleanup old data, the following cronjobs can be used.

```
# Remove pressure level data after 10 days
0 * * * * find /var/lib/openmeteo-api/data/ -type f -name "chunk_*" -wholename "*hPa*" -mtime +10 -delete

# Remove surface level data after 90 days
5 * * * * find /var/lib/openmeteo-api/data/ -type f -name "chunk_*" -mtime +90 -delete
```

For further questions, please use [GitHub Discussions](https://github.com/open-meteo/open-meteo/discussions).