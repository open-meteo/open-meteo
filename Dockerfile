# ================================
# Build image contains swift compiler and libraries like netcdf or eccodes
# ================================
FROM ghcr.io/open-meteo/docker-container-build:latest as build
WORKDIR /build

# First just resolve dependencies.
# This creates a cached layer that can be reused
# as long as your Package.swift/Package.resolved
# files do not change.
COPY ./Package.* ./
RUN swift package resolve

# Copy entire repo into container
COPY . .

# Compile with optimizations
RUN swift build -c release


# ================================
# Run image contains swift runtime libraries, netcdf, eccodes, cdo and cds utilities
# ================================
FROM ghcr.io/open-meteo/docker-container-build:latest

# Create a openmeteo user and group with /app as its home directory
RUN useradd --user-group --create-home --system --skel /dev/null --home-dir /app openmeteo

# Switch to the new home directory
WORKDIR /app

# Copy build artifacts
COPY --from=build --chown=openmeteo:openmeteo /build/.build/release/openmeteo-api /app
RUN mkdir -p /app/Resources
# COPY --from=build --chown=openmeteo:openmeteo /build/Resources /app/Resources
COPY --from=build --chown=openmeteo:openmeteo /build/.build/release/SwiftTimeZoneLookup_SwiftTimeZoneLookup.resources /app/Resources/
COPY --from=build --chown=openmeteo:openmeteo /build/Public /app/Public

# Attach a volumne
RUN mkdir /app/data && chown openmeteo:openmeteo /app/data
VOLUME /app/data

# Ensure all further commands run as the openmeteo user
USER openmeteo:openmeteo

# Start the service when the image is run, default to listening on 8080 in production environment 
ENTRYPOINT ["./openmeteo-api"]
CMD ["serve", "--env", "production", "--hostname", "0.0.0.0", "--port", "8080"]
