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
CONFIG_DIR=${CONFIG_DIR:-"$XDG_CONFIG_HOME/$PACKAGE_NAME"}
DEPLOY_DIR=${DEPLOY_DIR:-$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)}
ENV_FILE=${ENV_FILE:-"$CONFIG_DIR/.env"}

load_env_or_exit "$ENV_FILE"

COMPOSE_PROJECT_NAME=${COMPOSE_PROJECT_NAME:-$PACKAGE_NAME}
export COMPOSE_PROJECT_NAME

DATA_PATH=$(resolve_forgejo_data_path)
export FORGEJO_DATA_DIR="$DATA_PATH"

cd "$DEPLOY_DIR"

podman-compose -f "$DEPLOY_DIR/compose.yaml" -p "$COMPOSE_PROJECT_NAME" down
