local sbar = require("sketchybar")
local displays = require("displays")
local settings = require("settings")

if not displays.builtin_index then return end

local SKETCHYBAR = settings.paths.sketchybar

-- date と clock の自然幅は等しくないため、notch_spacer の中心が display 中心から
-- ずれる。それを補正するため、clock の後ろに「幅差ぶん」の透明 balance を追加する。
-- 幅は date/clock の実描画 size を sketchybar query で取得して動的に決める。
local balance = sbar.add("item", "notch_balance", {
  position = "center",
  associated_display = displays.builtin_index,
  width = 0,
  padding_left  = 0,
  padding_right = 0,
  icon = { drawing = false, padding_left = 0, padding_right = 0 },
  label = { drawing = false, padding_left = 0, padding_right = 0 },
  background = { drawing = false },
})

local function recompute()
  local key = "display-" .. displays.builtin_index
  -- date と clock の width を 1コマンドで取得 ("dw|cw" 形式)
  local cmd = "printf '%s|%s' "
    .. "\"$(" .. SKETCHYBAR .. " --query date 2>/dev/null | jq -r --arg k '" .. key .. "' '.bounding_rects[$k].size[0] // 0')\" "
    .. "\"$(" .. SKETCHYBAR .. " --query clock 2>/dev/null | jq -r --arg k '" .. key .. "' '.bounding_rects[$k].size[0] // 0')\""
  sbar.exec(cmd, function(result)
    local r = tostring(result or "")
    local dw_str, cw_str = r:match("^([%d%.]+)|([%d%.]+)")
    local dw = tonumber(dw_str) or 0
    local cw = tonumber(cw_str) or 0
    balance:set({ width = math.max(0, dw - cw) })
  end)
end

-- 別 relay で routine を駆動。date のラベル (月日) は1日1回しか変わらないが
-- clock は分単位で変わる→ 分単位の clock 幅変動 (例: 9:09 vs 11:34) も拾える
local relay = sbar.add("item", "notch_balance_relay", {
  drawing = false,
  updates = true,
  update_freq = 30,
})
relay:subscribe({ "routine", "forced", "system_woke" }, recompute)
-- 初回は items 描画後に走らせる
sbar.exec("sleep 1", recompute)
