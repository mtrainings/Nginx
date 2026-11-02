# LAB 10 – Web Application Firewall: attack & defend

> **Story:** PixelShop acquired a second shop – built on a (deliberately) vulnerable codebase: **OWASP Juice Shop**. It can't be fixed before launch, so you put a WAF tier in front of it: **ModSecurity v3 + OWASP Core Rule Set (CRS)**. First you attack, then you defend.

> ⚖️ Only attack systems you own. Everything here runs inside your lab containers.

| | |
|---|---|
| **Duration** | ~45 min (first image pull ≈ 2–3 min) |
| **You edit** | `conf.d/40-juice.conf`, `env/waf/REQUEST-900-EXCLUSION-RULES-BEFORE-CRS.conf` |
| **Solution** | `solutions/LAB10/` (or `./bin/ngx catchup 10`) |

```mermaid
flowchart LR
  A[attacker / client] --> E[edge NGINX<br/>TLS, rate limits]
  E -- juice.localtest.me --> W[WAF tier<br/>NGINX + ModSecurity v3<br/>+ OWASP CRS]
  W --> J[Juice Shop]
  E -. nowaf.localtest.me .-> J
```

**Why a separate WAF tier?** F5 ended support for its ModSecurity module in 2024 and the project moved to OWASP. The maintained `owasp/modsecurity-crs` image ships NGINX + libmodsecurity3 + CRS 4, so you don't have to compile the connector yourself (see *Appendix* for a VM install).

## Step 1 – Start the targets

```bash
docker compose -f env/docker-compose.yml --profile waf up -d
docker compose -f env/docker-compose.yml --profile waf ps
```

Create `env/nginx/conf.d/40-juice.conf`:

```nginx
server {
    listen 80;
    server_name juice.localtest.me nowaf.localtest.me;
    return 301 https://$host$request_uri;
}

# Through the WAF
server {
    listen 443 ssl;
    listen 443 quic;
    http2 on;
    server_name juice.localtest.me;
    include /etc/nginx/snippets/security-headers.conf;

    location / {
        set $waf_upstream http://waf:8080;      # variable = resolved per request,
        proxy_pass $waf_upstream;               # so nginx starts even when the WAF is down
        include /etc/nginx/snippets/proxy-headers.conf;
        proxy_http_version 1.1;
        proxy_set_header Upgrade    $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
    }
}

# Direct - NO WAF (comparison only!)
server {
    listen 443 ssl;
    listen 443 quic;
    http2 on;
    server_name nowaf.localtest.me;

    location / {
        set $juice_upstream http://juice:3000;
        proxy_pass $juice_upstream;
        include /etc/nginx/snippets/proxy-headers.conf;
        proxy_http_version 1.1;
        proxy_set_header Upgrade    $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
    }
}
```

```bash
./bin/ngx reload
curl -s -o /dev/null -w "%{http_code}\n" https://juice.localtest.me/
curl -s -o /dev/null -w "%{http_code}\n" https://nowaf.localtest.me/
```

✅ **Checkpoint:** both `200`. Open `https://juice.localtest.me` in a browser if you can.

## Step 2 – Attack (WAF in DetectionOnly mode)

The WAF starts in `DetectionOnly`: it logs but does not block – always the first phase of a real rollout.

```bash
J=https://juice.localtest.me
N=https://nowaf.localtest.me
code() { curl -s -o /dev/null -w "%{http_code}\n" "$@"; }

# 1. SQL injection in the product search - dumps the user table on the vulnerable app
curl -s --get --data-urlencode "q=qwert')) UNION SELECT id,email,password,'4','5','6','7','8','9' FROM Users--" \
  $N/rest/products/search | head -c 300; echo

# 2. the same request through the WAF
code --get --data-urlencode "q=qwert')) UNION SELECT id,email,password,'4','5','6','7','8','9' FROM Users--" $J/rest/products/search

# 3. XSS, path traversal, scanner user agent
code --get --data-urlencode "q=<script>alert(1)</script>" $J/rest/products/search
code --path-as-is "$J/ftp/../../etc/passwd"
code -A "sqlmap/1.8" $J/
```

✅ **Checkpoint:** the vulnerable app returns e-mails and password hashes 😱. Through the WAF the requests still pass (`200`) – **but** they are logged:

```bash
docker compose -f env/docker-compose.yml logs waf 2>&1 | grep -oE '\[id "[0-9]+"\]|\[msg "[^"]*"\]' | sort | uniq -c | sort -rn | head -15
```

