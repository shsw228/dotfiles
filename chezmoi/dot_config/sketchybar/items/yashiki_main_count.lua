local sbar = require("sketchybar")
local colors = require("colors")

-- tatami レイアウトの main-count を表示する。
-- yashiki/main_count.sh (alt-r→j/k や alt-,/. で呼ばれる wrapper) から
-- yashiki_main_count_change イベント (env.COUNT) を受信して更新。
local main_count = sbar.add("item", "yashiki_main_count", {
  position = "left",
  icon = {
    string = "M",
    color  = colors.fg_dim,
    padding_left  = 6,
    padding_right = 2,
    font = { family = "Monaspace Neon", style = "Bold", size = 11.0 },
  },
  label = {
    string = "1",
    color  = colors.fg,
    padding_left  = 2,
    padding_right = 6,
    font = { family = "Monaspace Neon", style = "Bold", size = 11.0 },
  },
  updates = true,
})

local function refresh()
  -- 初期値は wrapper のキャッシュファイルから読む
  sbar.exec("cat \"$HOME/.cache/yashiki/main_count\" 2>/dev/null || echo 1", function(result)
    -- gsub は第2戻り値に置換回数を返す。tonumber に直接渡すとそれが base 引数に
    -- 入って "base out of range" で落ちるので、一度変数に受けて1値に切る。
    local trimmed = (result or "1"):gsub("%s+$", "")
    local n = tonumber(trimmed) or 1
    main_count:set({ label = { string = tostring(n) } })
  end)
end

main_count:subscribe("yashiki_main_count_change", function(env)
  local n = tonumber(env.COUNT or "1") or 1
  main_count:set({ label = { string = tostring(n) } })
end)

main_count:subscribe({ "forced", "system_woke" }, refresh)
refresh()
