local sbar = require("sketchybar")
local colors = require("colors")
local icons = require("icons")

-- sketchybar 標準の media_change イベントを受けて再生中曲を表示する。
-- 何も再生していない (state ≠ playing) ときは hidden で隠す。
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
    max_chars = 30,
    width = "dynamic",
  },
  drawing = false,
  -- 左クリックで再生・一時停止 (Now Playing コマンド)
  click_script = "osascript -e 'tell application \"System Events\" to key code 16 using {function down}' 2>/dev/null",
})

media:subscribe("media_change", function(env)
  -- env.INFO は JSON で title / artist / state を含む
  if not env.INFO or env.INFO == "" then
    media:set({ drawing = false })
    return
  end
  -- JSON 構造例:
  --   {"app": "Music", "artist": "Foo", "title": "Bar", "state": "playing"}
  local state  = env.INFO:match('"state"%s*:%s*"([^"]+)"')
  local title  = env.INFO:match('"title"%s*:%s*"([^"]+)"')
  local artist = env.INFO:match('"artist"%s*:%s*"([^"]+)"')

  if state ~= "playing" then
    media:set({ drawing = false })
    return
  end

  local label
  if artist and artist ~= "" and title and title ~= "" then
    label = artist .. " — " .. title
  elseif title and title ~= "" then
    label = title
  else
    media:set({ drawing = false })
    return
  end

  media:set({
    drawing = true,
    icon  = { string = icons.media.playing },
    label = { string = label },
  })
end)
