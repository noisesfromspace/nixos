{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.maatwerk.niri;
in
{
  imports = [
    ./desktop.nix
  ];

  options.maatwerk.niri = {
    enable = mkEnableOption "Niri";
    isLaptop = mkOption {
      type = types.bool;
      default = false;
      description = "Whether this host is a laptop.";
    };
    laptopMonitorName = mkOption {
      type = types.str;
      default = "eDP-1";
      description = "Name of the laptop monitor output.";
    };
    laptopScalingFactor = mkOption {
      type = types.float;
      default = 1.0;
      description = "Scaling factor for the laptop monitor.";
    };
  };

  config = mkIf cfg.enable {
    maatwerk.desktop.enable = true;

    # Compositor-agnostic wayland session variables
    home.sessionVariables = {
      XDG_CURRENT_DESKTOP = "Niri";
      XDG_SESSION_TYPE = "wayland";
      XDG_SESSION_DESKTOP = "Niri";
      QT_QPA_PLATFORM = "wayland;xcb";
      QT_QPA_PLATFORMTHEME = "qt5ct";
    };

    home.packages = with pkgs; [
      swaybg
    ];

    programs.niri = {
      # Installation is handled by hosts.niri.enable via nixosModules.niri
      # We only configure settings here.
      settings = {
        spawn-at-startup = [
          {
            argv = [
              "swaybg"
              "-i"
              "${config.stylix.image}"
              "-m"
              "fill"
            ];
          }
          { argv = [ "fractal" ]; }
          { argv = [ "blueman-applet" ]; }
          {
            argv = [
              "systemctl"
              "--user"
              "start"
              "hyprpolkitagent"
            ];
          }
        ];

        # Xwayland integration (auto since niri 25.08, needs xwayland-satellite in PATH)
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

        # Screenshot path
        screenshot-path = "~/Pictures/screenshot_%Y-%m-%d_%H:%M:%S.png";

        # Output configuration
        outputs = mkIf cfg.isLaptop {
          "${cfg.laptopMonitorName}" = {
            scale = cfg.laptopScalingFactor;
          };
        };

        switch-events = {
          lid-close.action.spawn = [
            "sh"
            "-c"
            "hyprlock | niri msg output eDP-1 off"
          ];
          lid-open.action.spawn = [ "niri msg output eDP-1 on" ];
        };

        # Window rules: workspace pinning + per-app tweaks
        window-rules = [
          {
            matches = [ ];
            geometry-corner-radius = {
              top-left = 6.0;
              top-right = 6.0;
              bottom-right = 6.0;
              bottom-left = 6.0;
            };
            clip-to-geometry = true;
          }
          {
            matches = [ { app-id = "Wfica"; } ];
            open-on-workspace = "2";
          }
          {
            matches = [ { app-id = "Fractal"; } ];
            open-on-workspace = "5";
          }
          {
            matches = [ { app-id = "Signal"; } ];
            open-on-workspace = "5";
          }
          {
            matches = [ { app-id = "com.mitchellh.ghostty"; } ];
            opacity = 0.97;
          }
        ];

        layout = {
          # Single value for all gaps (inner + outer)
          gaps = 5;

          # Default new columns to 50% width so two windows fit side-by-side
          # without horizontal scrolling.
          default-column-width = {
            proportion = 0.5;
          };

          focus-ring = {
            enable = true;
            width = 2;
            active = {
              color = "#c4b28a";
            };
            inactive = {
              color = "#2a2927";
            };
          };

          insert-hint = {
            enable = true;
            display.color = "#c4b28a";
          };

          shadow = {
            enable = true;
            color = "rgba(0 0 0 0.06)";
            inactive-color = "rgba(0 0 0 0.03)";
          };
        };

        # Input settings (ported from hyprland)
        input = {
          keyboard = {
            xkb.layout = "us";
            repeat-rate = 40;
            repeat-delay = 450;
          };

          warp-mouse-to-focus = true;

          focus-follows-mouse.enable = true;

          touchpad = lib.mkIf cfg.isLaptop {
            natural-scroll = true;
            scroll-factor = 0.8;
          };
        };

        # Key bindings (ported from hyprland)
        binds = {
          # App launchers
          "Alt+W".action.spawn = "librewolf";
          "Alt+Q".action.spawn = [
            "ghostty"
            "+new-window"
          ];
          "Alt+E".action.spawn = "thunar";
          "Alt+Space".action.spawn = [
            "rofi"
            "-show"
            "combi"
          ];

          # Screenshots
          "Print".action.screenshot = [ ];
          "Alt+Print".action.screenshot-window = [ ];

          # Window management
          "Alt+F4".action.close-window = [ ];
          "Mod+Tab".action.toggle-overview = [ ];
          "Alt+V".action.toggle-window-floating = [ ];
          "Alt+O".action.fullscreen-window = [ ];
          # Make the focused column fill the workspace (not true fullscreen)
          "Alt+P".action.maximize-column = [ ];

          # Resize focused column to exactly half the output width
          "Alt+R".action.set-column-width = "50%";

          # Clipboard history
          "Ctrl+Alt+H".action.spawn = [
            "sh"
            "-c"
            "cliphist list | rofi -dmenu | cliphist decode | wl-copy"
          ];

          # Lock screen
          "Alt+M".action.spawn = "hyprlock";

          # Jump to leftmost/rightmost column
          "Alt+Home".action.focus-column-first = [ ];
          "Alt+End".action.focus-column-last = [ ];

          # Stacking / column management
          # In Niri, windows stack vertically *within* a column.
          # To pull the window to the right into the current column (stack it):
          "Alt+Comma".action.consume-window-into-column = [ ];
          # To remove the focused window from the stack, making it its own column:
          "Alt+Period".action.expel-window-from-column = [ ];

          # Movement (column-based tiling)
          "Alt+J".action.focus-column-left = [ ];
          "Alt+L".action.focus-column-right = [ ];
          "Alt+I".action.focus-window-up = [ ];
          "Alt+K".action.focus-window-down = [ ];

          "Alt+Shift+J".action.move-column-left = [ ];
          "Alt+Shift+L".action.move-column-right = [ ];
          "Alt+Shift+I".action.move-window-up = [ ];
          "Alt+Shift+K".action.move-window-down = [ ];

          # Resize (repeat) — fixed pixels for linear, predictable steps
          # Note: J/L resize the COLUMN width (all windows in the column together).
          #       I/K resize window height within a column (only when ≥2 windows are stacked).
          "Ctrl+Alt+J" = {
            action.set-column-width = "-128";
            repeat = true;
          };
          "Ctrl+Alt+L" = {
            action.set-column-width = "+128";
            repeat = true;
          };
          "Ctrl+Alt+I" = {
            action.set-window-height = "-128";
            repeat = true;
          };
          "Ctrl+Alt+K" = {
            action.set-window-height = "+128";
            repeat = true;
          };

          # Workspace switching (1-6)
          "Alt+1".action.focus-workspace = 1;
          "Alt+2".action.focus-workspace = 2;
          "Alt+3".action.focus-workspace = 3;
          "Alt+4".action.focus-workspace = 4;
          "Alt+5".action.focus-workspace = 5;
          "Alt+6".action.focus-workspace = 6;

          "Ctrl+Alt+Up".action.focus-workspace-up = [ ];
          "Ctrl+Alt+Down".action.focus-workspace-down = [ ];

          "Alt+Shift+1".action.move-column-to-workspace = 1;
          "Alt+Shift+2".action.move-column-to-workspace = 2;
          "Alt+Shift+3".action.move-column-to-workspace = 3;
          "Alt+Shift+4".action.move-column-to-workspace = 4;
          "Alt+Shift+5".action.move-column-to-workspace = 5;
          "Alt+Shift+6".action.move-column-to-workspace = 6;

          # Mouse wheel: Alt+scroll to move between columns
          "Mod+WheelScrollUp" = {
            action.focus-column-left = [ ];
            cooldown-ms = 150;
          };
          "Mod+WheelScrollDown" = {
            action.focus-column-right = [ ];
            cooldown-ms = 150;
          };
          "XF86AudioMute" = {
            action.spawn = [
              "wpctl"
              "set-mute"
              "@DEFAULT_AUDIO_SINK@"
              "toggle"
            ];
            allow-when-locked = true;
          };
          "XF86AudioPlay" = {
            action.spawn = [
              "playerctl"
              "play-pause"
            ];
            allow-when-locked = true;
          };
          "XF86AudioNext" = {
            action.spawn = [
              "playerctl"
              "next"
            ];
            allow-when-locked = true;
          };
          "XF86AudioPrev" = {
            action.spawn = [
              "playerctl"
              "previous"
            ];
            allow-when-locked = true;
          };
          "XF86AudioRaiseVolume" = {
            action.spawn = [
              "wpctl"
              "set-volume"
              "-l"
              "1.4"
              "@DEFAULT_AUDIO_SINK@"
              "3%+"
            ];
            repeat = true;
          };
          "XF86AudioLowerVolume" = {
            action.spawn = [
              "wpctl"
              "set-volume"
              "-l"
              "1.4"
              "@DEFAULT_AUDIO_SINK@"
              "3%-"
            ];
            repeat = true;
          };
          # TODO: XF86AudioMedia was used for iio-hyprland toggle. Needs replacement for niri.
        }
        // (lib.optionalAttrs cfg.isLaptop {
          # Brightness keys (locked)
          "XF86MonBrightnessDown" = {
            action.spawn = [
              "brightnessctl"
              "s"
              "10%-"
            ];
            allow-when-locked = true;
          };
          "XF86MonBrightnessUp" = {
            action.spawn = [
              "brightnessctl"
              "s"
              "+10%"
            ];
            allow-when-locked = true;
          };
        });

        # Gestures (Niri has hardcoded touchpad gestures; only edge-scroll + hot-corners are configurable).
        # Native touchpad gestures:
        #   3-finger vertical swipe   → switch workspaces
        #   3-finger horizontal swipe → horizontal view scroll
        #   4-finger vertical swipe   → toggle overview
        # Lost from Hyprland (no Niri equivalent):
        #   2-finger pinch → close window
        #   4-finger swipe → resize window
        gestures = {
          hot-corners.enable = true;
        };

        # Overview settings
        overview = {
          # Niri overview zoom; 0.5 is a reasonable default
          zoom = 0.5;
        };
      };
    };

    services.hypridle = {
      enable = true;
      settings =
        let
          lockCmd = lib.getExe pkgs.hyprlock;
          notifyCmd = lib.getExe pkgs.libnotify;
        in
        {
          general = {
            # Niri auto-handles monitor power on resume; no after_sleep_cmd needed
            ignore_dbus_inhibit = true;
            lock_cmd = lockCmd;
          };

          listener = [
            {
              timeout = (5 * 60) - 15;
              on-timeout = "${notifyCmd} 'Locking in 15 seconds...' -t 15000 -u critical";
            }
            {
              timeout = 5 * 60;
              on-timeout = lockCmd;
            }
            {
              timeout = 15 * 60;
              on-timeout = "niri msg action power-off-monitors";
              # Niri auto-wakes monitors on input; no on-resume needed
            }
            {
              timeout = 30 * 60;
              on-timeout = if cfg.isLaptop then "systemctl suspend-then-hibernate" else "systemctl suspend";
            }
          ];
        };
    };
  };
}
