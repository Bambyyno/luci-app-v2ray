#!/bin/sh
# Install this luci-app-v2ray fork onto an OpenWrt router.
# Does not replace an existing /etc/config/v2ray.
#
#   wget -qO- https://raw.githubusercontent.com/Bambyyno/luci-app-v2ray/cursor/subscription-hwid-7e4a/scripts/install.sh | sh
#
# The UI JavaScript in prebuilt/ is produced by `yarn package`.

set -eu

REPO="Bambyyno/luci-app-v2ray"
REF="${1:-${LUCI_APP_V2RAY_REF:-cursor/subscription-hwid-7e4a}}"
DEST="${DEST:-}"

info() {
	printf '%s\n' "$*"
}

die() {
	printf '%s\n' "$*" >&2
	exit 1
}

fetch() {
	url="$1"
	out="$2"
	if wget -q -O "$out" "$url" 2>/dev/null; then
		return 0
	fi
	if command -v uclient-fetch >/dev/null 2>&1; then
		uclient-fetch -O "$out" "$url" && return 0
	fi
	die "Could not download $url. Install wget with HTTPS (libustream-mbedtls or libustream-openssl)."
}

copy_tree() {
	src="$1"
	dst="$2"
	mkdir -p "$dst"
	cp -a "$src"/. "$dst"/
}

install_new() {
	src="$1"
	dst="$2"
	if [ -f "$dst" ]; then
		return 0
	fi
	mkdir -p "$(dirname "$dst")"
	cp "$src" "$dst"
}

TMP=""
cleanup() {
	if [ -n "$TMP" ] && [ -d "$TMP" ]; then
		rm -rf "$TMP"
	fi
}
trap cleanup EXIT

if [ "$(id -u)" -ne 0 ] && [ -z "$DEST" ]; then
	die "Run this as root on the router."
fi

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" 2>/dev/null && pwd || true)
if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/../public/luasrc/controller/v2ray.lua" ] && [ -f "$SCRIPT_DIR/../prebuilt/luci-static/resources/v2ray.js" ]; then
	SRC=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
	info "Installing from $SRC"
else
	TMP=$(mktemp -d)
	info "Downloading $REPO ($REF)"
	fetch "https://github.com/$REPO/archive/refs/heads/$REF.tar.gz" "$TMP/src.tar.gz"
	tar -xzf "$TMP/src.tar.gz" -C "$TMP"
	SRC=""
	for dir in "$TMP"/*; do
		if [ -d "$dir" ] && [ -f "$dir/public/luasrc/controller/v2ray.lua" ]; then
			SRC=$dir
			break
		fi
	done
	[ -n "$SRC" ] || die "Downloaded archive has no luci-app-v2ray sources."
fi

[ -f "$SRC/prebuilt/luci-static/resources/v2ray.js" ] || die "prebuilt/luci-static/resources/v2ray.js is missing."

ROOT="${DEST}"

info "Copying LuCI files"
copy_tree "$SRC/public/root/usr" "$ROOT/usr"
copy_tree "$SRC/public/root/etc/init.d" "$ROOT/etc/init.d"
mkdir -p "$ROOT/etc"
cp "$SRC/public/root/etc/firewall.v2ray" "$ROOT/etc/firewall.v2ray"
mkdir -p "$ROOT/etc/uci-defaults"
cp "$SRC/public/root/etc/uci-defaults/40_luci-v2ray" "$ROOT/etc/uci-defaults/40_luci-v2ray"
chmod 755 "$ROOT/etc/init.d/v2ray" "$ROOT/etc/uci-defaults/40_luci-v2ray" "$ROOT/usr/libexec/rpcd/luci.v2ray"

install_new "$SRC/public/root/etc/config/v2ray" "$ROOT/etc/config/v2ray"
mkdir -p "$ROOT/etc/v2ray"
for name in transport.json directlist.txt proxylist.txt gfwlist.txt chnroute.txt chnroute6.txt srcdirectlist.txt; do
	install_new "$SRC/public/root/etc/v2ray/$name" "$ROOT/etc/v2ray/$name"
done

mkdir -p "$ROOT/usr/lib/lua/luci/controller"
cp "$SRC/public/luasrc/controller/v2ray.lua" "$ROOT/usr/lib/lua/luci/controller/v2ray.lua"

mkdir -p "$ROOT/www/luci-static/resources"
copy_tree "$SRC/prebuilt/luci-static/resources" "$ROOT/www/luci-static/resources"

if command -v po2lmo >/dev/null 2>&1; then
	mkdir -p "$ROOT/usr/lib/lua/luci/i18n"
	po2lmo "$SRC/public/po/zh_Hans/v2ray.po" "$ROOT/usr/lib/lua/luci/i18n/v2ray.zh-cn.lmo"
	if [ -d "$ROOT/usr/share/luci/i18n" ] || [ -z "$DEST" ]; then
		mkdir -p "$ROOT/usr/share/luci/i18n"
		cp "$ROOT/usr/lib/lua/luci/i18n/v2ray.zh-cn.lmo" "$ROOT/usr/share/luci/i18n/v2ray.zh-cn.lmo"
	fi
else
	info "po2lmo not found, Chinese translation was not compiled. The UI stays in English."
fi

if [ -z "$DEST" ]; then
	if [ ! -f /usr/lib/lua/luci/dispatcher.lua ] && [ ! -f /usr/lib/lua/luci/http.lua ]; then
		info "Installing Lua LuCI runtime"
		opkg update || true
		opkg install luci-lua-runtime || opkg install luci-compat || info "Could not install luci-lua-runtime. The controller is Lua and needs it on OpenWrt 22.03 and later."
	fi

	missing=""
	command -v jshn >/dev/null 2>&1 || missing="$missing jshn"
	command -v ip >/dev/null 2>&1 || missing="$missing ip-full"
	command -v ipset >/dev/null 2>&1 || missing="$missing ipset"
	command -v iptables >/dev/null 2>&1 || missing="$missing iptables iptables-mod-tproxy"
	command -v resolveip >/dev/null 2>&1 || missing="$missing resolveip"
	if [ -n "$missing" ]; then
		info "Installing$missing"
		opkg update || true
		# shellcheck disable=SC2086
		opkg install $missing || info "Some packages did not install. Transparent proxy needs them; the LuCI pages can still open."
	fi

	if ! opkg list-installed 2>/dev/null | grep -q '^dnsmasq-full '; then
		info "dnsmasq-full is not installed. The app's ipset rules need it. Replacing dnsmasq is left to you, because that restarts DNS."
	fi

	if [ -f /etc/uci-defaults/40_luci-v2ray ]; then
		sh /etc/uci-defaults/40_luci-v2ray || true
	fi

	mkdir -p /etc/rc.d
	ln -sf ../init.d/v2ray /etc/rc.d/S99v2ray
	rm -rf /tmp/luci-indexcache /tmp/luci-modulecache
	if [ -x /etc/init.d/rpcd ]; then
		/etc/init.d/rpcd reload >/dev/null 2>&1 || true
	fi
fi

info "luci-app-v2ray is installed."
info "LuCI: Services → V2Ray. Hardware id is under Global Settings. Subscription URL is under Outbound."
info "Use v2ray-core 4.x. v2ray-core 5 and later do not accept this app's --config/--test command or its JSON."
