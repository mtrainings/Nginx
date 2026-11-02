#!/usr/bin/env bash
# Scores the LAB11 break-fix challenge
set -uo pipefail
pass=0; total=8
ok()   { echo "  PASS  $1"; pass=$((pass+1)); }
bad()  { echo "  FAIL  $1"; }
req()  { local host=$1; shift; curl -s --max-time 5 --resolve "$host:80:127.0.0.1" "$@"; }

echo "Break-fix challenge"

# BF1
c=$(req bf1.localtest.me -o /dev/null -w '%{http_code}' http://bf1.localtest.me/images/logo.svg)
[[ $c == 200 ]] && ok "BF1 images" || bad "BF1 images (got $c)"

# BF2
req bf2.localtest.me http://bf2.localtest.me/ | grep -qi '^Host: bf2.localtest.me' \
  && ok "BF2 Host header" || bad "BF2 Host header"

# BF3
h1=$(req bf3.localtest.me -sI http://bf3.localtest.me/)
h2=$(req bf3.localtest.me -sI http://bf3.localtest.me/assets/app.css)
if grep -qi 'x-content-type-options: nosniff' <<<"$h2" && grep -qi 'x-frame-options' <<<"$h2" \
   && grep -qi 'cache-control: public' <<<"$h2" && grep -qi 'x-content-type-options' <<<"$h1"; then
  ok "BF3 security headers"; else bad "BF3 security headers"; fi

# BF4
c=$(head -c 2000000 /dev/zero | req bf4.localtest.me -o /dev/null -w '%{http_code}' --data-binary @- http://bf4.localtest.me/upload)
[[ $c == 200 ]] && ok "BF4 upload 2 MB" || bad "BF4 upload 2 MB (got $c)"

# BF5
req bf5.localtest.me "http://bf5.localtest.me/legacy/hello?x=1" | grep -q 'GET /hello?x=1' \
  && ok "BF5 legacy URLs" || bad "BF5 legacy URLs"

# BF6
sleep 3
okc=0; for i in $(seq 1 10); do
  [[ $(req bf6.localtest.me -o /dev/null -w '%{http_code}' http://bf6.localtest.me/) == 200 ]] && okc=$((okc+1))
done
sleep 3
# flood in parallel - sequential curls can be slower than the allowed rate on slow machines
codes=$(seq 1 60 | xargs -P 20 -I{} curl -s --max-time 5 --resolve bf6.localtest.me:80:127.0.0.1 \
          -o /dev/null -w '%{http_code}\n' http://bf6.localtest.me/)
if [[ $okc -eq 10 ]] && grep -q 429 <<<"$codes" && ! grep -q 503 <<<"$codes"; then
  ok "BF6 rate limiting"; else bad "BF6 rate limiting (burst ok: $okc/10, flood: $(sort <<<"$codes" | uniq -c | tr '\n' ' '))"; fi

# BF7
l=$(req bf7.localtest.me -i -N --max-time 2 \
      -H 'Connection: Upgrade' -H 'Upgrade: websocket' \
      -H 'Sec-WebSocket-Version: 13' -H 'Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==' \
      http://bf7.localtest.me/echo | head -n 1)
grep -q ' 101' <<<"$l" && ok "BF7 WebSocket" || bad "BF7 WebSocket (got: ${l%$'\r'})"

# BF8
b=$(req bf8.localtest.me -L --max-redirs 3 http://bf8.localtest.me/old-path)
c=$(req bf8.localtest.me -o /dev/null -w '%{http_code}' http://bf8.localtest.me/)
[[ $b == "new page" && $c == 200 ]] && ok "BF8 redirects" || bad "BF8 redirects"

echo
echo "Score: $pass / $total"
