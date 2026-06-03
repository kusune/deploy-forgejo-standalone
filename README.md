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
- simple prerequisite, deploy, and test scripts
- user systemd service

The initial scope intentionally does not include external PostgreSQL, OIDC/SSO, reverse proxy, TLS termination, mail delivery, Forgejo Actions runners, monitoring, or backup orchestration.

Those features should be handled later as explicit extensions, external components, or higher-level orchestration.

## Quick start

```sh
cp .env.example .env
vi .env
bash scripts/check-prereq.sh
mkdir -p ~/.config/systemd/user
ln -sf "$PWD/systemd/forgejo.service" ~/.config/systemd/user/forgejo.service
systemctl --user daemon-reload
systemctl --user enable --now forgejo.service
bash scripts/check-runtime.sh
```

Then open the configured Forgejo URL and complete the initial setup if required.

For reboot-time automatic startup, the service user must have linger enabled by the host administrator:

```sh
sudo loginctl enable-linger <service-user>
```

The included unit assumes this repository is checked out at:

```text
${HOME}/deploy-forgejo-standalone
```

## Using from another repository

A higher-level repository may check out this repository and call the scripts with a specific environment file:

```sh
ENV_FILE=/path/to/forgejo.env bash scripts/check-prereq.sh
ENV_FILE=/path/to/forgejo.env bash scripts/deploy.sh
ENV_FILE=/path/to/forgejo.env bash scripts/test.sh
```

The environment file is expected to describe a standalone Forgejo deployment. It is not a variant selector for a multi-component stack.

## Data

By default, Forgejo data is stored under `${HOME}/.local/share/forgejo`.

Runtime data should be kept outside the Git checkout. The data directory is expected to be writable by the UID/GID configured in `.env`.

The `data/` path is still ignored by Git for temporary local testing.

To reset local runtime data for a fresh initial setup:

```sh
systemctl --user stop forgejo.service
podman unshare rm -rf "$HOME/.local/share/forgejo"
```

Use `podman unshare` for runtime data cleanup because rootless Podman maps container UIDs/GIDs to host-side subordinate IDs.

## Basic operation

Start service:

```sh
systemctl --user start forgejo.service
```

Stop service:

```sh
systemctl --user stop forgejo.service
```

Check service status:

```sh
systemctl --user status --no-pager forgejo.service
```

Check runtime state:

```sh
./scripts/check-runtime.sh
```
