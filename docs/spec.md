# deploy-forgejo-standalone specification

## Purpose

`deploy-forgejo-standalone` provides a minimal deployment set for running Forgejo as a standalone component.

The repository is intended to be public and reusable. It should not contain deployment-site specific details such as internal hostnames, IP addresses, VLANs, credentials, or organizational context.

## Initial scope

The initial deployment target is a small, standalone Forgejo instance.

Included:

- Forgejo container
- SQLite3 database used by Forgejo
- local Forgejo user authentication
- bind-mounted data directory
- prerequisite check script
- install/update script
- runtime start script
- runtime stop script
- runtime check script
- generated user systemd service
- example environment file

Not included:

- external PostgreSQL deployment
- external database variants
- OIDC / SSO integration
- reverse proxy management
- TLS certificate management
- SMTP / mail delivery setup
- Forgejo Actions runner setup
- monitoring integration
- backup orchestration
- multi-node or HA deployment

## Design boundary

This repository is a component deployment repository, not a full lab or platform orchestration repository.

The Git checkout is an install/update source. It is not the long-lived runtime directory.

Persistent runtime configuration is placed under the XDG config directory. Persistent deployment assets and Forgejo data are placed under the XDG data directory.

Default logical names:

```text
PACKAGE_NAME=forgejo
DEPLOY_NAME=deploy-forgejo-standalone
UNIT_NAME=forgejo.service
```

Default runtime paths:

```text
CONFIG_DIR=${XDG_CONFIG_HOME:-$HOME/.config}/forgejo
ENV_FILE=$CONFIG_DIR/.env
DEPLOY_DIR=${XDG_DATA_HOME:-$HOME/.local/share}/deploy-forgejo-standalone
FORGEJO_DATA_DIR=${XDG_DATA_HOME:-$HOME/.local/share}/forgejo
```

The `.env` file is used for parameters within the standalone shape. It is not intended to select large structural variants.

Reboot-time automatic startup is handled by a user systemd service. Host-level user creation, subordinate UID/GID setup, and linger enablement are outside this repository.

## Variant policy

Future requirements such as PostgreSQL, OIDC, reverse proxy, TLS, or Actions runners should be evaluated explicitly when they are needed.

Possible handling options include:

- extending this repository with a clearly named profile
- creating another component repository
- handling the feature in an outer stack repository

The initial implementation should avoid embedding complex conditional logic for variants that are not yet in scope.
