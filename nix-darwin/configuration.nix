{
  pkgs,
  username,
  homeDirectory,
  self,
  ...
}:
{
  system = {
    stateVersion = "6";
    configurationRevision = self.rev or self.dirtyRev or null;
    primaryUser = username;
  };
  users.users.${username}.home = homeDirectory;
  imports = [
    ./aerospace.nix
    ./homebrew.nix
    ./home_manager.nix
    ./notchnook.nix
    ./raycast.nix
  ];

  nixpkgs.hostPlatform = "aarch64-darwin";
  nixpkgs.config.allowUnfree = true;

  fonts.packages = with pkgs; [
    hack-font
    moralerspace
    nerd-fonts.hack
  ];

  nix.enable = false;
  environment.systemPackages = with pkgs; [
    # GUI applications
    _1password-gui
    discord
    ghostty-bin
    google-chrome
    raycast
    vscode
    wezterm
  ];

  programs.zsh.enable = true;
  security.pam.services.sudo_local.touchIdAuth = true;

  system.defaults = {
    NSGlobalDomain = {
      # キーボード
      NSAutomaticCapitalizationEnabled = false; # 文頭の自動大文字化を無効化
      NSAutomaticPeriodSubstitutionEnabled = false; # ピリオドの自動置換を無効化
      NSAutomaticSpellingCorrectionEnabled = false; # スペル自動修正を無効化
      NSAutomaticDashSubstitutionEnabled = false; # ダッシュの自動置換を無効化
      NSAutomaticQuoteSubstitutionEnabled = false; # クォートの自動置換を無効化

      # UI
      AppleInterfaceStyle = "Dark"; # ダークモードを有効化
      NSWindowResizeTime = 0.001; # ウィンドウのリサイズ速度を高速化

    };

    finder = {
      AppleShowAllExtensions = true; # 拡張子を常に表示
      AppleShowAllFiles = true; # 隠しファイルを表示
      FXDefaultSearchScope = "SCcf"; # デフォルトの検索範囲を現在のフォルダに設定
      ShowPathbar = true; # パスバーを表示
      FXPreferredViewStyle = "Nlsv"; # デフォルトの表示スタイルをリストビューに設定
      FXEnableExtensionChangeWarning = false; # 拡張子変更の警告を無効化
    };

    dock = {
      autohide = true; # Dockを自動的に隠す
      expose-group-apps = true; # App Exposéで同一アプリのウィンドウをまとめる
      show-process-indicators = true; # Dockにアプリの起動中インジケーターを表示
      show-recents = false; # 最近使用したアプリをDockに表示しない
      launchanim = false; # アプリ起動時のアニメーションを無効化
      mineffect = "scale"; # 最小化のエフェクトをスケールに設定
      mru-spaces = false; # Spacesの自動並び替えを無効化
      orientation = "bottom"; # Dockを画面下に配置
      tilesize = 35; # Dockアイコンのサイズ
      persistent-apps = [ ]; # Dock左側の固定アプリを置かない
    };
    spaces = {
      spans-displays = false; # ディスプレイごとに個別の操作スペースを無効化
    };
    screencapture = {
      target = "clipboard"; # スクリーンショットをクリップボードに保存
      disable-shadow = true; # スクリーンショットのウィンドウの影を無効化
    };

    CustomUserPreferences = {
      "com.apple.dock" = {
        "wvous-br-corner" = 0;
        "wvous-br-modifier" = 0;
      };
    };
  };
}
