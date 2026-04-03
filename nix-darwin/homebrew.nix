{ username, ... }:

{
  nix-homebrew = {
    enable = true;
    enableRosetta = true;
    user = username;
    autoMigrate = true;
  };

  homebrew = {
    enable = true;
    user = username;
    enableZshIntegration = true;
    onActivation.cleanup = "uninstall";
    taps = [
      "arto-app/tap"
      "dzirtusss/tap"
      "felixkratz/formulae"
      "getsentry/xcodebuildmcp"
      "kyome22/tap"
      "lihaoyun6/tap"
      "shsw228/tap"
      "yammerjp/tap"
    ];
    brews = [
      "aria2"
      "git-flow"
      "hidapi"
      "lazygit"
      "libusb"
      "lua"
      "make"
      "mint"
      "neovim"
      "node"
      "nowplaying-cli"
      "pnpm"
      "switchaudio-osx"
      "tig"
      "winetricks"
      "felixkratz/formulae/borders"
      "felixkratz/formulae/sketchybar"
      "getsentry/xcodebuildmcp/xcodebuildmcp"
      "kyome22/tap/luca"
      "yammerjp/tap/pdef"
    ];
    casks = [
      "1password"
      "1password-cli"
      "lihaoyun6/tap/airbattery"
      "alt-tab"
      "altserver"
      "arto-app/tap/arto"
      "betterdisplay"
      "clip-studio-paint"
      "codex"
      "copilot-cli"
      "discord"
      "font-hack-nerd-font"
      "font-moralerspace"
      "fork"
      "ghostty"
      "google-chrome"
      "hammerspoon"
      "hazeover"
      "karabiner-elements"
      "keycastr"
      "kicad"
      "notchnook"
      "obsidian"
      "qlmarkdown"
      "raycast"
      "sf-symbols"
      "syntax-highlight"
      "thaw"
      "vial"
      "dzirtusss/tap/vifari"
      "visual-studio-code"
      "shsw228/tap/vpn-mierukun"
    ];
  };
}
