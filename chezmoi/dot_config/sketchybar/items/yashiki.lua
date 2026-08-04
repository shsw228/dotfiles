local sbar = require("sketchybar")
local colors = require("colors")
local icons = require("icons")
local settings = require("settings")
local styles = require("styles")

local YASHIKI = settings.paths.yashiki

-- 起動時に yashiki list-outputs を読んで、ディスプレイを検出。
-- 各yashiki output_id を sketchybar 側の display index (1=main, 2..=secondary) にマップする。
local function discover_outputs()
  local f = io.popen(YASHIKI .. " list-outputs 2>&1")
  local outputs = {}
  if not f then
    return { { yashiki_id = "1", sb_display = 1 } }
  end
  local raw = f:read("*a")
  f:close()

  local main_id
  local others = {}
  for line in raw:gmatch("[^\n]+") do
    local id = line:match("^(%d+):")
    if id then
      if line:find("%(main%)") then
        main_id = id
      else
        table.insert(others, id)
      end
    end
  end

  if main_id then
    table.insert(outputs, { yashiki_id = main_id, sb_display = 1 })
  end
  for _, id in ipairs(others) do
    table.insert(outputs, { yashiki_id = id, sb_display = #outputs + 1 })
  end
  if #outputs == 0 then
    table.insert(outputs, { yashiki_id = "1", sb_display = 1 })
  end
  return outputs
end

local outputs = discover_outputs()

local tags = {
  { num = 1,  label = "1" },
  { num = 2,  label = "2" },
  { num = 3,  label = "3" },
  { num = 4,  label = "4" },
  { num = 5,  label = "5" },
  { num = 6,  label = "6" },
  { num = 7,  label = "7" },
  { num = 8,  label = "8" },
  { num = 9,  label = "9" },
  { num = 10, label = "0" },
}

local function build_icon_string(apps_csv)
  if apps_csv == nil or apps_csv == "" then return "" end
  local seen, out = {}, {}
  for app_id in apps_csv:gmatch("[^,]+") do
    local glyph = icons.app[app_id] or icons.app.default
    if glyph and not seen[glyph] then
      seen[glyph] = true
      table.insert(out, glyph)
    end
  end
  return table.concat(out)
end

-- active は accent の塗りつぶし、occupied は fg、空きは fg_faint。
-- active だけ塗りで分けるのは、階調3段では隣接状態を見分けられないため。
-- weight は状態で変えない。font の切り替えは補間できず、字形が瞬間的に飛んで
-- チラつきに見える。区別は色とリングだけで付ける。
local label_font = { family = settings.font.text, style = "Semibold", size = 12.0 }

-- 切り替えは色を補間してクロスフェードさせる。background.drawing の on/off は
-- 補間できないので、pill は常に描画したまま alpha 0 と accent の間を動かす。
local ANIM_CURVE    = "sin"
local ANIM_DURATION = 15   -- tick
local ACCENT_HIDDEN = colors.with_alpha(colors.accent, 0.0)

-- 可視タグがちょうど1つならそのタグ番号、そうでなければ nil。
-- スライドするインジケータ (items/yashiki_indicator.lua) は1つのときだけ出す。
local function single_active_tag(mask)
  if mask == 0 or (mask & (mask - 1)) ~= 0 then
    return nil
  end
  local num = 1
  while mask > 1 do
    mask = mask >> 1
    num = num + 1
  end
  return num
end

for _, out in ipairs(outputs) do
  local yid          = out.yashiki_id
  local active_key   = "OUTPUT_" .. yid .. "_ACTIVE_TAGS"
  local occupied_key = "OUTPUT_" .. yid .. "_OCCUPIED_TAGS"
  local member_names = {}

  for _, tag in ipairs(tags) do
    local bitmask  = 1 << (tag.num - 1)
    local apps_key = "OUTPUT_" .. yid .. "_TAG_APPS_" .. tag.num
    local item_id  = "yashiki." .. tag.num .. ".d" .. out.sb_display
    table.insert(member_names, item_id)

    local item = sbar.add("item", item_id, {
      position = "left",
      associated_display = out.sb_display,
      icon = {
        string = "",
        drawing = false,
        color = colors.fg_dim,
        padding_left  = 8,
        padding_right = 2,
      },
      label = {
        string = tag.label,
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
      click_script = YASHIKI .. " tag-view --output " .. yid .. " " .. bitmask,
    })

    -- 直前に入れた値。同じ値の入れ直しを避ける
    local last_icon, last_label_color, last_fill

    item:subscribe("yashiki_workspace_change", function(env)
      local active   = tonumber(env[active_key])   or 0
      local occupied = tonumber(env[occupied_key]) or 0
      local is_active   = (active   & bitmask) ~= 0
      local is_occupied = (occupied & bitmask) ~= 0

      local icon_str = build_icon_string(env[apps_key])
      local has_icon = icon_str ~= ""

      -- 可視タグが1つのときはスライドするリングが選択を示すので、こちらは塗らない。
      -- 中身はリングの中に透けるため、色は accent にして選択と分かるようにする。
      -- 複数のときはこの item の塗りがセルを覆うので on_accent。
      local owns_fill = is_active and single_active_tag(active) == nil

      local label_color, icon_color
      if is_active then
        label_color = owns_fill and colors.on_accent or colors.accent
        icon_color  = owns_fill and colors.on_accent or colors.accent
      elseif is_occupied then
        label_color = colors.fg
        icon_color  = colors.fg
      else
        label_color = colors.fg_faint
        icon_color  = colors.fg_faint
      end

      -- アイコンの出入りは補間できず幅も動くので、変わったときだけ触る。
      -- 毎イベント同じ文字列を入れ直すと再描画が走る。
      if icon_str ~= last_icon then
        last_icon = icon_str
        item:set({
          icon = {
            string  = icon_str,
            drawing = has_icon,
            padding_left  = has_icon and 8 or 0,
            padding_right = has_icon and 2 or 0,
          },
          label = { padding_left = has_icon and 2 or 8 },
        })
      end

      -- 色だけ補間する。同じ色なら何もしない。
      local fill = owns_fill and colors.accent or ACCENT_HIDDEN
      if label_color ~= last_label_color or fill ~= last_fill then
        last_label_color, last_fill = label_color, fill
        sbar.animate(ANIM_CURVE, ANIM_DURATION, function()
          item:set({
            background = { color = fill },
            icon  = { color = icon_color },
            label = { color = label_color },
          })
        end)
      end
    end)
  end

  -- このディスプレイの tag インジケータをまとめた bracket
  sbar.add("bracket", "tags_bracket_d" .. out.sb_display, member_names, {
    blur_radius = styles.bracket.blur_radius,
    background = styles.bracket.background,
    associated_display = out.sb_display,
  })
end

-- items/yashiki_indicator.lua が同じ定義でインジケータを組むために公開する
return {
  outputs = outputs,
  tags = tags,
  single_active_tag = single_active_tag,
  anim = { curve = ANIM_CURVE, duration = ANIM_DURATION },
  accent_hidden = ACCENT_HIDDEN,
}
