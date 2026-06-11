local sbar = require("sketchybar")
local colors = require("colors")

-- yashiki tag = AeroSpace 旧 workspace 相当。N (1..10) を bitmask に変換して判定。
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

for _, tag in ipairs(tags) do
  local bitmask = 1 << (tag.num - 1)
  local item = sbar.add("item", "yashiki." .. tag.num, {
    position = "left",
    icon = { drawing = false },
    label = {
      string = tag.label,
      padding_left  = 8,
      padding_right = 8,
      color = colors.grey,
    },
    background = {
      color = colors.transparent,
      border_width = 0,
      height = 22,
      corner_radius = 6,
    },
    click_script = "/opt/homebrew/bin/yashiki tag-view " .. bitmask,
  })

  item:subscribe("yashiki_workspace_change", function(env)
    local active   = tonumber(env.ACTIVE_TAGS) or 0
    local occupied = tonumber(env.OCCUPIED_TAGS) or 0
    local is_active   = (active   & bitmask) ~= 0
    local is_occupied = (occupied & bitmask) ~= 0
    if is_active then
      item:set({
        label = { color = colors.black },
        background = { color = colors.white },
      })
    elseif is_occupied then
      item:set({
        label = { color = colors.white },
        background = { color = colors.transparent },
      })
    else
      item:set({
        label = { color = colors.grey },
        background = { color = colors.transparent },
      })
    end
  end)
end