Note the rule IDs (942xxx = SQLi, 941xxx = XSS, 930xxx = path traversal, 913xxx = scanners) and the **anomaly score**.

## Step 3 – Defend: blocking mode

```bash
cd env
MODSEC_RULE_ENGINE=On docker compose --profile waf up -d waf
cd ..
```

Repeat the four attacks against `$J`.

✅ **Checkpoint:** `403` for each attack, while normal browsing (`code $J/`, `code "$J/rest/products/search?q=apple"`) still returns `200`.

**How CRS decides:** every matching rule adds points to an *anomaly score*; the request is blocked when the score reaches the threshold (`ANOMALY_INBOUND=5` = one critical rule). Higher **paranoia levels** (1–4) enable more rules → more protection, more false positives.

## Step 4 – False positives & exclusions

1. Raise the paranoia level and try legitimate-looking traffic:

   ```bash
   cd env
   MODSEC_RULE_ENGINE=On BLOCKING_PARANOIA=2 docker compose --profile waf up -d waf
   cd ..
   code --get --data-urlencode "q=select the best retro radio from the menu" $J/rest/products/search
   code --get --data-urlencode "q=O'Reilly book; drop shipping" $J/rest/products/search
   ```

2. If something legitimate is blocked, find **which rule** did it in the WAF log (`[id "…"]`).
3. Write a **narrow** exclusion in `env/waf/REQUEST-900-EXCLUSION-RULES-BEFORE-CRS.conf` – remove one rule for one argument on one path, never disable the WAF:

   ```apache
   SecRule REQUEST_URI "@beginsWith /rest/products/search" \
       "id:1001,phase:1,pass,nolog,\
        ctl:ruleRemoveTargetById=<RULE_ID>;ARGS:q"
   ```

4. Restart the WAF (from `env/`: `MODSEC_RULE_ENGINE=On BLOCKING_PARANOIA=2 docker compose --profile waf up -d --force-recreate waf`) and re-test both the legitimate request **and** the SQL injection. Discuss the trade-off you just made.

## Step 5 – Defense in depth at the edge

The WAF inspects content; the edge controls volume. Add a login rate limit in the `juice.localtest.me` server (zone `login_rl` from LAB06):

```nginx
    location = /rest/user/login {
        limit_req zone=login_rl burst=3 nodelay;
        set $waf_upstream http://waf:8080;
        proxy_pass $waf_upstream;
        include /etc/nginx/snippets/proxy-headers.conf;
    }
```

```bash
for i in $(seq 1 8); do code -X POST -H 'Content-Type: application/json' \
  -d '{"email":"admin@juice-sh.op","password":"guess'$i'"}' $J/rest/user/login; done
```

✅ **Checkpoint:** a few `401`s (wrong password, from the app), then `429` from the edge.

## Bonus

- Look at the WAF container's NGINX config: `docker compose -f env/docker-compose.yml exec waf sh -c 'nginx -T | grep -i modsecurity'` – find `modsecurity on;` and `modsecurity_rules_file`.
- **OWASP Coraza** is a modern, Go-based WAF engine that runs CRS too. **F5 WAF for NGINX** (formerly NGINX App Protect) is the commercial option for NGINX Plus. Compare.
- Turn on the response body inspection (`ANOMALY_OUTBOUND`) – what could it detect? What does it cost?

## Appendix – ModSecurity on a plain Ubuntu 24.04 VM (no compiling)

```bash
sudo apt install -y nginx libnginx-mod-http-modsecurity modsecurity-crs
sudo cp /etc/modsecurity/modsecurity.conf-recommended /etc/modsecurity/modsecurity.conf
sudo sed -i 's/^SecRuleEngine DetectionOnly/SecRuleEngine On/' /etc/modsecurity/modsecurity.conf
```

`/etc/nginx/modsec/main.conf`:

```apache
Include /etc/modsecurity/modsecurity.conf
Include /usr/share/modsecurity-crs/owasp-crs.load
```

In a server block: `modsecurity on;` and `modsecurity_rules_file /etc/nginx/modsec/main.conf;` → `sudo nginx -t && sudo systemctl reload nginx`. (Package names and paths are the Debian/Ubuntu ones – check `dpkg -L modsecurity-crs` on your release.)

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| `502` on juice.localtest.me | the `waf` profile is not running – `--profile waf up -d` |
| everything returns `403` | paranoia too high / exclusion syntax error – `docker compose logs waf` |
| no rule IDs in the log | the request never reached the WAF (check you used `$J`, not `$N`) |
