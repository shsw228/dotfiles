local sbar = require("sketchybar")
local displays = require("displays")

if not displays.builtin_index then return end

local NOTCH_PADDING = 10   -- notch 物理幅に追加する片側マージン

-- MBP のモデル識別子から notch の物理幅 (logical px) を返す。
-- M1 Pro/Max 以降の 14"/16" 系は notch あり。それ以外は 0。
local function detect_notch_width()
  local f = io.popen("system_profiler SPHardwareDataType 2>/dev/null | awk -F': +' '/Model Identifier/{print $2}'")
  if not f then return 0 end
  local model = (f:read("*l") or ""):gsub("%s+$", "")
  f:close()
  -- MacBookPro18,3/4 = 14"/16" M1 Pro/Max (2021)
  -- Mac14,5/6/7/9 = M2 Pro/Max 14"/16", M2 Air 13"/15" (notch あり機)
  -- Mac15/Mac16 = M3/M4 世代
  if model:match("^MacBookPro18,[34]")
    or model:match("^Mac1[456]")
  then
    return 220
  end
  return 0
end

local notch_w = detect_notch_width()
local spacer_w = notch_w + NOTCH_PADDING * 2

sbar.add("item", "notch_spacer", {
  position = "center",
  associated_display = displays.builtin_index,
  width = spacer_w,
  padding_left  = 0,
  padding_right = 0,
  icon = { drawing = false, padding_left = 0, padding_right = 0 },
  label = { drawing = false, padding_left = 0, padding_right = 0 },
  background = { drawing = false },
})
