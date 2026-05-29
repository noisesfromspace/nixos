{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.maatwerk.niri;

  # Premium Wayland On-Screen Keyboard toggle helper 
  # Checks if active; launches gracefully with a clean 20% transparent slide-over alpha on first boot!
  oskToggle = pkgs.writeShellScriptBin "osk" ''
    PROG="wvkbd"
    SIGNAL="SIGRTMIN"
    if ! pgrep "''${PROG}" > /dev/null; then
        "''${PROG}" --hidden --alpha 204 &
        sleep 0.1 # Secure startup buffer
    fi
    pkill --signal "''${SIGNAL}" "''${PROG}"
  '';
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
      QSG_RENDER_LOOP = "threaded"; # Enables hardware-accelerated threaded QML render loops (smooth animations)

      # Enforces GNU Readline 
      GTK_KEY_THEME_NAME = "Emacs";
    };

    home.packages = with pkgs; [
      swaybg
      wvkbd 
      oskToggle # Expose your premium virtual keyboard runner to your PATH!
    ];

    # Remove conflicting squeekboard services as wvkbd owns the space
    programs.niri = {
      # Installation is handled by hosts.niri.enable via nixosModules.niri
      # We only configure settings here.
      settings = {
        spawn-at-startup = [
          { argv = [ "fractal" ]; }
          { argv = [ "noctalia" ]; }
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

        # We can configure layer-rules for Niri window effects such as background contrast/vibrancy.
        # Background-effect sits globally in Window rules or as an effect in layout.
        # Let's clean up any invalid layer-rules parameters, relying on Niri default rendering.

        switch-events = {
          lid-close.action.spawn = [
            "sh"
            "-c"
            "hyprlock & niri msg output eDP-1 off"
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

        # Window rules: workspace pinning + per-app tweaks
        window-rules = [
          # Catch-all: all windows get rounded corners and slight transparency
          {
            matches = [ ];
            geometry-corner-radius = {
              top-left = 6.0;
              top-right = 6.0;
              bottom-right = 6.0;
              bottom-left = 6.0;
            };
            clip-to-geometry = true;
            opacity = 0.95;
          }
          # Wfica (Citrix): fully opaque
          {
            matches = [ { app-id = "Wfica"; } ];
            open-on-workspace = "2";
            opacity = 1.0;
          }
          # LibreWolf: fully opaque
          {
            matches = [ { app-id = "librewolf"; } ];
            opacity = 1.0;
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
          # Symmetric spacing: tight inner gaps, generous outer top gap beneath Noctalia islands
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

          warp-mouse-to-focus.enable = true;
          focus-follows-mouse.enable = false;

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
            "noctalia-shell"
            "ipc"
            "call"
            "launcher"
            "toggle"
          ];
          "Alt+S".action.spawn = [
            "noctalia-shell"
            "ipc"
            "call"
            "controlCenter"
            "toggle"
          ];

          # Screenshots
          "Print".action.screenshot = [ ];
          "Alt+Print".action.screenshot-window = [ ];

          # Window management
          "Alt+F4".action.close-window = [ ];
          "Mod+C".action.close-window = [ ];
          "Mod+MouseMiddle".action.close-window = [ ];
          "Mod+Tab".action.toggle-overview = [ ];
          "Alt+V".action.toggle-window-floating = [ ];
          "Alt+O".action.fullscreen-window = [ ];
          # Make the focused column fill the workspace (not true fullscreen)
          "Alt+P".action.maximize-column = [ ];

          # Resize focused column to exactly half the output width
          "Alt+R".action.set-column-width = "50%";

          # Clipboard history
          "Ctrl+Alt+H".action.spawn = [
            "noctalia-shell"
            "ipc"
            "call"
            "launcher"
            "clipboard"
          ];
          
          # Tablet & Convertible Rotation: Swing eDP-1 monitor by 90 degrees or reset normal!
          "Mod+R".action.spawn = [ 
            "sh" 
            "-c" 
            "current=$(niri msg --json outputs | jq -r '.[] | select(.name==\"eDP-1\") | .transform'); if [ \"$current\" = \"normal\" ] || [ \"$current\" = \"null\" ]; then niri msg output eDP-1 transform 90; else niri msg output eDP-1 transform normal; fi" 
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

          # Resize (repeat) - fixed pixels for linear, predictable steps
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
              "noctalia-shell"
              "ipc"
              "call"
              "volume"
              "muteOutput"
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
              "noctalia-shell"
              "ipc"
              "call"
              "volume"
              "increase"
            ];
            repeat = true;
          };
          "XF86AudioLowerVolume" = {
            action.spawn = [
              "noctalia-shell"
              "ipc"
              "call"
              "volume"
              "decrease"
            ];
            repeat = true;
          };
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
  };
}
