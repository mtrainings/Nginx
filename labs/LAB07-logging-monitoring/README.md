# LAB 07 – Logging, request tracing & monitoring

> **Story:** At 3 a.m. the API was slow and nobody could tell why. The CTO wants structured logs you can query, a request ID to follow a request across services, metrics in Prometheus, and a traffic dashboard for the business.

| | |
|---|---|
| **Duration** | ~40 min |
| **You edit** | `conf.d/02-logging.conf`, `conf.d/90-status.conf`, `30-api.conf`, `20-admin.conf`, `snippets/proxy-headers.conf` |
| **Solution** | `solutions/LAB07/` (or `./bin/ngx catchup 7`) |
| **Tools** | `jq` (`sudo apt install -y jq`) |

## Step 1 – JSON access log

`env/nginx/conf.d/02-logging.conf`:

```nginx
log_format json escape=json '{'
    '"time":"$time_iso8601",'
    '"request_id":"$request_id",'
    '"remote_addr":"$remote_addr",'
    '"host":"$host",'
    '"method":"$request_method",'
    '"uri":"$request_uri",'
    '"status":$status,'
    '"bytes":$body_bytes_sent,'
    '"rt":$request_time,'
    '"upstream":"$upstream_addr",'
    '"urt":"$upstream_response_time",'
    '"cache":"$upstream_cache_status",'
    '"ua":"$http_user_agent"'
'}';

map $request_uri $loggable {
    ~^/health  0;
    default    1;
}
```

In the api HTTPS server (server level):

```nginx
    access_log /var/log/nginx/api.json.log json if=$loggable;
```

Generate traffic and query it:

```bash
./bin/ngx reload
for i in $(seq 1 30); do curl -s -o /dev/null "https://api.localtest.me/?wait=$((RANDOM % 3))00ms"; done
curl -s -o /dev/null https://api.localtest.me/catalog/

jq -r '.status' env/logs/api.json.log | sort | uniq -c                    # status distribution
jq -r '.upstream' env/logs/api.json.log | sort | uniq -c                  # which instance served
jq -s 'sort_by(.rt) | reverse | .[0:3] | .[] | {uri, rt, upstream}' env/logs/api.json.log   # slowest
```

✅ **Checkpoint:** valid JSON lines; `rt` = total time at the edge, `urt` = time spent waiting for the backend. If `rt` ≫ `urt` the problem is between client and edge.

## Step 2 – Request ID end-to-end

1. Add to `snippets/proxy-headers.conf`: `proxy_set_header X-Request-ID $request_id;`
2. In the api server: `add_header X-Request-ID $request_id always;` (also add it inside `/catalog/`, which has its own `add_header` – remember LAB06!)

```bash
curl -si https://api.localtest.me/ | grep -iE '^x-request-id|X-Request-Id:'
```

✅ **Checkpoint:** the same ID appears in the response header, in the backend's view of the request (whoami prints `X-Request-Id`) and in `api.json.log`. Search for it: `grep <id> env/logs/api.json.log`.

## Step 3 – Error log levels

```bash
tail -n 5 env/logs/error.log
```

Temporarily set `error_log /var/log/nginx/api.error.log info;` in the api server and stop an API container – what extra details appear? (`debug` level needs the `nginx-debug` binary, which the official image also ships.)

## Step 4 – Metrics: stub_status + Prometheus exporter

1. `env/nginx/conf.d/90-status.conf`:

   ```nginx
   server {
       listen 8080;
       server_name _;
       access_log off;

       location = /stub_status {
           stub_status;
           allow 127.0.0.1;
           allow 172.16.0.0/12;
           allow 192.168.0.0/16;
           deny  all;
       }
   }
   ```

2. ```bash
   ./bin/ngx reload
   curl -s http://localhost:8080/stub_status
   docker compose -f env/docker-compose.yml --profile monitoring up -d exporter
   curl -s http://localhost:9113/metrics | grep -E '^nginx_(connections|http_requests)'
   ```

✅ **Checkpoint:** `Active connections: …` and the same numbers as Prometheus metrics. Run `hey` from LAB03 and watch `nginx_connections_active` change.

> Per-upstream / per-status metrics need NGINX Plus (API) or an exporter that parses logs – or OpenTelemetry (`ngx_otel_module` is packaged by nginx.org).

## Step 5 – Traffic dashboard with GoAccess

The main `access.log` uses the standard `combined` format, which GoAccess understands:

```bash
docker run --rm -v "$PWD/env/logs:/logs:ro" -v "$PWD/env/www/reports:/out" \
  allinurl/goaccess /logs/access.log --log-format=COMBINED -o /out/goaccess.html
```

Expose it on the (protected) admin site – in the admin HTTPS server:

```nginx
    location /reports/ {
        alias /srv/www/reports/;
        index goaccess.html;
    }
```

✅ **Checkpoint:** `https://admin.localtest.me/reports/` (user `admin`) shows the dashboard. In a browser trust `ca.crt` first, or use `curl -u 'admin:S3cret!' ... -o report.html`.

## Bonus

- Log only errors and slow requests from the shop: `map "$status:$request_time" $interesting { ~^[45] 1; ~:[1-9] 1; default 0; }`
- Buffered logging: `access_log ... buffer=64k flush=5s;` – trade-off?
- Ship logs to syslog: `access_log syslog:server=logs.example.com:514,tag=edge json;`
- Log rotation outside Docker: `logrotate` + `nginx -s reopen` (or `kill -USR1`). Why is it not needed when logging to stdout in containers?

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| `unknown log format "json"` | `log_format` must be defined (file order!) before it is used |
| `jq: parse error` | a line written before you switched to JSON – `> env/logs/api.json.log` to truncate |
| exporter shows `nginx_up 0` | 8080/stub_status not reachable from the exporter container (`allow` list) |
