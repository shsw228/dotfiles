-- Catppuccin Macchiato (dark) / Latte (light)。色は役割名で公開する。
-- 色名で公開すると light テーマで colors.white が黒くなる。
--
-- fg / fg_dim / fg_faint = テキストの3階調 (主 / 補助 / 空きタグ)
-- surface = 面の地。半透明なので必ず blur と併せる (styles.lua)
-- surface_raised = 面の上に置く不透明な塗り
-- accent / on_accent = 塗りつぶしコントロールの地とその上の文字
--
-- light は彩度色を暗く倒す。Latte の素の色は明面に対して 2:1 台しか出ない。
-- 外観切替時は items/theme.lua が --reload するので、判定は起動時の一度だけ。
local function is_dark()
  local f = io.popen("defaults read -g AppleInterfaceStyle 2>/dev/null")
  if not f then return true end
  local style = f:read("*l") or ""
  f:close()
  return style:find("Dark") ~= nil
end

local dark = {
  fg       = 0xffe1e3e4,
  fg_dim   = 0xffa5adcb,
  fg_faint = 0xff8087a2,

  surface        = 0x991e2030,
  surface_raised = 0xff363a4f,

  accent    = 0xff8aadf4,
  on_accent = 0xff181926,

  red     = 0xffed8796,
  green   = 0xffa6da95,
  blue    = 0xff8aadf4,
  yellow  = 0xffeed49f,
  orange  = 0xfff5a97f,
  magenta = 0xffc6a0f6,
}

local light = {
  fg       = 0xff4c4f69,
  fg_dim   = 0xff5c5f77,
  fg_faint = 0xff6c6f85,

  surface        = 0x99eff1f5,
  surface_raised = 0xffccd0da,

  accent    = 0xff1e66f5,
  on_accent = 0xffeff1f5,

  red     = 0xffd20f39,
  green   = 0xff40a02b,
  blue    = 0xff1e66f5,
  yellow  = 0xffa86f00,
  orange  = 0xffe05500,
  magenta = 0xff8839ef,
}

local dark_mode = is_dark()
local colors = dark_mode and dark or light

colors.is_dark = dark_mode
colors.transparent = 0x00000000

-- バー自体は透明。背景は bracket 側で持たせる
colors.bar = {
  bg     = 0x00000000,
  border = 0x00000000,
}

colors.with_alpha = function(color, alpha)
  if alpha > 1.0 or alpha < 0.0 then return color end
  return (color & 0x00ffffff) | (math.floor(alpha * 255.0) << 24)
end

return colors
