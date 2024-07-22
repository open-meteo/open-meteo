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
brew install netcdf cdo bzip2
open Package.swift
# `swift run` works as well
```


### Develop on Linux natively:

It is easiest to use ubuntu 22.04 since this is the only Linux where swift 5.8+ is supported natively.
```bash
git clone https://github.com/open-meteo/open-meteo.git
cd open-meteo

# Install the swift compiler as pointed out in the Vapor development guide
sudo apt install libnetcdf-dev libeccodes-dev libbz2-dev build-essential cdo curl
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
