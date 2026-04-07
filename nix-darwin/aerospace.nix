{ pkgs, ... }:

let
  workspaces = {
    browser = "1.Chrome";
    terminal = "2.Terminal";
    xcode = "3.Xcode";
    ai = "4.AI";
    "5" = "5";
    "6" = "6";
    "7" = "7";
    "8" = "8";
    "9" = "9";
    "10" = "10";
  };
  mainMonitorPattern = [
    "^DELL U4025QW$"
    "main"
  ];
  subMonitorPattern = [
    "secondary"
    "main"
  ];
  workspaceArg = workspace: "\"${workspace}\"";
  borderWidth = "5.0";
  tilingActiveColor = "0xffe1e3e4";
  floatingActiveColor = "0xfff5a97f";
  inactiveBorderColor = "0xff494d64";
  updateBorderColorCommand =
    ''exec-and-forget /bin/zsh -lc "layout=\$(aerospace list-windows --focused --format '%{window-layout}' 2>/dev/null); if [ \"\$layout\" = floating ]; then borders active_color=${floatingActiveColor} inactive_color=${inactiveBorderColor} width=${borderWidth}; else borders active_color=${tilingActiveColor} inactive_color=${inactiveBorderColor} width=${borderWidth}; fi"'';

  mainBinding = {
    alt-h = "focus --boundaries-action wrap-around-the-workspace left";
    alt-j = "focus --boundaries-action wrap-around-the-workspace down";
    alt-k = "focus --boundaries-action wrap-around-the-workspace up";
    alt-l = "focus --boundaries-action wrap-around-the-workspace right";

    alt-shift-s = "exec-and-forget screencapture -i -c";
    alt-shift-tab = "focus-monitor --wrap-around next";
    alt-tab = "workspace-back-and-forth";

    alt-shift-h = "move left";
    alt-shift-j = "move down";
    alt-shift-k = "move up";
    alt-shift-l = "move right";

    alt-f = "fullscreen";
    alt-slash = "layout tiles horizontal vertical";
    alt-space = "layout floating tiling";

    alt-1 = "workspace ${workspaceArg workspaces.browser}";
    alt-2 = "workspace ${workspaceArg workspaces.terminal}";
    alt-3 = "workspace ${workspaceArg workspaces.xcode}";
    alt-4 = "workspace ${workspaceArg workspaces.ai}";
    alt-5 = "workspace ${workspaceArg workspaces."5"}";
    alt-6 = "workspace ${workspaceArg workspaces."6"}";
    alt-7 = "workspace ${workspaceArg workspaces."7"}";
    alt-8 = "workspace ${workspaceArg workspaces."8"}";
    alt-9 = "workspace ${workspaceArg workspaces."9"}";
    alt-0 = "workspace ${workspaceArg workspaces."10"}";

    alt-r = "mode resize";
    alt-m = "mode move";
    cmd-h = [ ];
    cmd-alt-h = [ ];
  };

  moveToWorkspace = workspace: [
    "move-node-to-workspace ${workspaceArg workspace}"
    "mode main"
  ];

  moveBinding = {
    alt-1 = moveToWorkspace workspaces.browser;
    alt-2 = moveToWorkspace workspaces.terminal;
    alt-3 = moveToWorkspace workspaces.xcode;
    alt-4 = moveToWorkspace workspaces.ai;
    alt-5 = moveToWorkspace workspaces."5";
    alt-6 = moveToWorkspace workspaces."6";
    alt-7 = moveToWorkspace workspaces."7";
    alt-8 = moveToWorkspace workspaces."8";
    alt-9 = moveToWorkspace workspaces."9";
    alt-0 = moveToWorkspace workspaces."10";
    enter = "mode main";
    esc = "mode main";
  };

  resizeBinding = {
    h = "resize width -50";
    j = "resize height +50";
    k = "resize height -50";
    l = "resize width +50";
    enter = "mode main";
    esc = "mode main";
  };

  workspaceAssignments = {
    ${workspaces.browser} = mainMonitorPattern;
    ${workspaces.terminal} = mainMonitorPattern;
    ${workspaces.xcode} = mainMonitorPattern;
    ${workspaces.ai} = mainMonitorPattern;
    ${workspaces."5"} = subMonitorPattern;
    ${workspaces."6"} = mainMonitorPattern;
    ${workspaces."7"} = mainMonitorPattern;
    ${workspaces."8"} = mainMonitorPattern;
    ${workspaces."9"} = mainMonitorPattern;
    ${workspaces."10"} = mainMonitorPattern;
    Cintiq = "^Wacom";
  };

  mkWorkspaceRule = appId: workspace: {
    "if".app-id = appId;
    run = [ "move-node-to-workspace ${workspaceArg workspace}" ];
  };

  windowCategories = {
    browser = {
      workspace = workspaces.browser;
      appIds = [
        "com.google.Chrome"
      ];
    };
    terminal = {
      workspace = workspaces.terminal;
      appIds = [
        "com.mitchellh.ghostty"
        "com.apple.Terminal"
      ];
    };
    xcode = {
      workspace = workspaces.xcode;
      appIds = [
        "com.apple.dt.Xcode"
        "com.apple.iphonesimulator"
      ];
    };
    ai = {
      workspace = workspaces.ai;
      appIds = [
        "com.openai.codex"
      ];
    };
  };

  mkCategoryRules = category:
    builtins.map
      (appId: mkWorkspaceRule appId category.workspace)
      category.appIds;

  windowRules = [
    {
      "if".app-id = "com.google.Chrome";
      check-further-callbacks = true;
      run = [
        "layout floating"
        "move-node-to-workspace ${workspaceArg windowCategories.browser.workspace}"
      ];
    }
  ]
  ++ mkCategoryRules windowCategories.terminal
  ++ mkCategoryRules windowCategories.browser
  ++ mkCategoryRules windowCategories.xcode
  ++ mkCategoryRules windowCategories.ai
  ++ [
    {
      "if".app-id = "com.apple.iphonesimulator";
      check-further-callbacks = true;
      run = [
        "layout tiling"
        "move-node-to-workspace ${workspaceArg windowCategories.xcode.workspace}"
      ];
    }
    {
      "if".app-id = "jp.co.celsys.CLIPSTUDIOPAINT";
      run = [ "move-node-to-workspace Cintiq" ];
    }
  ];
in

{
  services.aerospace = {
    enable = true;
    package = pkgs.aerospace;
    settings = {
      enable-normalization-flatten-containers = true;
      enable-normalization-opposite-orientation-for-nested-containers = true;

      default-root-container-layout = "tiles";
      default-root-container-orientation = "horizontal";
      automatically-unhide-macos-hidden-apps = true;
      on-focus-changed = [
        "move-mouse window-lazy-center"
        updateBorderColorCommand
      ];
      after-startup-command = [
        "exec-and-forget borders active_color=${tilingActiveColor} inactive_color=${inactiveBorderColor} width=${borderWidth}"
        updateBorderColorCommand
      ];

      gaps = {
        outer = {
          top = 5;
          bottom = 5;
          left = 5;
          right = 5;
        };
      };

      mode = {
        main.binding = mainBinding;
        move.binding = moveBinding;
        resize.binding = resizeBinding;
      };

      workspace-to-monitor-force-assignment = workspaceAssignments;
      on-window-detected = windowRules;
    };
  };
}
