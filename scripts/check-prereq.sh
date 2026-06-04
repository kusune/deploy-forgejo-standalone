#!/usr/bin/env sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
LIB_FILE="$ROOT_DIR/scripts/lib.sh"

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
DEPLOY_DIR=${DEPLOY_DIR:-"$XDG_DATA_HOME/$DEPLOY_NAME"}
ENV_FILE=${ENV_FILE:-"$CONFIG_DIR/.env"}

check_cmd podman
check_cmd podman-compose
check_cmd systemctl
check_cmd loginctl
check_cmd curl

if podman info 2>/dev/null | awk '/rootless:/ {print $2}' | grep -q '^true$'; then
  check_ok "podman is running rootless"
else
  check_ng "podman rootless check failed"
fi

if systemctl --user status >/dev/null 2>&1; then
  check_ok "systemctl --user is usable"
else
  check_ng "systemctl --user is not usable"
fi

user_name=$(id -un)
if loginctl show-user "$user_name" -p Linger 2>/dev/null | grep -q '^Linger=yes$'; then
  check_ok "linger is enabled"
else
  check_ng "linger is not enabled"
  check_warn "ask the host administrator to run: sudo loginctl enable-linger $user_name"
fi

if grep -q "^$user_name:" /etc/subuid 2>/dev/null; then
  check_ok "/etc/subuid has $user_name entry"
else
  check_ng "/etc/subuid has no $user_name entry"
fi

if grep -q "^$user_name:" /etc/subgid 2>/dev/null; then
  check_ok "/etc/subgid has $user_name entry"
else
  check_ng "/etc/subgid has no $user_name entry"
fi

if [ -f "$ROOT_DIR/.env" ]; then
  check_ok "source environment file exists: $ROOT_DIR/.env"
  validate_env_bind_values_check "$ROOT_DIR/.env" "source environment file"
else
  check_warn "source environment file does not exist: $ROOT_DIR/.env"
  check_warn "deploy will use .env.example only if target environment file does not already exist"
fi

if [ -f "$ENV_FILE" ]; then
  check_ok "target environment file exists: $ENV_FILE"
  validate_env_bind_values_check "$ENV_FILE" "target environment file"
else
  check_warn "target environment file does not exist yet: $ENV_FILE"
fi

check_ok "default config directory: $CONFIG_DIR"
check_ok "default deploy directory: $DEPLOY_DIR"

if [ "$CHECK_FAILED" -eq 0 ]; then
  check_ok "prerequisite check completed"
fi

check_finish
