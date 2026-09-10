{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.maatwerk.niri;

  dms =
    args:
    [
      "dms"
      "ipc"
      "call"
    ]
    ++ args;
in
{
  options.maatwerk.niri = {
    enable = mkEnableOption "Niri";
    isLaptop = mkOption {
      type = types.bool;
      default = false;
      description = "Whether this host is a laptop.";
    };
    laptopScalingFactor = mkOption {
      type = types.float;
      default = 1.0;
      description = "Scaling factor for the laptop monitor.";
    };
  };

  config = mkIf cfg.enable {
    maatwerk.desktop.enable = true;

    # Escalate privileges
    services.hyprpolkitagent.enable = true;

    # Compositor-agnostic wayland session variables
    home.sessionVariables = {
      XDG_CURRENT_DESKTOP = "Niri";
      XDG_SESSION_TYPE = "wayland";
      XDG_SESSION_DESKTOP = "Niri";
      QT_QPA_PLATFORM = "wayland;xcb";
      _JAVA_AWT_WM_NONREPARENTING = "1"; # ghidra + java apps
      QT_QPA_PLATFORMTHEME = "qt5ct";
      QSG_RENDER_LOOP = "threaded"; # Enables hardware-accelerated threaded QML render loops (smooth animations)
      GTK_KEY_THEME_NAME = "Emacs"; # Enforces GNU Readline
    };

    home.packages = with pkgs; [
      wvkbd
    ];

    programs.niri = {
      settings = {
        spawn-at-startup = [
          {
            argv = [
              "systemctl"
              "--user"
              "start"
              "hyprpolkitagent"
            ];
          }
        ];

        # Xwayland integration
        xwayland-satellite = {
          enable = true;
        };

        clipboard = {
          disable-primary = false;
        };

        prefer-no-csd = true;

        # Disable default hotkey overlay on startup
        hotkey-overlay = {
          skip-at-startup = true;
        };

        cursor = {
          hide-when-typing = true;
          hide-after-inactive-ms = 1000;
        };

        # Screenshot path
        screenshot-path = "~/Pictures/screenshot_%Y-%m-%d_%H:%M:%S.png";

        # Output configuration
        outputs = mkIf cfg.isLaptop {
          "eDP-1" = {
            scale = cfg.laptopScalingFactor;
          };
        };

        switch-events = {
          lid-close.action.spawn = dms [
            "lockAndOutputsOff"
          ];
          lid-open.action.spawn = [
            "sh"
            "-c"
            "sleep 1; niri msg output eDP-1 on"
          ];
          tablet-mode-on.action.spawn = [
            "sh"
            "-c"
            "squeekboard &"
          ];
          tablet-mode-off.action.spawn = [
            "sh"
            "-c"
            "pkill squeekboard"
          ];
        };

        # Window rules: per-app tweaks
        window-rules = [
          # Catch-all: DMS-managed corners, subtle transparency, background blur
          {
            matches = [ ];
            clip-to-geometry = true;
            opacity = 0.87;
            background-effect = {
              blur = true;
              xray = true;
            };
          }
          # Wfica (Citrix): fully opaque
          {
            matches = [ { app-id = "Wfica"; } ];
            opacity = 1.0;
          }
          # LibreWolf: fully opaque
          {
            matches = [ { app-id = "librewolf"; } ];
            opacity = 1.0;
          }
          {
            matches = [ { app-id = "QEMU (omarchy)"; } ];
            opacity = 1.0;
          }
        ];

        layout = {
          gaps = 8;
          always-center-single-column = true;

          # Default new columns to 50% width so two windows fit side-by-side
          default-column-width = {
            proportion = 0.5;
          };

          focus-ring = {
            enable = true;
            width = 2;
            active = {
              color = config.lib.stylix.colors.withHashtag.base08;
            };
            inactive = {
              color = "#2a2927";
            };
          };

          insert-hint = {
            enable = true;
            display.color = config.lib.stylix.colors.withHashtag.base08;
          };

          shadow = {
            enable = true;
            color = config.lib.stylix.colors.withHashtag.base08;
            spread = 0;
            inactive-color = "#00000066";
          };
        };

        # Input settings
        input = {
          keyboard = {
            xkb.layout = "us";
            repeat-rate = 40;
            repeat-delay = 450;
          };

          warp-mouse-to-focus.enable = true;
          focus-follows-mouse.enable = false;
          mod-key = "Alt";

          touchpad = lib.mkIf cfg.isLaptop {
            natural-scroll = true;
            scroll-factor = 0.5;
          };
        };

        # Key bindings
        binds = {
          # App launchers
          "Alt+W".action.spawn = [ "librewolf" ];
          "Alt+Q".action.spawn = [
            "ghostty"
            "+new-window"
          ];
          "Alt+E".action.spawn = [ "thunar" ];
          "Alt+C".action.spawn = [
            "dcal"
            "toggle"
          ];

          # DankMaterialShell
          "Alt+Space".action.spawn = dms [
            "spotlight-bar"
            "toggle"
          ];
          "Ctrl+Alt+Space".action.spawn = dms [
            "spotlight"
            "toggle"
          ];
          "Alt+N".action.spawn = dms [
            "notifications"
            "toggle"
          ];
          "Alt+S".action.spawn = dms [
            "settings"
            "focusOrToggle"
          ];
          "Alt+X".action.spawn = dms [
            "powermenu"
            "toggle"
          ];
          "Alt+Z".action.spawn = dms [
            "bar"
            "toggle"
            "id"
            "default"
          ];
          "Alt+Shift+P".action.spawn = dms [
            "powerprofile"
            "toggle"
          ];
          "Ctrl+Alt+N".action.spawn = dms [
            "night"
            "toggle"
          ];

          # Screenshots
          "Print".action.spawn = dms [
            "quickCapture"
            "screenshot"
            "region"
            "edit"
          ];

          # Window management
          "Alt+Backslash".action.close-window = [ ];
          "Alt+F4".action.close-window = [ ];
          "Alt+MouseMiddle".action.close-window = [ ];
          "Alt+Semicolon".action.toggle-overview = [ ];
          "Alt+A".action.toggle-overview = [ ];
          "Alt+V".action.toggle-window-floating = [ ];
          "Alt+O".action.fullscreen-window = [ ];
          "Alt+P".action.center-column = [ ];
          "Alt+9".action.set-column-width = "50%";
          "Alt+0".action.maximize-column = [ ];

          # Clipboard history
          "Ctrl+Alt+H".action.spawn = dms [
            "clipboard"
            "toggle"
          ];

          # Lock screen
          "Alt+M".action.spawn = dms [
            "lock"
            "lock"
          ];

          # Stacking / column management
          "Alt+Comma".action.consume-window-into-column = [ ];
          "Alt+Period".action.expel-window-from-column = [ ];

          # Movement (column-based tiling)
          "Alt+J".action.focus-column-left = [ ];
          "Alt+L".action.focus-column-right = [ ];
          "Alt+I".action.focus-window-or-workspace-or-monitor-up = [ ];
          "Alt+K".action.focus-window-or-workspace-or-monitor-down = [ ];

          "Alt+Shift+J".action.move-column-left = [ ];
          "Alt+Shift+L".action.move-column-right = [ ];
          "Alt+Shift+I".action.move-window-to-workspace-up = [ ];
          "Alt+Shift+K".action.move-window-to-workspace-down = [ ];

          "Alt+6".action.focus-workspace-previous = [ ];

          # Resize (repeat) - fixed pixels for linear, predictable steps
          "Ctrl+Alt+J" = {
            action.set-column-width = "-128";
            repeat = true;
          };
          "Ctrl+Alt+L" = {
            action.set-column-width = "+128";
            repeat = true;
          };
          "Ctrl+Alt+I" = {
            action.set-window-height = "+128";
            repeat = true;
          };
          "Ctrl+Alt+K" = {
            action.set-window-height = "-128";
            repeat = true;
          };

          # Workspace switching
          "Alt+1".action.focus-workspace = 1;
          "Alt+2".action.focus-workspace = 2;
          "Alt+3".action.focus-workspace = 3;
          "Alt+4".action.focus-workspace = 4;
          "Alt+5".action.focus-workspace = 5;

          "Ctrl+Alt+Up".action.focus-workspace-up = [ ];
          "Ctrl+Alt+Down".action.focus-workspace-down = [ ];

          "Alt+Shift+1".action.move-column-to-workspace = 1;
          "Alt+Shift+2".action.move-column-to-workspace = 2;
          "Alt+Shift+3".action.move-column-to-workspace = 3;
          "Alt+Shift+4".action.move-column-to-workspace = 4;
          "Alt+Shift+5".action.move-column-to-workspace = 5;
          "Alt+Shift+6".action.move-column-to-workspace = 6;

          # Mouse wheel: Alt+scroll to move between columns
          "Alt+WheelScrollUp" = {
            action.focus-column-left = [ ];
            cooldown-ms = 150;
          };
          "Alt+WheelScrollDown" = {
            action.focus-column-right = [ ];
            cooldown-ms = 150;
          };
          # Audio and media
          "XF86AudioRaiseVolume" = {
            action.spawn = dms [
              "audio"
              "increment"
              "3"
            ];
            allow-when-locked = true;
            repeat = true;
          };
          "XF86AudioLowerVolume" = {
            action.spawn = dms [
              "audio"
              "decrement"
              "3"
            ];
            allow-when-locked = true;
            repeat = true;
          };
          "XF86AudioMute" = {
            action.spawn = dms [
              "audio"
              "mute"
            ];
            allow-when-locked = true;
          };
          "XF86AudioMicMute" = {
            action.spawn = dms [
              "mic"
              "mute"
            ];
            allow-when-locked = true;
          };
          "XF86AudioPlay" = {
            action.spawn = dms [
              "mpris"
              "playPause"
            ];
            allow-when-locked = true;
          };
          "XF86AudioPause" = {
            action.spawn = dms [
              "mpris"
              "playPause"
            ];
            allow-when-locked = true;
          };
          "XF86AudioNext" = {
            action.spawn = dms [
              "mpris"
              "next"
            ];
            allow-when-locked = true;
          };
          "XF86AudioPrev" = {
            action.spawn = dms [
              "mpris"
              "previous"
            ];
            allow-when-locked = true;
          };

          # Brightness
          "XF86MonBrightnessUp" = {
            action.spawn = dms [
              "brightness"
              "increment"
              "5"
              ""
            ];
            allow-when-locked = true;
            repeat = true;
          };
          "XF86MonBrightnessDown" = {
            action.spawn = dms [
              "brightness"
              "decrement"
              "5"
              ""
            ];
            allow-when-locked = true;
            repeat = true;
          };
        };

        # Gestures (Niri has hardcoded touchpad gestures; only edge-scroll + hot-corners are configurable).
        gestures = {
          hot-corners.enable = true;
        };

        # Overview settings
        overview = {
          zoom = 0.5;
        };

        # Disable built-in Alt+Tab recent-windows switcher so keys pass through to Citrix
        recent-windows.enable = false;
      };
    };
  };
}
