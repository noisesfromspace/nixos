{
  config,
  pkgs,
  lib,
  ...
}:
with lib;
let
  # On-screen keyboard toggle for battery widget
  oskToggle = pkgs.writeShellScriptBin "osk" ''
    PROG="wvkbd"
    SIGNAL="SIGRTMIN"
    if ! pgrep "''${PROG}" > /dev/null; then
        "''${PROG}" --hidden --alpha 204 &
    fi
    pkill --signal "''${SIGNAL}" "''${PROG}"
  '';

  # WAN IP display script
  wanIP = pkgs.writeShellScriptBin "wan-ip" ''
    wan_ip=$(curl -s https://ip.boers.email)
    echo "󰖟 $wan_ip"
  '';

  khalScript =
    pkgs.writers.writePython3Bin "khal-script"
      {
        flakeIgnore = [
          "E501"
          "W293"
        ];
      } # python
      ''
        import subprocess
        import json
        import datetime
        from html import escape

        data = {}

        # Get JSON output from khal
        output = subprocess.check_output("khal list now 7days --json all", shell=True)
        output = output.decode("utf-8").strip()

        # Parse each day's events (one JSON array per line)
        days = []
        for line in output.split("\n"):
            if line.strip():
                days.append(json.loads(line))

        # Process events and count today's remaining
        today = datetime.date.today()
        now = datetime.datetime.now()
        today_remaining_count = 0
        tooltip_lines = []

        # Define colors for visual hierarchy
        COLOR_DAY = "#c4b28a"
        COLOR_TIME = "#87a987"
        COLOR_TITLE = "#c5c9c5"
        COLOR_LOCATION = "#8ba4b0"
        COLOR_DESC = "#737c73"
        COLOR_REPEAT = "#c4746e"

        day_index = 0
        for day_events in days:
            if not day_events:
                day_index += 1
                continue

            # Calculate the actual day based on the index
            current_date = today + datetime.timedelta(days=day_index)

            # Format day header: "Mon, mar 31"
            day_name = current_date.strftime("%a")
            month_name = current_date.strftime("%b").lower()
            day_str = current_date.strftime("%d")

            is_today = current_date == today
            day_prefix = "📌 " if is_today else ""
            day_header = f"<span color='{COLOR_DAY}'><b>"
            day_header += f"{day_prefix}{day_name}, {month_name} {day_str}"
            day_header += "</b></span>"
            tooltip_lines.append(day_header)

            # Separate all-day and timed events
            all_day_events = []
            timed_events = []

            for event in day_events:
                all_day = event.get("all-day", "False") == "True"
                if all_day:
                    all_day_events.append(event)
                else:
                    timed_events.append(event)

            # Process all-day events (grouped together)
            if all_day_events:
                tooltip_lines.append(f"  <span color='{COLOR_TIME}'>All day</span>")
                for event in all_day_events:
                    title = event.get("title", "")
                    location = event.get("location", "")
                    description = event.get("description", "")
                    repeat_symbol = event.get("repeat-symbol", "")

                    # Build title with location
                    title_text = escape(title)
                    if location:
                        title_text += f" <span color='{COLOR_LOCATION}'>({escape(location)})</span>"

                    # Add repeat symbol if present
                    if repeat_symbol:
                        title_text += f" <span color='{COLOR_REPEAT}'>⟳</span>"

                    tooltip_lines.append(f"    <span color='{COLOR_TITLE}'>• {title_text}</span>")

                    # Description if present
                    if description:
                        desc_truncated = escape(description[:60])
                        desc_suffix = "..." if len(description) > 60 else ""
                        desc_line = f"    <span color='{COLOR_DESC}'>📝 {desc_truncated}{desc_suffix}</span>"
                        tooltip_lines.append(desc_line)

                    # Count today's remaining all-day events
                    if is_today:
                        today_remaining_count += 1

            # Process timed events
            for event in timed_events:
                title = event.get("title", "")
                location = event.get("location", "")
                description = event.get("description", "")
                start_time = event.get("start-time", "")
                end_time = event.get("end-time", "")
                repeat_symbol = event.get("repeat-symbol", "")

                # Build time string
                time_str = f"<span color='{COLOR_TIME}'>"
                time_str += f"{start_time[:5]} - {end_time[:5]}"
                time_str += "</span>"

                # Add repeat symbol if present
                if repeat_symbol:
                    time_str += f" <span color='{COLOR_REPEAT}'>⟳</span>"

                tooltip_lines.append(f"  {time_str}")

                # Build title with location
                title_text = escape(title)
                if location:
                    title_text += f" <span color='{COLOR_LOCATION}'>({escape(location)})</span>"

                tooltip_lines.append(f"    <span color='{COLOR_TITLE}'>• {title_text}</span>")

                # Description if present
                if description:
                    desc_truncated = escape(description[:60])
                    desc_suffix = "..." if len(description) > 60 else ""
                    desc_line = f"    <span color='{COLOR_DESC}'>📝 {desc_truncated}{desc_suffix}</span>"
                    tooltip_lines.append(desc_line)

                # Count today's remaining events
                if is_today:
                    try:
                        event_hour = int(start_time[:2])
                        event_min = int(start_time[3:5])
                        event_time = now.replace(
                            hour=event_hour, minute=event_min,
                            second=0, microsecond=0
                        )
                        if event_time > now:
                            today_remaining_count += 1
                    except Exception:
                        today_remaining_count += 1

            tooltip_lines.append("")
            day_index += 1

        data["tooltip"] = "\n".join(tooltip_lines).strip()
        data["text"] = f"{today_remaining_count}"
        print(json.dumps(data))
      '';

  # Quick settings menu
  quickSettings = pkgs.writeShellScriptBin "quick-settings" ''
    # Define options with icons
    options="⌨️  Keyboard"

    # Show wofi menu with larger font/padding for touch
    chosen=$(echo -e "$options" | wofi \
      --dmenu \
      --hide-search \
      --insensitive \
      --prompt "" \
      --width 300 \
      --height 100 \
      --cache-file /dev/null \
      --style ${pkgs.writeText "wofi-quicksettings.css" ''
        #entry {
          padding: 20px;
          font-size: 20px;
        }
      ''})

    # Execute based on selection
    case "$chosen" in
      "⌨️  Keyboard")
        ${lib.getExe oskToggle}
        ;;
    esac
  '';

  workspaceModule = "niri/workspaces";
  windowModule = "niri/window";

  workspaceConfig = {
    all-outputs = false;
    format = "{icon}";
    format-icons = {
      "1" = "󰹈";
      "2" = "󰭆";
      "3" = "󱌚";
      "4" = "";
      "5" = "";
      "6" = "󰻈";
    };
  };
