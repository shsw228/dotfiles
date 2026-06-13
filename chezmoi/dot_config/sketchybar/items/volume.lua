local sbar = require("sketchybar")
local colors = require("colors")
local icons = require("icons")
local settings = require("settings")
local displays = require("displays")

local SKETCHYBAR = settings.paths.sketchybar

-- 共通の状態キャッシュ
local current_device = "—"
local current_device_icon = icons.audio.speaker
local current_vol = 0
local current_muted = false

local function pick_device_icon(name)
  local n = name:lower()
  if n:find("airpods") then return icons.audio.airpods end
  if n:find("headphone") or n:find("ヘッドホン") or n:find("phones") then
    return icons.audio.headphones
  end
  if n:find("bluetooth") then return icons.audio.bluetooth end
  return icons.audio.speaker
end

local CLICK_MUTE = [[osascript -e 'set volume output muted (not (output muted of (get volume settings)))' && ]]
  .. SKETCHYBAR .. " --trigger volume_state_refresh"

-- ディスプレイごとに表示形式の異なる item を生成し、それぞれの render 関数を返す。
local function make_audio_item(name, display_idx, simple)
  local label_props
  if simple then
    label_props = { color = colors.white, padding_right = 8, width = 40, align = "right" }
  else
    label_props = { color = colors.white, padding_right = 8, max_chars = 24 }
  end
  local item = sbar.add("item", name, {
    position = "right",
    associated_display = display_idx,
    icon = {
      string = icons.audio.speaker,
      color  = colors.magenta,
      padding_left  = 8,
      padding_right = 4,
    },
    label = label_props,
    update_freq = 10,
    click_script = CLICK_MUTE,
  })
  return function()
    local right = current_muted and "mute" or (tostring(current_vol) .. "%")
    local label_str = simple and right or (current_device .. " · " .. right)
    item:set({
      icon  = { string = current_device_icon, color = current_muted and colors.red or colors.magenta },
      label = { string = label_str },
    })
  end
end

-- ディスプレイ構成に応じて item を立てる
local renderers = {}
local ext = displays.external_indices[1]
if ext then
  table.insert(renderers, make_audio_item("audio", ext, false))
end
if displays.builtin_index then
  table.insert(renderers, make_audio_item("audio_simple", displays.builtin_index, true))
end
if #renderers == 0 then
  -- ディスプレイ情報を取れなかった fallback: 全 display 向けに full
  table.insert(renderers, make_audio_item("audio", nil, false))
end

local function render_all()
  for _, r in ipairs(renderers) do r() end
end

-- OS 問い合わせ
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

local function refresh_volume()
  sbar.exec(
    "osascript -e 'set s to get volume settings' "
      .. "-e 'set v to output volume of s as integer' "
      .. "-e 'set m to output muted of s' "
      .. "-e '\"\" & v & \"|\" & m'",
    function(result)
      local vol_str, muted_str = (result or ""):match("^(%-?%d+)|(%a+)")
      current_vol = tonumber(vol_str) or 0
      current_muted = muted_str == "true"
      render_all()
    end
  )
end

local function refresh_all()
  refresh_device(refresh_volume)
end

-- 非表示イベントリレー item に subscribe をまとめる。update_freq でroutine駆動。
local relay = sbar.add("item", "audio_event_relay", {
  drawing = false,
  updates = true,
  update_freq = 10,
})
relay:subscribe("volume_change", function(env)
  local vol = tonumber(env.INFO)
  if vol then
    current_vol = vol
    current_muted = false
    render_all()
  else
    refresh_volume()
  end
end)
relay:subscribe("volume_state_refresh", refresh_volume)
relay:subscribe({ "routine", "forced", "system_woke" }, refresh_all)

refresh_all()
