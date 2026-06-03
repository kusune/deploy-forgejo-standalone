#!/usr/bin/env sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ENV_FILE=${ENV_FILE:-"$ROOT_DIR/.env"}

fail=0

info() {
  printf '%s\n' "$*"
}

warn() {
  printf 'WARN: %s\n' "$*" >&2
}

err() {
  printf 'ERROR: %s\n' "$*" >&2
  fail=1
}

resolve_path() {
  case "$1" in
    /*) printf '%s\n' "$1" ;;
    *) printf '%s\n' "$ROOT_DIR/$1" ;;
  esac
}

if [ ! -f "$ENV_FILE" ]; then
  err "environment file not found: $ENV_FILE"
  warn "copy .env.example to .env and edit it"
else
  info "OK: environment file exists: $ENV_FILE"
fi

if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  info "OK: docker compose is available"
elif command -v podman-compose >/dev/null 2>&1; then
  info "OK: podman-compose is available"
elif command -v podman >/dev/null 2>&1 && podman compose version >/dev/null 2>&1; then
  info "OK: podman compose is available"
else
  err "no supported compose command found"
  warn "need one of: docker compose, podman-compose, podman compose"
fi

if [ -f "$ENV_FILE" ]; then
  set -a
  . "$ENV_FILE"
  set +a

  DATA_DIR=${FORGEJO_DATA_DIR:-${HOME}/.local/share/forgejo}
  DATA_PATH=$(resolve_path "$DATA_DIR")

  if [ -e "$DATA_PATH" ]; then
    if [ -d "$DATA_PATH" ]; then
      info "OK: data directory exists: $DATA_PATH"
    else
      err "data path exists but is not a directory: $DATA_PATH"
    fi
  else
    info "OK: data directory does not exist yet: $DATA_PATH"
  fi
fi

if [ "$fail" -ne 0 ]; then
  exit 1
fi

info "prerequisite check completed"
