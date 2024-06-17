## Downloading datasets
Because data is consumed from different national weather services with different open-data servers and update times, many different downloaders are available.

Please note, that only the command arguments are listed below. Whether you are using Docker, prebuilt or native, the command differs a bit. There is an example to download ECMWF forecasts at each installation method above. All arguments that are available for the binary, are accessible via `<exe> --help`. Please mind that `<exe> --help` should be the path to your executable:

```
# openmeteo-api --help                          
Usage: /usr/local/bin/openmeteo-api <command>

Commands:
                   benchmark Benchmark Open-Meteo core functions like data manipulation and compression
                        boot Boots the application's providers.
                  convert-om Convert an om file to to NetCDF
                     cronjob Emits the cronjob definition
                    download Download a specified icon model run
               download-cams Download global and european CAMS air quality forecasts
              download-cmip6 Download CMIP6 data and convert
                download-dem Convert digital elevation model
              download-ecmwf Download a specified ecmwf model run
               download-era5 Download ERA5 from the ECMWF climate data store and convert
                download-gem Download Gem models
                download-gfs Download GFS from NOAA NCEP
             download-glofas Download river discharge data from GloFAS
           download-iconwave Download a specified wave model run
                download-jma Download JMA models
        download-meteofrance Download MeteoFrance models
              download-metno Download MetNo models
          download-satellite Download satellite datasets
  download-seasonal-forecast Download seasonal forecasts from Copernicus
                      export Export to dataset to NetCDF
                      routes Displays all registered routes.
                       serve Begins serving the app over HTTP.
                        sync Synchronise weather database from a remote server

Use `/usr/local/bin/openmeteo-api <command> [--help,-h]` for more information on a command.
```

All data is stored in the current working directory in `./data`. Please make sure that your current working directory is correct. All downloaders will create the required directories automatically. All subsequent downloader invocations will update weather data in this directory. Deleting it, will delete all historical weather data.

Additionally all download instructions as a cronjob file are available [here](./cronjobs.md). At a larger stage, an integrated task scheduler might be integrated into the API itself. Currently all downloads are initiated by cronjobs on Open-Meteo servers. If you are using the prebuilt Ubuntu binaries, make sure to add a symbolic link to the data directory in the users home directory executing the cronjobs `ln -s /var/lib/openmeteo-api/data`.

### DWD ICON
The DWD ICON models are the most important source for the 7 days weather API. There are 3 different domains available:

| Model               | Resolution | Runs at                          |
|---------------------|------------|----------------------------------|
| ICON global `icon`  | 11 km      | `00, 06, 12, 18`                 |
| ICON EU `icon-eu`   | 7 km       | `00, 03, 06, 09, 12, 15, 18, 21` |
| ICON D2 `icon-d2`   | 2 km       | `00, 03, 06, 09, 12, 15, 18, 21` |


As a minimum requirement, ICON global should be downloaded. To download the 00 run:

```bash
<exe> download icon --run 00 --only-variables temperature_2m,weather_code
``` 
 
If `only-variables` is omitted, all ICON weather variables are downloaded, which could take a couple of hours.

For the first run, the ICON downloader will download additional domain geometry information and prepare reproduction weights. It might take a while.

A list of all ICON weather variables that can be downloaded is available here: [IconVariables](https://github.com/open-meteo/open-meteo/blob/82a73573e2cb4d3dbecb972f5ce3924030b3a37e/Sources/App/Icon/IconVariable.swift#L90). To save resource on the public DWD servers, please only downloaded required weather variables.

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

**Requirements**: Install gdal and make sure the command `gdal_translate` is available.
- Mac: `brew install gdal`
- Linux: `apt install gdal`

Afterwards it can be converted with `<exe> download-dem dem-90m` and input data can be removed with `rm -R dem-90m data/dem90/`. The converted files will be available at `data/omfile-dem90`
