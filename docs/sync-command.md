# Running Open-Meteo on multiple nodes

Open-Meteo is designed to be run distributed across many servers, datacenters and even continents. Due to the amount of data is it recommended to run weather model downloader on different servers and synchronize only the final database to API servers.

The synchronization is using HTTP to keep API servers up to date automatically. In this configuration the API nodes "pull" the `omfile` database every couple of seconds from a server. The server implements a file listing HTTP action, clients pull this list of files and compare it its local files. Any missing or newly modified file will be downloaded from the server via HTTP.

The entire code can be found in [SyncController.swift](/Sources/App/Controllers/SyncController.swift).

## Configuring the Server

A server is typically downloading one or weather models and update the local database in the directories `data/omfile-*`. This server can of course run the API endpoint at the same time. In addition it can be configured to serve the `omfile` database to other API nodes.

Per default, serving the database to clients is disabled. To enable it the following steps are required:

1. Set the environment variable `API_SYNC_APIKEYS=mykey123` for the API service. For the Ubuntu packages this can be set in `/etc/default/openmeteo-api.env`. For Docker, it need to be prepended to the Docker command.

2. You need an nginx server running in front of the API instance which enables the NGINX sendfile feature and the location `/data` needs to be mapped to the open-meteo data directory. The configuration could look like this:

```nginx
upstream vapor {
        server 127.0.0.1:8080 fail_timeout=0;
        keepalive 2048;
}

upstream gwsocket {
     server 127.0.0.1:7890;
 }

server {
    server_name myserver.com;

    location /data {
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

You can check the configuration by calling the list endpoint: https://myserver.com/sync/list?directories=omfile-*&apikey=mykey123

And to confirm that the NGINX sendfile download is working, try to download a file http://myserver.com/sync/download?file=omfile-icon/wind_v_component_120m_1854.om&apikey=mykey123 (Note: This given file example my not exist on your machine)


## Configuring the Client

In order to "pull" from from a server, the client can execute the `sync` command. In the example below `--repeat-interval` is set to 10 seconds, which means that the process will continue to run indefinitely and retry every 10 seconds.

```bash
openmeteo-api sync omfile-* --apikey mykey123 --server https://myserver.com/ --repeat-interval 10
```

With Docker, you can just spawn this command and leave it running in the background.

The Ubuntu packages contain a systemd servive `openmeteo-sync` to start this command. It can be enabled in `/etc/default/openmeteo-api.env` by setting `SYNC_ENABLED=true`, `SYNC_APIKEY=mykey123`, `SYNC_DOMAINS=omfile-*` and `SYNC_REPEAT_INTERVAL=10` followed by a restart with `systemctl restart openmeteo-sync`.