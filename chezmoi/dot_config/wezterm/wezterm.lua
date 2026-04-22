local wezterm = require("wezterm")

local config = wezterm.config_builder()

config.font = wezterm.font_with_fallback({
  "Hack Nerd Font Mono",
  "Hack Nerd Font",
  "Hack",
})
config.harfbuzz_features = { "dlig=0" }
config.font_size = 20.0

config.window_background_opacity = 0.7
config.macos_window_background_blur = 13
config.inactive_pane_hsb = {
  saturation = 1.0,
  brightness = 0.6,
}

config.window_decorations = "RESIZE"
config.native_macos_fullscreen_mode = false
config.enable_tab_bar = false
config.window_padding = {
  left = 2,
  right = 2,
  top = 2,
  bottom = 2,
}
config.adjust_window_size_when_changing_font_size = false

config.colors = {
  foreground = "#ffffff",
  background = "#000000",
  selection_fg = "#ffffff",
  selection_bg = "#43454b",
  ansi = {
    "#43454b",
    "#ff8a7a",
    "#83c9bc",
    "#d9c668",
    "#4ec4e6",
    "#ff85b8",
    "#cda1ff",
    "#ffffff",
  },
  brights = {
    "#838991",
    "#ff8a7a",
    "#b1faeb",
    "#ffa14f",
    "#6bdfff",
    "#ff85b8",
    "#e5cfff",
    "#ffffff",
  },
}

config.keys = {
  {
    key = "Backspace",
    mods = "SUPER",
    action = wezterm.action.SendKey({
      key = "u",
      mods = "CTRL",
    }),
  },
}

return config
