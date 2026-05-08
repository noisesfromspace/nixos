{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.maatwerk.hyprland;
  # Can't just do dpms on because nvidia sucks ass
  reloadCmd = "hyprctl --batch \"keyword monitor ${cfg.laptopMonitorName},preferred,auto,${toString cfg.laptopScalingFactor}; keyword monitor ,preferred,auto,1\"";
in
{
  imports = [
    ./desktop.nix
    ./waybar.nix
  ];

  options.maatwerk.hyprland = {
    enable = mkEnableOption "Hyprland";
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
    services.hyprpolkitagent.enable = true; # escalate privileges

    services.dunst = {
      enable = true;
      settings.global = {
        frame_width = 1;
        corner_radius = 6;
        progress_bar_corner_radius = 6;
        corners = "top-left,bottom";
        progress_bar_corners = "top-left,bottom-right";
        offset = "32x20";
        gap_size = 5;
        format = "<b>󰁕 %a</b>\n%s\n<i>%b</i>";
        mouse_left_click = "close_current";
        mouse_right_click = "context";
        alignment = "center";
        word_wrap = true;
      };
    };

    programs.satty = {
      enable = true;
      settings = {
        general = {
          output-filename = "/home/martijn/Pictures/screenshot_%Y-%m-%d_%H:%M:%S.png";
          early-exit = false;
        };
      };
    };

    home.file = {
      "${config.xdg.configHome}/hyprdynamicmonitors/config.toml".text = # toml
        ''
          [notifications]
          disabled = true

          # Dell workstation with lid closed (external only)
          [profiles.dell_closed]
          config_file = "${
            pkgs.writeText "dell-closed.conf" # bash
              ''
                monitor=${cfg.laptopMonitorName},disable
                monitor=description:U3821DW,preferred,0x0,1
              ''
          }"
          config_file_type = "static"
          [profiles.dell_closed.conditions]
          lid_state = "Closed"
          [[profiles.dell_closed.conditions.required_monitors]]
          name = "${cfg.laptopMonitorName}"
          [[profiles.dell_closed.conditions.required_monitors]]
          description = ".*U3821DW.*"
          match_description_using_regex = true

          # Dell workstation with lid open (extended desktop)
          [profiles.dell_extended]
          config_file = "${
            pkgs.writeText "dell-extended.conf" # bash
              ''
                monitor=${cfg.laptopMonitorName},preferred,auto,${toString cfg.laptopScalingFactor}
                monitor=description:U3821DW,preferred,2560x0,1
                # Pin workspaces to ensure they move correctly
                workspace=1,monitor:${cfg.laptopMonitorName}
                workspace=3,monitor:${cfg.laptopMonitorName}
                workspace=5,monitor:${cfg.laptopMonitorName}
                workspace=2,monitor:description:U3821DW
                workspace=4,monitor:description:U3821DW
                workspace=6,monitor:description:U3821DW
              ''
          }"
          config_file_type = "static"
          [profiles.dell_extended.conditions]
          lid_state = "Opened"
          [[profiles.dell_extended.conditions.required_monitors]]
          name = "${cfg.laptopMonitorName}"
          [[profiles.dell_extended.conditions.required_monitors]]
          description = ".*U3821DW.*"
          match_description_using_regex = true

          # Laptop only
          [profiles.laptop_only]
          config_file = "${pkgs.writeText "laptop.conf" ''
            monitor=${cfg.laptopMonitorName},preferred,auto,${toString cfg.laptopScalingFactor}
          ''}"
          config_file_type = "static"
          [profiles.laptop_only.conditions]
          lid_state = "Opened"
          [[profiles.laptop_only.conditions.required_monitors]]
          name = "${cfg.laptopMonitorName}"

          # External Display - Mirror (Lid Open)
          [profiles.external_mirror]
          config_file = "${pkgs.writeText "mirror.conf" ''
            monitor=,preferred,auto,1
            monitor=${cfg.laptopMonitorName},preferred,auto,1,mirror,
          ''}"
          config_file_type = "static"
          [profiles.external_mirror.conditions]
          lid_state = "Opened"
          [[profiles.external_mirror.conditions.required_monitors]]
          name = "${cfg.laptopMonitorName}"
          [[profiles.external_mirror.conditions.required_monitors]]
          description = ".*"
          match_description_using_regex = true

          # External Display - Only (Lid Closed)
          [profiles.external_only]
          config_file = "${pkgs.writeText "external.conf" ''
            monitor=${cfg.laptopMonitorName},disable
            monitor=,preferred,auto,1
          ''}"
          config_file_type = "static"
          [profiles.external_only.conditions]
          lid_state = "Closed"
          [[profiles.external_only.conditions.required_monitors]]
          name = "${cfg.laptopMonitorName}"
          [[profiles.external_only.conditions.required_monitors]]
          description = ".*"
          match_description_using_regex = true

          # Fallback (Desktop or unknown)
          [profiles.default]
          config_file = "${pkgs.writeText "default.conf" ''
            monitor=,preferred,0x0,1,transform,0
          ''}"
          config_file_type = "static"
          [profiles.default.conditions]
          [[profiles.default.conditions.required_monitors]]
          description = ".*"
          match_description_using_regex = true
        '';

      # Avatar image
      ".config/avatar.png" = {
        source = pkgs.fetchurl {
          url = "https://random.storage.boers.email/icon.png";
          hash = "sha256-YxJuLqQ4BpWKyMOTl+J09uRVuK4e0CVinXuNb5u/8aY=";
        };
      };
    };

    # HyprDynamicMonitors systemd service
    systemd.user.services.hyprdynamicmonitors = {
      Unit = {
        Description = "HyprDynamicMonitors - Dynamic monitor configuration for Hyprland";
        After = [ "hyprland-session.target" ];
        PartOf = [ "hyprland-session.target" ];
      };
      Service = {
        Type = "simple";
        ExecStart = "${lib.getExe pkgs.hyprdynamicmonitors} run --enable-lid-events --disable-power-events";
        Restart = "on-failure";
        RestartSec = 1;
      };
      Install = {
        WantedBy = [ "hyprland-session.target" ];
      };
    };

    # HyprDynamicMonitors prepare service (runs before Hyprland starts)
    systemd.user.services.hyprdynamicmonitors-prepare = {
      Unit = {
        Description = "HyprDynamicMonitors prepare - Clean up monitor config before start";
        Before = [ "hyprland-session.target" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${lib.getExe pkgs.bash} -c '>>${config.xdg.configHome}/hypr/monitors.conf; ${lib.getExe pkgs.hyprdynamicmonitors} prepare'";
      };
      Install = {
        WantedBy = [ "hyprland-session.target" ];
      };
    };

    home.packages =
      with pkgs;
      with kdePackages;
      [
        # utilities
        blueman # bluetooth
        pavucontrol # audio
        playerctl
        wlogout

        wl-clipboard # clipboard
        cliphist
        hyprmon # display settings
        iwgtk # wifi applet
        hyprdynamicmonitors # dynamic monitor configuration with lid support
      ];

    wayland.windowManager.hyprland = {
      enable = true;
      systemd = {
        enable = true;
        variables = [ "all" ]; # pass all user env variables to systemd
      };
      plugins = [ pkgs.hyprspace-custom ];
      # https://wiki.hyprland.org/Configuring/Variables/
      settings = {
        "$mod" = "ALT";
        "$prog" = "CTRL ALT";
        "$super" = "SUPER";
        exec-once = [
          "fractal &"
          "blueman-applet &"
          "systemctl --user start hyprpolkitagent &"
        ];
        "$terminal" = "ghostty +new-window";
        "$fileManager" = "thunar";
        "$browser" = "librewolf";
        "$menu" = "rofi -show combi";

        plugin.overview = {
          affectStrut = false; # re-renders citrix
          hideBackgroundLayers = true;
          hideTopLayers = true;
          hideOverlayLayers = true;
          hideRealLayers = true;
          exitOnSwitch = true;
        };

        # hyprlandhyprctl clients
        windowrule = [
          "workspace 2, match:class ^(Wfica)$" # citrix
          "workspace 5, match:class ^(Fractal)$"
          "workspace 5, match:class ^(Signal)$"

          # Set opacity active, inactive, and full screen for kitty
          "opacity 1 override 0.93 override 1 override, match:class com.mitchellh.ghostty"
        ];

        # l -> locked, will also work when an input inhibitor (e.g. a lockscreen) is active.
        # r -> release, will trigger on release of a key.
        # e -> repeat, will repeat when held.
        # n -> non-consuming, key/mouse events will be passed to the active window in addition to triggering the dispatcher.
        # m -> mouse, see below
        # t -> transparent, cannot be shadowed by other binds.
        # i -> ignore mods, will ignore modifiers.
        bindm = [
          "$mod,mouse:272,movewindow"
          "$mod,mouse:273,resizewindow"
        ];

        bindr = [
          ", XF86AudioRaiseVolume, exec, wpctl set-volume -l 1.4 @DEFAULT_AUDIO_SINK@ 3%+"
          ", XF86AudioLowerVolume, exec, wpctl set-volume -l 1.4 @DEFAULT_AUDIO_SINK@ 3%-"
        ];

        bindl = [
          ", XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
          ", XF86AudioPlay, exec, playerctl play-pause"
          ", XF86AudioNext, exec, playerctl next"
          ", XF86AudioPrev, exec, playerctl previous"
          ", XF86AudioMedia, exec, ${
            let
              osk = pkgs.writeShellScriptBin "osk" ''
                PROG="iio-hyprland"
                if ! pgrep "''${PROG}" > /dev/null; then
                  "''${PROG}" &
                else
                  pkill "''${PROG}"
                fi
              '';
            in
            lib.getExe osk
          }"
        ]
        ++ (lib.optionals cfg.isLaptop [
          ", switch:on:Lid Switch, exec, hyprctl keyword monitor \"${cfg.laptopMonitorName}, disable\"; ${lib.getExe pkgs.hyprlock}"
          ", switch:off:Lid Switch, exec, ${reloadCmd}"
          ", XF86MonBrightnessDown, exec, ${lib.getExe pkgs.brightnessctl} s 10%-"
          ", XF86MonBrightnessUp, exec, ${lib.getExe pkgs.brightnessctl}  s +10%"
        ]);

        binde = [
          "$prog, j, resizeactive, -35 0"
          "$prog, l, resizeactive, 35 0"
          "$prog, i, resizeactive, 0 -35"
          "$prog, k, resizeactive, 0 35"
        ];

        bind = [
          "$mod, W, exec, $browser"
          "$mod, Q, exec, $terminal"
          "$mod, E, exec, $fileManager"
          "$mod, Space, exec, $menu"
          '', Print, exec, ${lib.getExe pkgs.grim} -g "$(${lib.getExe pkgs.slurp})" - | satty -f -''
          ''$mod, Print, exec, ${lib.getExe pkgs.grim} -g "$(${lib.getExe pkgs.slurp})" - | ${lib.getExe pkgs.tesseract} - stdout | wl-copy''
          "$mod, F4, killactive"
          "$super, tab, overview:toggle"
          "$prog, H, exec, cliphist list | rofi -dmenu | cliphist decode | wl-copy"
          "$mod, M, exec, hyprlock"

          # movement
          # https://wiki.hyprland.org/Configuring/Dispatchers/#list-of-dispatchers
          "$mod, V, togglefloating"
          "$prog, down, workspace, -1"
          "$prog, up, workspace, +1"
          "$mod, J, movefocus, l"
          "$mod, L, movefocus, r"
          "$mod, I, movefocus, u"
          "$mod, K, movefocus, d"

          # Swap windows directionally (exchange positions)
          "$mod SHIFT, I, swapwindow, u"
          "$mod SHIFT, K, swapwindow, d"
          "$mod SHIFT, J, swapwindow, l"
          "$mod SHIFT, L, swapwindow, r"

          "$mod, O, fullscreen,"
          "$mod, P, pseudo," # dwindle
          "$mod, H, layoutmsg, togglesplit" # dwindle
        ]
        ++ (
          # Define keybindings for workspaces 1 to 6
          builtins.concatLists (
            builtins.genList (
              x:
              let
                ws = toString (x + 1); # Workspace number as a string
              in
              [
                "$mod, ${ws}, workspace, ${ws}" # Switch to workspace {ws}
                "$mod SHIFT, ${ws}, movetoworkspace, ${ws}" # Move to workspace {ws}
              ]
            ) 6
          )
        );

        # See https://wiki.hyprland.org/Configuring/Dwindle-Layout/ for more
        dwindle = {
          pseudotile = true;
          preserve_split = true;
          default_split_ratio = 1.3;
        };

        general = {
          gaps_in = 3;
          gaps_out = "5,12,12,12";
          border_size = 2;

          # Please see https://wiki.hyprland.org/Configuring/Tearing/ before you turn this on
          allow_tearing = false;
          layout = "dwindle";

          # https://github.com/danth/stylix/issues/430
          "col.active_border" = lib.mkForce "rgb(${config.lib.stylix.colors.base05})";
          "col.inactive_border" = lib.mkForce "rgb(${config.lib.stylix.colors.base02})";
        };
        input = {
          kb_layout = "us";
          repeat_rate = 40;
          repeat_delay = 450;
          touchpad = lib.mkIf cfg.isLaptop {
            natural_scroll = false;
            scroll_factor = 0.8;
          };
        };

        decoration = {
          rounding = 3;
          shadow = {
            enabled = true;
            range = 4;
            color = lib.mkForce "rgb(${config.lib.stylix.colors.base06})";
            color_inactive = "rgba(00000044)"; # transparant
          };
        };
        ecosystem = {
          no_donation_nag = true;
          no_update_news = true;
        };
        misc = {
          disable_hyprland_logo = true;
          animate_manual_resizes = false;
          animate_mouse_windowdragging = false;
          background_color = "rgb(${config.lib.stylix.colors.base00})";
          close_special_on_empty = true;
        };
      };
      extraConfig =
        lib.optionalString cfg.isLaptop ''
          gesture = 3, horizontal, workspace
          gesture = 2, pinchout, close
          gesture = 4, swipe, resize
        ''
        + ''
          # Source the config file managed by hyprdynamicmonitors.
          source = ${config.xdg.configHome}/hypr/monitors.conf

          animations {
            # https://cubic-bezier.com/
            # https://easings.net
            # https://https://www.cssportal.com/css-cubic-bezier-generator/
            enabled = true

            bezier = wind, 0.05, 0.9, 0.1, 1.05
            bezier = winIn, 0.1, 1.1, 0.1, 1.1
            bezier = winOut, 0.3, -0.3, 0, 1
            bezier = linear, 1, 1, 1, 1
            bezier = Cubic, 0.1, 0.1, 0.1, 1
            bezier = overshot, 0.05, 0.9, 0.1, 1.1
            bezier = ease-in-out, 0.17, 0.67, 0.83, 0.67
            bezier = ease-in, 0.17, 0.67, 0.83, 0.67
            bezier = ease-out, 0.42, 0, 1, 1
            bezier = easeInOutSine, 0.37, 0, 0.63, 1
            bezier = easeInSine, 0.12, 0, 0.39, 0
            bezier = easeOutSine, 0.61, 1, 0.88, 1

            animation = windowsIn, 1, 1.2, easeInOutSine, popin
            animation = windowsOut, 1, 1.2, easeInOutSine, popin
            animation = border, 1, 1.2, easeInOutSine
            animation = borderangle, 1, 30, easeInOutSine, loop
            animation = workspacesIn, 1, 2, easeInOutSine, slidefade
            animation = workspacesOut, 1, 2, easeInOutSine, slidefade
            animation = layersIn, 1, 3, easeInOutSine, fade
            animation = layersOut, 1, 3, easeInOutSine, fade
          }

          env = XDG_CURRENT_DESKTOP,Hyprland
          env = XDG_SESSION_TYPE,wayland
          env = XDG_SESSION_DESKTOP,Hyprland
          env = QT_QPA_PLATFORM,wayland;xcb
          env = QT_QPA_PLATFORMTHEME,qt5ct
        '';
    };

    services.wlsunset = {
      enable = true;
      latitude = "52.081038939033604";
      longitude = "4.306721564001391";
      temperature.night = 3000;
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
            after_sleep_cmd = "hyprctl dispatch dpms on";
            ignore_dbus_inhibit = true; # Ignore apps like browsers playing video
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
              on-timeout = "hyprctl dispatch dpms off";
              on-resume = "hyprctl dispatch dpms on";
            }
            {
              timeout = 30 * 60;
              on-timeout = if cfg.isLaptop then "systemctl suspend-then-hibernate" else "systemctl suspend";
            }
          ];
        };
    };

    programs.rofi = {
      enable = true;
      extraConfig = {
        show-icons = true;
        display-combi = " :";
        display-drun = "";
        display-window = "";
        display-run = "󰨡";
        modes = "combi,calc";
        combi-modes = "window,drun,run,emoji";
      };
      theme =
        let
          # Use `mkLiteral` for string-like values that should show without quotes
          inherit (config.lib.formats.rasi) mkLiteral;
        in
        {
          "*" = {
            width = 700;
          };
          element-icon = {
            size = mkLiteral "1.2em";
          };
        };
      plugins = with pkgs; [
        rofi-calc
        rofi-emoji
      ];
    };

    services.cliphist.enable = true;

    programs.hyprlock = {
      enable = true;
      settings = {
        general = {
          hide_cursor = true;
        };

        background = [
          {
            path = "screenshot";
            blur_passes = 4;
            blur_size = 8;
          }
        ];

        shape = [
          {
            monitor = "";
            size = "320, 280";
            rounding = 6;
            # Muted background, using base01
            color = "rgba(29, 28, 25, 0.5)";
            position = "0, 0";
            halign = "center";
            valign = "center";
            zindex = 0;

            shadow_passes = 2;
            shadow_size = 5;
            # Darkest color for shadow, using base00
            shadow_color = "rgba(13, 12, 12, 0.4)";
          }
        ];

        image = [
          {
            path = "${config.xdg.configHome}/avatar.png";
            size = 90;
            rounding = -1;
            border_size = 3;
            # Bright UI color for border, using base05
            border_color = "rgb(197, 201, 197)";
            position = "0, 65";
            halign = "center";
            valign = "center";
            zindex = 1;
          }
        ];

        "input-field" = [
          {
            size = "220, 45";
            position = "0, -55";
            halign = "center";
            valign = "center";
            zindex = 1;
            shadow_passes = 1;
            shadow_size = 2;
            monitor = "";
            dots_center = true;
            fade_on_empty = false;
            # Bright text color, using base05
            font_color = "rgb(197, 201, 197)";
            # Dark inner background, using base02 for contrast
            inner_color = "rgb(40, 39, 39)";
            # Bright outline, using base05
            outer_color = "rgb(197, 201, 197)";
            outline_thickness = 3;
            placeholder_text = "Rara...";
            rounding = 6;
            # Red for failure, using base08
            fail_color = "rgb(196, 116, 110)";
            fail_text = "<i>$FAIL <b>($ATTEMPTS)</b></i>";
            # Green for success, using base0B
            check_color = "rgb(135, 169, 135)";
            # Orange/Brown for Caps Lock, using base09
            capslock_color = "rgb(185, 141, 123)";
          }
        ];
      };
    };
  };
}
