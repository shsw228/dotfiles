-- 起動時に外部コマンドの実体パスを引いて固定化する。
-- sketchybar の click_script は別 shell で実行されるため絶対パスで渡したい。
local function which(cmd)
  local f = io.popen("command -v " .. cmd .. " 2>/dev/null")
  if not f then return cmd end
  local path = (f:read("*l") or ""):gsub("%s+$", "")
  f:close()
  if path == "" then return cmd end
  return path
end

return {
  paddings = 3,
  font = {
    text  = "Monaspace Neon",
    icons = "Monaspace Neon",
  },
  paths = {
    yashiki    = which("yashiki"),
    sketchybar = which("sketchybar"),
  },
}
