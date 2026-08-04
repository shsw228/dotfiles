local sbar = require("sketchybar")
local colors = require("colors")
local styles = require("styles")
local outputs = require("items.yashiki_outputs")

-- リング (選択タグを囲む枠) の土台 item。items/init.lua でタグ item より先に
-- require して、タグ列の左端・磨りガラスの上・数字の下のレイヤに置く。
--
-- ここで作るのは動かない 1px の土台だけで、リングは icon.background として描く。
-- 幅は icon.width、位置は icon.background.x_offset で決める。どちらも補間できて
-- (実測: 途中で新しい目標を与えても現在値から反転なしで繋がる)、item の width を
-- 触らないのでレイアウトに影響しない。
--   * リングがどこへ動いても他の item は 1px も動かない
--   * 土台はタグ列より前にあるので、front_app などタグ列より後の item の伸縮に
--     一切依存しない
--
-- label は幅固定の透明な下敷き。item の描画領域は中身の幅から決まり、あとから
-- x_offset を変えても広がらない (クリップされてリングが消える)。タグ列全体を
-- 常に覆う下敷きを敷いておくことで、リングがどの位置でも描ける。リング本体を
-- icon 側に持つのは、icon が label より左にあり x_offset が常に正で済むため
-- (負の x_offset は無視される)。
--
-- item の background は「item width ぶんしか描けない」ので使えない (width を
-- 動かすとタグ列ごと押してしまう)。bracket の background は member が 1px だと
-- 描画されない。
--
-- 動かすロジックは items/yashiki_indicator.lua にある。

local M = { items = {} }

for _, out in ipairs(outputs) do
  M.items[out.sb_display] = sbar.add("item", "yashiki.ring.d" .. out.sb_display, {
    position = "left",
    associated_display = out.sb_display,
    width = 1,
    -- 既定 (sbar.default) は 3。土台の footprint を 1px きっかりにする
    padding_left  = 0,
    padding_right = 0,
    icon = {
      drawing = true,
      string = "",
      width = 0,
      padding_left  = 0,
      padding_right = 0,
      background = {
        color = colors.transparent,
        border_color = colors.transparent,
        border_width = 2,
        corner_radius = styles.control.corner_radius,
        height = styles.control.height,
      },
    },
    -- 描画領域をタグ列全体ぶん確保する下敷き。アイコン無しで実測 ~300px、
    -- 全タグにアイコンが付くと ~470px まで伸びるので余裕を持たせる
    label = {
      drawing = true,
      string = "",
      width = 520,
      padding_left  = 0,
      padding_right = 0,
      background = { drawing = false },
    },
    background = { drawing = false },
    updates = true,
  })
end

return M
