local sbar = require("sketchybar")
local colors = require("colors")
local settings = require("settings")

-- システム外観の切り替えで --reload して色を組み直す。
-- event の第2引数に NSDistributedNotification 名を渡せるのでポーリング不要。
sbar.add("event", "system_appearance_change", "AppleInterfaceThemeChangedNotification")

local LOCK_DIR = os.getenv("HOME") .. "/.cache/sketchybar"
local LOCK = LOCK_DIR .. "/theme_reload.lock"

-- 通知は 1 回の切り替えで束になって飛ぶので、mkdir ロックで先頭だけを通し、
-- さらに外観が実際に変わったときだけリロードする。
-- defaults の書き込みと競合するので、読む前に少し待つ。
local RELOAD_IF_CHANGED = string.format(
  'mkdir -p %s; '
    .. 'mkdir %s 2>/dev/null || exit 0; '
    .. 'sleep 0.3; '
    .. 'now=$(defaults read -g AppleInterfaceStyle 2>/dev/null || echo Light); '
    .. '[ "$now" = "%s" ] || %s --reload; '
    .. 'rmdir %s 2>/dev/null',
  LOCK_DIR,
  LOCK,
  colors.is_dark and "Dark" or "Light",
  settings.paths.sketchybar,
  LOCK
)

-- rmdir まで到達できなかった残骸を捨てる。残ると以降の切り替えが効かなくなる。
sbar.exec("rmdir " .. LOCK .. " 2>/dev/null; true")

local watcher = sbar.add("item", "theme_watcher", {
  drawing = false,
  updates = true,
})

watcher:subscribe("system_appearance_change", function()
  sbar.exec(RELOAD_IF_CHANGED)
end)
