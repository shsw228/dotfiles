local sbar = require("sketchybar")
local colors = require("colors")
local icons = require("icons")

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
  },
  background = {
    color = colors.bg1,
    height = 22,
    corner_radius = 6,
  },
})

local function pick_icon(vol)
  if vol <= 0  then return icons.volume["0"]
  elseif vol <= 20 then return icons.volume["10"]
  elseif vol <= 50 then return icons.volume["33"]
  elseif vol <= 80 then return icons.volume["66"]
  else return icons.volume["100"]
  end
end

volume:subscribe("volume_change", function(env)
  local vol = tonumber(env.INFO) or 0
  volume:set({
    icon  = { string = pick_icon(vol) },
    label = { string = tostring(vol) .. "%" },
  })
end)
