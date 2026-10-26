module("luci.controller.v2ray", package.seeall)

local fs = require "nixio.fs"
local http = require "luci.http"
local i18n = require "luci.i18n"
local sys = require "luci.sys"
local uci = require "luci.model.uci"
local util = require "luci.util"

local UUID_PATTERN = "^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$"

function index()
	if not nixio.fs.access("/etc/config/v2ray") then
		return
	end

	entry({"admin", "services", "v2ray"}, firstchild(), _("V2Ray")).dependent = false

	entry({"admin", "services", "v2ray", "main"}, view("v2ray/main"), _("Global Settings"), 10)

	entry({"admin", "services", "v2ray", "inbound"}, view("v2ray/inbound"), _("Inbound"), 20).leaf = true

	entry({"admin", "services", "v2ray", "outbound"}, view("v2ray/outbound"), _("Outbound"), 30).leaf = true

	entry({"admin", "services", "v2ray", "dns"}, view("v2ray/dns"), _("DNS"), 40)

	entry({"admin", "services", "v2ray", "routing"}, view("v2ray/routing"), _("Routing"), 50)

	entry({"admin", "services", "v2ray", "policy"}, view("v2ray/policy"), _("Policy"), 60)

	entry({"admin", "services", "v2ray", "reverse"}, view("v2ray/reverse"), _("Reverse"), 70)

	entry({"admin", "services", "v2ray", "transparent-proxy"}, view("v2ray/transparent-proxy"), _("Transparent Proxy"), 80)

  entry({"admin", "services", "v2ray", "about"}, view("v2ray/about"), _("About"), 90)

  entry({"admin", "services", "v2ray", "request"}, call("action_request"))

  entry({"admin", "services", "v2ray", "hwid"}, call("action_hwid"))
end

local function new_uuid()
  local f = io.open("/proc/sys/kernel/random/uuid", "r")
  if not f then
    return nil
  end

  local uuid = f:read("*l")
  f:close()

  if uuid and uuid:match(UUID_PATTERN) then
    return uuid:lower()
  end

  return nil
end

-- Stored on the main UCI section, same file as the rest of the app config.
local function ensure_hwid()
  local c = uci.cursor()

  if c:get("v2ray", "main") ~= "v2ray" then
    return nil
  end

  local hwid = c:get("v2ray", "main", "hwid")
  if type(hwid) == "string" and hwid:match(UUID_PATTERN) then
    return hwid
  end

  hwid = new_uuid()
  if not hwid then
    return nil
  end

  c:set("v2ray", "main", "hwid", hwid)
  c:commit("v2ray")
  return hwid
end

function action_hwid()
  local hwid = ensure_hwid()

  http.prepare_content("application/json")

  if not hwid then
    http.write_json({
      code = 1,
      message = i18n.translate("Failed to generate hardware ID.")
    })
    return
  end

  http.write_json({
    code = 0,
    hwid = hwid
  })
end

function action_request()
  local url = http.formvalue("url")

  if not url or url == "" then
    http.prepare_content("application/json")
    http.write_json({
      code = 1,
      message = i18n.translate("Invalid url")
    })
    return
  end

  if string.sub(url, 1, 5) == "https" and
    not fs.stat("/lib/libustream-ssl.so") then
    http.prepare_content("application/json")
    http.write_json({
      code = 1,
      message = i18n.translatef("wget: SSL support not available, please install %s or %s.", "libustream-openssl", "libustream-mbedtls")
    })
    return
  end

  local content
  if http.formvalue("subscription") == "1" then
    if not url:match("^https?://") then
      http.prepare_content("application/json")
      http.write_json({
        code = 1,
        message = i18n.translate("Invalid url")
      })
      return
    end

    local hwid = ensure_hwid()
    if not hwid then
      http.prepare_content("application/json")
      http.write_json({
        code = 1,
        message = i18n.translate("Failed to generate hardware ID.")
      })
      return
    end

    -- Same wget fetch as luci.sys.httpget, plus the headers Happ and
    -- Remnawave-style panels require on a subscription GET.
    content = util.exec(string.format(
      "wget -qO- --header=%s --header=%s %s",
      util.shellquote("x-hwid: " .. hwid),
      util.shellquote("HWID: " .. hwid),
      util.shellquote(url)
    ))
  else
    content = sys.httpget(url, false)
  end

  if not content or content == "" then
    http.prepare_content("application/json")
    http.write_json({
      code = 1,
      message = i18n.translate("Failed to request.")
    })
  else
    http.prepare_content("application/json")
    http.write_json({
      code = 0,
      content = content
    })
  end
end
