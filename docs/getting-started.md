# Getting started

## Architecture
Open-Meteo has 3 components:
- HTTP server for APIs and simple web-interfaces
- Download commands for weather datasets
- File-based database to store all downloaded datasets. Literally just the `./data` directory

The HTTP server and download commands are developed using the Vapor Swift framework and compile to a single binary `openmeteo-api`. 

Once the binary is available, you can start an HTTP server and download weather data from open-data sources. The file based database is automatically created as soon aa first data are downloaded.

Hardware requirements:
- A relatively modern CPU with SIMD instructions. `x86_64` and `arm` are supported
- At least 8 GB memory. 16 GB recommended.
- For all forecast data, 150 GB disk space are recommended. If only a small selection for weather variables is used, just a couple of GB are fine.

## Running the API
There are different option to run Open-Meteo: Docker or with prebuilt ubuntu jammy packages.

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

# Download ECMWF IFS temperature forecast 
docker run -it --rm -v ${PWD}/data:/app/data ghcr.io/open-meteo/open-meteo download-ecmwf --run 00 --only-variables temperature_2m

# Get your forecast
curl "http://127.0.0.1:8080/v1/forecast?latitude=47.1&longitude=8.4&models=ecmwf_ifs04&hourly=temperature_2m"
```

### Using prebuilt Ubuntu jammy packages
If you are running Ubuntu 22.04 jammy, you can use prebuilt binaries.

They can be installed via APT:
```bash
curl -L https://apt.open-meteo.com/public.key | sudo gpg --dearmour -o /etc/apt/trusted.gpg.d/openmeteo.gpg
echo "deb [arch=amd64] https://apt.open-meteo.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/openmeteo-api.list
sudo apt update
sudo apt install cdo
sudo apt install openmeteo-api

# Download ECMWF
sudo chown -R $(id -u):$(id -g) /var/lib/openmeteo-api
cd /var/lib/openmeteo-api
openmeteo-api download-ecmwf --run 00 --only-variables temperature_2m
```

This will automatically install and run an empty API instance at `http://127.0.0.1:8080`. It can be checked with:
```bash
sudo systemctl status openmeteo-api
sudo systemctl restart openmeteo-api
sudo journalctl -u openmeteo-api.service
```

Per default, port 8080 is bound to 127.0.0.1 and not exposed to the network. You can set `API_BIND="0.0.0.0:8080"` in `/etc/default/openmeteo-api.env` and restart the service to expose the service. However, it is recommended to use a proxy like NGINX.

## Downloading datasets
The instruction above, setup an API instance, but do not download any weather data yet. Because data is consumed from different national weather services with different open-data servers and update times, many different downloader are available.

Please note, that only the command arguments are listed below. Whether you are using Docker, prebuilt or native, the command differs a bit. There is an example to download ECMWF forecasts at each installation method above. All arguments are available for the binary are available with `<exe> --help`:

```
# openmeteo-api --help
Usage: openmeteo-api <command>

Commands:
          benchmark Run benchmark
               boot Boots the application's providers.
            cronjob Emits the cronjob definition
           download Download a specified icon model run
       download-dem Download digital elevation model
     download-ecmwf Download a specified ecmwf model run
      download-era5 Download ERA5 from the ECMWF climate data store and convert
  download-iconwave Download a specified wave model run
             routes Displays all registered routes.
              serve Begins serving the app over HTTP.

Use `openmeteo-api <command> [--help,-h]` for more information on a command.
```

All data is stored in the current working directory in `./data`. Please make sure that your current working directory is correct. All downloaders will create the required directories automatically. All subsequent downloader invocations will update weather data in this directory. Deleting it, will delete all historical weather data.

