#!/usr/bin/env sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-"$HOME/.config"}
XDG_DATA_HOME=${XDG_DATA_HOME:-"$HOME/.local/share"}

PACKAGE_NAME=${PACKAGE_NAME:-forgejo}
DEPLOY_NAME=${DEPLOY_NAME:-deploy-${PACKAGE_NAME}-standalone}
UNIT_NAME=${UNIT_NAME:-${PACKAGE_NAME}.service}

CONFIG_DIR=${CONFIG_DIR:-"$XDG_CONFIG_HOME/$PACKAGE_NAME"}
DEPLOY_DIR=${DEPLOY_DIR:-"$XDG_DATA_HOME/$DEPLOY_NAME"}
ENV_FILE=${ENV_FILE:-"$CONFIG_DIR/.env"}

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

check_cmd podman
check_cmd podman-compose
check_cmd systemctl
check_cmd curl

if [ -d "$DEPLOY_DIR" ]; then
  ok "deploy directory exists: $DEPLOY_DIR"
else
  ng "deploy directory does not exist: $DEPLOY_DIR"
fi

if [ -f "$DEPLOY_DIR/compose.yaml" ]; then
  ok "compose file exists: $DEPLOY_DIR/compose.yaml"
else
  ng "compose file does not exist: $DEPLOY_DIR/compose.yaml"
fi

if [ -f "$ENV_FILE" ]; then
  ok "environment file exists: $ENV_FILE"
  set -a
  . "$ENV_FILE"
  set +a
else
  ng "environment file not found: $ENV_FILE"
fi

COMPOSE_PROJECT_NAME=${COMPOSE_PROJECT_NAME:-$PACKAGE_NAME}
URL=${FORGEJO_ROOT_URL:-http://localhost:3000/}

if podman-compose -f "$DEPLOY_DIR/compose.yaml" -p "$COMPOSE_PROJECT_NAME" ps >/dev/null 2>&1; then
  ok "podman-compose ps succeeded"
else
  ng "podman-compose ps failed"
fi

if systemctl --user is-enabled --quiet "$UNIT_NAME"; then
  ok "$UNIT_NAME is enabled"
else
  ng "$UNIT_NAME is not enabled"
fi

if systemctl --user is-active --quiet "$UNIT_NAME"; then
  ok "$UNIT_NAME is active"
else
  ng "$UNIT_NAME is not active"
fi

if podman container exists "$COMPOSE_PROJECT_NAME"; then
  state=$(podman inspect "$COMPOSE_PROJECT_NAME" --format "{{.State.Status}}" 2>/dev/null || true)
  if [ "$state" = "running" ]; then
    ok "$COMPOSE_PROJECT_NAME is running"
  else
    ng "$COMPOSE_PROJECT_NAME is not running: $state"
  fi
else
  ng "$COMPOSE_PROJECT_NAME container does not exist"
fi

if curl -fsS -L --max-time 10 "$URL" >/dev/null; then
  ok "Forgejo HTTP endpoint responded: $URL"
else
  ng "Forgejo HTTP endpoint did not respond successfully: $URL"
fi

exit "$fail"
