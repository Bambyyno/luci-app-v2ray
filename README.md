# luci-app-v2ray

Luci support for V2Ray

**This branch is new LuCI for OpenWrt 19.07 and later.**

**For legacy version: [Branch legacy](https://github.com/kuoruan/luci-app-v2ray/tree/legacy)**

[![Release Version](https://img.shields.io/github/release/kuoruan/luci-app-v2ray.svg)](https://github.com/kuoruan/luci-app-v2ray/releases/latest) [![Latest Release Download](https://img.shields.io/github/downloads/kuoruan/luci-app-v2ray/latest/total.svg)](https://github.com/kuoruan/luci-app-v2ray/releases/latest) [![Total Download](https://img.shields.io/github/downloads/kuoruan/luci-app-v2ray/total.svg)](https://github.com/kuoruan/luci-app-v2ray/releases)

## Установка на роутер одной командой

Этот форк ставится отдельно от фида kuoruan: в том фиде нет hardware id для подписки. На роутере под root нужен `wget` с HTTPS (`libustream-mbedtls` или `libustream-openssl`):

```sh
wget -qO- https://raw.githubusercontent.com/Bambyyno/luci-app-v2ray/cursor/subscription-hwid-7e4a/scripts/install.sh | sh
```

Скрипт скачивает эту ветку, копирует файлы LuCI и сбрасывает кэш LuCI. Уже существующий `/etc/config/v2ray` он не перезаписывает. Если hardware id ещё пустой, uci-defaults создаёт его. Повторный запуск обновляет приложение. На OpenWrt 22.03 и новее скрипт ставит `luci-lua-runtime`: контроллер написан на Lua.

Зависимости ставятся тем менеджером пакетов, который есть на роутере. Если в `PATH` есть `apk`, скрипт вызывает `apk update` и `apk add`. Иначе, если есть `opkg`, вызывает `opkg update` и `opkg install`. Если нет ни `apk`, ни `opkg`, скрипт останавливается с ошибкой.

Дальше в LuCI: **Services → V2Ray**. Hardware id — на странице Global Settings, адрес подписки — на Outbound. После смены id или адреса нажмите Save & Apply.

Скрипт: [`scripts/install.sh`](scripts/install.sh). Собранный интерфейс, который он кладёт в `/www`, лежит в `prebuilt/` и обновляется командой `yarn package`.

### Какой v2ray-core подходит

LuCI собирает JSON формата V2Ray 4 и запускает бинарник так: `v2ray --config=...`. Перед стартом проверка идёт через `v2ray --test --config=...`.

- **v2ray-core 4.x** подходит. Последний такой выпуск — 4.45.2.
- **v2ray-core 5 и новее не подойдут.** У них другая командная строка (`v2ray run -config ...`) и другая схема JSON. Init-скрипт сочтёт конфиг неверным и не запустит процесс.
- Поставить вместо него Xray и только поменять путь к файлу тоже нельзя: JSON ближе к v4, но этот init вызывает флаги именно v2ray 4.

## Install from the kuoruan feed

The feed below is the original project. It does not include the hardware id from this fork.

### Install via OPKG

1. Add new opkg key:

```sh
wget -O kuoruan-public.key http://openwrt.kuoruan.net/packages/public.key
opkg-key add kuoruan-public.key
```

2. Add opkg repository from kuoruan:

```sh
echo "src/gz kuoruan_universal http://openwrt.kuoruan.net/packages/releases/all" \
  >> /etc/opkg/customfeeds.conf
opkg update
```

3. Install package:

```sh
opkg install luci-app-v2ray
opkg install luci-i18n-v2ray-zh-cn
```

We also support HTTPS protocol.

4. Upgrade package:

```sh
opkg update
opkg upgrade luci-app-v2ray
opkg upgrade luci-i18n-v2ray-zh-cn
```

### Manual install

1. Download ipk files from [release](https://github.com/kuoruan/luci-app-v2ray/releases) page

2. Upload files to your router

3. Install package with opkg:

```sh
opkg install luci-app-v2ray_*.ipk
```

Dependencies:

- jshn
- ip (ip-tiny or ip-full)
- ipset
- iptables
- iptables-mod-tproxy
- resolveip
- dnsmasq-full (dnsmasq ipset is required)

For translations, please install ```luci-i18n-v2ray-*```.

> You may need to remove ```dnsmasq``` before installing this package.

## Configure

1. Download V2Ray file from V2Ray release [link](https://github.com/v2ray/v2ray-core/releases) or V2Ray ipk release [link](https://github.com/kuoruan/openwrt-v2ray/releases).

2. Upload V2Ray file to your router, or install the ipk file.

3. Config V2Ray file path in LuCI page.

4. Add your inbound and outbound rules.

5. Enable the service via LuCI.

## Build

Package files is in branch [luci2](https://github.com/kuoruan/luci-app-v2ray/tree/luci2)

Download with Git:

```sh
git clone -b luci2 https://github.com/kuoruan/luci-app-v2ray.git luci-app-v2ray
```
