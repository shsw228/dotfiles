local sbar = require("sketchybar")
local colors = require("colors")
local icons = require("icons")
local displays = require("displays")

-- ウィジェット仕様:
--   full mode (外部モニタ): "title — artist"
--   minimum mode (Built-in、横幅が狭い): "title" のみ
-- 状態に応じて icon 切替:
--   playing → 􀊃 / magenta
--   paused  → 􀊆 / grey
--   stopped or unavailable → 􀫀 / grey ＋ "—"

local CLICK_PLAYPAUSE = [[osascript -e 'tell application "Music" to playpause' 2>/dev/null]]

local function make_media_item(name, display_idx)
  return sbar.add("item", name, {
    position = "right",
    associated_display = display_idx,
    icon = {
      string = icons.media.note,
      color  = colors.grey,
      padding_left  = 8,
      padding_right = 4,
    },
    label = {
      color = colors.white,
      padding_right = 8,
      max_chars = 24,
      scroll_duration = 180,
    },
    scroll_texts = true,
    background = {
      color = colors.bg1,
      height = 22,
      corner_radius = 6,
    },
    updates = true,
    update_freq = 5,
    click_script = CLICK_PLAYPAUSE,
  })
end

-- 共通の状態キャッシュ
local current_state, current_artist, current_title = "", "", ""

local renderers = {}

local function add_renderer(item, mode)
  table.insert(renderers, function()
    local label
    if not current_title or current_title == "" then
      label = "—"
    elseif mode == "min" or current_artist == "" then
      label = current_title
    else
      label = current_title .. " — " .. current_artist
    end

    local icon_str, icon_color
    if current_state == "playing" then
      icon_str, icon_color = icons.media.playing, colors.magenta
    elseif current_state == "paused" then
      icon_str, icon_color = icons.media.paused, colors.grey
    else
      icon_str, icon_color = icons.media.note, colors.grey
    end

    item:set({
      icon  = { string = icon_str, color = icon_color },
      label = { string = label },
    })
  end)
end

local ext = displays.external_indices[1]
if ext then
  add_renderer(make_media_item("media", ext), "full")
end
if displays.builtin_index then
  add_renderer(make_media_item("media_simple", displays.builtin_index), "min")
end
if #renderers == 0 then
  -- ディスプレイ情報を取れなかった fallback
  add_renderer(make_media_item("media", nil), "full")
end

local function render_all()
  for _, r in ipairs(renderers) do r() end
end

-- "state|artist|title" を返す。Music未起動時は "" を返す。
local MUSIC_CMD = table.concat({
  [[osascript]],
  [[-e 'try']],
  [[-e 'tell application "Music"']],
  [[-e   'if it is running then']],
  [[-e     'set pState to (get player state) as string']],
  [[-e     'try']],
  [[-e       'set a to (get artist of current track)']],
  [[-e       'set t to (get name of current track)']],
  [[-e     'on error']],
  [[-e       'set a to ""']],
  [[-e       'set t to ""']],
  [[-e     'end try']],
  [[-e     'return pState & "|" & a & "|" & t']],
  [[-e   'end if']],
  [[-e 'end tell']],
  [[-e 'end try']],
  [[-e 'return ""']],
  [[2>/dev/null]],
}, " ")

local function refresh()
  sbar.exec(MUSIC_CMD, function(result)
    local body = (result or ""):gsub("%s+$", "")
    if body == "" then
      current_state, current_artist, current_title = "", "", ""
    else
      local s, a, t = body:match("^([^|]*)|([^|]*)|(.+)$")
      current_state  = s or ""
      current_artist = a or ""
      current_title  = t or ""
    end
    render_all()
  end)
end

-- イベントリレー (非表示item) に subscribe をまとめる。update_freq でroutine駆動。
local relay = sbar.add("item", "media_event_relay", {
  drawing = false,
  updates = true,
  update_freq = 5,
})
relay:subscribe({ "routine", "forced", "system_woke" }, refresh)

refresh()
