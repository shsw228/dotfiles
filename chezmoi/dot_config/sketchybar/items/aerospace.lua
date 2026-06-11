local sbar = require("sketchybar")
local colors = require("colors")

-- aerospace.toml の workspace 名と表示ラベル
local workspaces = {
  { name = "1.Browser",  label = "1" },
  { name = "2.Terminal", label = "2" },
  { name = "3.Xcode",    label = "3" },
  { name = "4.AI",       label = "4" },
  { name = "5",          label = "5" },
  { name = "6",          label = "6" },
  { name = "7",          label = "7" },
  { name = "8",          label = "8" },
  { name = "9",          label = "9" },
  { name = "10",         label = "0" },
}

for _, ws in ipairs(workspaces) do
  local item = sbar.add("item", "aerospace." .. ws.name, {
    position = "left",
    icon = { drawing = false },
    label = {
      string = ws.label,
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
    click_script = "aerospace workspace '" .. ws.name .. "'",
  })

  item:subscribe("aerospace_workspace_change", function(env)
    local focused = env.FOCUSED_WORKSPACE or ""
    if focused == ws.name then
      item:set({
        label = { color = colors.black },
        background = { color = colors.white },
      })
    else
      item:set({
        label = { color = colors.grey },
        background = { color = colors.transparent },
      })
    end
  end)
end
