local sbar = require("sketchybar")
local colors = require("colors")
local icons = require("icons")

local battery = sbar.add("item", "battery", {
  position = "right",
  icon = {
    string = icons.battery["100"],
    color  = colors.white,
    padding_left  = 8,
    padding_right = 4,
  },
  label = {
    color = colors.white,
    padding_right = 8,
  },
  update_freq = 120,
})

local function refresh()
  sbar.exec("pmset -g batt", function(result)
    result = result or ""
    local pct = tonumber(result:match("(%d+)%%")) or 0
    local charging = result:find("AC Power") ~= nil

    local icon
    if charging then
      icon = icons.battery.charging
    elseif pct >= 90 then icon = icons.battery["100"]
    elseif pct >= 60 then icon = icons.battery["75"]
    elseif pct >= 40 then icon = icons.battery["50"]
    elseif pct >= 20 then icon = icons.battery["25"]
    else icon = icons.battery["0"]
    end

    local color
    if charging then color = colors.green
    elseif pct >= 30 then color = colors.white
    elseif pct >= 15 then color = colors.yellow
    else color = colors.red
    end

    battery:set({
      icon  = { string = icon, color = color },
      label = { string = tostring(pct) .. "%" },
    })
  end)
end

battery:subscribe({ "routine", "forced", "system_woke", "power_source_change" }, refresh)
refresh()
