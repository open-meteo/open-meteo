# SARAH-3 archive correction

`correct-eumetsat-sarah` repairs the scan-time alignment described in
[issue #2173](https://github.com/open-meteo/open-meteo/issues/2173).
It reads the legacy `shortwave_radiation` and `direct_radiation` directories,
undoes their solar-geometry averaging, shifts the output label by +30 minutes,
and averages again with scan offset minus 0.5 hours. It writes sibling
`shortwave_radiation_corrected` and `direct_radiation_corrected` directories.

```sh
.build/release/openmeteo-api correct-eumetsat-sarah \
  /var/lib/openmeteo-api/data/eumetsat_sarah3_30min --concurrent 8
```

The auxiliary NetCDF is read automatically from
`\(domain.downloadDirectory)/AuxilaryData_SARAH-3.nc`, the same path used by the
downloader. Both `time_difference_MVIRI` and `time_difference_SEVIRI`
are required. The choice depends on the **source** date, switching on 2006-01-01.
The `static/HSURF.om` and `static/meta.json` files do not contain these offsets.

For a trial, add `--variables shortwave_radiation --file chunk_2965.om`.
Neighbouring files are still read. Omit `--file` to process all years and chunks.
Build in release mode for the full archive.

## Reading corrected data

The forecast API exposes both files under their stored names for `models=eumetsat_sarah3`:

```text
/v1/forecast?latitude=50.8&longitude=4.35&models=eumetsat_sarah3&hourly=shortwave_radiation,shortwave_radiation_corrected,direct_radiation,direct_radiation_corrected&temporal_resolution=native
```

The `_corrected` fields read the corresponding corrected directories and return
W/m². Original fields and their derived variables continue to use the original
archive. Missing corrected coverage stays missing; it does not fall back to
uncorrected radiation. Downloads still populate only the original variables.
JSON/CSV retain the `_corrected` names; FlatBuffers uses the existing shortwave
and direct radiation identifiers for these fields.

## Throughput

`--concurrent` / `-c` controls spatial workers (default: CPU count, capped at 8).
Workers read/decompress and correct independent x/y tiles in parallel. A single
writer consumes tiles in file order, overlapping compression/writes with workers.
The number of outstanding tiles, including completed tiles awaiting earlier ones,
is bounded. The worker count is reduced if estimated tile buffers exceed 512 MiB;
mapped files, solar caches and OM lookup tables are additional memory.

Time-dependent solar geometry is calculated once per file and shared by workers.
Location geometry and scan offsets are reused, and tiles outside the satellite
footprint or containing only NaNs skip solar calculations.

Start with `--concurrent 4` or `8`, then compare timings on your storage. Each
completed file logs elapsed tile-processing time, summed worker read/decode and
solar time, and serial compression/write time. Worker times overlap and therefore
can exceed elapsed time. If compression/write dominates, more spatial workers
will have limited benefit. Separate processes with different `--file` selections
can also parallelise compression, at the cost of more memory and competing disk
I/O. Those processes must write distinct output files. Use `--concurrent 1` for a
serial comparison; completed outputs are skipped, so compare fresh output paths.

A reproducible CPU-only benchmark (excluding disk and compression) is available:

```sh
SARAH_CORRECTION_BENCHMARK=1 swift test -c release --filter SarahCorrectionBenchmark
```

It compares uncached serial, cached serial, and eight cached workers over 768
locations and a leap year, checking that all configurations produce identical
checksums. Use the archive timing logs to assess end-to-end throughput.

## Storage and restart behaviour

- Freeze source files for the duration of a run. Do not mix already corrected
  data with the legacy input. This command does not change live ingestion or
  switch the API to the corrected variables.
- Budget roughly another archive's worth of disk space; compression sizes can
  change. Sources are never overwritten.
- Files retain their time ranges and basenames. The previous source timestep
  supplies the first output timestep across chunk and year boundaries. Missing
  source coverage stays NaN. A trailing chunk preserves the final shifted sample;
  its remaining uncovered timesteps are NaN.
- Overlapping source coverage prefers yearly files, with the target's own source
  taking precedence. Input and output are 3D `[y,x,time]` OM files, preserving
  the source's compression and scale.
- Each file is written to
  `.partial`, finalised, synced, reopened to check dimensions, then atomically
  renamed. Rerunning skips completed files and restarts the interrupted file.
  Resume granularity is one file, not one spatial chunk.
- Decompression and writing use source-aligned spatial chunks and their full time
  series, avoiding repeated decoding of overlapping temporal chunks. Buffers do
  not scale with the full spatial grid. Two full-grid offset arrays, shared solar geometry, mapped input
  files and OM lookup tables add overhead. Oversized spatial tiles are rejected
  above 128 MiB per input buffer; ordinary yearly chunks are much smaller.

## Accuracy limits

The legacy archive is quantised. Its conversion also clipped low-sun values and
occasionally filled missing/sunset observations using previous clearness. Those
operations cannot be reversed exactly. This tool inverts the geometric scaling
where it exists, retains zeros, and leaves missing or unrecoverable values NaN.
It reproduces daily backfill resets when re-averaging. Recovering observations
lost to clipping requires downloading the original satellite data again.

Validate a trial against station data or freshly converted satellite samples
before switching the API's archive. The command checks the output container
before publication but does not reread all 5.3 TB for a second decompression pass.
