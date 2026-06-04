# deploy-forgejo-standalone specification

## Purpose

`deploy-forgejo-standalone` は、standalone component として Forgejo を動かすための
最小 deploy set を提供する。

この repository は再利用可能であることを意図している。

実際の hostname、IP address、credential、組織固有の文脈など、
deployment-site specific な情報は含めない方針である。

site-specific な値は、local environment file または外側の deployment process から与える。

## Initial scope

初期 deployment target は、小規模な standalone Forgejo instance である。

Included:

- Forgejo container
- Forgejo が使う SQLite3 database
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

この repository は、1 つの standalone Forgejo instance のための
component deployment repository である。

単体の simple deployment package として直接使える。
また、より大きな deployment の component として使うこともできる。

ただし、この repository 自体は単体で理解・利用できる状態を保つ。

Git checkout は install/update source である。
長期的な runtime directory ではない。

persistent runtime configuration は XDG config directory 配下に置く。
persistent deployment assets と Forgejo data は XDG data directory 配下に置く。

default logical names:

```text
PACKAGE_NAME=forgejo
DEPLOY_NAME=deploy-forgejo-standalone
UNIT_NAME=forgejo.service
```

default runtime paths:

```text
CONFIG_DIR=${XDG_CONFIG_HOME:-$HOME/.config}/forgejo
ENV_FILE=$CONFIG_DIR/.env
DEPLOY_DIR=${XDG_DATA_HOME:-$HOME/.local/share}/deploy-forgejo-standalone
FORGEJO_DATA_DIR=${XDG_DATA_HOME:-$HOME/.local/share}/forgejo
```

`.env` は standalone shape の中で使う parameter を指定するためのものである。
大きな構造的 variant を切り替えるためのものではない。

reboot-time automatic startup は user systemd service で扱う。

host-level user creation、subordinate UID/GID setup、linger enablement は
この repository の外側の責務である。

## Installation model

checkout-local repository には source deployment assets を置く。

`scripts/deploy.sh` は、persistent runtime assets を `DEPLOY_DIR` 配下へ
install/update する。

generated user systemd unit は、Git checkout ではなく
persistent deploy directory 配下の runtime scripts を呼び出す。

この分離により、checkout は source/update location として使いながら、
runtime location は明示的で安定した場所にできる。

## Runtime model

generated systemd user service は以下を使う。

```text
Type=oneshot
RemainAfterExit=yes
ExecStart=<DEPLOY_DIR>/scripts/start.sh
ExecStop=<DEPLOY_DIR>/scripts/stop.sh
```

`start.sh` は `podman-compose up -d` を実行する。

`stop.sh` は `podman-compose down` を実行する。

したがって、動作は以下である。

- `systemctl --user start forgejo.service` は compose stack を create/start する。
- `systemctl --user stop forgejo.service` は compose-managed container を stop/remove する。
- `systemctl --user restart forgejo.service` は stop してから start し、container を再作成する。

`systemctl --user reload forgejo.service` は意図的に定義していない。
runtime configuration change は restart によって反映する想定である。

## Environment variable policy

environment file には、network 関連で意味の異なる 2 種類の値がある。

Public service values:

```text
FORGEJO_DOMAIN
FORGEJO_ROOT_URL
```

これらは、利用者に見える名前や URL、Forgejo が生成する URL に関係する。

Host bind values:

```text
FORGEJO_HTTP_HOST
FORGEJO_SSH_HOST
```

これらは、Podman port publishing に渡される host-side bind address である。
hostname や FQDN ではなく、IP address を指定する。

この区別は意図的なものである。

public URL は hostname や FQDN で構わない。
一方、Podman bind address は port publishing implementation が受け付ける
literal address である必要がある。

## Data policy

Forgejo runtime data は Git checkout の外に保存する。

default:

```text
${XDG_DATA_HOME:-$HOME/.local/share}/forgejo
```

rootless Podman では、host 側から subordinate UID/GID mapping の owner として
file が見えることがある。

data directory を手動で削除する場合は、`podman unshare` を使うべきである。

## Variant policy

PostgreSQL、OIDC、reverse proxy、TLS、SMTP、Actions runner などが必要になった場合は、
その時点で明示的に扱い方を評価する。

Possible handling options:

- この repository に明確な profile として追加する
- 別 component repository を作る
- 外側の stack / deployment repository で扱う

初期実装では、まだ scope に入っていない variant のために
複雑な conditional logic を埋め込まない方針である。

大きな構造的 variant は、その挙動を理解・運用しやすい状態に保てない限り、
単一の `.env` switch の裏に隠すべきではない。
