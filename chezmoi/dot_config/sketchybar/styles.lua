-- 面のスタイル。blur_radius は background の中ではなく item/bracket のトップ
-- レベル、popup では popup.blur_radius に置く。
--
-- 縁に border も shadow も足さない。sketchybar の background.shadow は形の複製を
-- distance ぶんずらして塗るだけで、座標のずれた二重枠になる。
--
-- 面は blur 必須。blur した backdrop が実効背景を決めるので、壁紙の明暗で文字
-- コントラストが動かなくなる。バーが透明なので、面の無い item は壁紙の上に直接
-- 文字が乗って読めない。

local colors = require("colors")
local settings = require("settings")

local M = {}

-- 角丸は外側から余白ぶんを差し引いて同心にする。bar > 面 > コントロール の
-- 各段で、上下に空く余白 (高さの差の半分) を親の角丸から引く。
local function concentric(outer_radius, outer_height, height)
  return outer_radius - (outer_height - height) / 2
end

local BRACKET_HEIGHT = 28
local PILL_HEIGHT    = 24
local CONTROL_HEIGHT = 22

local BRACKET_RADIUS = concentric(settings.bar.corner_radius, settings.bar.height, BRACKET_HEIGHT)
local PILL_RADIUS    = concentric(settings.bar.corner_radius, settings.bar.height, PILL_HEIGHT)

local function surface(height, radius)
  return {
    blur_radius = 30,
    background = {
      color = colors.surface,
      border_width = 0,
      corner_radius = radius,
      height = height,
      shadow = { drawing = false },
    },
  }
end

M.bracket = surface(BRACKET_HEIGHT, BRACKET_RADIUS)

-- bracket を組めない単独 item (中央の date / clock) 用
M.pill = surface(PILL_HEIGHT, PILL_RADIUS)

-- popup は行数で高さが変わるので高さ指定なし
M.glass = surface(nil, BRACKET_RADIUS)

-- 面の上に乗る塗りつぶしコントロール (active tag / mode バッジ / media チップ)
M.control = {
  height = CONTROL_HEIGHT,
  corner_radius = concentric(BRACKET_RADIUS, BRACKET_HEIGHT, CONTROL_HEIGHT),
}

-- グループ間の隙間。bracket は member の外周に張り付くので、隙間はどちらの
-- bracket にも属さないダミー item で作る (item padding では bracket ごと広がる)。
M.group_gap = 8

return M
