#!/bin/sh
set -eu

engine="${CONTAINER_ENGINE:-podman}"
image="${PLAYWRIGHT_IMAGE:-mcr.microsoft.com/playwright:v1.61.1-noble}"
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

exec "$engine" run --rm \
  --mount "type=bind,source=${root},target=/work" \
  --mount "type=tmpfs,destination=/work/node_modules" \
  -e "CI=${CI:-}" \
  -e PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 \
  -w /work \
  "$image" \
  sh -c 'npm ci --no-audit --no-fund && node node_modules/@playwright/test/cli.js test "$@"' sh "$@"
