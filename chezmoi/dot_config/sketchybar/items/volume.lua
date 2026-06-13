local sbar = require("sketchybar")
local colors = require("colors")
local icons = require("icons")
local settings = require("settings")

local SKETCHYBAR = settings.paths.sketchybar

-- 出力デバイス + 音量 + ミュート状態をひとつのアイテムに統合
--   icon  = デバイス種別 (speaker/headphones/airpods/bluetooth)
--   label = "DeviceName 75%"  / mute時は "DeviceName mute"
--   click = ミュートトグル
local audio = sbar.add("item", "audio", {
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
    max_chars = 24,
  },
  update_freq = 10,
  click_script = [[osascript -e 'set volume output muted (not (output muted of (get volume settings)))' && ]]
    .. SKETCHYBAR .. " --trigger volume_state_refresh",
})

local function pick_device_icon(name)
  local n = name:lower()
  if n:find("airpods") then return icons.audio.airpods end
  if n:find("headphone") or n:find("ヘッドホン") or n:find("phones") then
    return icons.audio.headphones
  end
  if n:find("bluetooth") then return icons.audio.bluetooth end
  return icons.audio.speaker
end

-- 出力デバイス名キャッシュ。volume_change で頻繁に呼ばれても device 取得しない
local current_device = "—"
local current_device_icon = icons.audio.speaker

-- icon = デバイス種別 / label = "デバイス名 · 75%"
local function render(vol, muted)
  local right = muted and "mute" or (tostring(vol) .. "%")
  audio:set({
    icon  = { string = current_device_icon, color = muted and colors.red or colors.magenta },
    label = { string = current_device .. " · " .. right },
  })
end

-- 出力デバイス名を取得 → cache
local function refresh_device(after)
  sbar.exec(
    "system_profiler SPAudioDataType -json 2>/dev/null | "
      .. "jq -r '.. | objects | select(.coreaudio_default_audio_output_device==\"spaudio_yes\") | ._name' | head -1",
    function(result)
      local name = (result or ""):gsub("%s+$", "")
      if name == "" then
        current_device = "—"
        current_device_icon = icons.audio.speaker
      else
        current_device = name
        current_device_icon = pick_device_icon(name)
      end
      if after then after() end
    end
  )
end

-- OS に音量・ミュート状態問い合わせて render
local function refresh_volume()
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

local function refresh_all()
  refresh_device(refresh_volume)
end

audio:subscribe("volume_change", function(env)
  local vol = tonumber(env.INFO)
  if vol then render(vol, false) else refresh_volume() end
end)

audio:subscribe("volume_state_refresh", refresh_volume)
-- routine = update_freq による定期発火。デバイス変化を拾うため device も含めて refresh
audio:subscribe({ "routine", "forced", "system_woke" }, refresh_all)

-- 初回: デバイス + 音量
refresh_all()
