# 🌤 Open-Meteo Weather API

[![Test](https://github.com/open-meteo/open-meteo/actions/workflows/test.yml/badge.svg?branch=main)](https://github.com/open-meteo/open-meteo/actions/workflows/test.yml) [![codebeat badge](https://codebeat.co/badges/af28fed6-9cbf-41df-96a1-9bba03ae3c53)](https://codebeat.co/projects/github-com-open-meteo-open-meteo-main) [![GitHub license](https://img.shields.io/github/license/open-meteo/open-meteo)](https://github.com/open-meteo/open-meteo/blob/main/LICENSE) [![license: CC BY-NC 4.0](https://img.shields.io/badge/license-CC%20BY--NC%204.0-lightgrey.svg)](https://creativecommons.org/licenses/by-nc/4.0/) [![Twitter](https://img.shields.io/twitter/url/https/twitter.com/open_meteo.svg?style=social&label=Follow%20%40Open-Meteo)](https://twitter.com/open_meteo)


Open-Meteo is an open-source weather API and offers free access for non-commercial use. No API key is required. You can use it inmediately!

Head over to https://open-meteo.com! Stay up to date with our blog at https://openmeteo.substack.com.

## Features 
- Hourly weather forecast for 7 days
- Global weather models 11 km and regional up to 2 km resolution
- 60 years Historical Weather API
- No API key required, CORS supported, no ads, no tracking, not even cookies
- Free for non-commercial use under Attribution-NonCommercial 4.0 International (CC BY-NC 4.0)
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

Repositories:
- [Captain Cold](https://github.com/cburton-godaddy/captain-cold) Simple Open-Meteo -> Discord integration

Other:
- Contributions welcome!

Do you use Open-Meteo? Please open a pull request and add your repository or app to the list!

## Client SDKs
- Go https://github.com/HectorMalot/omgo
- Python https://github.com/m0rp43us/openmeteopy

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


## Development instructions
This section is under development and should cover:
- Using prebuild ubuntu binaries
- Downloading datasets, running the API
- Basic application design
- Development with docker xcode

Using prebuild Ubuntu 20.04 focal packages:
```bash
curl -L https://open-meteo.github.io/open-meteo/public.key | sudo apt-key add -
echo "deb [arch=amd64] https://open-meteo.github.io/open-meteo/repo $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/openmeteo-api.list
sudo apt update
sudo apt install openmeteo-api
```

This will automatically install and run an empty API instance. It can be checked with
```bash
sudo systemctl status openmeteo-api
sudo systemctl restart openmeteo-api
sudo journalctl -u openmeteo-api.service
```


## Terms & Privacy
Open-Meteo APIs are free for open-source developer and non-commercial use. We do not restrict access, but ask for fair use.

If your application exceeds 10'000 requests per day, please contact us. We reserve the right to block applications and IP addresses that misuse our service.

For commercial use of Open-Meteo APIs, please contact us.

All data is provided as is without any warrenty.

We do not collect any personal data. We do not share any personal information. We do not integrate any third party analytics, ads, beacons or plugins.

## Data License
API data are offered under Attribution-NonCommercial 4.0 International (CC BY-NC 4.0)

You are free to share: copy and redistribute the material in any medium or format and adapt: remix, transform, and build upon the material.

Attribution: You must give appropriate credit, provide a link to the license, and indicate if changes were made. You may do so in any reasonable manner, but not in any way that suggests the licensor endorses you or your use.

You must include a link next to any location, Open-Meteo data are displayed like:

<a href="https://open-meteo.com/">Weather data by Open-Meteo.com</a>

NonCommercial: You may not use the material for commercial purposes.


## Source Code License
Open-Meteo is open-source under the GNU Affero General Public License Version 3 (AGPLv3) or any later version. You can [find the license here](LICENSE). Exceptions are third party source-code with individual licencing in each file.
