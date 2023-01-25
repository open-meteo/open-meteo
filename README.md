# 🌤 Open-Meteo Weather API

[![Test](https://github.com/open-meteo/open-meteo/actions/workflows/test.yml/badge.svg?branch=main)](https://github.com/open-meteo/open-meteo/actions/workflows/test.yml) [![codebeat badge](https://codebeat.co/badges/af28fed6-9cbf-41df-96a1-9bba03ae3c53)](https://codebeat.co/projects/github-com-open-meteo-open-meteo-main) [![GitHub license](https://img.shields.io/github/license/open-meteo/open-meteo)](https://github.com/open-meteo/open-meteo/blob/main/LICENSE) [![license: CC BY 4.0](https://img.shields.io/badge/license-CC%20BY%204.0-lightgrey.svg)](https://creativecommons.org/licenses/by/4.0/) [![Twitter](https://img.shields.io/twitter/follow/open_meteo)](https://twitter.com/open_meteo) [![Mastodon](https://img.shields.io/mastodon/follow/109320332765909743?domain=https%3A%2F%2Ffosstodon.org)](https://fosstodon.org/@openmeteo)


Open-Meteo is an open-source weather API and offers free access for non-commercial use. No API key is required. You can use it immediately!

Head over to https://open-meteo.com! Stay up to date with our blog at https://openmeteo.substack.com.

## Features 
- [Hourly weather forecast](https://open-meteo.com/en/docs) for 7 days
- Global weather models 11 km and regional up to 1.5 km resolution
- 60 years [Historical Weather API](https://open-meteo.com/en/docs/historical-weather-api)
- Based on the best weather models: [NOAA GFS with HRRR](https://open-meteo.com/en/docs/gfs-api), [DWD ICON](https://open-meteo.com/en/docs/dwd-api), [MeteoFrance Arome&Arpege](https://open-meteo.com/en/docs/meteofrance-api), [ECMWF IFS](https://open-meteo.com/en/docs/ecmwf-api), [JMA](https://open-meteo.com/en/docs/jma-api) 
- [Marine Forecast API](https://open-meteo.com/en/docs/marine-weather-api), [Air Quality API](https://open-meteo.com/en/docs/air-quality-api), [Geocoding API](https://open-meteo.com/en/docs/geocoding-api), [Elevation API](https://open-meteo.com/en/docs/elevation-api)
- No API key required, CORS supported, no ads, no tracking, not even cookies
- Free for non-commercial use with data under Attribution 4.0 International (CC BY 4.0)
- Lightning fast APIs with response times below 10 ms
- Servers located in Germany (POP for North-America in planning. Sponsors welcome!)
- Source code available under AGPLv3

## How does Open-Meteo work?
Open-Meteo is using open-data weather forecasts from national weather providers (NWP). 

NWPs offer numerical weather predictions free to download. Unfortunately working with those models is difficult and requires expert knowledge about binary file formats, grid-systems, projections and fundamentals in weather predictions.

The gap between downloading weather forecasts from NWPs and using weather forecasts in your home automation system, personal website, widgets for Linux or just tinkering around is huge! Even for small pet projects, you have to sign-up with credit-cards to large API vendors, which honestly do not offer properly engineered APIs.

Open-Meteo fills this gap and offers free weather forecast APIs for non-commercial use without any sign-up, credit-card or even an API key required!

- Do you want to build an open-source widget for Ubuntu? Sure!
- Use Open-Meteo for a React/Angular/Flutter App? Go for it!
- Improve your home automation system? Automate your robot lawn mower? Optimize your garden irrigation system? Open-Meteo is a good place to start!

## Who is using Open-Meteo?
Apps:
- [WeatherGraph](https://weathergraph.app) Apple Watch App
- [Slideshow](https://slideshow.digital/) Digital Signage app for Android

Repositories:
- [Captain Cold](https://github.com/cburton-godaddy/captain-cold) Simple Open-Meteo -> Discord integration
- [wthrr-the-weathercrab](https://github.com/tobealive/wthrr-the-weathercrab) Weather companion for the terminal
- [Weather-Cli](https://github.com/Rayrsn/Weather-Cli) A CLI program written in golang that allows you to get weather information from the terminal
- [Homepage](https://github.com/benphelps/homepage/) A highly customizable homepage (or startpage / application dashboard) with Docker and service API integrations.
- [Spots Guru](https://www.spots.guru) Weather forecast for lazy, the best wind & wave spots around you. 

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

Contributions welcome! Writing a SDK for Open-Meteo is more than welcome and a great way to help users.

## Roadmap 
- Forecasts in 6-hour intervals for `morning`, `afternoon`, `evening` and `night`
- 14 day weather forecast based on GFS ensemble and ICON ensemble
- Wave and current forecasts
- Air quality forecast with gases and pollen in hourly resolution
- 15 minutes weather forecast for 2 days for temperature, wind and solar radiation

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
