local sbar = require("sketchybar")
local colors = require("colors")
local settings = require("settings")
local styles = require("styles")
local yashiki = require("items.yashiki")

-- 可視タグが1つのとき、そのセルを囲むリングを描き、切り替えで横にスライドさせる。
-- 可視タグが複数のときは1つでは表せないので隠し、タグ側の塗りに戻す。
--
-- 前提となる sketchybar の性質 (実測):
--   * item は重ねられない。負の padding_left なら描画位置だけ左へ動かせるが、
--     後続 item の advance は絶対値ぶん増え、負の padding_right と負の
--     background.x_offset は無視されるので打ち消せない
--     → 「後ろに item が無い」位置にしか置けない。左グループの最後で require する
--   * 描画順は追加順なので、この item はタグ item の上に来る。bracket なら下に
--     描かれるが、bracket の幅はメンバー幅に固定で動かせない
--
-- 上に来るので塗りつぶすとタグの数字とアイコンを隠してしまう。中身をこちらに複製
-- すると、幅の補間中にアイコンの文字列だけが瞬間的に入れ替わってチラつく。
-- そこで塗りは透明にして縁だけを描き、中身はタグ item のまま透かせる。
-- 補間するのは位置と幅と縁の色だけになる。

local ANIM_CURVE = yashiki.anim.curve
local ANIM_DURATION = yashiki.anim.duration
local SKETCHYBAR = settings.paths.sketchybar
local BORDER_WIDTH = 2

-- 対象タグのセルと自分の矩形を1回のシェル呼び出しで取る。自分の位置も毎回測るので
-- ずれても次の移動で自己修正する。
local function query_rects(target_id, self_id, display_key, callback)
  sbar.exec(
    "{ " .. SKETCHYBAR .. " --query " .. target_id .. "; "
      .. SKETCHYBAR .. " --query " .. self_id .. "; } | "
      .. "jq -rs --arg k '" .. display_key .. "' "
      .. "'[.[0].bounding_rects[$k].origin[0], .[0].bounding_rects[$k].size[0], "
      .. ".[1].bounding_rects[$k].origin[0]] | @tsv'",
    callback
  )
end

for _, out in ipairs(yashiki.outputs) do
  local active_key = "OUTPUT_" .. out.yashiki_id .. "_ACTIVE_TAGS"
  local display_key = "display-" .. out.sb_display
  local item_id = "yashiki.indicator.d" .. out.sb_display

  local indicator = sbar.add("item", item_id, {
    position = "left",
    associated_display = out.sb_display,
    width = 1,
    -- 既定 (sbar.default) は 3。下で追う padding の初期値と合わせて 0 にする
    padding_left  = 0,
    padding_right = 0,
    icon  = { drawing = false, padding_left = 0, padding_right = 0 },
    label = { drawing = false, padding_left = 0, padding_right = 0 },
    background = {
      color = colors.transparent,
      border_color = yashiki.accent_hidden,
      border_width = BORDER_WIDTH,
      corner_radius = styles.control.corner_radius,
      height = styles.control.height,
    },
    updates = true,
  })

  local padding = 0        -- いま入れている padding_left
  local placed = false     -- 一度でも位置を合わせられたか

  local function hide()
    sbar.animate(ANIM_CURVE, ANIM_DURATION, function()
      indicator:set({ background = { border_color = yashiki.accent_hidden } })
    end)
    -- 次に出すときは、離れた位置から滑ってくるのではなくその場でフェードさせる
    placed = false
  end

  -- リロード直後はまだレイアウトが無く矩形が引けない。数回だけ間を置いて粘る。
  -- 引けたとしてもアイコンが出そろう前の幅で測っていることがあるので、初回
  -- (settle) だけ一度置いてから測り直す。
  local function place(target, attempt, settle)
    local target_id = "yashiki." .. target .. ".d" .. out.sb_display
    query_rects(target_id, item_id, display_key, function(result)
      local x, w, self_x =
        tostring(result or ""):match("([%-%d%.]+)%s+([%-%d%.]+)%s+([%-%d%.]+)")
      x, w, self_x = tonumber(x), tonumber(w), tonumber(self_x)
      if not (x and w and self_x) then
        if attempt < 5 then
          sbar.exec("sleep 0.4", function() place(target, attempt + 1, settle) end)
        end
        return
      end

      local next_padding = padding + (x - self_x)
      local props = {
        width = w,
        padding_left = next_padding,
        background = { border_color = colors.accent },
      }

      if placed then
        sbar.animate(ANIM_CURVE, ANIM_DURATION, function() indicator:set(props) end)
      else
        indicator:set(props)
        if settle then
          sbar.exec("sleep 0.3", function() place(target, 1, false) end)
        else
          placed = true
        end
      end
      padding = next_padding
    end)
  end

  indicator:subscribe("yashiki_workspace_change", function(env)
    local active = tonumber(env[active_key]) or 0
    local target = yashiki.single_active_tag(active)
    if not target then
      hide()
      return
    end
    place(target, 1, not placed)
  end)
end
