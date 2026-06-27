module("luci.controller.aiqos", package.seeall)

function index()
    if not nixio.fs.access("/etc/config/aiqos") then
        return
    end

    local page = entry({"admin", "services", "aiqos"}, alias("admin", "services", "aiqos", "settings"), _("AIQoS"), 60)
    page.dependent = true
    page.acl_depends = { "luci-app-aiqos" }

    entry({"admin", "services", "aiqos", "settings"}, cbi("aiqos"), _("Settings"), 10)
    entry({"admin", "services", "aiqos", "status"}, template("aiqos/status"), _("Status"), 20)
    entry({"admin", "services", "aiqos", "status_json"}, call("action_status_json"))
end

function action_status_json()
    local rv = {
        sinr_coeff = "",
        capability = "",
        running = false,
    }

    local f = io.open("/tmp/aiqos_sinr_coeff", "r")
    if f then
        rv.sinr_coeff = f:read("*a"):gsub("%s+", "")
        f:close()
    end

    local f2 = io.open("/tmp/aiqos_capability.json", "r")
    if f2 then
        rv.capability = f2:read("*a")
        f2:close()
    end

    -- Check if daemon is running
    local p = io.popen("pgrep -f sinr_injector.sh 2>/dev/null")
    if p then
        local pid = p:read("*a"):gsub("%s+", "")
        p:close()
        if pid ~= "" then
            rv.running = true
        end
    end

    luci.http.prepare_content("application/json")
    luci.http.write_json(rv)
end
