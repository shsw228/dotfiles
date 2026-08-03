local sbar = require("sketchybar")
local colors = require("colors")
local icons = require("icons")

local wifi = sbar.add("item", "wifi", {
  position = "right",
  icon = {
    string = icons.wifi.connected,
    color  = colors.fg,
    padding_left  = 8,
    padding_right = 4,
  },
  label = {
    color = colors.fg,
    padding_right = 8,
    max_chars = 20,
  },
  update_freq = 120,
})

local function refresh()
  -- macOS 14+ では networksetup / ipconfig は位置情報権限なしで SSID を <redacted> に
  -- 伏せる。system_profiler の SPAirPortDataType だけは権限不要で実 SSID を返す。
  -- 実行に数秒かかるが sbar.exec が非同期なのでバー側はブロックしない。
  sbar.exec(
    "system_profiler SPAirPortDataType -json 2>/dev/null "
      .. "| jq -r 'first(..|objects|.spairport_current_network_information?|select(.)|._name)' 2>/dev/null",
    function(result)
      local ssid = (result or ""):gsub("%s+$", "")
      if ssid == "" or ssid == "null" then
        wifi:set({
          icon  = { string = icons.wifi.disconnected, color = colors.fg_dim },
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
