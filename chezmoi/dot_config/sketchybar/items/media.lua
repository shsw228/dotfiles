local sbar = require("sketchybar")
local colors = require("colors")
local icons = require("icons")

-- Apple Music の現状を osascript ポーリングで取得。常時表示し、
-- 再生状態に応じてアイコンを切替える:
--   playing → 􀊃 (play.fill) / magenta
--   paused  → 􀊆 (pause.fill) / grey
--   stopped or unavailable → 􀫀 (music.note) / grey ＋ "—"
local media = sbar.add("item", "media", {
  position = "right",
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
  click_script = "osascript -e 'tell application \"Music\" to playpause' 2>/dev/null",
})

-- "state|artist|title" を返す。Music未起動時は "" を返す。
-- ※ "set X to player state as string" は AppleScript parser に弾かれるため
--   "(get player state)" + as string で取る形にする
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
    local state, artist, title = body:match("^([^|]*)|([^|]*)|(.+)$")

    -- Music 未起動 or トラック無し
    if not state or state == "" then
      media:set({
        icon  = { string = icons.media.note, color = colors.grey },
        label = { string = "—" },
      })
      return
    end

    local has_track = title and title ~= ""
    local label
    if has_track then
      if artist and artist ~= "" then
        label = title .. " — " .. artist
      else
        label = title
      end
    else
      label = "—"
    end

    local icon_str, icon_color
    if state == "playing" then
      icon_str, icon_color = icons.media.playing, colors.magenta
    elseif state == "paused" then
      icon_str, icon_color = icons.media.paused, colors.grey
    else
      icon_str, icon_color = icons.media.note, colors.grey
    end

    media:set({
      icon  = { string = icon_str, color = icon_color },
      label = { string = label },
    })
  end)
end

media:subscribe({ "routine", "forced", "system_woke" }, refresh)
refresh()
