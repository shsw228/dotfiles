local sbar = require("sketchybar")
local colors = require("colors")
local icons = require("icons")
local settings = require("settings")

local SKETCHYBAR = settings.paths.sketchybar

local function pick_icon(vol)
  if vol <= 0  then return icons.volume["0"]
  elseif vol <= 20 then return icons.volume["10"]
  elseif vol <= 50 then return icons.volume["33"]
  elseif vol <= 80 then return icons.volume["66"]
  else return icons.volume["100"]
  end
end

local volume = sbar.add("item", "volume", {
  position = "right",
  icon = {
    string = icons.volume["66"],
    color  = colors.white,
    padding_left  = 8,
    padding_right = 4,
  },
  label = {
    color = colors.white,
    padding_right = 8,
    width = 40,
    align = "right",
  },
  -- 左クリックでミュートをトグル
  click_script = [[osascript -e 'set volume output muted (not (output muted of (get volume settings)))' && ]]
    .. SKETCHYBAR .. " --trigger volume_state_refresh",
})

local function render(vol, muted)
  if muted then
    volume:set({
      icon  = { string = icons.volume["0"], color = colors.red },
      label = { string = "mute" },
    })
  else
    volume:set({
      icon  = { string = pick_icon(vol), color = colors.white },
      label = { string = tostring(vol) .. "%" },
    })
  end
end

-- OS に音量・ミュート状態を問い合わせて反映
local function refresh()
  sbar.exec(
    "osascript -e 'set s to get volume settings' "
      .. "-e 'set v to output volume of s as integer' "
      .. "-e 'set m to output muted of s' "
      .. "-e '\"\" & v & \"|\" & m'",
    function(result)
      local vol_str, muted_str = (result or ""):match("^(%-?%d+)|(%a+)")
      render(tonumber(vol_str) or 0, muted_str == "true")
    end
  )
end

-- volume_change は INFO に新音量が来るのでそのまま描画 (muted は変わらず=false 前提)
volume:subscribe("volume_change", function(env)
  local vol = tonumber(env.INFO)
  if vol then render(vol, false) else refresh() end
end)

volume:subscribe("volume_state_refresh", refresh)
volume:subscribe({ "system_woke", "forced" }, refresh)

refresh()
