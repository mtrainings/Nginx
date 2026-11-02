# LAB 06 – Access control, rate limiting & security headers

> **Story:** A penetration test report landed on your desk: the admin panel is open to the world, the login API can be brute-forced, a single client can flood the API, and security headers are missing. Fix all four.

| | |
|---|---|
| **Duration** | ~45 min |
| **You edit** | `conf.d/03-security.conf`, `snippets/security-headers.conf`, `10-shop.conf`, `20-admin.conf`, `30-api.conf` |
| **Solution** | `solutions/LAB06/` (or `./bin/ngx catchup 6`) |

> Make sure `export CURL_CA_BUNDLE=$PWD/env/nginx/certs/ca.crt` is set (LAB05).

## Step 1 – Admin: office network OR password

1. Create a password file (SHA-512 crypt; `htpasswd -B` from `apache2-utils` would give bcrypt):

   ```bash
   printf 'admin:%s\n' "$(openssl passwd -6 'S3cret!')" > env/nginx/auth/admin.htpasswd
   ```

2. In the admin **HTTPS server** (server level, so it protects every location):

   ```nginx
       satisfy any;
       allow 10.0.0.0/8;           # e.g. office VPN
       deny  all;
       auth_basic           "PixelShop Admin";
       auth_basic_user_file /etc/nginx/auth/admin.htpasswd;
   ```

3. Test:

   ```bash
   ./bin/ngx reload
   curl -s -o /dev/null -w "%{http_code}\n" https://admin.localtest.me/                    # 401
   curl -s -o /dev/null -w "%{http_code}\n" -u 'admin:S3cret!' https://admin.localtest.me/  # 200
   ```

4. **Which IP does NGINX see?** `tail -n 3 env/logs/access.log` – it is the Docker gateway (e.g. `172.18.0.1`), not `127.0.0.1`. Add `allow` for that address and reload: now no password is asked. Change `satisfy any` to `satisfy all` – what changes? Revert to `allow 10.0.0.0/8` + `satisfy any` at the end.

> ⚠️ Basic auth sends the password with every request (base64, **not** encrypted) – only ever use it over HTTPS.

## Step 2 – Rate limiting the API

1. `env/nginx/conf.d/03-security.conf` (http level):

   ```nginx
   limit_req_zone  $binary_remote_addr zone=api_rl:10m   rate=5r/s;
   limit_req_zone  $binary_remote_addr zone=login_rl:10m rate=1r/s;
   limit_conn_zone $binary_remote_addr zone=perip:10m;
   limit_req_status  429;
   limit_conn_status 429;
   client_max_body_size 1m;
   ```

2. In the api `location /`:

   ```nginx
           limit_req  zone=api_rl burst=10 nodelay;
           limit_conn perip 20;
   ```

3. And a stricter login endpoint:

   ```nginx
       location = /login {
           limit_req zone=login_rl burst=3;
           proxy_pass http://api_backend;
           include /etc/nginx/snippets/proxy-headers.conf;
       }
   ```

4. Test:

   ```bash
   # 30 requests, 10 at a time - faster than 5 r/s on any machine
   seq 1 30 | xargs -P 10 -I{} curl -s -o /dev/null -w "%{http_code}\n" https://api.localtest.me/ | sort | uniq -c
   time (for i in $(seq 1 5); do curl -s -o /dev/null -w "%{http_code} " https://api.localtest.me/login; done)
   ```

   ✅ **Checkpoint:** roughly 11 × `200` and the rest `429` (burst of 10 + the allowed rate). The login loop is **slowed down** to about one request per second (queued, no `nodelay`) – that's how you throttle brute force without returning errors.

   > A plain `for` loop sends one request after another; on a slow machine every HTTPS handshake takes long enough that you never exceed 5 r/s and see no `429`. Test rate limits with **parallel** requests.

5. Upload limit: `head -c 2000000 /dev/zero | curl -s -o /dev/null -w "%{http_code}\n" --data-binary @- https://api.localtest.me/` → `413`.

## Step 3 – API key check with `auth_request`

