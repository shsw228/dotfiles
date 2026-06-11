local sbar = require("sketchybar")
local colors = require("colors")
local icons = require("icons")

local wifi = sbar.add("item", "wifi", {
  position = "right",
  icon = {
    string = icons.wifi.connected,
    color  = colors.white,
    padding_left  = 8,
    padding_right = 4,
  },
  label = {
    color = colors.white,
    padding_right = 8,
    max_chars = 20,
  },
  background = {
    color = colors.bg1,
    height = 22,
    corner_radius = 6,
  },
  update_freq = 60,
})

local function refresh()
  sbar.exec(
    "networksetup -getairportnetwork en0 2>/dev/null || echo 'Current Wi-Fi Network: '",
    function(result)
      local ssid = (result or ""):match("Current Wi%-Fi Network:%s*(.-)%s*$") or ""
      if ssid == "" or ssid == "You are not associated with an AirPort network." then
        wifi:set({
          icon  = { string = icons.wifi.disconnected, color = colors.grey },
          label = { string = "off" },
        })
      else
        wifi:set({
          icon  = { string = icons.wifi.connected, color = colors.blue },
          label = { string = ssid },
        })
      end
    end
  )
end

wifi:subscribe({ "routine", "forced", "system_woke", "wifi_change" }, refresh)
refresh()
