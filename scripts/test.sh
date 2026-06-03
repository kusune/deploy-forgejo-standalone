#!/usr/bin/env sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ENV_FILE=${ENV_FILE:-"$ROOT_DIR/.env"}

if [ ! -f "$ENV_FILE" ]; then
  echo "ERROR: environment file not found: $ENV_FILE" >&2
  exit 1
fi

set -a
. "$ENV_FILE"
set +a

URL=${FORGEJO_ROOT_URL:-http://localhost:3000/}

if command -v curl >/dev/null 2>&1; then
  if curl -fsS -L "$URL" >/dev/null; then
    echo "OK: Forgejo HTTP endpoint responded: $URL"
  else
    echo "ERROR: Forgejo HTTP endpoint did not respond successfully: $URL" >&2
    exit 1
  fi
else
  echo "ERROR: curl is not available" >&2
  exit 1
fi
