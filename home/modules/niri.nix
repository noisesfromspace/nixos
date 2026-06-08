{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.maatwerk.niri;

  noctalia =
    cmd:
    [
      "noctalia-shell"
      "ipc"
      "call"
    ]
    ++ (lib.splitString " " cmd);
  noctaliaStr = cmd: "noctalia-shell ipc call " + cmd;

  rotateScript =
    let
      jq = "${pkgs.jq}/bin/jq";
    in
    ''
      current=$(niri msg --json outputs | ${jq} -r '.[] | select(.name=="eDP-1") | .transform')
      if [ "$current" = "normal" ] || [ "$current" = "null" ]; then
        niri msg output eDP-1 transform 90
      else
        niri msg output eDP-1 transform normal
      fi
    '';

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

    # Escalate privileges
    services.hyprpolkitagent.enable = true;

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
      iwgtk
      oskToggle # Expose your premium virtual keyboard runner to your PATH!
    ];

    # Remove conflicting squeekboard services as wvkbd owns the space
    programs.niri = {
      # Installation is handled by hosts.desktop.enable via nixosModules.niri
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

        switch-events = {
          lid-close.action.spawn = [
            "sh"
            "-c"
            "${noctaliaStr "lockScreen lock"} && niri msg output eDP-1 off"
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
          gaps = 7;

          # Default new columns to 50% width so two windows fit side-by-side
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

        # Input settings
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

        # Key bindings
        binds = {
          # App launchers
          "Alt+W".action.spawn = [ "librewolf" ];
          "Alt+Q".action.spawn = [
            "ghostty"
            "+new-window"
          ];
          "Alt+E".action.spawn = [ "thunar" ];
          "Alt+Space".action.spawn = noctalia "launcher toggle";
          "Alt+S".action.spawn = noctalia "controlCenter toggle";

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
          "Alt+P".action.center-column = [ ];
          "Alt+9".action.set-column-width = "50%";
          "Alt+0".action.maximize-column = [ ];

          # Clipboard history
          "Ctrl+Alt+H".action.spawn = noctalia "launcher clipboard";

          # Tablet & Convertible Rotation: Swing eDP-1 monitor by 90 degrees or reset normal!
          "Mod+R".action.spawn = [
            "sh"
            "-c"
            rotateScript
          ];

          # Lock screen
          "Alt+M".action.spawn = noctalia "lockScreen lock";

          # Jump to leftmost/rightmost column
          "Alt+Home".action.focus-column-first = [ ];
          "Alt+End".action.focus-column-last = [ ];

          # Stacking / column management
          "Alt+Comma".action.consume-window-into-column = [ ];
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
            action.spawn = noctalia "volume muteOutput";
            allow-when-locked = true;
          };
          "XF86AudioPlay" = {
            action.spawn = noctalia "media playPause";
            allow-when-locked = true;
          };
          "XF86AudioNext" = {
            action.spawn = noctalia "media next";
            allow-when-locked = true;
          };
          "XF86AudioPrev" = {
            action.spawn = noctalia "media previous";
            allow-when-locked = true;
          };
          "XF86AudioRaiseVolume" = {
            action.spawn = noctalia "volume increase";
            repeat = true;
          };
          "XF86AudioLowerVolume" = {
            action.spawn = noctalia "volume decrease";
            repeat = true;
          };
        }
        // (lib.optionalAttrs cfg.isLaptop {
          # Brightness keys (locked)
          "XF86MonBrightnessDown" = {
            action.spawn = noctalia "brightness decrease";
            allow-when-locked = true;
          };
          "XF86MonBrightnessUp" = {
            action.spawn = noctalia "brightness increase";
            allow-when-locked = true;
          };
        });

        # Gestures (Niri has hardcoded touchpad gestures; only edge-scroll + hot-corners are configurable).
        gestures = {
          hot-corners.enable = true;
        };

        # Overview settings
        overview = {
          zoom = 0.5;
        };
      };
    };
  };
}
