# deploy-forgejo-standalone

Standalone Forgejo deployment assets for small self-hosted environments.

This repository provides a minimal all-in-one Forgejo deployment set. It is intended to be reusable as a component repository from an outer environment repository, such as a lab orchestration repository.

## Current status

The current tested baseline is:

- rootless Podman
- podman-compose
- user systemd service
- Forgejo reachable on `127.0.0.1:3000` by default
- SQLite3 database
- Git over SSH via the container's sshd

## Scope

This repository manages a standalone Forgejo instance with:

- Forgejo container image
- SQLite3 database used by Forgejo
- local Forgejo users
- bind-mounted Forgejo data directory
- install/update script
- runtime start/stop scripts
- runtime check script
- user systemd service generation

The initial scope intentionally does not include external PostgreSQL, OIDC/SSO, reverse proxy, TLS termination, mail delivery, Forgejo Actions runners, monitoring, or backup orchestration.

Those features should be handled later as explicit extensions, external components, or higher-level orchestration.

## Installed layout

The Git checkout is treated as an install/update source, not as the long-lived runtime directory.

Default installed paths are:

```text
~/.config/forgejo/.env
~/.local/share/deploy-forgejo-standalone/
~/.local/share/forgejo/
~/.config/systemd/user/forgejo.service
```

The defaults are derived from:

```text
PACKAGE_NAME=forgejo
DEPLOY_NAME=deploy-forgejo-standalone
UNIT_NAME=forgejo.service
```

The main derived paths can be overridden with environment variables such as `CONFIG_DIR`, `DEPLOY_DIR`, `ENV_FILE`, and `UNIT_NAME`.

## Quick start

Prepare an environment file in the checkout:

```sh
cp .env.example .env
vi .env
```

Check prerequisites:

```sh
bash scripts/check-prereq.sh
```

Install or update the persistent deployment:

```sh
bash scripts/deploy.sh
```

Start or restart the service:

```sh
systemctl --user restart forgejo.service
```

Check runtime state:

```sh
~/.local/share/deploy-forgejo-standalone/scripts/check-runtime.sh
```

Then open the configured Forgejo URL and complete the initial setup if required.

For reboot-time automatic startup, the service user must have linger enabled by the host administrator:

```sh
sudo loginctl enable-linger <service-user>
```

## Configuration

The runtime `.env` file is installed to:

```text
~/.config/forgejo/.env
```

After the initial install, edit this persistent `.env` file for runtime configuration changes.

Then restart the service:

```sh
systemctl --user restart forgejo.service
```

The checkout-local `.env` is an install/update input. It is not the file read by systemd after deployment.

If the persistent `.env` already exists, `scripts/deploy.sh` keeps it and does not overwrite it.

## Basic operation

Start service:

```sh
systemctl --user start forgejo.service
```

Stop service:

```sh
systemctl --user stop forgejo.service
```

Restart service after changing persistent config:

```sh
systemctl --user restart forgejo.service
```

Check service status:

```sh
systemctl --user status --no-pager forgejo.service
```

Check runtime state:

```sh
~/.local/share/deploy-forgejo-standalone/scripts/check-runtime.sh
```

## Data

By default, Forgejo data is stored under:

```text
~/.local/share/forgejo/
```

Runtime data should be kept outside the Git checkout.

To reset local runtime data for a fresh initial setup:

```sh
systemctl --user stop forgejo.service
podman unshare rm -rf "$HOME/.local/share/forgejo"
```

Use `podman unshare` for runtime data cleanup because rootless Podman maps container UIDs/GIDs to host-side subordinate IDs.

The `data/` path is still ignored by Git for temporary local testing.
