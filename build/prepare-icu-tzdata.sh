#!/usr/bin/env bash
set -euo pipefail

# ICU's little-endian resources support the production x86_64 and arm64 targets.
# Update the version, immutable commit and checksums together.
version=2026f
revision=6eac2f4d349d9f4a0825103bb41845d8e5ab7add
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
destination=${1:?Usage: prepare-icu-tzdata.sh DESTINATION}
mkdir -p "$destination"
staging=$(mktemp -d)
trap 'rm -rf "$staging"' EXIT

for resource in zoneinfo64 windowsZones timezoneTypes metaZones; do
    curl --fail --silent --show-error --location --retry 3 \
        "https://raw.githubusercontent.com/unicode-org/icu-data/$revision/tzdata/icunew/$version/44/le/$resource.res" \
        --output "$staging/$resource.res"
done
(cd "$staging" && sha256sum --check "$script_dir/icu-tzdata.sha256")
install -m 644 "$staging/"*.res "$destination/"
printf '%s\n' "$version" > "$destination/version"
