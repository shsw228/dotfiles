{ pkgs, ... }:

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
      on-focus-changed = [ "move-mouse window-lazy-center" ];
      after-startup-command = [
        "exec-and-forget borders active_color=0xffe1e3e4 inactive_color=0xff494d64 width=5.0"
      ];

      gaps = {
        inner = {
          horizontal = 10;
          vertical = 10;
        };
        outer = {
          top = 10;
          bottom = 10;
          left = 10;
          right = 10;
        };
      };

      mode = {
        main.binding = {
          alt-h = "focus --boundaries-action wrap-around-the-workspace left";
          alt-j = "focus --boundaries-action wrap-around-the-workspace down";
          alt-k = "focus --boundaries-action wrap-around-the-workspace up";
          alt-l = "focus --boundaries-action wrap-around-the-workspace right";

          alt-shift-s = "exec-and-forget screencapture -i -c";
          alt-shift-tab = "move-workspace-to-monitor --wrap-around next";
          alt-tab = "workspace-back-and-forth";

          alt-shift-h = "move left";
          alt-shift-j = "move down";
          alt-shift-k = "move up";
          alt-shift-l = "move right";

          alt-f = "fullscreen";
          alt-slash = "layout tiles horizontal vertical";
          alt-space = "layout floating tiling";

          alt-1 = "workspace 1";
          alt-2 = "workspace 2";
          alt-3 = "workspace 3";
          alt-4 = "workspace 4";
          alt-5 = "workspace 5";
          alt-6 = "workspace 6";
          alt-7 = "workspace 7";
          alt-8 = "workspace 8";
          alt-9 = "workspace 9";
          alt-0 = "workspace 10";

          alt-r = "mode resize";
          alt-m = "mode move";
          cmd-h = [ ];
          cmd-alt-h = [ ];
        };

        move.binding = {
          alt-1 = [
            "move-node-to-workspace 1"
            "mode main"
          ];
          alt-2 = [
            "move-node-to-workspace 2"
            "mode main"
          ];
          alt-3 = [
            "move-node-to-workspace 3"
            "mode main"
          ];
          alt-4 = [
            "move-node-to-workspace 4"
            "mode main"
          ];
          alt-5 = [
            "move-node-to-workspace 5"
            "mode main"
          ];
          alt-6 = [
            "move-node-to-workspace 6"
            "mode main"
          ];
          alt-7 = [
            "move-node-to-workspace 7"
            "mode main"
          ];
          alt-8 = [
            "move-node-to-workspace 8"
            "mode main"
          ];
          alt-9 = [
            "move-node-to-workspace 9"
            "mode main"
          ];
          alt-0 = [
            "move-node-to-workspace 10"
            "mode main"
          ];
          enter = "mode main";
          esc = "mode main";
        };

        resize.binding = {
          h = "resize width -50";
          j = "resize height +50";
          k = "resize height -50";
          l = "resize width +50";
          enter = "mode main";
          esc = "mode main";
        };
      };

      workspace-to-monitor-force-assignment = {
        "1" = "main";
        "2" = "main";
        "3" = "main";
        "4" = "main";
        "5" = "main";
        "6" = "built-in";
        "7" = "built-in";
        "8" = "built-in";
        "9" = "built-in";
        "10" = "built-in";
        Cintiq = "^Wacom";
        Media = "^Wacom";
      };

      on-window-detected = [
        {
          "if".app-id = "jp.co.celsys.CLIPSTUDIOPAINT";
          run = [ "move-node-to-workspace Cintiq" ];
        }
        {
          "if".window-title-regex-substring = "YouTube";
          run = [ "move-node-to-workspace Media" ];
        }
      ];
    };
  };
}
