#!/usr/bin/env sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
LIB_FILE="$SCRIPT_DIR/lib.sh"

if [ ! -r "$LIB_FILE" ]; then
  echo "ERROR: cannot continue: required helper script is missing: $LIB_FILE" >&2
  exit 1
fi

# shellcheck disable=SC1090
. "$LIB_FILE"

XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-"$HOME/.config"}
XDG_DATA_HOME=${XDG_DATA_HOME:-"$HOME/.local/share"}

PACKAGE_NAME=${PACKAGE_NAME:-forgejo}
DEPLOY_NAME=${DEPLOY_NAME:-deploy-${PACKAGE_NAME}-standalone}
UNIT_NAME=${UNIT_NAME:-${PACKAGE_NAME}.service}

CONFIG_DIR=${CONFIG_DIR:-"$XDG_CONFIG_HOME/$PACKAGE_NAME"}
DEPLOY_DIR=${DEPLOY_DIR:-"$XDG_DATA_HOME/$DEPLOY_NAME"}
ENV_FILE=${ENV_FILE:-"$CONFIG_DIR/.env"}

check_cmd podman
check_cmd podman-compose
check_cmd systemctl
check_cmd curl

if [ -d "$DEPLOY_DIR" ]; then
  check_ok "deploy directory exists: $DEPLOY_DIR"
else
  check_ng "deploy directory does not exist: $DEPLOY_DIR"
fi

if [ -f "$DEPLOY_DIR/compose.yaml" ]; then
  check_ok "compose file exists: $DEPLOY_DIR/compose.yaml"
else
  check_ng "compose file does not exist: $DEPLOY_DIR/compose.yaml"
fi

if [ -f "$ENV_FILE" ]; then
  if [ -r "$ENV_FILE" ]; then
    check_ok "environment file exists: $ENV_FILE"
    set -a
    # shellcheck disable=SC1090
    . "$ENV_FILE"
    set +a
  else
    check_ng "environment file is not readable: $ENV_FILE"
  fi
else
  check_ng "environment file not found: $ENV_FILE"
fi

COMPOSE_PROJECT_NAME=${COMPOSE_PROJECT_NAME:-$PACKAGE_NAME}
URL=${FORGEJO_ROOT_URL:-http://localhost:3000/}

if podman-compose -f "$DEPLOY_DIR/compose.yaml" -p "$COMPOSE_PROJECT_NAME" ps >/dev/null 2>&1; then
  check_ok "podman-compose ps succeeded"
else
  check_ng "podman-compose ps failed"
fi

if systemctl --user is-enabled --quiet "$UNIT_NAME"; then
  check_ok "$UNIT_NAME is enabled"
else
  check_ng "$UNIT_NAME is not enabled"
fi

if systemctl --user is-active --quiet "$UNIT_NAME"; then
  check_ok "$UNIT_NAME is active"
else
  check_ng "$UNIT_NAME is not active"
fi

if podman container exists "$COMPOSE_PROJECT_NAME"; then
  state=$(podman inspect "$COMPOSE_PROJECT_NAME" --format "{{.State.Status}}" 2>/dev/null || true)
  if [ "$state" = "running" ]; then
    check_ok "$COMPOSE_PROJECT_NAME is running"
  else
    check_ng "$COMPOSE_PROJECT_NAME is not running: $state"
  fi
else
  check_ng "$COMPOSE_PROJECT_NAME container does not exist"
fi

if curl -fsS -L --max-time 10 "$URL" >/dev/null; then
  check_ok "Forgejo HTTP endpoint responded: $URL"
else
  check_ng "Forgejo HTTP endpoint did not respond successfully: $URL"
fi

check_finish
