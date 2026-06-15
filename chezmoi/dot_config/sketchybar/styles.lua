-- bracket / popup 等で使い回す背景スタイルを集約する。
-- blur_radius は background の中ではなく、item/bracket のトップレベル、
-- popup の場合は popup.blur_radius に置く必要がある点に注意。

local M = {}

-- ガラス風背景。bracket / popup どちらにも使う想定。
-- 使い方:
--   item/bracket: sbar.add("bracket", name, members, { blur_radius = M.glass.blur_radius, background = M.glass.background })
--   popup:        popup = { blur_radius = M.glass.blur_radius, background = M.glass.background, ... }
M.glass = {
  blur_radius = 10,
  background = {
    color = 0x6a282a36,
    border_color = 0x48ffffff,
    border_width = 1,
    corner_radius = 8,
  },
}

-- 旧: 右側ウィジェット群や tag bracket で使っていた非 glass の暗背景。
-- 互換用に残す（必要に応じて M.glass に統合してもよい）。
M.bracket_bg = {
  color = 0x99000000,
  corner_radius = 8,
  height = 28,
  border_width = 0,
}

return M
