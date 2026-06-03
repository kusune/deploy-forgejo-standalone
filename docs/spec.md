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
- basic prerequisite check script
- deploy script
- simple runtime test script
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

Environment-specific orchestration, host placement, component version pinning, and actual parameters should live in an outer repository.

The `.env` file is used for parameters within the standalone shape. It is not intended to select large structural variants.

## Variant policy

Future requirements such as PostgreSQL, OIDC, reverse proxy, TLS, or Actions runners should be evaluated explicitly when they are needed.

Possible handling options include:

- extending this repository with a clearly named profile
- creating another component repository
- handling the feature in an outer stack repository

The initial implementation should avoid embedding complex conditional logic for variants that are not yet in scope.
