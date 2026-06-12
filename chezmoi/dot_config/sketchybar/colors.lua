-- AeroSpace borders で使っている色との整合を取った Catppuccin Macchiato 寄りのパレット
local colors = {
  black     = 0xff181926,
  white     = 0xffe1e3e4,
  red       = 0xffed8796,
  green     = 0xffa6da95,
  blue      = 0xff8aadf4,
  yellow    = 0xffeed49f,
  orange    = 0xfff5a97f,
  magenta   = 0xffc6a0f6,
  grey      = 0xff939ab7,
  transparent = 0x00000000,

  bar = {
    bg     = 0x80000000,  -- 約50%の黒で軽く陰影をかける
    border = 0x00000000,
  },
  bg1    = 0xff363a4f,
  bg2    = 0xff494d64,

  with_alpha = function(color, alpha)
    if alpha > 1.0 or alpha < 0.0 then return color end
    return (color & 0x00ffffff) | (math.floor(alpha * 255.0) << 24)
  end,
}

return colors
