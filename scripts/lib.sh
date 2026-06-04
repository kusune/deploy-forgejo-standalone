#!/usr/bin/env sh

# Shared shell helpers for deploy-forgejo-standalone.
#
# Check scripts should report normal check results through:
#   [OK]    requirement is satisfied
#   [WARN]  note for operator review, without changing exit status
#   [NG]    requirement is not satisfied; final exit status becomes 1
#
# ERROR is reserved for states where script execution itself cannot continue,
# such as missing helper files, broken installed assets, or internal
# assumptions that do not hold.

CHECK_FAILED=${CHECK_FAILED:-0}

check_ok() {
  printf '[OK] %s\n' "$*"
}

check_warn() {
  printf '[WARN] %s\n' "$*" >&2
}

check_ng() {
  printf '[NG] %s\n' "$*" >&2
  CHECK_FAILED=1
}

check_finish() {
  exit "$CHECK_FAILED"
}

fatal_error() {
  printf 'ERROR: cannot continue: %s\n' "$*" >&2
  exit 1
}

state_error() {
  printf 'ERROR: internal or installation state error: %s\n' "$*" >&2
  exit 1
}

check_cmd() {
  cmd=$1

  if command -v "$cmd" >/dev/null 2>&1; then
    check_ok "$cmd found: $(command -v "$cmd")"
  else
    check_ng "$cmd not found"
  fi
}

validate_bind_ip_literal_check() {
  name=$1
  value=${2-}
  label=${3:-environment file}

  if [ -z "$value" ]; then
    check_ng "$label: $name is empty"
    return
  fi

  case "$value" in
    *[!0123456789abcdefABCDEF:.%]*)
      check_ng "$label: $name must be an IP address for Podman port binding, not a hostname: $value"
      return
      ;;
    *[g-zG-Z]*)
      check_ng "$label: $name looks like a hostname, but Podman port binding requires an IP address: $value"
      return
      ;;
  esac
}

validate_bind_ip_literal_or_exit() {
  name=$1
  value=${2-}

  if [ -z "$value" ]; then
    fatal_error "$name is empty"
  fi

  case "$value" in
    *[!0123456789abcdefABCDEF:.%]*)
      fatal_error "$name must be an IP address for Podman port binding, not a hostname: $value"
      ;;
    *[g-zG-Z]*)
      fatal_error "$name looks like a hostname, but Podman port binding requires an IP address: $value"
      ;;
  esac
}

validate_env_bind_values_check() {
  file=$1
  label=$2

  if [ ! -f "$file" ]; then
    return
  fi

  if [ ! -r "$file" ]; then
    check_ng "$label is not readable: $file"
    return
  fi

  unset FORGEJO_HTTP_HOST FORGEJO_SSH_HOST FORGEJO_ROOT_URL

  # shellcheck disable=SC1090
  . "$file"

  validate_bind_ip_literal_check FORGEJO_HTTP_HOST "${FORGEJO_HTTP_HOST:-}" "$label"
  validate_bind_ip_literal_check FORGEJO_SSH_HOST "${FORGEJO_SSH_HOST:-}" "$label"

  if [ -n "${FORGEJO_ROOT_URL:-}" ]; then
    check_ok "$label ROOT_URL: $FORGEJO_ROOT_URL"
  fi
}

load_env_or_exit() {
  file=$1

  if [ ! -f "$file" ]; then
    fatal_error "environment file not found: $file"
  fi

  if [ ! -r "$file" ]; then
    fatal_error "environment file is not readable: $file"
  fi

  set -a
  # shellcheck disable=SC1090
  . "$file"
  set +a
}

resolve_forgejo_data_path() {
  data_dir=${FORGEJO_DATA_DIR:-"$XDG_DATA_HOME/$PACKAGE_NAME"}

  case "$data_dir" in
    /*) data_path=$data_dir ;;
    *) data_path=$DEPLOY_DIR/$data_dir ;;
  esac

  printf '%s\n' "$data_path"
}
