# Instructor guide

## Before the course

1. One VM per participant (Ubuntu 24.04, 2 vCPU / 4 GB / 15 GB, Docker + Compose, `jq`, `dnsutils`).
2. Clone the repo on every VM and pre-pull all images – the Juice Shop and WAF images are large:

   ```bash
   chmod +x bin/* && ./bin/prepull.sh
   ```

3. Pin versions for the course in `env/.env` (`NGINX_TAG=1.30.x`, `EDGE_IMAGE=nginx:1.30.x`) and, if you want full reproducibility, the image tags in `env/docker-compose.yml`.
4. Smoke test: `./bin/ngx up`, then `./bin/ngx catchup 10` and `./bin/ngx test` – must be green. Reset with `./bin/ngx catchup 1`.
5. No public DNS in the classroom? `*.localtest.me` will not resolve – add the names to `/etc/hosts` with `tee -a`.

## Suggested schedule (2 days, 9:00–16:00)

| | Day 1 – Core | Day 2 – Security, operations, cloud-native |
|---|---|---|
| 09:00 | Intro, architecture, configuration model | Recap + quiz |
| 09:45 | **LAB01** vhosts & locations | Access control & rate limiting → **LAB06** |
| 10:45 | ☕ | ☕ |
| 11:00 | Reverse proxy → **LAB02** | Logging & monitoring → **LAB07** |
| 12:00 | Load balancing → **LAB03** | Stream (L4) → **LAB08** (short) |
| 12:45 | 🍽 | 🍽 |
| 13:30 | Caching & compression → **LAB04** | Modules & njs → **LAB09** |
| 14:30 | ☕ | WAF → **LAB10** |
| 14:45 | TLS, HTTP/2, HTTP/3, ACME → **LAB05** | ☕ / Containers & Kubernetes (slides + demo) |
| 15:45 | Wrap-up day 1 | **LAB11** break-fix, Q&A, survey |

Bonus tasks are for fast participants – never wait for them. Anyone who falls behind: `./bin/ngx catchup <N>`.

## Teaching notes

- **LAB01** – let people *predict* the location table before testing; it is the most valuable 10 minutes of day 1.
- **LAB02** – whoami makes headers visible; insist on the "`proxy_set_header` / `add_header` inheritance" rule – it comes back in LAB05, LAB06 and BF3.
- **LAB03** – the stale-IP effect after `docker compose start` is intentional; it motivates `resolve` (OSS since 1.27.3). Active health checks (`health_check`) are **NGINX Plus only**.
- **LAB04** – the `STALE` demo (all APIs stopped, shop still answers) is the "wow" moment.
- **LAB05** – `listen ... http2` is deprecated since 1.25.1 – use `http2 on;`. Only one `reuseport` per `address:port`.
- **LAB06** – the gateway-IP discovery (Step 1.4) teaches more than the config itself. Default `limit_req_status` is 503.
- **LAB08** – Step 2 (inconsistent reads) is a deliberate failure: LB ≠ replication.
- **LAB09** – the module build needs internet access to nginx.org and GitHub (~3–5 min). Pre-build `pixelshop/edge:modules` on the VMs if the network is slow.
- **LAB10** – check the WAF log output format on the image version you pinned; rule IDs can differ slightly between CRS releases.

## LAB11 – solutions

Full fixed configs: `solutions/LAB11/`.

| # | Root cause | Fix |
|---|---|---|
| BF1 | `alias /srv/www/shop/img` without trailing slash → `/srv/www/shop/imglogo.svg` | `alias /srv/www/shop/img/;` |
| BF2 | default `proxy_set_header Host $proxy_host` = upstream name | `proxy_set_header Host $host;` |
| BF3 | location with its own `add_header` inherits none from server | repeat headers (or a snippet) in the location |
| BF4 | `client_max_body_size 512k` → 413 | `client_max_body_size 5m;` |
| BF5 | `proxy_pass` with URI inside a regex location → `nginx -t` fails | prefix location + `rewrite ^/legacy/(.*)$ /$1 break;` |
| BF6 | `rate=1r/m`, no burst, status 503 | e.g. `rate=5r/s`, `burst=10 nodelay`, `limit_req_status 429` |
| BF7 | Upgrade/Connection not forwarded, HTTP/1.0 to upstream | `proxy_http_version 1.1` + `Upgrade` / `Connection` headers |
| BF8 | `rewrite ^ /new-path` in `location /` also matches `/new-path` | exact locations for `/old-path` and `/new-path` |
