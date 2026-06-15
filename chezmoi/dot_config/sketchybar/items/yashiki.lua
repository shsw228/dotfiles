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
        color = colors.grey,
        padding_left  = 8,
        padding_right = 2,
      },
      label = {
        string = tag.label,
        padding_left  = 8,
        padding_right = 8,
        color = colors.bg2,
      },
      click_script = YASHIKI .. " tag-view --output " .. yid .. " " .. bitmask,
    })

    item:subscribe("yashiki_workspace_change", function(env)
      local active   = tonumber(env[active_key])   or 0
      local occupied = tonumber(env[occupied_key]) or 0
      local is_active   = (active   & bitmask) ~= 0
      local is_occupied = (occupied & bitmask) ~= 0

      local icon_str = build_icon_string(env[apps_key])
      local has_icon = icon_str ~= ""

      local label_color, icon_color
      if is_active then
        label_color = colors.white
        icon_color  = colors.white
      elseif is_occupied then
        label_color = colors.grey
        icon_color  = colors.grey
      else
        label_color = colors.bg2
        icon_color  = colors.bg2
      end

      item:set({
        icon = {
          string  = icon_str,
          drawing = has_icon,
          color   = icon_color,
          padding_left  = has_icon and 8 or 0,
          padding_right = has_icon and 2 or 0,
        },
        label = {
          color = label_color,
          padding_left = has_icon and 2 or 8,
        },
      })
    end)
  end

  -- このディスプレイの tag インジケータをまとめた bracket
  sbar.add("bracket", "tags_bracket_d" .. out.sb_display, member_names, {
    background = styles.bracket_bg,
    associated_display = out.sb_display,
  })
end
