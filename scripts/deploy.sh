#!/usr/bin/env sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-"$HOME/.config"}
XDG_DATA_HOME=${XDG_DATA_HOME:-"$HOME/.local/share"}

PACKAGE_NAME=${PACKAGE_NAME:-forgejo}
DEPLOY_NAME=${DEPLOY_NAME:-deploy-${PACKAGE_NAME}-standalone}
UNIT_NAME=${UNIT_NAME:-${PACKAGE_NAME}.service}

CONFIG_DIR=${CONFIG_DIR:-"$XDG_CONFIG_HOME/$PACKAGE_NAME"}
DEPLOY_DIR=${DEPLOY_DIR:-"$XDG_DATA_HOME/$DEPLOY_NAME"}
SYSTEMD_USER_DIR=${SYSTEMD_USER_DIR:-"$XDG_CONFIG_HOME/systemd/user"}

ENV_FILE=${ENV_FILE:-"$CONFIG_DIR/.env"}
SOURCE_ENV_FILE=${SOURCE_ENV_FILE:-"$ROOT_DIR/.env"}

mkdir -p "$CONFIG_DIR" "$DEPLOY_DIR/scripts" "$SYSTEMD_USER_DIR"

cp "$ROOT_DIR/compose.yaml" "$DEPLOY_DIR/compose.yaml"
cp "$ROOT_DIR/scripts/start.sh" "$DEPLOY_DIR/scripts/start.sh"
cp "$ROOT_DIR/scripts/stop.sh" "$DEPLOY_DIR/scripts/stop.sh"
cp "$ROOT_DIR/scripts/check-runtime.sh" "$DEPLOY_DIR/scripts/check-runtime.sh"
chmod 755 "$DEPLOY_DIR/scripts/start.sh" "$DEPLOY_DIR/scripts/stop.sh" "$DEPLOY_DIR/scripts/check-runtime.sh"

if [ -f "$ENV_FILE" ]; then
  echo "OK: keep existing environment file: $ENV_FILE"
else
  if [ -f "$SOURCE_ENV_FILE" ]; then
    cp "$SOURCE_ENV_FILE" "$ENV_FILE"
    chmod 600 "$ENV_FILE"
    echo "OK: installed environment file from $SOURCE_ENV_FILE to $ENV_FILE"
  elif [ -f "$ROOT_DIR/.env.example" ]; then
    cp "$ROOT_DIR/.env.example" "$ENV_FILE"
    chmod 600 "$ENV_FILE"
    echo "OK: installed environment file from .env.example to $ENV_FILE"
    echo "WARN: review and edit $ENV_FILE before regular use" >&2
  else
    echo "ERROR: no source environment file found" >&2
    exit 1
  fi
fi

unit_file="$SYSTEMD_USER_DIR/$UNIT_NAME"
unit_tmp="$unit_file.tmp.$$"

cat > "$unit_tmp" <<EOF_UNIT
[Unit]
Description=Forgejo standalone rootless Podman compose stack
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
Environment=PACKAGE_NAME=$PACKAGE_NAME
Environment=DEPLOY_NAME=$DEPLOY_NAME
Environment=CONFIG_DIR=$CONFIG_DIR
Environment=DEPLOY_DIR=$DEPLOY_DIR
Environment=ENV_FILE=$ENV_FILE
Environment=UNIT_NAME=$UNIT_NAME
WorkingDirectory=$DEPLOY_DIR
ExecStart=$DEPLOY_DIR/scripts/start.sh
ExecStop=$DEPLOY_DIR/scripts/stop.sh
RemainAfterExit=yes
TimeoutStartSec=300
TimeoutStopSec=120

[Install]
WantedBy=default.target
EOF_UNIT

rm -f "$unit_file"
mv "$unit_tmp" "$unit_file"

systemctl --user daemon-reload
systemctl --user enable "$UNIT_NAME"

echo "OK: installed deploy assets to $DEPLOY_DIR"
echo "OK: installed systemd user unit: $unit_file"
echo
echo "Next:"
echo "  systemctl --user restart $UNIT_NAME"
echo "  $DEPLOY_DIR/scripts/check-runtime.sh"
