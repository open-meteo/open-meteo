# Running Open-Meteo on multiple nodes

Open-Meteo is designed to be run distributed across many servers, data-centers and continents. Due to the amount of data is it recommended to run weather model downloader on different servers and synchronize only the final database to API servers.

The synchronization is using HTTP to keep API servers up to date automatically. In this configuration the API nodes "pull" the Open-Meteo database every couple of minutes from a server. The server implements the S3 file list API, clients pull this list of files and compare it its local files. Any missing or newly modified file will be downloaded from the server via HTTP.

The sync code can be found in [SyncCommand.swift](/Sources/App/Commands/SyncCommand.swift). As a server any S3 compatible endpoint can be used. The integrated S3 server part is in [S3DataController.swift](/Sources/App/Controllers/S3DataController.swift)

## Configuring the Server

A server is typically downloading one or weather models and update the local database in the directories `data/omfile-*`. This server can of course run the API endpoint at the same time. In addition it can be configured to serve the `omfile` database to other API nodes.

Per default, serving the database to clients is disabled. To enable it the following steps are required:

1. Set the environment variable `API_SYNC_APIKEYS=mykey123` for the API service. For the Ubuntu packages this can be set in `/etc/default/openmeteo-api.env`. For Docker, it need to be prepended to the Docker command.

```nginx
upstream vapor {
    server 127.0.0.1:8080 fail_timeout=0;
    keepalive 2048;
}

server {
    server_name myserver.com;

    location /data-internal {
       internal;
       alias /var/lib/openmeteo-api/data;
    }

    location / {
        try_files $uri @proxy;
    }


    location @proxy {
        proxy_pass http://vapor;
        proxy_set_header Connection "";
        proxy_http_version 1.1;
	    proxy_pass_header Server;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_pass_header Server;
        proxy_connect_timeout 3s;
        proxy_read_timeout 10s;
    }
}
```

3. Check the list endpoint https://myserver.com/?list-type=2&delimiter=/&prefix=data/&apikey=mykey123 and confirm that download are working http://myserver.com/data/cmc_gem_gdps/shortwave_radiation/chunk_1430.om?apikey=123 (Note: This given file example my not exist on your machine)


## Configuring the Client

In order to "pull" from a server, the client can execute the `sync` command. In the example below `--repeat-interval` is set to 5 minute, which means that the process will continue to run indefinitely and retry every 5 minutes.

```bash
openmeteo-api sync cmc_gem_gdps,dwd_icon temperature_2m,shortwave_radiation --apikey mykey123 --server https://myserver.com/ --repeat-interval 5
```

With Docker, you can just spawn this command and leave it running in the background.

The Ubuntu packages contain a systemd servive `openmeteo-sync` to start this command. It can be enabled in `/etc/default/openmeteo-api.env` by setting `SYNC_ENABLED=true`, `SYNC_APIKEY=mykey123`, `SYNC_DOMAINS=cmc_gem_gdps,dwd_icon`, `SYNC_VARIABLES=temperature_2m,shortwave_radiation` and `SYNC_REPEAT_INTERVAL=5` followed by a restart with `systemctl restart openmeteo-sync`.


### Syncing a region only

`--bounding-box lat1,lon1,lat2,lon2` keeps only the data around a latitude/longitude box, e.g. `--bounding-box 45,5,48,11`. A grid cell is inside if its coordinate lies in the box. Every chunk of a weather variable file that holds a cell inside the box is copied byte for byte, without decoding it. All other chunks are written empty, which reads as NaN, so the API returns `null` for those chunks, and the file keeps its dimensions, chunking and compression. Chunks are whole, so the data reaches a little beyond the box. Selected chunks separated by gaps of up to 1 MiB share an HTTP range request of up to 8 MiB; a single larger chunk is fetched in one request. Gap bytes are downloaded but discarded, and unselected chunks are written as NaN. The last 8 KiB of each file are prefetched for metadata. Up to eight requests run concurrently per file, and chunks are written serially in file order. A box that reaches beyond the grid of a regional model keeps the cells inside the grid; a box without any cell fails with an error.

`--polygon` selects one or more regions, including regions with holes, using a GeoJSON MultiPolygon **coordinates array** in WGS84 degrees. Positions use `[longitude, latitude]`, unlike the latitude-first `--bounding-box` parameter. Pass the coordinates array only, without a GeoJSON geometry object.

For example, this rectangular boundary covers an illustrative Central Europe region from 5°E to 20°E and 45°N to 55°N. It is an approximate selection area, not an administrative boundary:

```bash
openmeteo-api sync ecmwf_ifs temperature_2m,shortwave_radiation --polygon '[[[[5,45],[20,45],[20,55],[5,55],[5,45]]]]'
```

This rectangle selects the same cells as `--bounding-box 45,5,55,20`. To use a file instead, save the following coordinates to `central-europe.json`:

```json
[
  [
    [[5, 45], [20, 45], [20, 55], [5, 55], [5, 45]]
  ]
]
```

Then replace the inline `--polygon` argument with `--polygon @central-europe.json`. File input is useful for detailed boundaries that would exceed command-line length limits.

- The nesting is polygons → rings → positions. Each position must contain exactly two numbers: longitude and latitude. Altitude is not supported.
- Each ring needs at least four positions and must repeat its first position at the end. The first ring is the exterior; subsequent rings are holes. Exterior rings must run counter-clockwise and holes clockwise, otherwise the command fails with the ring named.
- For an existing GeoJSON MultiPolygon geometry, use its `coordinates` field directly. For a GeoJSON Polygon geometry, wrap its `coordinates` field in one additional array.
- A grid cell is selected when its centre lies inside a polygon and outside its holes. Whole compressed chunks containing selected cells are retained, so downloaded data can extend beyond the boundary. Unselected chunks read as missing data (`null` in the API). A region containing no grid cells fails with an error.
- `--polygon` and `--bounding-box` cannot be combined. Rings must not cross the antimeridian; split such regions into separate polygons.

Static files, `meta.json` and files that are not an array of floating point numbers on the model grid are copied whole. The grid may be followed or preceded by other dimensions, e.g. ensemble members. Files synced with a box or polygon are compared by modification time only, because their size differs from the remote file. The first file that fails stops the model with that error. A file is retried up to 10 times if the remote file changes during the copy or a request times out. A file whose layout does not match the model grid is copied whole, with an info log line.

When changing the box or polygon, use a fresh data directory or remove the previously synced weather files first. Modification times alone cannot detect a changed region. Files containing empty chunks require the updated OM reader.

## Cleanup old data
To automatically cleanup old data, the following cronjobs can be used.

```
# Remove pressure level data after 10 days
0 * * * * find /var/lib/openmeteo-api/data/ -type f -name "chunk_*" -wholename "*hPa*" -mtime +10 -delete

# Remove surface level data after 90 days
5 * * * * find /var/lib/openmeteo-api/data/ -type f -name "chunk_*" -mtime +90 -delete
```
