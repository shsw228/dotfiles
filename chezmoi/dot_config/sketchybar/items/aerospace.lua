local sbar = require("sketchybar")
local colors = require("colors")
local settings = require("settings")
local styles = require("styles")

local AEROSPACE = settings.paths.aerospace

local outputs = require("items.aerospace_outputs")

-- AeroSpace 側のワークスペース名は用途付き (1.Browser)。バーは番号だけ出す。
-- 10 は alt-0 で開くので "0" と表示する。
--
-- key は bridge が環境変数名に使う形。ドットは変数名に使えないので、英数字
-- 以外を _ に潰したものを両者で揃える (plugins/aerospace_bridge.sh と同じ変換)。
local spaces = {
  { name = "1.Browser",  label = "1" },
  { name = "2.Terminal", label = "2" },
  { name = "3.Xcode",    label = "3" },
  { name = "4.AI",       label = "4" },
  { name = "5",          label = "5" },
  { name = "6",          label = "6" },
  { name = "7",          label = "7" },
  { name = "8",          label = "8" },
  { name = "9",          label = "9" },
  { name = "10.Music",   label = "0" },
}

for _, space in ipairs(spaces) do
  space.key = space.name:gsub("[^%w]", "_")
end

local function csv_has(csv, want)
  if csv == nil or csv == "" then return false end
  for v in csv:gmatch("[^,]+") do
    if v == want then return true end
  end
  return false
end

-- active は accent、occupied は fg、空きは fg_faint。
-- weight は状態で変えない。font の切り替えは補間できず、字形が瞬間的に飛んで
-- チラつきに見える。区別は色とリングだけで付ける。
local label_font = { family = settings.font.text, style = "Semibold", size = 12.0 }

-- 切り替えは色を補間してクロスフェードさせる。background.drawing の on/off は
-- 補間できないので、pill は常に描画したまま alpha 0 と accent の間を動かす。
local ANIM_CURVE    = "sin"
local ANIM_DURATION = 10   -- tick
local ACCENT_HIDDEN = colors.with_alpha(colors.accent, 0.0)

for _, out in ipairs(outputs) do
  local mid          = out.aerospace_id
  local active_key   = "OUTPUT_" .. mid .. "_ACTIVE"
  local occupied_key = "OUTPUT_" .. mid .. "_OCCUPIED"
  local member_names = {}

  for _, space in ipairs(spaces) do
    local item_id  = "aerospace." .. space.key .. ".d" .. out.sb_display
    table.insert(member_names, item_id)

    local item = sbar.add("item", item_id, {
      position = "left",
      associated_display = out.sb_display,
      -- アプリアイコンは front_app の隣 (items/workspace_apps.lua) に移した。
      -- ピルは番号だけになり、幅が中身で変わらなくなる。リングの測り直しが
      -- 要らなくなるぶん、切り替えが常に補間だけで済む。
      icon = { drawing = false, padding_left = 0, padding_right = 0 },
      label = {
        string = space.label,
        padding_left  = 8,
        padding_right = 8,
        color = colors.fg_faint,
        font = label_font,
      },
      background = {
        color = ACCENT_HIDDEN,
        corner_radius = styles.control.corner_radius,
        height = styles.control.height,
      },
      click_script = AEROSPACE .. " workspace '" .. space.name .. "'",
    })

    -- 直前に入れた値。同じ値の入れ直しを避ける
    local last_label_color

    item:subscribe("aerospace_workspace_change", function(env)
      local is_active   = (env[active_key] == space.name)
      local is_occupied = csv_has(env[occupied_key], space.name)

      -- 可視ワークスペースはディスプレイごとに必ず1つなので、選択はスライドする
      -- リングだけで示す。ここは塗らず、色を accent にして選択と分かるようにする。
      -- (yashiki のタグはビットマスクで複数可視になり得たため、複数のときだけ
      --  セルを塗り分けていた。AeroSpace では排他なのでその分岐が要らない)
      local label_color
      if is_active then
        label_color = colors.accent
      elseif is_occupied then
        label_color = colors.fg
      else
        label_color = colors.fg_faint
      end

      -- 色だけ補間する。同じ色なら何もしない。
      if label_color ~= last_label_color then
        last_label_color = label_color
        sbar.animate(ANIM_CURVE, ANIM_DURATION, function()
          item:set({ label = { color = label_color } })
        end)
      end
    end)
  end

  -- 現在いるワークスペースの用途名。ピル群の直後に置き、同じ bracket に入れる。
  -- 「どのワークスペースにいるか」の情報を1か所に集めるため (前は front_app を
  -- 挟んだ向こう側にあり、場所の話とアプリの話が交互に並んでいた)。
  --
  -- 番号は隣のピルが出しているので "2.Terminal" から "Terminal" だけ取る。
  -- 用途を決めていない "5" のようなワークスペースでは何も出さない。
  local name_id = "workspace_name.d" .. out.sb_display
  table.insert(member_names, name_id)

  local name_item = sbar.add("item", name_id, {
    position = "left",
    associated_display = out.sb_display,
    icon = { drawing = false, padding_left = 0, padding_right = 0 },
    label = {
      string = "",
      color = colors.fg_dim,
      padding_left  = 6,
      padding_right = 10,
      font = label_font,
    },
    background = { drawing = false },
    -- updates の既定は when_shown。用途名の無いワークスペースで drawing=off に
    -- すると、その時点でイベントが届かなくなり二度と戻せない。
    updates = true,
  })

  local last_name
  name_item:subscribe("aerospace_workspace_change", function(env)
    local active = env[active_key]
    local category = active and active:match("^%d+%.(.+)$") or ""
    if category ~= last_name then
      last_name = category
      name_item:set({
        label = { string = category },
        drawing = category ~= "",
      })
    end
  end)

  -- このディスプレイのワークスペース表示をまとめた bracket
  sbar.add("bracket", "spaces_bracket_d" .. out.sb_display, member_names, {
    blur_radius = styles.bracket.blur_radius,
    background = styles.bracket.background,
    associated_display = out.sb_display,
  })
end

-- items/aerospace_indicator.lua が同じ定義でインジケータを組むために公開する
return {
  outputs = outputs,
  spaces = spaces,
  anim = { curve = ANIM_CURVE, duration = ANIM_DURATION },
  accent_hidden = ACCENT_HIDDEN,
}
