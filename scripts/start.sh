#!/usr/bin/env sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-"$HOME/.config"}
XDG_DATA_HOME=${XDG_DATA_HOME:-"$HOME/.local/share"}

PACKAGE_NAME=${PACKAGE_NAME:-forgejo}
DEPLOY_NAME=${DEPLOY_NAME:-deploy-${PACKAGE_NAME}-standalone}
CONFIG_DIR=${CONFIG_DIR:-"$XDG_CONFIG_HOME/$PACKAGE_NAME"}
DEPLOY_DIR=${DEPLOY_DIR:-$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)}
ENV_FILE=${ENV_FILE:-"$CONFIG_DIR/.env"}

if [ ! -f "$ENV_FILE" ]; then
  echo "ERROR: environment file not found: $ENV_FILE" >&2
  exit 1
fi

set -a
. "$ENV_FILE"
set +a

COMPOSE_PROJECT_NAME=${COMPOSE_PROJECT_NAME:-$PACKAGE_NAME}
export COMPOSE_PROJECT_NAME

DATA_DIR=${FORGEJO_DATA_DIR:-"$XDG_DATA_HOME/$PACKAGE_NAME"}
case "$DATA_DIR" in
  /*) DATA_PATH=$DATA_DIR ;;
  *) DATA_PATH=$DEPLOY_DIR/$DATA_DIR ;;
esac

mkdir -p "$DATA_PATH"
export FORGEJO_DATA_DIR="$DATA_PATH"

cd "$DEPLOY_DIR"

podman-compose -f "$DEPLOY_DIR/compose.yaml" -p "$COMPOSE_PROJECT_NAME" up -d
