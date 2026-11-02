#!/usr/bin/env bash
# Instructor: run once per VM before the course - pulls every image used in the labs
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../env"
docker compose --profile '*' pull
docker pull nginx:stable
docker pull redis:7-alpine
echo "All images pulled."
