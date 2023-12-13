# Running Open-Meteo on multiple nodes

Open-Meteo is designed to be run distributed across many servers, data-centers and continents. Due to the amount of data is it recommended to run weather model downloader on different servers and synchronize only the final database to API servers.

The synchronization is using HTTP to keep API servers up to date automatically. In this configuration the API nodes "pull" the Open-Meteo database every couple of minutes from a server. The server implements the S3 file list API, clients pull this list of files and compare it its local files. Any missing or newly modified file will be downloaded from the server via HTTP.

The sync code can be found in [SyncCommand.swift](/Sources/App/Commands/SyncCommand.swift). As a server any S3 compatible endpoint can be used. The integrated S3 server part is in [S3DataController.swift](/Sources/App/Controllers/S3DataController.swift)

## Configuring the Server

A server is typically downloading one or weather models and update the local database in the directories `data/omfile-*`. This server can of course run the API endpoint at the same time. In addition it can be configured to serve the `omfile` database to other API nodes.

Per default, serving the database to clients is disabled. To enable it the following steps are required:

1. Set the environment variable `API_SYNC_APIKEYS=mykey123` for the API service. For the Ubuntu packages this can be set in `/etc/default/openmeteo-api.env`. For Docker, it need to be prepended to the Docker command.

2. (OPTIONAL) You can use an nginx server running in front of the API instance which enables the NGINX sendfile feature. This is only recommended for large deployments! The location `/data-internal` needs to be mapped to the open-meteo data directory and the API server started with `NGINX_SENDFILE_PREFIX=data-internal`. IF `NGINX_SENDFILE_PREFIX` is not set, the Open-Meteo API server will send the file directly. The configuration could look like this:

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
