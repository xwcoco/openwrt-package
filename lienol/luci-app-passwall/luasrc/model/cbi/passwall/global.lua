local o = require "luci.dispatcher"
local fs = require "nixio.fs"
local sys = require "luci.sys"
local ipkg = require("luci.model.ipkg")
local uci = require"luci.model.uci".cursor()
local api = require "luci.model.cbi.passwall.api.api"
local appname = "passwall"

local function is_installed(e) return ipkg.installed(e) end

local function is_finded(e)
    return
        sys.exec("find /usr/*bin -iname " .. e .. " -type f") ~= "" and true or
            false
end

local n = {}
uci:foreach(appname, "nodes", function(e)
    if e.type and e.address and e.remarks then
        if e.use_kcp and e.use_kcp == "1" then
            n[e[".name"]] = "%s+%s：[%s] %s" %
                                {e.type, "Kcptun", e.remarks, e.address}
        else
            n[e[".name"]] = "%s：[%s] %s" % {e.type, e.remarks, e.address}
        end
    end
end)

local key_table = {}
for key, _ in pairs(n) do table.insert(key_table, key) end
table.sort(key_table)

m = Map(appname)
local status_use_big_icon = api.uci_get_type("global_other",
                                             "status_use_big_icon", 1)
if status_use_big_icon and status_use_big_icon == "1" then
    m:append(Template("passwall/global/status"))
else
    m:append(Template("passwall/global/status2"))
end

-- [[ Global Settings ]]--
s = m:section(TypedSection, "global", translate("Global Settings"))
-- s.description = translate("If you can use it, very stable. If not, GG !!!")
s.anonymous = true
s.addremove = false

---- TCP Node
local tcp_node_num = api.uci_get_type("global_other", "tcp_node_num", 1)
for i = 1, tcp_node_num, 1 do
    if i == 1 then
        o = s:option(ListValue, "tcp_node" .. i, translate("TCP Node"),
                     translate("For used to surf the Internet."))
    else
        o = s:option(ListValue, "tcp_node" .. i,
                     translate("TCP Node") .. " " .. i)
    end
    o:value("nil", translate("Close"))
    for _, key in pairs(key_table) do o:value(key, n[key]) end
end

---- UDP Node
local udp_node_num = api.uci_get_type("global_other", "udp_node_num", 1)
for i = 1, udp_node_num, 1 do
    if i == 1 then
        o = s:option(ListValue, "udp_node" .. i, translate("UDP Node"),
                     translate("For Game Mode or DNS resolution and more.") ..
                         translate("The selected server will not use Kcptun."))
        o:value("nil", translate("Close"))
        o:value("default", translate("Same as the tcp node"))
    else
        o = s:option(ListValue, "udp_node" .. i,
                     translate("UDP Node") .. " " .. i)
        o:value("nil", translate("Close"))
    end
    for _, key in pairs(key_table) do o:value(key, n[key]) end
end

---- Socks5 Node
local socks5_node_num = api.uci_get_type("global_other", "socks5_node_num", 1)
for i = 1, socks5_node_num, 1 do
    if i == 1 then
        o = s:option(ListValue, "socks5_node" .. i, translate("Socks5 Node"),
                     translate("The client can use the router's Socks5 proxy."))
    else
        o = s:option(ListValue, "socks5_node" .. i,
                     translate("Socks5 Node") .. " " .. i)
    end
    o:value("nil", translate("Close"))
    for _, key in pairs(key_table) do o:value(key, n[key]) end
end

---- DNS Forward Mode
o = s:option(ListValue, "dns_mode", translate("DNS Forward Mode"), translate(
                 "if you use no patterns are used, DNS of wan will be used by default as upstream of dnsmasq.<br />if has problem, please try another mode."))
o.rmempty = false
o:reset_values()
if is_finded("chinadns-ng") then o:value("chinadns-ng", "ChinaDNS-NG") end
if is_finded("dns2socks") then
    o:value("dns2socks", "dns2socks " .. translate("Need Socks5 server"))
end
if is_installed("pdnsd") or is_installed("pdnsd-alt") or is_finded("pdnsd") then
    o:value("pdnsd", "pdnsd")
end
o:value("local_7913", translate("Use local port 7913 as DNS"))
o:value("nonuse", translate("No patterns are used"))

