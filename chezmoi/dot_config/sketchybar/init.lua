local home = os.getenv("HOME")
local config_dir = home .. "/.config/sketchybar"
package.path  = package.path  .. ";" .. config_dir .. "/?.lua;" .. config_dir .. "/?/init.lua"
package.cpath = package.cpath .. ";" .. home .. "/.local/share/sketchybar_lua/?.so"

require("colors")
require("settings")
require("icons")

local sbar = require("sketchybar")

sbar.begin_config()
require("bar")
require("default")
require("items")
sbar.hotload(true)
sbar.end_config()
sbar.event_loop()
