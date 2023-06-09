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

It is easiest to use ubuntu 22.04 since this is the only Linux where swift 5.6+ is supported natively.
```bash
git clone https://github.com/open-meteo/open-meteo.git
cd open-meteo

# Install the swift compiler as pointed out in the Vapor development guide
sudo apt install libnetcdf-dev libeccodes-dev libbz2-dev build-essential cdo python3-pip curl
sudo apt-get install binutils git gnupg2 libc6-dev libcurl4-openssl-dev libedit2 libgcc-9-dev libpython3.8 \
  libsqlite3-0 libstdc++-9-dev libxml2-dev libz3-dev pkg-config tzdata unzip zlib1g-dev
sudo apt install libbz2-dev libz-dev

pip3 install cdsapi
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
