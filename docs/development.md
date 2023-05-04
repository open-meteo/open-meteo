### Development
Using docker helps to run Open-Meteo, but all changes require a new image build, which slows down development. The Vapor development guide for [macOS](https://docs.vapor.codes/install/macos/) and [linux](https://docs.vapor.codes/install/linux/) help to get started.

Develop with Docker:
```bash
git clone https://github.com/open-meteo/open-meteo.git
cd open-meteo

# Install docker
docker build -f Dockerfile.development -t open-meteo-development .
docker run -it --security-opt seccomp=unconfined -p 8080:8080 -v ${PWD}/data:/app/data -t open-meteo-development /bin/bash
# Run commands inside docker container:
swift run
swift run openmeteo-api download-ecmwf --run 00
```

Develop on macOS:
```bash
git clone https://github.com/open-meteo/open-meteo.git
cd open-meteo

# Install Xcode from the App store
# Install brew
brew install netcdf cdo bzip2
pip3 install cdsapi
open Package.swift
# `swift run` works as well
```


Develop on Linux natively:
```bash
git clone https://github.com/open-meteo/open-meteo.git
cd open-meteo

# Install the swift compiler as pointed out in the Vapor development guide
apt install libnetcdf-dev libeccodes-dev libbz2-dev build-essential cdo python3-pip curl
pip3 install cdsapi
swift run
swift run openmeteo-api download-ecmwf --run 00
```

Notes: 
- To restart `swift run` press `ctrl+c` and run `swift run` again
- Add `-c release` to swift run to switch to a faster release build