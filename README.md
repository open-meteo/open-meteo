# 🌤 Open-Meteo Weather API

[![Test](https://github.com/open-meteo/open-meteo/actions/workflows/test.yml/badge.svg?branch=main)](https://github.com/open-meteo/open-meteo/actions/workflows/test.yml) [![codebeat badge](https://codebeat.co/badges/af28fed6-9cbf-41df-96a1-9bba03ae3c53)](https://codebeat.co/projects/github-com-open-meteo-open-meteo-main) [![GitHub license](https://img.shields.io/github/license/open-meteo/open-meteo)](https://github.com/open-meteo/open-meteo/blob/main/LICENSE) [![license: CC BY 4.0](https://img.shields.io/badge/license-CC%20BY%204.0-lightgrey.svg)](https://creativecommons.org/licenses/by/4.0/) [![Twitter](https://img.shields.io/badge/follow-%40open_meteo-1DA1F2?logo=twitter&style=social)](https://twitter.com/open_meteo) [![Mastodon](https://img.shields.io/mastodon/follow/109320332765909743?domain=https%3A%2F%2Ffosstodon.org)](https://fosstodon.org/@openmeteo) [![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.7970649.svg)](https://doi.org/10.5281/zenodo.7970649)


Open-Meteo is an open-source weather API and offers free access for non-commercial use. No API key is required. You can use it immediately!

Head over to https://open-meteo.com! Stay up to date with our blog at https://openmeteo.substack.com.

## Features
- [Hourly weather forecast](https://open-meteo.com/en/docs) for up to 16 days
- Global weather models with 11 km and regional models up to 1.5 km resolution
- Weather model updates every hour for Europe and North America
- 80 years [Historical Weather API](https://open-meteo.com/en/docs/historical-weather-api)
- Based on the best weather models: [NOAA GFS with HRRR](https://open-meteo.com/en/docs/gfs-api), [DWD ICON](https://open-meteo.com/en/docs/dwd-api), [MeteoFrance Arome&Arpege](https://open-meteo.com/en/docs/meteofrance-api), [ECMWF IFS](https://open-meteo.com/en/docs/ecmwf-api), [JMA](https://open-meteo.com/en/docs/jma-api), [GEM HRDPS](https://open-meteo.com/en/docs/gem-api), [MET Norway](https://open-meteo.com/en/docs/metno-api)
- [Marine Forecast API](https://open-meteo.com/en/docs/marine-weather-api), [Air Quality API](https://open-meteo.com/en/docs/air-quality-api), [Geocoding API](https://open-meteo.com/en/docs/geocoding-api), [Elevation API](https://open-meteo.com/en/docs/elevation-api), [Flood API](https://open-meteo.com/en/docs/flood-api)
- Lightning fast APIs with response times below 10 ms
- Servers located in Europe and North America with GeoDNS for best latency and high-availability
- No API key required, CORS supported, no ads, no tracking, not even cookies
- Free for non-commercial use with data under Attribution 4.0 International (CC BY 4.0)
- Source code available under AGPLv3

## How does Open-Meteo work?
Open-Meteo utilizes open-data weather forecasts provided by national weather services. These services offer numerical weather predictions that are free to download. However, working with these models can be challenging, as it requires expertise in binary file formats, grid-systems, projections, and the fundamentals of weather predictions.

Like many other weather APIs, Open-Meteo integrates high-resolution local and global weather models. Over 2 TB of data are downloaded and processed daily from multiple national weather services. The collected data is then stored in local files using a customized file format and compression technique to enhance access to time-series data such as a 14-day temperature forecast.

In contrast to other weather APIs, Open-Meteo provides complete access to its source code, and all data sources are openly listed, crediting the national weather services for their work. With Docker or prebuilt Ubuntu packages, it is possible to launch your own weather API within minutes. By providing the source code, users can conduct detailed verifications of the weather data processing and even make modifications themselves. Contributions are highly encouraged and welcomed.

The API is available for non-commercial use at no cost. Despite being free of charge, the forecast accuracy is top-notch. The API utilizes a vast array of local weather models with rapid updates, ensuring that the most precise forecast is generated for any location globally.

## Resources
- All API documentation can be found on https://open-meteo.com. The source code for the website, documentation and API generator is available here: https://github.com/open-meteo/open-meteo-website
- The free non-commerical API is hosted at [https://api.open-meteo.com](https://api.open-meteo.com/v1/forecast?latitude=52.52&longitude=13.41&hourly=temperature_2m) using to GeoDNS to servers in Europe and North America (HTTPS is optional). The API source code is in this current repository.
- The geocoding API source code is available in a separate repository https://github.com/open-meteo/geocoding-api
- Larger changes are announced in the [Open-Meteo Blog](https://openmeteo.substack.com)

## Who is using Open-Meteo?
Apps:
- [WeatherGraph](https://weathergraph.app) Apple Watch App
- [Slideshow](https://slideshow.digital/) Digital Signage app for Android
- [weewx-DWD](https://github.com/roe-dl/weewx-DWD) Weather forecasts etc. for WeeWX
- [omWeather](https://github.com/woheller69/omweather) Android Weather App
- [solXpect](https://github.com/woheller69/solxpect) Android app which forecasts the output of your solar power plant
- [Raindrop](https://github.com/metalfoxdev/Raindrop) Simple and intuitive weather app for the linux terminal.
- [Weatherian](https://weatherian.com/) Multi-model meteogram (multi-platform)
- [WeatherAI](https://play.google.com/store/apps/details?id=com.kingfu.weatherai) WeatherAI offers an intuitive user experience that makes checking the weather a breeze.
- [Weather](https://github.com/GustavLindberg99/AndroidWeather) Free, open source, simple and complete weather app for Android
- [DroneWeather](https://play.google.com/store/apps/details?id=xyz.droneweather.app) Weather forecasts, satellite count, and KP index for drone pilots.
- [Clima](https://f-droid.org/packages/co.prestosole.clima/) Beautiful, minimal, and fast weather app
- [SkyMuse](https://github.com/cakephone/skymuse) Minimal, privacy-respecting weather app. Built with web technologies.
- [Weather Please](https://github.com/ggaidelevicius/weather-please/) Clean and minimal new tab replacement for browsers
- [QuickWeather](https://github.com/TylerWilliamson/QuickWeather) Fast, free, and open source Android app

Repositories:
- [Captain Cold](https://github.com/cburton-godaddy/captain-cold) Simple Open-Meteo -> Discord integration
- [wthrr-the-weathercrab](https://github.com/tobealive/wthrr-the-weathercrab) Weather companion for the terminal
- [Weather-Cli](https://github.com/Rayrsn/Weather-Cli) A CLI program written in golang that allows you to get weather information from the terminal
- [Homepage](https://github.com/benphelps/homepage/) A highly customizable homepage (or startpage / application dashboard) with Docker and service API integrations.
- [Spots Guru](https://www.spots.guru) Weather forecast for lazy, the best wind & wave spots around you.
- [WeatherReport.jl](https://github.com/vnegi10/WeatherReport.jl) A simple weather app for the Julia REPL

Other:
- [Menubar Weather](https://www.raycast.com/koinzhang/menubar-weather) A Raycast extension that displays live weather information in your menu bar
- Contributions welcome!

Do you use Open-Meteo? Please open a pull request and add your repository or app to the list!

## Client SDKs
- Go https://github.com/HectorMalot/omgo
- Python https://github.com/m0rp43us/openmeteopy
- Kotlin https://github.com/open-meteo/open-meteo-api-kotlin
- .Net / C# https://github.com/AlienDwarf/open-meteo-dotnet
- PHP Laravel https://github.com/michaelnabil230/laravel-weather
- R https://github.com/tpisel/openmeteo
- PHP Symfony 6.2 https://gitlab.com/flibidi67/open-meteo
- PHP for Geocoding API: https://gitlab.com/flibidi67/open-meteo-geocoding
- Android library for Geocoding API: https://github.com/woheller69/OmGeoDialog
- Rust: https://github.com/angelodlfrtr/open-meteo-rs

Contributions welcome! Writing a SDK for Open-Meteo is more than welcome and a great way to help users.

## Support
If you encounter bugs while using Open-Meteo APIs, please file a new issue ticket. For general ideas or Q&A please use the [Discussion](https://github.com/open-meteo/open-meteo/discussions) section on Github. Thanks!

For other enquiries please contact info@open-meteo.com


## Run your own API
Instructions to use Docker to run your own weather API are available in the [getting started guide](/docs/getting-started.md).



## Terms & Privacy
Open-Meteo APIs are free for open-source developer and non-commercial use. We do not restrict access, but ask for fair use.

If your application exceeds 10'000 requests per day, please contact us. We reserve the right to block applications and IP addresses that misuse our service.

For commercial use of Open-Meteo APIs, please contact us.

All data is provided as is without any warranty.

We do not collect any personal data. We do not share any personal information. We do not integrate any third party analytics, ads, beacons or plugins.

## Data License
API data are offered under Attribution 4.0 International (CC BY 4.0)

You are free to share: copy and redistribute the material in any medium or format and adapt: remix, transform, and build upon the material.

Attribution: You must give appropriate credit, provide a link to the license, and indicate if changes were made. You may do so in any reasonable manner, but not in any way that suggests the licensor endorses you or your use.

You must include a link next to any location, Open-Meteo data are displayed like:

<a href="https://open-meteo.com/">Weather data by Open-Meteo.com</a>


## Source Code License
Open-Meteo is open-source under the GNU Affero General Public License Version 3 (AGPLv3) or any later version. You can [find the license here](LICENSE). Exceptions are third party source-code with individual licensing in each file.