Additionally all download instructions as a cronjob file are available [here](https://github.com/open-meteo/open-meteo/blob/main/Sources/App/Commands/CronjobCommand.swift). At a larger stage, an integrated task scheduler might be integrated into the API itself. Currently all downloads are initiated by cronjobs on Open-Meteo servers. If you are using the prebuilt Ubuntu binaries, make sure to add a symbolic link to the data directory in the users home directory executing the cronjobs `ln -s /var/lib/openmeteo-api/data`.

### DWD ICON
The DWD ICON models are the most important source for the 7 days weather API. There are 3 different domains available:
- ICON global at 11 km resolution, runs `00,06,12,18`
- ICON EU with 7 km, runs `00,03,06,09,12,15,18,21`
- ICON D2 Central Europe with 2 km resolution, runs `00,03,06,09,12,15,18,21`

As a minimum requirement, ICON global should be downloaded. To download the 00 run: `<exe> download icon --run 00 --only-variables temperature_2m,weathercode`. If `only-variables` is omitted, all ICON weather variables are downloaded, which could take a couple of hours.

For the first run, the ICON downloader will download additional domain geometry information and prepare reproduction weights. It might take a while.

A list of all ICON weather variables that can be downloaded is available here: [IconVariables](https://github.com/open-meteo/open-meteo/blob/main/Sources/App/Icon/IconVariableDownloadable.swift#L84). To save resource on the public DWD servers, please only downloaded required weather variables.

The icon download command has the following arguments:
```
api# openmeteo-api download --help
Usage: openmeteo-api download <domain> <run> [--only-variables] [--skip-existing]

Download a specified icon model run

Arguments:
         domain            run
Options:
  only-variables
Flags:
  skip-existing
```

### ECMWF IFS
For the ECMWF API, only one domain is available with runs at `00,06,12,18`. Currently it is not supported to only download a subset of weather variables, but all variables need to be downloaded.

To download ECMWF forecasts, run the binary with arguments `<exe> download-ecmwf --run 00`.


### ERA5
ERA5 is driving the Historical Weather API and can be downloaded for the past. You have to register at copernicus.eu and accept the license terms at the end of [the ERA5 hourly data site](https://cds.climate.copernicus.eu/cdsapp#!/dataset/reanalysis-era5-single-levels?tab=overview).

From your Copernicus account, you need an API key in form `234234:XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX`. The CDS key is a required argument in the next step.

To download most recent ERA5 data, simply run `<exe> download-era5 <domain> --cdskey 234234:XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX`. This will download the last 2 weeks of era5 data,
where domain must be one of the following options.
- era5
- era5_land
- cerra
- ecmwf_ifs

To download a various time-range, specify additionally the parameter time-interval: `<exe> download-era5 <domain> --timeinterval 20220101-20220131 --cdskey ...`

To download an entire year: `<exe> download-era5 <domain> --year 2021 --cdskey`. Per year of data, roughly 60 GB of disk space are required.

All arguments for the `<exe> download-era5` command:
```
# openmeteo-api download-era5 --help
Usage: openmeteo-api download-era5 <domain> [--timeinterval,-t] [--year,-y] [--stripseaYear,-s] [--cdskey,-k]

Download ERA5 from the ECMWF climate data store and convert

Options:
  timeinterval Timeinterval to download with format 20220101-20220131
          year Download one year
        cdskey CDS API user and key like: 123456:8ec08f...
```

### Digital elevation model
To download the 90 meter elevation model for the Elevation API as well as improving weather forecast accuracy, you first have to download the Copernicus DEM: https://copernicus-dem-30m.s3.amazonaws.com/readme.html

A fast way is to use:
```
sudo apt-get install awscli
aws s3 sync --no-sign-request --exclude "*" --include "Copernicus_DSM_COG_30*/*_DEM.tif" s3://copernicus-dem-90m/ dem-90m
```
For further installation instructions see, [Install or update the latest version of the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html).

Requirements: Install gdal and make sure the command `gdal_translate` is available. Mac: `brew install gdal` Linux: `apt install gdal`

Afterwards it can be converted with `<exe> download-dem dem-90m` and input data can be removed with `rm -R dem-90m data/dem90/`. The converted files will be available at `data/omfile-dem90`
