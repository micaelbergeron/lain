
--[[
                                                  
     Licensed under GNU General Public License v2 
      * (c) 2013,      Luke Bonham                
      * (c) 2010-2012, Peter Hofmann              
                                                  
--]]

local helpers      = require("lain.helpers")

local notify_fg    = require("beautiful").fg_focus
local naughty      = require("naughty")
local wibox        = require("wibox")
local debug        = require("gears.debug")

local io           = { popen  = io.popen }
local tostring     = tostring
local string       = { format = string.format,
                       gsub   = string.gsub,
                       match  = string.match }
local math         = { ceil = math.ceil }

local setmetatable = setmetatable

-- Network infos
-- lain.widgets.net
local net = {
    last_t = 0,
    last_r = 0
}

function net.get_device()
    f = io.popen("ip link show | cut -d' ' -f2,9")
    ws = f:read("*a")
    f:close()
    ws = ws:match("%w+: UP") or ws:match("ppp%w+: UNKNOWN")
    if ws ~= nil then
        return ws:match("(%w+):")
    else
        return "network off"
    end
end

local function worker(args)
    local args = args or {}
    args.timeout = args.timeout     or 2
    args.units = args.units         or 1024 --kb
    args.notify = args.notify       or "on"
    args.screen = args.screen       or 1
    args.format = args.format       or '%.1f'
    args.settings = args.settings   or function() end
    args.iface = args.iface         or net.get_device()

    debug.dump(args, 'Net args interface')
    net.widget = wibox.widget.textbox('')
    helpers.set_map(args.iface, true)

    function update()
        net_now = {}

        if args.iface == "" or string.match(args.iface, "network off")
        then
            args.iface = net.get_device()
        end

        local now_t = helpers.first_line('/sys/class/net/' .. args.iface .. '/statistics/tx_bytes') or 0
        local now_r = helpers.first_line('/sys/class/net/' .. args.iface .. '/statistics/rx_bytes') or 0
        net_now.carrier = helpers.first_line('/sys/class/net/' .. args.iface .. '/carrier') or "0"
        net_now.state = helpers.first_line('/sys/class/net/' .. args.iface .. '/operstate') or "down"

        debug.dump({
            now_t = now_t,
            now_r = now_r,
            carrier = net_now.carrier,
            state = net_now.state
            }, 'Interface state')

        net_now.units_sent = math.ceil((now_t - net.last_t) / args.timeout / args.units)
        net_now.units_received = math.ceil((now_r - net.last_r) / args.timeout / args.units)
        debug.dump(net_now, "Bandwidth used (in unit/timeout)")            
        net.last_t = now_t
        net.last_r = now_r

        net_now.sent = string.gsub(string.format(args.format, net_now.units_sent), ",", ".")
        net_now.received = string.gsub(string.format(args.format, net_now.units_received), ",", ".")

        widget = net.widget
        args:settings()
        if net_now.carrier ~= "1" and args.notify == "on"
        then
            if helpers.get_map(args.iface)
            then
                naughty.notify({
                    title    = args.iface,
                    text     = "no carrier",
                    timeout  = 7,
                    position = "top_left",
                    icon     = helpers.icons_dir .. "no_net.png",
                    fg       = notify_fg or "#FFFFFF",
                    screen   = args.screen
                })
                helpers.set_map(args.iface, false)
            end
        else
            helpers.set_map(args.iface, true)
        end
    end

    helpers.newtimer(args.iface, args.timeout, update)
    return net.widget
end

return setmetatable(net, { __call = function(_, ...) return worker(...) end })
