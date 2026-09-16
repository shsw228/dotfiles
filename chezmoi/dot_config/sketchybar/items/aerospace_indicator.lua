local sbar = require("sketchybar")
local colors = require("colors")
local settings = require("settings")
local aerospace = require("items.aerospace")
local outputs = require("items.aerospace_outputs")
local anchor = require("items.aerospace_ring_anchor")

-- 可視ワークスペースのセルを囲むリングを描き、切り替えで横にスライドさせる。
-- AeroSpace の可視ワークスペースはディスプレイごとに必ず1つなので、yashiki 時代の
-- 「複数可視なら隠す」分岐は無い。
--
-- リングは items/aerospace_ring_anchor.lua の 1px 土台の icon.background として描き、
-- 位置は icon.background.x_offset、幅は icon.width で動かす。どちらも補間可能で
-- (実測: 途中で新しい目標を与えても現在値から反転なしで繋がる)、レイアウトを
-- 通らないため、リングの移動が他の item を動かすことも、他の item の伸縮が
-- リングを動かすこともない。
--
-- 以前は「後ろに item が無い位置に置いて負の padding で動かす」方式だったが、
-- 土台の位置が手前の front_app のラベル幅に依存し、ワークスペース切り替え = 前面アプリの
-- 切り替えと同時に土台ごと横へ飛ぶため、あさっての方向へ動いてから戻る動きが
-- 出ていた。土台をワークスペース列より前に固定したことでこの依存は構造的に消えている。
--
-- 動く量は「対象セルの x - 土台の x」。土台はワークスペース列より前なので、ワークスペースのアイコンの
-- 増減 (セル幅が変わる) でも動かない。セル矩形だけをアイコンの署名をキーに
-- キャッシュし、キャッシュがあれば測らずに色の補間と同じイベントで動き出す。

local ANIM_CURVE = aerospace.anim.curve
local ANIM_DURATION = aerospace.anim.duration
local SKETCHYBAR = settings.paths.sketchybar

-- アニメーションが終わってから測るための待ち (tick は 1/60 秒)
local SETTLE_DELAY = string.format("%.2f", ANIM_DURATION / 60 + 0.1)

-- 対象ワークスペースのセルと土台を1回のシェル呼び出しで測る
local function query_rects(target_id, ring_id, display_key, callback)
  sbar.exec(
    "{ " .. SKETCHYBAR .. " --query " .. target_id .. "; "
      .. SKETCHYBAR .. " --query " .. ring_id .. "; } | "
      .. "jq -rs --arg k '" .. display_key .. "' "
      .. "'[.[0].bounding_rects[$k].origin[0], .[0].bounding_rects[$k].size[0], "
      .. ".[1].bounding_rects[$k].origin[0]] | @tsv'",
    function(result)
      local tx, tw, ax = tostring(result or "")
        :match("([%-%d%.]+)%s+([%-%d%.]+)%s+([%-%d%.]+)")
      callback(tonumber(tx), tonumber(tw), tonumber(ax))
    end
  )
end

for _, out in ipairs(outputs) do
  local ring = anchor.items[out.sb_display]
  local ring_id = "aerospace.ring.d" .. out.sb_display
  local active_key = "OUTPUT_" .. out.aerospace_id .. "_ACTIVE"
  local display_key = "display-" .. out.sb_display

  -- 表示名 -> item id に使う key。bridge の環境変数名と揃えてある。
  local key_of = {}
  for _, space in ipairs(aerospace.spaces) do
    key_of[space.name] = space.key
  end

  local cells = {}       -- ワークスペース名 -> { x, w }
  local anchor_x = nil   -- 土台の左端。ディスプレイ構成でしか動かない
  local shown = false    -- リングが出ているか
  local target_ws = nil  -- いま囲んでいるワークスペース
  -- 測り直しの世代。素早く切り替えると前の測定結果が後から届くので、
  -- 最新でなければ捨てる
  local generation = 0

  local function apply(cell, animate)
    local props = {
      icon = {
        width = cell.w,
        background = {
          x_offset = cell.x - anchor_x,
          border_color = colors.accent,
        },
      },
    }
    if animate then
      sbar.animate(ANIM_CURVE, ANIM_DURATION, function() ring:set(props) end)
    else
      ring:set(props)
    end
  end

  -- 測ってから置く。リロード直後は矩形が引けないので数回だけ粘る。
  -- 置いた後、レイアウト確定前の値だった可能性に備えて一度だけ照合する。
  local probe
  probe = function(target, my_generation, attempt)
    local target_id = "aerospace." .. (key_of[target] or target) .. ".d" .. out.sb_display
    query_rects(target_id, ring_id, display_key, function(tx, tw, ax)
      if my_generation ~= generation then return end
      if not (tx and tw and ax) then
        if attempt < 5 then
          sbar.exec("sleep 0.4", function() probe(target, my_generation, attempt + 1) end)
        end
        return
      end
      anchor_x = ax
      cells[target] = { x = tx, w = tw }
      apply(cells[target], shown)
      shown = true
      sbar.exec("sleep " .. SETTLE_DELAY, function()
        if my_generation ~= generation then return end
        query_rects(target_id, ring_id, display_key, function(tx2, tw2, ax2)
          if my_generation ~= generation then return end
          if not (tx2 and tw2 and ax2) then return end
          anchor_x = ax2
          cells[target] = { x = tx2, w = tw2 }
          if math.abs(tx2 - tx) > 0.5 or math.abs(tw2 - tw) > 0.5 or math.abs(ax2 - ax) > 0.5 then
            apply(cells[target], true)
          end
        end)
      end)
    end)
  end

  ring:subscribe("aerospace_workspace_change", function(env)
    local target = env[active_key]
    generation = generation + 1

    if target == nil or target == "" then
      sbar.animate(ANIM_CURVE, ANIM_DURATION, function()
        ring:set({ icon = { background = { border_color = colors.transparent } } })
      end)
      -- 次に出すときは、離れた位置から滑ってくるのではなくその場でフェードさせる
      shown = false
      return
    end

    -- ピルは番号だけの固定幅になったので、セル幅は中身で変わらない。
    -- 一度測れば使い回せる (アイコンを出していた頃は署名で破棄していた)。

    target_ws = target

    local cell = cells[target]
    if cell and anchor_x then
      -- 測らずに動き出す。タグ側の色の補間と同じイベントで始まる。
      apply(cell, shown)
      shown = true
    else
      probe(target, generation, 1)
    end
  end)

  -- ディスプレイ構成が変わると土台もセルも動くが、ワークスペースイベントは来ない。
  -- 復帰時も同様。捨てて測り直す。
  ring:subscribe({ "display_change", "system_woke" }, function()
    cells = {}
    anchor_x = nil
    generation = generation + 1
    if target_ws then
      probe(target_ws, generation, 1)
    end
  end)
end
