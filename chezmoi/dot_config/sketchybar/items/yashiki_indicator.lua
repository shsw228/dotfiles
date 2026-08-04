local sbar = require("sketchybar")
local colors = require("colors")
local settings = require("settings")
local styles = require("styles")
local yashiki = require("items.yashiki")

-- 可視タグが1つのとき、そのセルを囲むリングを描き、切り替えで横にスライドさせる。
-- 可視タグが複数のときは1つでは表せないので隠す。
--
-- 前提となる sketchybar の性質 (実測):
--   * item は重ねられない。負の padding_left なら描画位置だけ左へ動かせるが、
--     後続 item の advance は絶対値ぶん増え、負の padding_right と負の
--     background.x_offset は無視されるので打ち消せない
--     → 「後ろに item が無い」位置にしか置けない。左グループの最後で require する
--   * 描画順は追加順なので、この item はタグ item の上に来る。bracket なら下に
--     描かれるが、bracket の幅はメンバー幅に固定で動かせない
--
-- 上に来るので塗りつぶすとタグの中身を隠す。中身をこちらに複製すると、幅の補間中に
-- アイコンの文字列だけが瞬間的に入れ替わってチラつく。そこで塗りは透明にして縁だけを
-- 描き、中身はタグ item のまま透かせる。補間するのは位置と幅と縁の色だけ。
--
-- 位置は毎回 --query で測るのではなくキャッシュから引く。測ってから動かすと、
-- タグ側の色が先に変わってワンテンポ遅れて動いて見える。セル幅はアイコンの有無で
-- 決まるので、アイコンの署名が同じならキャッシュは有効。動かした後に裏で測り直し、
-- ずれていればその場で直す。

local ANIM_CURVE = yashiki.anim.curve
local ANIM_DURATION = yashiki.anim.duration
local SKETCHYBAR = settings.paths.sketchybar
local BORDER_WIDTH = 2

-- アニメーションが終わってから測るための待ち (tick は 1/60 秒)
local SETTLE_DELAY = string.format("%.2f", ANIM_DURATION / 60 + 0.1)

-- 対象タグのセルと自分の矩形を1回のシェル呼び出しで取る
local function query_rects(target_id, self_id, display_key, callback)
  sbar.exec(
    "{ " .. SKETCHYBAR .. " --query " .. target_id .. "; "
      .. SKETCHYBAR .. " --query " .. self_id .. "; } | "
      .. "jq -rs --arg k '" .. display_key .. "' "
      .. "'[.[0].bounding_rects[$k].origin[0], .[0].bounding_rects[$k].size[0], "
      .. ".[1].bounding_rects[$k].origin[0]] | @tsv'",
    function(result)
      local x, w, self_x =
        tostring(result or ""):match("([%-%d%.]+)%s+([%-%d%.]+)%s+([%-%d%.]+)")
      callback(tonumber(x), tonumber(w), tonumber(self_x))
    end
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

  local cells = {}       -- タグ番号 -> { x, w }
  local cells_sig = nil  -- タグ列の内容の署名。変わればセル幅も変わる
  local natural_x = nil  -- padding_left = 0 のときの自分の左端
  local padding = 0      -- いま入れている padding_left
  local shown = false    -- リングが出ているか
  local target_tag = nil -- いま囲んでいるタグ

  local function apply(x, w, animate)
    local next_padding = x - natural_x
    local props = {
      width = w,
      padding_left = next_padding,
      background = { border_color = colors.accent },
    }
    if animate then
      sbar.animate(ANIM_CURVE, ANIM_DURATION, function() indicator:set(props) end)
    else
      indicator:set(props)
    end
    padding = next_padding
  end

  -- 動かした後に測り直す。キャッシュと natural_x を直し、ずれていればその場で寄せる。
  local function verify(target)
    local target_id = "yashiki." .. target .. ".d" .. out.sb_display
    sbar.exec("sleep " .. SETTLE_DELAY, function()
      query_rects(target_id, item_id, display_key, function(x, w, self_x)
        if not (x and w and self_x) then return end
        cells[target] = { x = x, w = w }
        natural_x = self_x - padding
        if math.abs(x - self_x) > 0.5 then
          apply(x, w, false)
        end
      end)
    end)
  end

  -- キャッシュが無いときだけ測ってから置く。リロード直後は矩形が引けないので粘る。
  local function measure_and_place(target, attempt)
    local target_id = "yashiki." .. target .. ".d" .. out.sb_display
    query_rects(target_id, item_id, display_key, function(x, w, self_x)
      if not (x and w and self_x) then
        if attempt < 5 then
          sbar.exec("sleep 0.4", function() measure_and_place(target, attempt + 1) end)
        end
        return
      end
      cells[target] = { x = x, w = w }
      natural_x = self_x - padding
      apply(x, w, shown)
      shown = true
      verify(target)
    end)
  end

  indicator:subscribe("yashiki_workspace_change", function(env)
    local active = tonumber(env[active_key]) or 0
    local target = yashiki.single_active_tag(active)

    if not target then
      sbar.animate(ANIM_CURVE, ANIM_DURATION, function()
        indicator:set({ background = { border_color = yashiki.accent_hidden } })
      end)
      -- 次に出すときは、離れた位置から滑ってくるのではなくその場でフェードさせる
      shown = false
      return
    end

    -- セル幅はどのタグにアイコンが出ているかで決まる
    local sig = {}
    for _, tag in ipairs(yashiki.tags) do
      sig[#sig + 1] = env["OUTPUT_" .. out.yashiki_id .. "_TAG_APPS_" .. tag.num] or ""
    end
    sig = table.concat(sig, "|")
    if sig ~= cells_sig then
      cells_sig = sig
      cells = {}
    end

    target_tag = target

    local cell = cells[target]
    if cell and natural_x then
      -- 測らずに即座に動かす。タグ側の色の補間と同時に始まる。
      apply(cell.x, cell.w, shown)
      shown = true
      verify(target)
    else
      measure_and_place(target, 1)
    end
  end)

  -- ディスプレイ構成が変わると列の基準 x が変わるが、ワークスペースイベントは来ない。
  -- 復帰時も同様。キャッシュを捨てて測り直す。
  indicator:subscribe({ "display_change", "system_woke" }, function()
    cells = {}
    cells_sig = nil
    natural_x = nil
    if target_tag then
      measure_and_place(target_tag, 1)
    end
  end)
end
