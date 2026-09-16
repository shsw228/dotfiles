-- 起動時に aerospace list-monitors を読んで displays を分類する。
--   main_index    : sketchybar の display 1 (= macOS の main display)
--   builtin_index : Built-in Retina (MacBook 本体) の sketchybar 上の index (nil なら未接続)
--   external_indices : 外部モニタ群の sketchybar index 一覧
local function discover()
  local result = {
    main_index = 1,
    builtin_index = nil,
    external_indices = {},
  }
  local f = io.popen("/opt/homebrew/bin/aerospace list-monitors --format '%{monitor-id}|%{monitor-name}' 2>/dev/null")
  if not f then return result end
  local raw = f:read("*a") or ""
  f:close()

  -- 行を解析。main を先頭に置いて、その後を順に。
  -- AeroSpace は main を印字しないので、--mouse で引いた id を main とみなす。
  -- 起動直後はマウスが主ディスプレイに居るのが通常で、外れても下の sort で
  -- id 昇順に落ちるだけなので致命的にはならない。
  local main_id
  do
    local mf = io.popen("/opt/homebrew/bin/aerospace list-monitors --mouse --format '%{monitor-id}' 2>/dev/null")
    if mf then
      main_id = (mf:read("*a") or ""):match("%d+")
      mf:close()
    end
  end

  local entries = {}
  for line in raw:gmatch("[^\n]+") do
    local id, name = line:match("^(%d+)|(.*)$")
    if id then
      table.insert(entries, {
        id = id,
        is_main    = (id == main_id),
        is_builtin = name:find("Built%-[Ii]n") ~= nil,
        raw_line = line,
      })
    end
  end

  -- main first, then others. AeroSpace の monitor-id は左→右だが main を sketchybar index 1 にする。
  table.sort(entries, function(a, b)
    if a.is_main ~= b.is_main then return a.is_main end
    return tonumber(a.id) < tonumber(b.id)
  end)

  for i, e in ipairs(entries) do
    if e.is_builtin then
      result.builtin_index = i
    else
      table.insert(result.external_indices, i)
    end
  end
  return result
end

return discover()
