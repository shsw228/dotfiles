local sbar = require("sketchybar")
local colors = require("colors")
local icons = require("icons")

-- sketchybar 標準には media_change イベントがないので、osascript ポーリングで
-- Apple Music の再生状態を取得する。再生していないときは item を隠す。
local media = sbar.add("item", "media", {
  position = "right",
  icon = {
    string = icons.media.note,
    color  = colors.magenta,
    padding_left  = 8,
    padding_right = 4,
  },
  label = {
    color = colors.white,
    padding_right = 8,
    max_chars = 24,           -- max_chars 超は scroll_texts が有効ならスクロール
    width = 180,
    scroll_duration = 120,    -- 1文字ぶん移動するのにかける ms
  },
  scroll_texts = true,        -- label を自動スクロール
  drawing = false,
  updates = true,
  update_freq = 5,
  click_script = "osascript -e 'tell application \"Music\" to playpause' 2>/dev/null",
})

-- Apple Music の player state + 曲情報を返すワンライナー (paren付きでparser安定)
local MUSIC_CMD = table.concat({
  [[osascript]],
  [[-e 'try']],
  [[-e 'tell application "Music"']],
  [[-e   'if it is running and player state is playing then']],
  [[-e     'return (artist of current track) & "|" & (name of current track)']],
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
      media:set({ drawing = false })
      return
    end
    -- 形式: "artist|title"
    local artist, title = body:match("^([^|]*)|(.+)$")
    if not title or title == "" then
      media:set({ drawing = false })
      return
    end
    local label
    if artist and artist ~= "" then
      label = artist .. " — " .. title
    else
      label = title
    end
    media:set({
      drawing = true,
      icon  = { string = icons.media.playing, color = colors.magenta },
      label = { string = label },
    })
  end)
end

media:subscribe({ "routine", "forced", "system_woke" }, refresh)
refresh()
