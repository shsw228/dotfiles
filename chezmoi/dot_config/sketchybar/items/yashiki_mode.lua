local sbar = require("sketchybar")
local colors = require("colors")
local styles = require("styles")

-- yashiki が normal 以外の mode (resize 等) に入っているとき、左に mode 名バッジを
-- 表示し、その下に popup でその mode のキー一覧を出す。

local mode_item = sbar.add("item", "yashiki_mode", {
  position = "left",
  icon = { drawing = false, padding_left = 0, padding_right = 0 },
  label = {
    string = "",
    color = colors.on_accent,
    padding_left  = 8,
    padding_right = 8,
    font = { family = "Monaspace Neon", style = "Bold", size = 11.0 },
  },
  background = {
    color = colors.orange,
    corner_radius = styles.control.corner_radius,
    height = styles.control.height,
  },
  popup = {
    align = "center",
    blur_radius = styles.glass.blur_radius,
    background = styles.glass.background,
    y_offset = 6,
  },
  drawing = false,
  updates = true,
})

-- 各 mode のキー一覧 (1行=1キー説明)。"key 描述" 形式。
local cheatsheets = {
  resize = {
    "h        main-ratio 減",
    "l        main-ratio 増",
    "j        main-count 減",
    "k        main-count 増",
    "↵ / esc  normal へ戻る",
  },
  -- 他 mode を declare-mode したらここに追加
}

-- popup 内の行 item を事前生成 (最大行数ぶん)
local POPUP_ROWS = 8
local rows = {}
for i = 1, POPUP_ROWS do
  rows[i] = sbar.add("item", "popup.yashiki_mode.row_" .. i, {
    position = "popup.yashiki_mode",
    background = { drawing = false },
    icon = { drawing = false },
    label = {
      string = "",
      font = { family = "Monaspace Neon", style = "Regular", size = 15.0 },
      color = colors.fg,
      padding_left  = 14,
      padding_right = 14,
      align = "left",
    },
    drawing = false,
  })
end

local function fill_popup(mode)
  local sheet = cheatsheets[mode]
  if not sheet then
    for i = 1, POPUP_ROWS do rows[i]:set({ drawing = false }) end
    return
  end
  for i = 1, POPUP_ROWS do
    if sheet[i] then
      rows[i]:set({ drawing = true, label = { string = sheet[i] } })
    else
      rows[i]:set({ drawing = false })
    end
  end
end

mode_item:subscribe("yashiki_mode_change", function(env)
  local mode = env.MODE or "normal"
  if mode == "normal" or mode == "" then
    mode_item:set({
      drawing = false,
      popup = { drawing = false },
    })
  else
    fill_popup(mode)
    mode_item:set({
      drawing = true,
      label = { string = mode:upper() },
      popup = { drawing = true },
    })
  end
end)