`auth_request` asks a subrequest "may this request pass?" – 2xx = yes, 401/403 = no. Usually the subrequest goes to an SSO/OIDC service (e.g. oauth2-proxy); here a tiny check inside NGINX is enough.

Add to `03-security.conf`:

```nginx
map $http_x_api_key $api_key_valid {
    default            0;
    "pk-training-2026" 1;
}
```

and to the api server:

```nginx
    location /reports/ {
        auth_request /_auth;
        proxy_pass http://api_backend;
        include /etc/nginx/snippets/proxy-headers.conf;
    }

    location = /_auth {
        internal;
        if ($api_key_valid = 0) {
            return 401;
        }
        return 204;
    }
```

✅ **Checkpoint:** `/reports/` → 401 without the header, 200 with `-H "X-API-Key: pk-training-2026"`.

## Step 4 – Block a network & trust the right proxy

1. Add a blocklist to `03-security.conf` (the `geo` module is built in – no GeoIP database needed for IP ranges):

   ```nginx
   geo $blocked_net {
       default        0;
       203.0.113.0/24 1;
   }
   ```

2. In the shop HTTPS server:

   ```nginx
       set_real_ip_from  172.16.0.0/12;      # trust X-Forwarded-For only from these proxies
       real_ip_header    X-Forwarded-For;
       real_ip_recursive on;

       if ($blocked_net) {
           return 403;
       }
   ```

3. Pretend you are behind a load balancer that adds `X-Forwarded-For`:

   ```bash
   curl -s -o /dev/null -w "%{http_code}\n" -H "X-Forwarded-For: 198.51.100.7" https://shop.localtest.me/  # 200
   curl -s -o /dev/null -w "%{http_code}\n" -H "X-Forwarded-For: 203.0.113.7" https://shop.localtest.me/   # 403
   ```

   **Discuss:** we trust the whole Docker range, so *anyone* reaching NGINX from there can spoof their IP. In production `set_real_ip_from` must list **only** your real load balancers / CDN ranges.

## Step 5 – Security headers (and the inheritance trap)

1. `env/nginx/snippets/security-headers.conf`:

   ```nginx
   add_header Strict-Transport-Security "max-age=300" always;
   add_header Alt-Svc 'h3=":443"; ma=86400' always;
   add_header X-Content-Type-Options "nosniff" always;
   add_header X-Frame-Options "DENY" always;
   add_header Referrer-Policy "strict-origin-when-cross-origin" always;
   add_header Permissions-Policy "camera=(), microphone=(), geolocation=()" always;
   add_header Content-Security-Policy "default-src 'self'; img-src 'self' data:" always;
   ```

2. Replace the server-level `add_header` lines in the shop with `include /etc/nginx/snippets/security-headers.conf;` and add the same include **inside every location that has its own `add_header`** (`/assets/`, images). Do the same for admin.

✅ **Checkpoint:**

```bash
for u in / /assets/app.js /img/logo.svg; do
  echo "$u: $(curl -sI https://shop.localtest.me$u | grep -ciE 'x-content-type|strict-transport|content-security')"
done
```

prints `3` for every URL. Bonus check: <https://securityheaders.com> logic – which header would you add next?

## Bonus

- Return `444` (close connection, no response) for requests without a `Host` header or for `/wp-login.php` scanners.
- Limit by API key instead of IP: `limit_req_zone $http_x_api_key zone=perkey:10m rate=50r/s;` – what happens to requests without a key? (Empty key = not limited!)
- Country blocking needs the third-party **geoip2** module + MaxMind GeoLite2 database (free account). Sketch the config with `geoip2` + `map` + `return 403`.

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| 503 instead of 429 | `limit_req_status` not set (default is 503) |
| always 401 even with the right password | wrong file path / permissions, or password created with an unsupported hash |
| headers missing on some URLs | `add_header` inheritance – include the snippet in that location |
| everybody is blocked by `geo` | `real_ip_header` trusts a header the client controls |
| `X-Forwarded-For` test in Step 4 has no effect | your Docker network is not in `172.16.0.0/12` (check `tail env/logs/access.log`) – add its range to `set_real_ip_from` |
