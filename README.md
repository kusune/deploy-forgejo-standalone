# deploy-forgejo-standalone

Standalone Forgejo deployment assets for small self-hosted environments.

This repository provides a minimal all-in-one Forgejo deployment set. It is intended to be reusable as a component repository from an outer environment repository, such as a lab orchestration repository.

## Scope

This repository manages a standalone Forgejo instance with:

- Forgejo container image
- SQLite3 database used by Forgejo
- local Forgejo users
- bind-mounted Forgejo data directory
- simple prerequisite, deploy, and test scripts

The initial scope intentionally does not include external PostgreSQL, OIDC/SSO, reverse proxy, TLS termination, mail delivery, Forgejo Actions runners, monitoring, or backup orchestration.

Those features should be handled later as explicit extensions, external components, or higher-level orchestration.

## Quick start

```sh
cp .env.example .env
vi .env
bash scripts/check-prereq.sh
bash scripts/deploy.sh
bash scripts/test.sh
```

Then open the configured Forgejo URL and complete the initial setup if required.

## Using from another repository

A higher-level repository may check out this repository and call the scripts with a specific environment file:

```sh
ENV_FILE=/path/to/forgejo.env bash scripts/check-prereq.sh
ENV_FILE=/path/to/forgejo.env bash scripts/deploy.sh
ENV_FILE=/path/to/forgejo.env bash scripts/test.sh
```

The environment file is expected to describe a standalone Forgejo deployment. It is not a variant selector for a multi-component stack.

## Data

By default, Forgejo data is stored under `./data/forgejo` and is ignored by Git.

The data directory is expected to be writable by the UID/GID configured in `.env`.
