#!/usr/bin/env sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ENV_FILE=${ENV_FILE:-"$ROOT_DIR/.env"}

fail=0

ok() {
  printf '[OK] %s\n' "$*"
}

ng() {
  printf '[NG] %s\n' "$*" >&2
  fail=1
}

check_cmd() {
  if command -v "$1" >/dev/null 2>&1; then
    ok "$1 found"
  else
    ng "$1 not found"
  fi
}

resolve_path() {
  case "$1" in
    /*) printf '%s\n' "$1" ;;
    *) printf '%s\n' "$ROOT_DIR/$1" ;;
  esac
}

check_container() {
  name="$1"

  if ! podman container exists "$name"; then
    ng "$name container does not exist"
    return
  fi

  state=$(podman inspect "$name" --format "{{.State.Status}}" 2>/dev/null || true)

  if [ "$state" = "running" ]; then
    ok "$name is running"
  else
    ng "$name is not running: $state"
  fi
}

check_cmd podman
check_cmd podman-compose
check_cmd systemctl
check_cmd curl

if [ ! -f "$ENV_FILE" ]; then
  ng "environment file not found: $ENV_FILE"
else
  set -a
  . "$ENV_FILE"
  set +a
fi

DATA_DIR=${FORGEJO_DATA_DIR:-${HOME}/.local/share/forgejo}
DATA_PATH=$(resolve_path "$DATA_DIR")
export FORGEJO_DATA_DIR="$DATA_PATH"

CONTAINER_NAME=${COMPOSE_PROJECT_NAME:-forgejo}
URL=${FORGEJO_ROOT_URL:-http://localhost:3000/}

cd "$ROOT_DIR"

if podman-compose -f "$ROOT_DIR/compose.yaml" config >/dev/null 2>&1; then
  ok "podman-compose config is valid"
else
  ng "podman-compose config failed"
fi

if systemctl --user is-enabled --quiet forgejo.service; then
  ok "forgejo.service is enabled"
else
  ng "forgejo.service is not enabled"
fi

if systemctl --user is-active --quiet forgejo.service; then
  ok "forgejo.service is active"
else
  ng "forgejo.service is not active"
fi

check_container "$CONTAINER_NAME"

if curl -fsS -L --max-time 10 "$URL" >/dev/null; then
  ok "Forgejo HTTP endpoint responded: $URL"
else
  ng "Forgejo HTTP endpoint did not respond successfully: $URL"
fi

exit "$fail"
