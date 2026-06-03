#!/usr/bin/env sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ENV_FILE=${ENV_FILE:-"$ROOT_DIR/.env"}

if [ ! -f "$ENV_FILE" ]; then
  echo "ERROR: environment file not found: $ENV_FILE" >&2
  echo "Hint: cp .env.example .env" >&2
  exit 1
fi

set -a
. "$ENV_FILE"
set +a

DATA_DIR=${FORGEJO_DATA_DIR:-${HOME}/.local/share/forgejo}
case "$DATA_DIR" in
  /*) DATA_PATH=$DATA_DIR ;;
  *) DATA_PATH=$ROOT_DIR/$DATA_DIR ;;
esac

mkdir -p "$DATA_PATH"

# Pass the resolved absolute data path to compose.
export FORGEJO_DATA_DIR="$DATA_PATH"

cd "$ROOT_DIR"

if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  docker compose -f "$ROOT_DIR/compose.yaml" up -d
elif command -v podman-compose >/dev/null 2>&1; then
  podman-compose -f "$ROOT_DIR/compose.yaml" up -d
elif command -v podman >/dev/null 2>&1 && podman compose version >/dev/null 2>&1; then
  podman compose -f "$ROOT_DIR/compose.yaml" up -d
else
  echo "ERROR: no supported compose command found" >&2
  echo "Need one of: docker compose, podman-compose, podman compose" >&2
  exit 1
fi
