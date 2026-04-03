{
  pkgs,
  username,
  homeDirectory,
  self,
  ...
}:
let
  opCli = "/opt/homebrew/bin/op";
  opConfigDir = "${homeDirectory}/.config/1password";
  opServiceAccountTokenFile = "${opConfigDir}/service-account-token";
  opServiceAccountTokenRef = "op://Personal/Machine Bootstrap/service_account_token";
  notchNookLicenseRefBase = "op://machine-secrets/NotchNook License";
in
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
  ];

  nixpkgs.hostPlatform = "aarch64-darwin";

  nix.enable = false;

  programs.zsh.enable = true;
  security.pam.services.sudo_local.touchIdAuth = true;

  system.activationScripts.postActivation.text = ''
    if [ -x "${opCli}" ]; then
      service_account_token=""

      if [ -r "${opServiceAccountTokenFile}" ]; then
        service_account_token=$(/usr/bin/head -n 1 "${opServiceAccountTokenFile}" 2>/dev/null || true)
      fi

      if [ -z "$service_account_token" ]; then
        bootstrap_token=$(/usr/bin/sudo -u ${username} env HOME=${homeDirectory} ${opCli} read '${opServiceAccountTokenRef}' 2>/dev/null || true)

        if [ -n "$bootstrap_token" ]; then
          /usr/bin/sudo -u ${username} /bin/mkdir -p "${opConfigDir}"
          /usr/bin/sudo -u ${username} /bin/sh -c 'umask 077 && printf %s "$1" > "$2"' -- "$bootstrap_token" "${opServiceAccountTokenFile}"
          service_account_token="$bootstrap_token"
        fi
      fi

      notch_nook_email=""
      notch_nook_key=""

      if [ -n "$service_account_token" ]; then
        notch_nook_email=$(/usr/bin/sudo -u ${username} env HOME=${homeDirectory} OP_SERVICE_ACCOUNT_TOKEN="$service_account_token" ${opCli} read '${notchNookLicenseRefBase}/email' 2>/dev/null || true)
        notch_nook_key=$(/usr/bin/sudo -u ${username} env HOME=${homeDirectory} OP_SERVICE_ACCOUNT_TOKEN="$service_account_token" ${opCli} read '${notchNookLicenseRefBase}/license_key' 2>/dev/null || true)
      fi

      if [ -n "$notch_nook_email" ] && [ -n "$notch_nook_key" ]; then
        notch_nook_key_active=$(${pkgs.jq}/bin/jq -cn \
          --arg email "$notch_nook_email" \
          --arg key "$notch_nook_key" \
          '{ email: $email, key: $key }')

        /usr/bin/sudo -u ${username} env HOME=${homeDirectory} \
          /usr/bin/defaults write lo.cafe.NotchNook keyActive -string "$notch_nook_key_active"
      fi
    fi
  '';

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
      "com.apple.symbolichotkeys" = {
        AppleSymbolicHotKeys = {
          # 入力ソース切り替え系
          "31" = {
            enabled = false;
            value = {
              type = "standard";
              parameters = [ 52 21 1835008 ];
            };
          };
          # Mission Control / Exposé 系
          "34" = {
            enabled = false;
            value = {
              type = "standard";
              parameters = [ 65535 126 2490368 ];
            };
          };
          "35" = {
            enabled = false;
            value = {
              type = "standard";
              parameters = [ 65535 125 2490368 ];
            };
          };
          # デスクトップ表示系
          "37" = {
            enabled = false;
            value = {
              type = "standard";
              parameters = [ 65535 103 131072 ];
            };
          };
          # 入力ソース切り替え系
          "51" = {
            enabled = false;
            value = {
              type = "standard";
              parameters = [ 64 33 1572864 ];
            };
          };
          # キーボード輝度系
          "55" = {
            enabled = false;
            value = {
              type = "standard";
              parameters = [ 65535 107 524288 ];
            };
          };
          "56" = {
            enabled = false;
            value = {
              type = "standard";
              parameters = [ 65535 113 524288 ];
            };
          };
          # メディア / ファンクションキー系
          "62" = {
            enabled = false;
            value = {
              type = "standard";
              parameters = [ 65535 111 0 ];
            };
          };
          "63" = {
            enabled = false;
            value = {
              type = "standard";
              parameters = [ 65535 111 131072 ];
            };
          };
          # Dock 表示切り替え
          "70" = {
            enabled = false;
            value = {
              type = "standard";
              parameters = [ 100 2 1310720 ];
            };
          };
          # システム標準ショートカット
          "73" = {
            enabled = false;
            value = {
              type = "standard";
              parameters = [ 65535 53 1048576 ];
            };
          };
          # Spaces 間移動
          "80" = {
            enabled = false;
            value = {
              type = "standard";
              parameters = [ 65535 123 8781824 ];
            };
          };
          "82" = {
            enabled = false;
            value = {
              type = "standard";
              parameters = [ 65535 124 8781824 ];
            };
          };
          # 入力ソース切り替え
          "156" = {
            enabled = false;
            value = {
              type = "standard";
              parameters = [ 65535 49 393216 ];
            };
          };
        };
      };
    };
  };
}
