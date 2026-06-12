-- SF Symbols (Monaspace NF にグリフが入っている前提)
return {
  clock   = "􀐬",
  battery = {
    ["100"] = "􀛨",
    ["75"]  = "􀺸",
    ["50"]  = "􀺶",
    ["25"]  = "􀛩",
    ["0"]   = "􀛪",
    charging = "􀢋",
  },
  wifi = {
    connected    = "􀙇",
    disconnected = "􀙈",
  },
  volume = {
    ["100"] = "􀊨",
    ["66"]  = "􀊧",
    ["33"]  = "􀊥",
    ["10"]  = "􀊡",
    ["0"]   = "􀊣",
  },
  layout = {
    tiling   = "􀏝",
    floating = "􀎮",
  },
  audio = {
    speaker    = "􀊥",
    headphones = "􀑈",
    airpods    = "􀺹",
    bluetooth  = "􀋨",
  },
  -- app_id → 表示アイコン。bridge から流れてくる TAG_APPS_N を yashiki.lua がここで引く。
  -- マッチしないものは default を表示。
  app = {
    ["com.google.Chrome"]         = "􀆪",     -- globe
    ["net.imput.helium"]          = "􀆪",
    ["com.mitchellh.ghostty"]     = "􀩼",    -- terminal
    ["com.apple.Terminal"]        = "􀩼",
    ["com.apple.dt.Xcode"]        = "󰣦",   -- MDI hammer
    ["com.apple.iphonesimulator"] = "􀟝",   -- iphone
    ["com.openai.codex"]          = "􀇻",    -- sparkles
    ["md.obsidian"]               = "􀉛",    -- doc.text
    ["com.microsoft.VSCode"]      = "􀙎",    -- chevron.left.slash.chevron.right
    ["com.spotify.client"]        = "􀫀",    -- music.note
    ["com.tinyspeck.slackmacgap"] = "􀒲",    -- bubble.left.and.bubble.right
    ["com.hnc.Discord"]           = "􀒲",
    ["com.danpristupov.Fork"]     = "􀙱",    -- arrow.triangle.branch
    ["com.1password.1password"]   = "􀎠",    -- lock
    ["com.apple.systempreferences"] = "􀣋",  -- gearshape
    ["com.apple.finder"]            = "􀂒",  -- folder
    ["com.apple.mail"]              = "􀍕",  -- envelope
    ["com.apple.Notes"]             = "􀉛",  -- doc.text
    ["com.apple.Music"]             = "􀫀",  -- music.note
    ["com.apple.Preview"]           = "􀏅",  -- doc.richtext
    ["com.apple.AppStore"]          = "􀍗",  -- bag
    default                         = "􀀁",    -- small dot
  },
}
