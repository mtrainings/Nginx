# LAB 11 – Break-fix challenge 🔧

> **Story:** It's Monday morning. Over the weekend "someone" deployed eight changes to the edge. Production is on fire, the ticket queue is full. You have 45 minutes.

| | |
|---|---|
| **Duration** | 30–45 min (works great in pairs or as a team competition) |
| **You edit** | `env/nginx/conf.d/99-bf-*.conf` |
| **Score** | `./bin/ngx check` |

## Start

```bash
./bin/ngx breakfix      # copies 8 broken configs to env/nginx/conf.d/99-bf-*.conf
./bin/ngx check         # your score - run it as often as you like
```

Each file starts with the ticket text and the expected behaviour. The servers listen on plain HTTP: `bf1.localtest.me` … `bf8.localtest.me`.

## The tickets

| # | Ticket | Hint (only if you are stuck) |
|---|---|---|
| BF1 | Product images under `/images/` return 404 since the last deploy. | Compare the location and the `alias` path character by character. Read `env/logs/error.log`. |
| BF2 | The application generates links with the host name `bf2_app`. | What `Host` header does NGINX send by default? |
| BF3 | Security scan: CSS/JS files are missing `X-Content-Type-Options` and `X-Frame-Options`. | `add_header` inheritance. |
| BF4 | Uploading a 2 MB product photo fails. | What status code do you get? |
| BF5 | **nginx does not reload any more!** Old URLs `/legacy/<path>` must reach the API as `/<path>`. | `./bin/ngx test` tells you exactly what is wrong. `rewrite ... break`. |
| BF6 | Customers get *503 Service Temporarily Unavailable* when they click quickly. | Look at `rate`, `burst` and the status code. |
| BF7 | Live chat on `/echo` fails with HTTP 400. | WebSocket needs two headers and HTTP/1.1. |
| BF8 | Browser: *ERR_TOO_MANY_REDIRECTS* on `/old-path`. | Which location matches `/new-path`? `curl -sI` shows every hop. |

> Tip: start with **BF5** – as long as `nginx -t` fails, none of your other fixes can be reloaded.

## Useful commands

```bash
./bin/ngx test && ./bin/ngx reload
curl -sv http://bf1.localtest.me/images/logo.svg -o /dev/null
tail -f env/logs/error.log
./bin/ngx dump | grep -n -A15 'bf6.localtest.me'
```

## Finish

✅ **Goal:** `Score: 8 / 8`.

Then discuss with your neighbour: which of these bugs would `nginx -t` have caught? Which only a test (`curl`, smoke tests in CI) would catch? How would you prevent each in a real pipeline?

Clean up: `rm env/nginx/conf.d/99-bf-*.conf && ./bin/ngx reload`
