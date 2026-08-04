local sbar = require("sketchybar")
local colors = require("colors")
local settings = require("settings")
local yashiki = require("items.yashiki")
local outputs = require("items.yashiki_outputs")
local anchor = require("items.yashiki_ring_anchor")

-- 可視タグが1つのとき、そのセルを囲むリングを描き、切り替えで横にスライドさせる。
-- 可視タグが複数のときは1つでは表せないので隠す。
--
-- リングは items/yashiki_ring_anchor.lua の 1px 土台の icon.background として描き、
-- 位置は icon.background.x_offset、幅は icon.width で動かす。どちらも補間可能で
-- (実測: 途中で新しい目標を与えても現在値から反転なしで繋がる)、レイアウトを
-- 通らないため、リングの移動が他の item を動かすことも、他の item の伸縮が
-- リングを動かすこともない。
--
-- 以前は「後ろに item が無い位置に置いて負の padding で動かす」方式だったが、
-- 土台の位置が手前の front_app のラベル幅に依存し、タグ切り替え = 前面アプリの
-- 切り替えと同時に土台ごと横へ飛ぶため、あさっての方向へ動いてから戻る動きが
-- 出ていた。土台をタグ列より前に固定したことでこの依存は構造的に消えている。
--
-- 動く量は「対象セルの x - 土台の x」。土台はタグ列より前なので、タグのアイコンの
-- 増減 (セル幅が変わる) でも動かない。セル矩形だけをアイコンの署名をキーに
-- キャッシュし、キャッシュがあれば測らずに色の補間と同じイベントで動き出す。

local ANIM_CURVE = yashiki.anim.curve
local ANIM_DURATION = yashiki.anim.duration
local SKETCHYBAR = settings.paths.sketchybar

-- アニメーションが終わってから測るための待ち (tick は 1/60 秒)
local SETTLE_DELAY = string.format("%.2f", ANIM_DURATION / 60 + 0.1)

-- 対象タグのセルと土台を1回のシェル呼び出しで測る
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
  local ring_id = "yashiki.ring.d" .. out.sb_display
  local active_key = "OUTPUT_" .. out.yashiki_id .. "_ACTIVE_TAGS"
  local display_key = "display-" .. out.sb_display

  local cells = {}       -- タグ番号 -> { x, w }
  local cells_sig = nil  -- タグ列の内容の署名。変わればセル幅も変わる
  local anchor_x = nil   -- 土台の左端。ディスプレイ構成でしか動かない
  local shown = false    -- リングが出ているか
  local target_tag = nil -- いま囲んでいるタグ
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
    local target_id = "yashiki." .. target .. ".d" .. out.sb_display
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

  ring:subscribe("yashiki_workspace_change", function(env)
    local active = tonumber(env[active_key]) or 0
    local target = yashiki.single_active_tag(active)
    generation = generation + 1

    if not target then
      sbar.animate(ANIM_CURVE, ANIM_DURATION, function()
        ring:set({ icon = { background = { border_color = colors.transparent } } })
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
    cells_sig = nil
    anchor_x = nil
    generation = generation + 1
    if target_tag then
      probe(target_tag, generation, 1)
    end
  end)
end
