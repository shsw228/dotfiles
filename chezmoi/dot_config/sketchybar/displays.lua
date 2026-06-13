-- 起動時に yashiki list-outputs を読んで displays を分類する。
--   main_index    : sketchybar の display 1 (= macOS の main display)
--   builtin_index : Built-in Retina (MacBook 本体) の sketchybar 上の index (nil なら未接続)
--   external_indices : 外部モニタ群の sketchybar index 一覧
local function discover()
  local result = {
    main_index = 1,
    builtin_index = nil,
    external_indices = {},
  }
  local f = io.popen("/opt/homebrew/bin/yashiki list-outputs 2>&1")
  if not f then return result end
  local raw = f:read("*a") or ""
  f:close()

  -- 行を解析。main を先頭に置いて、その後を順に。
  local entries = {}
  for line in raw:gmatch("[^\n]+") do
    local id = line:match("^(%d+):")
    if id then
      table.insert(entries, {
        id = id,
        is_main    = line:find("%(main%)") ~= nil,
        is_builtin = line:find("Built%-[Ii]n") ~= nil,
        raw_line = line,
      })
    end
  end

  -- main first, then others. yashiki output order: ID 昇順だが main をsketchybar index 1 にする。
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