---- Use TCP Node Resolve DNS
o = s:option(Flag, "use_tcp_node_resolve_dns",
             translate("Use TCP Node Resolve DNS"),
             translate("If checked, DNS is resolved using the TCP node."))
o.default = 1
o:depends("dns_mode", "pdnsd")

---- Upstream china DNS Server for ChinaDNS-NG
o = s:option(Value, "up_china_chinadns_ng_dns",
             translate("Upstream china DNS Server for ChinaDNS-NG") .. "(UDP)",
             translate(
                 "Domestic DNS server in Advanced Settings is used as domestic DNS by default.<br />Example: 127.0.0.1#5335,223.5.5.5#53<br />Only use two at most. such as smartdns,AdGuard Home..."))
o.default = "default"
o:value("default", translate("default"))
o:value("223.5.5.5", "223.5.5.5(" .. translate("Ali") .. "DNS1)")
o:value("223.6.6.6", "223.6.6.6(" .. translate("Ali") .. "DNS2)")
o:value("114.114.114.114", "114.114.114.114(114DNS1)")
o:value("114.114.115.115", "114.114.115.115(114DNS2)")
o:value("119.29.29.29", "119.29.29.29(DNSPOD DNS1)")
o:value("182.254.116.116", "182.254.116.116(DNSPOD DNS2)")
o:value("1.2.4.8", "1.2.4.8(CNNIC DNS1)")
o:value("210.2.4.8", "210.2.4.8(CNNIC DNS2)")
o:value("180.76.76.76", "180.76.76.76(" .. translate("Baidu") .. "DNS)")
o:depends("dns_mode", "chinadns-ng")

---- Upstream trust DNS Server for ChinaDNS-NG
o = s:option(Value, "up_trust_chinadns_ng_dns",
             translate("Upstream trust DNS Server for ChinaDNS-NG") .. "(UDP)",
             translate(
                 "Example: 127.0.0.1#5353<br />Only use two at most. such as dns2socks,dns-forwarder..."))
o.default = "8.8.4.4,8.8.8.8"
o:value("8.8.4.4,8.8.8.8", "8.8.4.4, 8.8.8.8 (Google DNS)")
o:value("208.67.222.222,208.67.220.220",
        "208.67.222.222, 208.67.220.220 (OpenDNS DNS)")
if is_finded("dns2socks") then
    o:value("dns2socks", "dns2socks " .. translate("Need Socks5 server"))
end
o:depends("dns_mode", "chinadns-ng")

---- DNS Forward
o = s:option(Value, "dns_forward", translate("DNS Forward Address"))
o.default = "8.8.4.4"
o:value("8.8.4.4", "8.8.4.4 (Google DNS)")
o:value("8.8.8.8", "8.8.8.8 (Google DNS)")
o:value("208.67.222.222", "208.67.222.222 (OpenDNS DNS)")
o:value("208.67.220.220", "208.67.220.220 (OpenDNS DNS)")
o:depends("dns_mode", "dns2socks")
o:depends("dns_mode", "pdnsd")
o:depends("up_trust_chinadns_ng_dns", "dns2socks")

---- Default Proxy Mode
o = s:option(ListValue, "proxy_mode",
             translate("Default") .. translate("Proxy Mode"))
o.default = "gfwlist"
o.rmempty = false
o:value("disable", translate("No Proxy"))
o:value("global", translate("Global Proxy"))
o:value("gfwlist", translate("GFW List"))
o:value("chnroute", translate("China WhiteList"))
o:value("gamemode", translate("Game Mode"))
o:value("returnhome", translate("Return Home"))

---- Localhost Proxy Mode
o = s:option(ListValue, "localhost_proxy_mode",
             translate("Localhost") .. translate("Proxy Mode"), translate(
                 "The server client can also use this rule to scientifically surf the Internet.<br /> Global and continental whitelist are not recommended for non-special cases!"))
o:value("default", translate("Default"))
o:value("global",
        translate("Global Proxy") .. "（" .. translate("Danger") .. "）")
o:value("gfwlist", translate("GFW List"))
o:value("chnroute", translate("China WhiteList"))
o.default = "default"
o.rmempty = false

--[[
local apply = luci.http.formvalue("cbi.apply")
if apply then
os.execute("/etc/init.d/passwall restart")
end
--]]

return m
