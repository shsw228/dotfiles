{
  self,
  ...
}:
{
  system = {
    stateVersion = "6";
    configurationRevision = self.rev or self.dirtyRev or null;
  };
  nixpkgs.hostPlatform = "aarch64-darwin";

  nix.enable = false;

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
      show-process-indicators = true; # Dockにアプリの起動中インジケーターを表示
      show-recents = false; # 最近使用したアプリをDockに表示しない
      launchanim = false; # アプリ起動時のアニメーションを無効化
      mineffect = "scale"; # 最小化のエフェクトをスケールに設定
    };
    screencapture = {
      target = "clipboard"; # スクリーンショットをクリップボードに保存
      disable-shadow = true; # スクリーンショットのウィンドウの影を無効化
    };
  };
}
