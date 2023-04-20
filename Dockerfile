# ================================
# Build image
# ================================
FROM swift:5.8.0-jammy as build
WORKDIR /build

# First just resolve dependencies.
# This creates a cached layer that can be reused
# as long as your Package.swift/Package.resolved
# files do not change.
COPY ./Package.* ./
RUN swift package resolve

# Copy entire repo into container
COPY . .

ENV DEBIAN_FRONTEND=noninteractive
RUN apt update && apt install -y wget gpg
RUN wget -qO - https://patrick-zippenfenig.github.io/ecCodes-ubuntu/public.key | gpg --dearmor -o /etc/apt/trusted.gpg.d/ecCodes-ubuntu.gpg
RUN echo "deb https://patrick-zippenfenig.github.io/ecCodes-ubuntu/ jammy main" > /etc/apt/sources.list.d/ecCodes-ubuntu.list
RUN apt update && apt install -y libnetcdf-dev openmeteo-eccodes libbz2-dev build-essential && rm -rf /var/lib/apt/lists/*

# Compile with optimizations
RUN swift build --enable-test-discovery -c release

# ================================
# Run image
# ================================
FROM swift:5.8.0-jammy-slim

# Create a vapor user and group with /app as its home directory
RUN useradd --user-group --create-home --system --skel /dev/null --home-dir /app vapor


ENV DEBIAN_FRONTEND=noninteractive
RUN apt update && apt install -y wget gpg
RUN wget -qO - https://patrick-zippenfenig.github.io/ecCodes-ubuntu/public.key | gpg --dearmor -o /etc/apt/trusted.gpg.d/ecCodes-ubuntu.gpg
RUN echo "deb https://patrick-zippenfenig.github.io/ecCodes-ubuntu/ jammy main" > /etc/apt/sources.list.d/ecCodes-ubuntu.list
RUN apt update && apt install -y libnetcdf19 openmeteo-eccodes bzip2 cdo curl python3-pip && rm -rf /var/lib/apt/lists/*
RUN pip3 install cdsapi

# Switch to the new home directory
WORKDIR /app

# Copy build artifacts
COPY --from=build --chown=vapor:vapor /build/.build/release /app
RUN mkdir -p /app/Resources
# COPY --from=build --chown=vapor:vapor /build/Resources /app/Resources
COPY --from=build --chown=vapor:vapor /build/.build/release/SwiftTimeZoneLookup_SwiftTimeZoneLookup.resources /app/Resources/
COPY --from=build --chown=vapor:vapor /build/Public /app/Public

# Ensure all further commands run as the vapor user
USER vapor:vapor

# Start the Vapor service when the image is run, default to listening on 8080 in production environment 
ENTRYPOINT ["./openmeteo-api"]
CMD ["serve", "--env", "production", "--hostname", "0.0.0.0", "--port", "8080"]
