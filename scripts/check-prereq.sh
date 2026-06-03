#!/usr/bin/env sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-"$HOME/.config"}
XDG_DATA_HOME=${XDG_DATA_HOME:-"$HOME/.local/share"}

PACKAGE_NAME=${PACKAGE_NAME:-forgejo}
DEPLOY_NAME=${DEPLOY_NAME:-deploy-${PACKAGE_NAME}-standalone}

CONFIG_DIR=${CONFIG_DIR:-"$XDG_CONFIG_HOME/$PACKAGE_NAME"}
DEPLOY_DIR=${DEPLOY_DIR:-"$XDG_DATA_HOME/$DEPLOY_NAME"}
ENV_FILE=${ENV_FILE:-"$CONFIG_DIR/.env"}

fail=0

info() {
  printf 'OK: %s\n' "$*"
}

warn() {
  printf 'WARN: %s\n' "$*" >&2
}

err() {
  printf 'ERROR: %s\n' "$*" >&2
  fail=1
}

need_cmd() {
  if command -v "$1" >/dev/null 2>&1; then
    info "$1 found: $(command -v "$1")"
  else
    err "$1 not found"
  fi
}

validate_bind_ip_literal() {
  name=$1
  value=$2
  label=$3

  if [ -z "$value" ]; then
    err "$label: $name is empty"
    return
  fi

  case "$value" in
    *[!0123456789abcdefABCDEF:.%]*)
      err "$label: $name must be an IP address for Podman port binding, not a hostname: $value"
      return
      ;;
    *[g-zG-Z]*)
      err "$label: $name looks like a hostname, but Podman port binding requires an IP address: $value"
      return
      ;;
  esac
}

validate_env_file() {
  file=$1
  label=$2

  if [ ! -f "$file" ]; then
    return
  fi

  # shellcheck disable=SC1090
  . "$file"

  validate_bind_ip_literal FORGEJO_HTTP_HOST "${FORGEJO_HTTP_HOST:-}" "$label"
  validate_bind_ip_literal FORGEJO_SSH_HOST "${FORGEJO_SSH_HOST:-}" "$label"

  if [ -n "${FORGEJO_ROOT_URL:-}" ]; then
    info "$label ROOT_URL: $FORGEJO_ROOT_URL"
  fi
}

need_cmd podman
need_cmd podman-compose
need_cmd systemctl
need_cmd loginctl
need_cmd curl

if podman info 2>/dev/null | awk '/rootless:/ {print $2}' | grep -q '^true$'; then
  info "podman is running rootless"
else
  err "podman rootless check failed"
fi

if systemctl --user status >/dev/null 2>&1; then
  info "systemctl --user is usable"
else
  err "systemctl --user is not usable"
fi

user_name=$(id -un)
if loginctl show-user "$user_name" -p Linger 2>/dev/null | grep -q '^Linger=yes$'; then
  info "linger is enabled"
else
  err "linger is not enabled"
  warn "ask the host administrator to run: sudo loginctl enable-linger $user_name"
fi

if grep -q "^$user_name:" /etc/subuid 2>/dev/null; then
  info "/etc/subuid has $user_name entry"
else
  err "/etc/subuid has no $user_name entry"
fi

if grep -q "^$user_name:" /etc/subgid 2>/dev/null; then
  info "/etc/subgid has $user_name entry"
else
  err "/etc/subgid has no $user_name entry"
fi

if [ -f "$ROOT_DIR/.env" ]; then
  info "source environment file exists: $ROOT_DIR/.env"
  validate_env_file "$ROOT_DIR/.env" "source environment file"
else
  warn "source environment file does not exist: $ROOT_DIR/.env"
  warn "deploy will use .env.example only if target environment file does not already exist"
fi

if [ -f "$ENV_FILE" ]; then
  info "target environment file exists: $ENV_FILE"
  validate_env_file "$ENV_FILE" "target environment file"
else
  warn "target environment file does not exist yet: $ENV_FILE"
fi

info "default config directory: $CONFIG_DIR"
info "default deploy directory: $DEPLOY_DIR"

if [ "$fail" -ne 0 ]; then
  exit 1
fi

info "prerequisite check completed"
