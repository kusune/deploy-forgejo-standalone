# deploy-forgejo-standalone

rootless Podman、podman-compose、user systemd service を使って、
standalone な Forgejo instance を動かすための小さな deploy package である。

## これでできること

この repository は、最小構成の Forgejo deployment を再現しやすくするためのものである。

`.env` を用意し、prerequisite check がすべて OK になるように設定できていれば、
基本的には次の流れで Forgejo を deploy できる。

```sh
bash scripts/check-prereq.sh
bash scripts/deploy.sh
systemctl --user restart forgejo.service
~/.local/share/deploy-forgejo-standalone/scripts/check-runtime.sh
```

`deploy.sh` は runtime 用の資材を XDG 風の永続配置先へ install し、
user systemd service を生成する。

runtime config は Git checkout の外に置かれる。

default の構成では、以下が得られる。

- standalone な Forgejo container
- SQLite3 database
- Forgejo local user authentication
- container 内 sshd による Git over SSH
- rootless Podman 実行
- podman-compose による lifecycle 管理
- user systemd service による service 管理
- linger 有効時の reboot-time startup
- prerequisite check script
- runtime check script
- Git checkout 外の runtime data 配置

clone して、`.env` を書いて、check して、deploy し、
その後は systemd で運用する、という単純な流れを目指している。

## 現在確認済みの baseline

現在の確認済み baseline は以下である。

- Debian 系 host
- rootless Podman
- podman-compose
- user systemd service
- Forgejo container image `codeberg.org/forgejo/forgejo:12`
- SQLite3 database
- default では `127.0.0.1:3000` で Forgejo に到達

## Scope

この repository が扱う standalone Forgejo instance には、以下を含む。

- Forgejo container image
- Forgejo が使う SQLite3 database
- Forgejo local user
- bind-mounted Forgejo data directory
- prerequisite check script
- install/update script
- runtime start/stop scripts
- runtime check script
- user systemd service generation

初期 scope には、以下を含めない。

- external PostgreSQL
- OIDC / SSO
- reverse proxy
- TLS termination
- mail delivery
- Forgejo Actions runner
- monitoring
- backup orchestration

これらが必要になった場合は、明示的な拡張、別 component、
または上位の orchestration 側で扱う。

## Installed layout

Git checkout は install/update source として扱う。
長期的な runtime directory ではない。

default の install 先は以下である。

```text
~/.config/forgejo/.env
~/.local/share/deploy-forgejo-standalone/
~/.local/share/forgejo/
~/.config/systemd/user/forgejo.service
```

default は以下の logical name から導出される。

```text
PACKAGE_NAME=forgejo
DEPLOY_NAME=deploy-forgejo-standalone
UNIT_NAME=forgejo.service
```

主な path は、`CONFIG_DIR`、`DEPLOY_DIR`、`ENV_FILE`、`UNIT_NAME` などの
環境変数で override できる。

## Quick start

checkout 内で environment file を用意する。

```sh
cp .env.example .env
vi .env
```

prerequisite check を実行する。

```sh
bash scripts/check-prereq.sh
```

`[NG]` が出た場合は、通常の prerequisite が満たされていない。
表示された問題を解消し、`check-prereq.sh` を再実行する。

`ERROR:` が出た場合は、repository や script の実行前提が壊れており、
通常の check として継続できない状態である。
repository の取得状態や install 済み資材の欠損を確認する。

すべての必須項目が `[OK]` になった状態で deploy する想定である。

永続配置先へ install/update する。

```sh
bash scripts/deploy.sh
```

service を start/restart する。

```sh
systemctl --user restart forgejo.service
```

runtime state を確認する。

```sh
~/.local/share/deploy-forgejo-standalone/scripts/check-runtime.sh
```

その後、設定した Forgejo URL を開き、必要に応じて初期設定を完了する。

reboot 後にも user service を自動起動させるには、
host administrator によって service user の linger が有効化されている必要がある。

```sh
sudo loginctl enable-linger <service-user>
```

## Configuration

runtime 用の `.env` は以下に install される。

```text
~/.config/forgejo/.env
```

初回 install 後に runtime config を変更する場合は、この persistent `.env` を編集する。

編集後は service を restart する。

```sh
systemctl --user restart forgejo.service
```

checkout-local の `.env` は install/update 用の input である。
deploy 後に systemd から読まれる file ではない。

persistent `.env` がすでに存在する場合、`scripts/deploy.sh` はそれを保持し、
上書きしない。

### Public URL と bind address

`FORGEJO_DOMAIN` と `FORGEJO_ROOT_URL` は、Forgejo が利用者に見せる
URL/name、または Forgejo が生成する URL に関係する。

`FORGEJO_HTTP_HOST` と `FORGEJO_SSH_HOST` は、
Podman port publishing に渡される host-side bind address である。

hostname や FQDN ではなく、IP address を指定する。

host-local access の例である。

```env
FORGEJO_DOMAIN=localhost
FORGEJO_ROOT_URL=http://localhost:3000/
FORGEJO_HTTP_HOST=127.0.0.1
FORGEJO_HTTP_PORT=3000
FORGEJO_SSH_HOST=127.0.0.1
FORGEJO_SSH_PORT=2222
```

特定の host address に bind する例である。

```env
FORGEJO_DOMAIN=forgejo.example.internal
FORGEJO_ROOT_URL=http://forgejo.example.internal:3000/
FORGEJO_HTTP_HOST=10.x.y.z
FORGEJO_HTTP_PORT=3000
FORGEJO_SSH_HOST=10.x.y.z
FORGEJO_SSH_PORT=2222
```

`0.0.0.0` は wildcard exposure を意図している場合だけ使う。

## Basic operation

service を start する。

```sh
systemctl --user start forgejo.service
```

service を stop する。

```sh
systemctl --user stop forgejo.service
```

persistent config 変更後などに service を restart する。

```sh
systemctl --user restart forgejo.service
```

service status を確認する。

```sh
systemctl --user status --no-pager forgejo.service
```

runtime state を確認する。

```sh
~/.local/share/deploy-forgejo-standalone/scripts/check-runtime.sh
```

より詳しい運用手順は以下を参照する。

```text
docs/operations.md
```

設計方針は以下を参照する。

```text
docs/spec.md
```

## Data

default では、Forgejo data は以下に保存される。

```text
~/.local/share/forgejo/
```

runtime data は Git checkout の外に置く。

初期設定からやり直すために runtime data を削除する場合は、以下を実行する。

```sh
systemctl --user stop forgejo.service
podman unshare rm -rf "$HOME/.local/share/forgejo"
```

rootless Podman では container UID/GID が host 側の subordinate UID/GID に
map されるため、runtime data cleanup には `podman unshare` を使う。

temporary local testing 用に、`data/` path は Git ignore されている。