in
{
  config = mkIf config.maatwerk.niri.enable {
    programs.wofi = {
      enable = true; # settings menu
      settings = {
        single_click = true;
      };
    };
    programs.waybar = {
      enable = true;
      systemd.enable = true;
      style = # css
        ''
          @define-color base00 #0d0c0c;
          @define-color base01 #1d1c19;
          @define-color base02 #282727;
          @define-color base03 #737c73;
          @define-color base04 #a6a69c;
          @define-color base05 #c5c9c5;
          @define-color base06 #7a8382;
          @define-color base07 #c5c9c5;
          @define-color base08 #c4746e;
          @define-color base09 #b98d7b;
          @define-color base0A #c4b28a;
          @define-color base0B #87a987;
          @define-color base0C #8ea4a2;
          @define-color base0D #8ba4b0;
          @define-color base0E #8992a7;
          @define-color base0F #a292a3;

          * {
            min-height: 0;
            font-family: ${config.stylix.fonts.monospace.name};
            font-size: ${toString config.stylix.fonts.sizes.terminal}px;
            border: none;
            border-radius: 0;
          }

          window#waybar {
            background: transparent;
            color: @base03;
            transition-property: background-color;
            transition-duration: 0.5s;
          }

          #custom-power, #custom-quick-settings, #workspaces, #custom-notification,
          #custom-wan, #custom-khal,  #window, #clock-privacy, #system-stats, #system-tray {
              background: @base01;
              border: 1px solid @base02;
              border-radius: 6px;
              margin: 0 4px 0 0;
              padding: 5px 12px;
              font-weight: 600;
              transition: background-color 0.3s ease;
          }

          #custom-power:hover, #custom-quick-settings:hover, #custom-notification:hover,
          #custom-wan:hover, #custom-khal:hover, #window:hover, #clock-privacy:hover,
          #system-stats:hover, #system-tray:hover, #mpris:hover {
            background: @base02;
          }

          #custom-power {
            color: @base0A;
            padding-left: 15px;
            padding-right: 15px;
            border-right: 1px solid @base03;
            margin-right: 0;
            border-top-right-radius: 0;
            border-bottom-right-radius: 0;
          }

          #window {
            color: @base05;
          }

          #custom-notification,
          #custom-wan, #custom-khal  {
            color: @base04;
          }

          #custom-quick-settings {
            color: @base0C;
            padding-left: 15px;
            padding-right: 20px;
            border-top-left-radius: 0;
            border-bottom-left-radius: 0;
            border-left: none;
            margin-left: 0;
          }

          #workspaces {
            padding: 4px 8px;
          }

          #workspaces button {
            color: @base0A;
            font-weight: 600;
            margin: 0;
            background-color: transparent;
            transition: all 0.3s ease;
            padding: 0 4px;
          }

          #workspaces button:hover {
            background-color: @base02;
            border-radius: 6px;
          }

          #workspaces button.active {
            color: @base03;
            background-color: @base0A;
            border-radius: 6px;
          }

          #workspaces button.urgent { color: @base08; }
          #workspaces button.empty { color: @base03; }
          #workspaces button.focused {
            color: @base03;
            background-color: @base0A;
            border-radius: 6px;
          }

          window#waybar.empty #window {
              background-color: transparent;
              border-color: transparent;
          }

          tooltip {
            background-color: @base01;
            border: 1px solid @base02;
            border-radius: 6px;
            padding: 10px;
          }

          tooltip label {
            color: @base05;
          }

          #battery.charging { color: @base0B; }
          #battery.warning:not(.charging) { color: @base0A }
          #battery.critical:not(.charging) { color: @base08; }
          #network.disconnected { color: @base08; }

          #clock, #privacy, #cpu, #temperature, #disk, #idle_inhibitor,
          #memory, #battery, #wireplumber, #pulseaudio, #bluetooth, #network {
            background: transparent;
            border: none;
            color: @base04;
            padding: 0;
          }

          #clock {
            font-weight: 700;
          }

          #privacy {
            border-left: 1px solid @base03;
            padding-left: 10px;
            margin-left: 10px;
          }

          #network {
            padding-right: 8px;
          }

           #battery, #idle_inhibitor, #bluetooth, #cpu, #disk, #temperature, #wireplumber {
            border-right: 1px solid @base03;
            padding-right: 10px;
            margin-right: 10px;
          }

          #mpris {
            background: transparent;
            border: none;
            color: @base04;
            padding: 0 4px 0 0;
            border-left: 1px solid @base03;
            padding-left: 10px;
            margin-left: 10px;
            transition: color 0.3s ease;
          }

          #mpris:hover {
            color: @base05;
          }

          #mpris.playing {
            color: @base0B;
          }

          #mpris.paused {
            color: @base0A;
          }

          #mpris.stopped {
            color: @base03;
          }
        '';
      settings = [
        {
          layer = "top";
          position = "top";
          margin-left = 12;
          margin-right = 12;
          margin-top = 5;
          spacing = 0;

          modules-left = [
            "custom/power"
            "custom/quick-settings"
            "custom/khal"
            workspaceModule
            windowModule
          ];
          modules-center = [
            "group/clock-privacy"
          ];
          modules-right = [
            "custom/wan"
            "group/system-stats"
            "group/system-tray"
          ];

          "${workspaceModule}" = workspaceConfig;

          "${windowModule}" = {
            format = "{}";
          };

          clock = {
            interval = 60;
            format = "{:%a %b %d <b>%H:%M</b>}";
            tooltip-format = "<big>{calendar}</big>";
            calendar = {
              mode = "month";
              mode-mon-col = 3;
              weeks-pos = "right";
              on-scroll = 1;
              format = {
                months = "<span color='#ffcb6b'><b>{}</b></span>";
                weekdays = "<span color='#b2ccd6'><b>{}</b></span>";
                weeks = "<span color='#585b70'><b>W{}</b></span>";
                days = "<span color='#eeffff'><b>{}</b></span>";
                today = "<span color='#f38ba8'><b><u>{}</u></b></span>";
              };
            };
            actions = {
              on-click-right = "mode";
              on-scroll-up = "shift_up";
              on-scroll-down = "shift_down";
            };
          };

          cpu = {
            interval = 2;
            format = "  {usage}%";
            min-length = 6;
            tooltip = true;
            tooltip-format = "<b>CPU</b>\nLoad: {load}%\nFrequency: {avg_frequency} GHz";
          };

          network = {
            format-wifi = "󱚻";
            format-ethernet = "󰈀";
            format-disconnected = "󱘖";
            tooltip = true;
            tooltip-format-wifi = "<b>{essid}</b>\nSignal Strength: {signalStrength}%";
            on-click = "iwgtk";
          };

          bluetooth = {
            format = " {status}";
            format-connected = " {num_connections}";
            tooltip = true;
            tooltip-format = "Bluetooth: {status}";
            tooltip-format-connected = "<b>{device_alias}</b>\nBattery: {device_battery_percentage}%";
            on-click = "blueman-manager";
          };

          "group/system-tray" = {
            orientation = "horizontal";
            modules = [
              "wireplumber"
              "battery"
              "bluetooth"
              "network"
            ];
          };

          "group/clock-privacy" = {
            orientation = "horizontal";
            modules = [
              "idle_inhibitor"
              "clock"
              "privacy"
              "mpris"
            ];
          };

          "group/system-stats" = {
            orientation = "horizontal";
            modules = [
              "cpu"
              "temperature"
              "disk"
              "memory"
            ];
          };

          idle_inhibitor = {
            format = "{icon}";
            format-icons = {
              activated = " ";
              deactivated = " ";
            };
          };

          memory = {
            interval = 2;
            format = "  {}%";
          };

          battery = {
            interval = 2;
            states = {
              warning = 25;
              critical = 10;
            };
            format = "  {capacity}%";
            format-charging = "󱐋 {capacity}%";
            format-warning = "󰚥 {capacity}%";
            format-critical = "󱗗 {capacity}%";
          };

          disk = {
            interval = 15;
            format = "󰋊 {percentage_used}%";
            path = "/";
          };

          wireplumber = {
            format = "{icon}  {volume}%";
            format-bluetooth = "{icon}  {volume}% 󰂯";
            format-bluetooth-muted = "󰖁 {icon} 󰂯";
            format-muted = "󰖁 {format_source}";
            format-source = "{volume}% ";
            format-source-muted = "";
            format-icons = {
              headphone = "󰋋";
              hands-free = "󱡒";
              headset = "󰋎";
              phone = "";
              portable = "";
              car = "";
              default = [
                ""
                ""
                ""
              ];
            };
            on-click = "pavucontrol";
          };

          "custom/power" = {
            tooltip = false;
            format = "{icon}";
            format-icons = "⏻";
            exec-on-event = "true";
            on-click = "wlogout";
          };

          "custom/quick-settings" = {
            tooltip = false;
            format = "{icon}";
            format-icons = "";
            exec-on-event = "true";
            on-click = lib.getExe quickSettings;
          };

          "custom/khal" = {
            format = "󰨲 {}";
            tooltip = true;
            interval = 300;
            exec = lib.getExe khalScript;
            return-type = "json";
          };

          "custom/wan" = {
            tooltip = false;
            exec = lib.getExe wanIP;
            interval = 5;
          };

          temperature = {
            "hwmon-path" = "/sys/class/hwmon/hwmon1/temp2_input";
            format = "󰈸 {temperatureC}°C";
          };

          mpris = {
            format = "{status_icon}";
            status-icons = {
              playing = "";
              paused = "";
              stopped = "";
            };
            tooltip = true;
            tooltip-format = "{artist} - {title}\nAlbum: {album}\nPlayer: {player}";
            tooltip-interval = 50;
            interval = 1;
          };

          privacy = {
            icon-size = 14;
            icon-spacing = 5;
            modules = [
              {
                type = "screenshare";
                tooltip = true;
              }
              {
                type = "audio-in";
                tooltip = true;
              }
            ];
          };

          "custom/sepp" = {
            format = "|";
          };
        }
      ];
    };
  };
}
