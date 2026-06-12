local sbar = require("sketchybar")
local colors = require("colors")
local icons = require("icons")

local audio = sbar.add("item", "audio_device", {
  position = "right",
  icon = {
    string = icons.audio.speaker,
    color  = colors.magenta,
    padding_left  = 8,
    padding_right = 4,
  },
  label = {
    color = colors.white,
    padding_right = 8,
    max_chars = 18,
  },
  update_freq = 5,
})

local function pick_icon(name)
  local n = name:lower()
  if n:find("airpods") then return icons.audio.airpods end
  if n:find("headphone") or n:find("ヘッドホン") or n:find("phones") then
    return icons.audio.headphones
  end
  if n:find("bluetooth") then return icons.audio.bluetooth end
  return icons.audio.speaker
end

local function refresh()
  sbar.exec(
    "system_profiler SPAudioDataType -json 2>/dev/null | "
      .. "jq -r '.. | objects | select(.coreaudio_default_audio_output_device==\"spaudio_yes\") | ._name' | head -1",
    function(result)
      local name = (result or ""):gsub("%s+$", "")
      if name == "" then
        audio:set({
          icon  = { string = icons.audio.speaker, color = colors.grey },
          label = { string = "—" },
        })
      else
        audio:set({
          icon  = { string = pick_icon(name), color = colors.magenta },
          label = { string = name },
        })
      end
    end
  )
end

audio:subscribe({ "routine", "forced", "system_woke", "volume_change" }, refresh)
refresh()
