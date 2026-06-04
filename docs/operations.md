# Operations

この document は、deploy 済みの `deploy-forgejo-standalone` instance の
日常運用について説明する。

## Runtime paths

default の persistent paths は以下である。

```text
~/.config/forgejo/.env
~/.local/share/deploy-forgejo-standalone/
~/.local/share/forgejo/
~/.config/systemd/user/forgejo.service
```

Git checkout は install/update に使う。

runtime systemd service は persistent deploy directory を使って実行される。

## Prerequisite check

Git checkout から実行する。

```sh
bash scripts/check-prereq.sh
```

この script は以下を確認する。

- required commands
- rootless Podman availability
- user systemd availability
- linger setting
- subordinate UID/GID entries
- source environment file
- すでに install 済みの場合は persistent environment file
- bind address values

`FORGEJO_HTTP_HOST` と `FORGEJO_SSH_HOST` は IP address である必要がある。
hostname や FQDN は指定できない。

`[NG]` や `ERROR` が出た場合は、そのまま deploy/update に進まない。
表示された問題を解消し、`check-prereq.sh` を再実行してから
`scripts/deploy.sh` に進む。

`WARN` は必ずしも即時停止条件ではない。
ただし、内容を確認し、その環境で意図した状態かどうかを判断する。

## Install or update persistent deployment

Git checkout から実行する。

```sh
bash scripts/deploy.sh
```

この script は以下を install/update する。

```text
~/.local/share/deploy-forgejo-standalone/compose.yaml
~/.local/share/deploy-forgejo-standalone/scripts/start.sh
~/.local/share/deploy-forgejo-standalone/scripts/stop.sh
~/.local/share/deploy-forgejo-standalone/scripts/check-runtime.sh
~/.config/systemd/user/forgejo.service
```

初回 install 時には、environment file も以下へ install する。

```text
~/.config/forgejo/.env
```

persistent `.env` がすでに存在する場合は、それを保持し、上書きしない。

## Start

```sh
systemctl --user start forgejo.service
```

persistent `start.sh` が呼び出され、`podman-compose up -d` が実行される。

## Stop

```sh
systemctl --user stop forgejo.service
```

persistent `stop.sh` が呼び出され、`podman-compose down` が実行される。

compose-managed container は stop 時に remove される。

## Restart

```sh
systemctl --user restart forgejo.service
```

compose-managed container を stop してから recreate する。

以下を変更した後は restart を使う。

- `~/.config/forgejo/.env`
- port bind settings
- image name
- volume/data settings
- installed compose.yaml
- installed runtime scripts

## Reload

reload は定義していない。

軽量な `podman restart` 的操作を `systemctl reload` として公開すると、
多くの configuration change が反映されないため、誤解を招きやすい。

configuration change を反映する場合は restart を使う。

```sh
systemctl --user restart forgejo.service
```

## Status

systemd service status を確認する。

```sh
systemctl --user status --no-pager forgejo.service
```

この service は以下のように表示される想定である。

```text
Active: active (exited)
```

これは `Type=oneshot` と `RemainAfterExit=yes` を使っているためであり、正常である。

実際の container は以下で確認する。

```sh
podman ps
```

## Runtime check

install 済みの runtime check script を使う。

```sh
~/.local/share/deploy-forgejo-standalone/scripts/check-runtime.sh
```

この script は以下を確認する。

- required commands
- persistent deploy directory
- persistent compose.yaml
- persistent environment file
- `podman-compose ps`
- systemd service enabled state
- systemd service active state
- container running state
- Forgejo HTTP endpoint response

## Change configuration

persistent environment file を編集する。

```sh
vi ~/.config/forgejo/.env
```

編集後、service を restart する。

```sh
systemctl --user restart forgejo.service
```

checkout-local の `.env` は install/update 用の input である。
deploy 後に systemd から読まれる runtime configuration ではない。

## Update deployment assets

Git checkout を pull または修正した後、以下を実行する。

```sh
bash scripts/check-prereq.sh
bash scripts/deploy.sh
systemctl --user restart forgejo.service
~/.local/share/deploy-forgejo-standalone/scripts/check-runtime.sh
```

deploy script は既存の persistent `.env` を保持する。

## Network settings

`FORGEJO_DOMAIN` と `FORGEJO_ROOT_URL` は、
Forgejo が使う public service name / URL を表す。

Example:

```env
FORGEJO_DOMAIN=forgejo.example.internal
FORGEJO_ROOT_URL=http://forgejo.example.internal:3000/
```

`FORGEJO_HTTP_HOST` と `FORGEJO_SSH_HOST` は Podman bind address である。

これらは IP address である必要がある。

Example:

```env
FORGEJO_HTTP_HOST=127.0.0.1
FORGEJO_HTTP_PORT=3000
FORGEJO_SSH_HOST=127.0.0.1
FORGEJO_SSH_PORT=2222
```

`127.0.0.1` を使うと、service は host-local になる。

特定の host interface address を使うと、その address 上で service を expose する。

`0.0.0.0` を使うと、host のすべての address で service を expose する。
意図している場合だけ使う。

## Host-local access with SSH tunnel

HTTP bind を host-local にする場合である。

```env
FORGEJO_HTTP_HOST=127.0.0.1
FORGEJO_HTTP_PORT=3000
```

別 machine からアクセスする場合は、SSH port forwarding を使える。

```sh
ssh -L 3000:127.0.0.1:3000 <service-user>@<host>
```

その後、以下を開く。

```text
http://localhost:3000/
```

この mode では、`FORGEJO_ROOT_URL` を利用者が実際にアクセスする URL と
矛盾しないように設定する。

## Data directory

default の Forgejo data directory は以下である。

```text
~/.local/share/forgejo/
```

初期設定からやり直すために runtime data を reset する場合は、以下を実行する。

```sh
systemctl --user stop forgejo.service
podman unshare rm -rf "$HOME/.local/share/forgejo"
```

rootless Podman では container UID/GID が host 側の subordinate UID/GID に
map されるため、`podman unshare` を使う。

## Reboot-time startup

service user には linger が必要である。

```sh
sudo loginctl enable-linger <service-user>
```

reboot 後は以下で確認する。

```sh
systemctl --user status --no-pager forgejo.service
~/.local/share/deploy-forgejo-standalone/scripts/check-runtime.sh
```

## Operational notes

### install 後は persistent `.env` が正

install 後、runtime configuration は以下から読まれる。

```text
~/.config/forgejo/.env
```

checkout-local の `.env` だけを変更しても、running service には反映されない。

### Stop は container を remove する

`systemctl --user stop forgejo.service` は `podman-compose down` を実行する。

container は remove されるが、persistent Forgejo data は configured data directory に残る。

### bind address と public URL は別物

`FORGEJO_ROOT_URL` には hostname や FQDN を含めることができる。

`FORGEJO_HTTP_HOST` と `FORGEJO_SSH_HOST` は IP address である必要がある。

この分離は意図的なものである。
reverse proxy など外側の component で deployment model を変更する場合を除き、
混同しないこと。
