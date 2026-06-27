-- AIQoS LuCI CBI Configuration
-- SimpleForm with 7 toggles + preset scenarios

local m, s, o

m = SimpleForm("aiqos", translate("AIQoS Settings"),
    translate("Intelligent QoS management for 5G CPE routers. " ..
              "SINR-aware bandwidth adjustment, night-time cell locking, " ..
              "and hardware acceleration compatible."))

m.submit = translate("Save & Apply")
m.reset = false

-- Only write UCI on POST
if not m:formvalue("cbi.submit") then
    return m
end

-- Section: Main Controls
s = m:section(SimpleSection, nil, translate("Main Controls"))

o = s:option(Flag, "enabled", translate("Enable AIQoS"))
o.default = 1
o.rmempty = false

o = s:option(Flag, "sinr_inject", translate("SINR Injection"),
    translate("Continuously monitor 5G signal quality and adjust QoS parameters"))
o.default = 1

o = s:option(Flag, "night_lock", translate("Night Cell Lock"),
    translate("Lock to the strongest 5G cell during off-peak hours"))
o.default = 0

o = s:option(Flag, "cake_enabled", translate("CAKE Qdisc"),
    translate("Use CAKE queue discipline for intelligent packet scheduling"))
o.default = 1

o = s:option(Flag, "latency_control", translate("Low Latency Mode"),
    translate("Prioritize latency-sensitive traffic (VoIP, gaming)"))
o.default = 0

o = s:option(Flag, "gaming_mode", translate("Gaming Mode"),
    translate("Optimize for gaming: low bufferbloat, UDP priority"))
o.default = 0

o = s:option(Flag, "auto_detect", translate("Auto-Detect Capabilities"),
    translate("Automatically detect platform capabilities on boot"))
o.default = 1

-- Section: Presets
s = m:section(SimpleSection, nil, translate("Quick Presets"))

local presets = {
    { "office", translate("Office"), translate("Balanced for work: video calls + downloads") },
    { "gaming", translate("Gaming"), translate("Lowest latency, UDP priority") },
    { "streaming", translate("Streaming"), translate("Maximum throughput for 4K video") },
    { "download", translate("Download"), translate("Bulk downloads with background QoS") },
}

o = s:option(ListValue, "preset", translate("Scenario"))
o.default = "office"
for _, p in ipairs(presets) do
    o:value(p[1], p[2])
end
o.description = translate("Select a preset scenario to auto-configure QoS parameters")

-- Preset联动: switch presets via JavaScript
o.write = function(self, section, value)
    local preset_config = {
        office   = { enabled=1, sinr_inject=1, night_lock=0, cake_enabled=1, latency_control=0, gaming_mode=0, auto_detect=1 },
        gaming   = { enabled=1, sinr_inject=1, night_lock=1, cake_enabled=1, latency_control=1, gaming_mode=1, auto_detect=1 },
        streaming= { enabled=1, sinr_inject=0, night_lock=0, cake_enabled=1, latency_control=0, gaming_mode=0, auto_detect=1 },
        download = { enabled=1, sinr_inject=0, night_lock=0, cake_enabled=1, latency_control=0, gaming_mode=0, auto_detect=1 },
    }

    local cfg = preset_config[value]
    if cfg then
        for k, v in pairs(cfg) do
            m.uci:set("aiqos", "main", k, v)
        end
    end
    m.uci:set("aiqos", "main", "preset", value)
end

-- Save handler
function m.on_after_commit(self)
    luci.sys.call("/etc/init.d/aiqosd restart >/dev/null 2>&1 &")
end

return m
