#!/usr/bin/env bash
# Creates a local training CA and a certificate for localtest.me + *.localtest.me (LAB05)
set -euo pipefail
OUT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/env/nginx/certs"
mkdir -p "$OUT" && cd "$OUT"

if [[ ! -f ca.crt ]]; then
  openssl req -x509 -new -nodes -newkey rsa:3072 -sha256 -days 365 \
    -keyout ca.key -out ca.crt -subj "/CN=PixelShop Training CA"
fi

openssl req -new -nodes -newkey rsa:2048 \
  -keyout localtest.me.key -out localtest.me.csr -subj "/CN=*.localtest.me"

cat > san.ext <<EOF
basicConstraints=CA:FALSE
keyUsage=digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth
subjectAltName=DNS:localtest.me,DNS:*.localtest.me
EOF

openssl x509 -req -in localtest.me.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out localtest.me.crt -days 90 -sha256 -extfile san.ext
rm -f localtest.me.csr san.ext
chmod 600 ca.key localtest.me.key

echo
echo "Done. Trust the CA for curl in this shell:"
echo "  export CURL_CA_BUNDLE=$OUT/ca.crt"
