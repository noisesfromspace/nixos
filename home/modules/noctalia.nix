{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:
with lib;
{
  config = mkIf config.maatwerk.niri.enable {
    home.file = {
      # Avatar image used by Noctalia
      ".config/avatar.png" = {
        source = pkgs.fetchurl {
          url = "https://random.storage.boers.email/icon.png";
          hash = "sha256-YxJuLqQ4BpWKyMOTl+J09uRVuK4e0CVinXuNb5u/8aY=";
        };
      };

      # Download and place your gorgeous default wallpaper into the monitored Wallpapers drawer!
      "Pictures/Wallpapers/default_wallpaper.jpg" = {
        source = pkgs.fetchurl {
          url = "https://random.storage.boers.email/wallpaper_optimized.jpg";
          hash = "sha256-7tCkOYseY4Oayw+WHxn+fK45BdOjRaELYPp33m9+UYI="; # Let's fetch directly from your server!
        };
      };
    };

    programs.noctalia-shell = {
      enable = true;
      systemd.enable = true;
      package = inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default.override {
        calendarSupport = true;
      };

      settings = {
        bar = {
          # Beautiful floating island layouts inside Noctalia v4!
          floating = true;
          position = "top";
          density = "default";
          showOutline = false;
          showCapsule = true;
          
          # Cohesive unified rendering (disable separate opacity logic)
          useSeparateOpacity = false;

          # Default background colors (Niri's layer rules will scale the final alpha to 85%)
          backgroundOpacity = lib.mkForce 1.00; 
          capsuleOpacity = lib.mkForce 1.00;
          outerCorners = true;

          # Match Niri's sharp modern 6.0px corners
          radius = 6;
          frameRadius = 6;
          
          # Spacing gaps around the floating bar (supports 0-18px offsets in v4)
          # Snug to top bezel, letting Niri's outer top gap create the room below!
          marginVertical = 6;
          marginHorizontal = 7;
          widgetSpacing = 10; # Beautiful snug separation gaps between capsules (was 12)
          contentPadding = 2; # Sleek, compact height for the visual bar (was 4)
          outerPadding = 0;   # Restore compact flush alignments (was 4)
          fontScale = 1.04;   # Mild legibility text increase without inflating bar height!

          # Stop windows from bleeding under the bar segment (creates clean empty buffer)
          enableExclusionZoneInset = false;
          exclusionZoneOffset = false;
          
          widgets = {
            left = [
              { id = "Launcher"; }
              { id = "Workspace"; }
              { id = "ActiveWindow"; }
            ];
            center = [
              { id = "Clock"; }
              { id = "KeepAwake"; }
            ];
            right = [
              { id = "Tray"; }
              { id = "NotificationHistory"; }
              { id = "Battery"; }
              { id = "Volume"; }
              { id = "Brightness"; }
              { 
                id = "CustomButton"; 
                icon = "keyboard"; 
                tooltip = "Toggle On-Screen Keyboard";
                # Triggers your native high-performance virtual keyboard toggler!
                leftClickExec = "osk";
                rightClickExec = "osk";
              }
              { id = "PowerProfile"; } # Direct battery-saver / high-performance scaling slider!
              { id = "ControlCenter"; }
            ];
          };
        };

        # Force the Control Center dropdown to slide down in the absolute screen middle (HUD style!)
        controlCenter = {
          position = "center";
        };

        # Align bottom app dock (Niri's layer rules will scale the final alpha to 85%)
        dock = {
          enabled = true;
          dockType = "floating"; # Stands floatingly above the bottom border
          backgroundOpacity = lib.mkForce 1.00; # We let Niri's forced layer-rules own the rendering!
        };

        general = {
          compactLockScreen = false;
          lockOnSuspend = true;
          
          # Hyper fast 400% animation scaling for buttery-smooth rapid slides (snappy yet fluid!)
          animationDisabled = false;
          animationSpeed = 4.0; 
          avatarImage = "/home/martijn/.config/avatar.png";
          
          # Match Niri window consistency (Semi-square, sharp, no fake rounded display corners)
          showScreenCorners = false;
          radiusRatio = 0.3; # Clamp popup containers & cards to elegant semi-square structures
          
          enableBlurBehind = true;
          enableShadows = true;

          # Stylized lockscreen clock & behavior
          clockStyle = "custom";
          clockFormat = "hh\nmm";
          lockScreenBlur = 8;
          lockScreenTint = 0.3;
          enableLockScreenMediaControls = true;
          showSessionButtonsOnLockScreen = true;
        };

        audio = {
          volumeOverdrive = true;
        };

        appLauncher = {
          enableClipboardHistory = true;
          enableClipPreview = true;
          enableClipboardChips = true;
          enableClipboardDateHeaders = true;
          enableClipboardSmartIcons = true;
          
          # Launcher Micro-Optimizations & Power-User Niceties
          terminalCommand = "ghostty -e"; # Wraps CLI binaries instantly inside Ghostty
          sortByMostUsed = true;          # Learns your frequency to sort daily apps first
          ignoreInitialMousePosition = true; # Stops mouse-drifts on pop-up from stealing keys
          iconMode = "native";            # Syncs system app icons onto launcher plates
          
          # Deep Search Modules
          enableWindowsSearch = true;     # Quick window search & focus switcher
          enableSettingsSearch = true;    # Direct setting adjustment in-launcher
          enableSessionSearch = true;     # Quickly activate lock, logout, or sleep commands
          
          pinnedApps = [
            "ghostty.desktop"
            "firefox.desktop"
          ];
        };

        # Map your personal wallpapers folder to the native picker!
        wallpaper = {
          enabled = true;
          directory = "/home/martijn/Pictures/Wallpapers";
          viewMode = "grid";
          transitionType = [
            "fade"
            "pixelate"
            "honeycomb"
          ];
        };

        # Spacious, highly-visible notification styling
        notifications = {
          respectExpireTimeout = true;
          density = "comfortable"; # Big, elegant cards with perfect typography
          sounds.enabled = false;
          offset_x = 24; # Pushed safely in from the right edge
          offset_y = 12; # Pushed safely down from the status gaps
          
          # Generous alert slide display timing (expressed in seconds)
          lowUrgencyDuration = 6;
          normalUrgencyDuration = 10;
          criticalUrgencyDuration = 20;
        };

        # Gorgeous scheduling screen warming night light
        nightLight = {
          enabled = true;
          nightTemp = "3200";
          dayTemp = "6500";
          autoSchedule = true;
        };

        # Weather engine with realistic rain/snow visual particle effects
        weather = {
          enabled = true;
          auto_locate = false;
          address = "The Hague, Netherlands";
          refresh_minutes = 30;
          unit = "metric";
        };

        location = {
          name = "The Hague, Netherlands";
          autoLocate = false; # Explicit geocoding preference
          showCalendarEvents = true; # Queries Evolution Data Server natively
          showCalendarWeather = true; # Overlays temperature forecasts into calendar slots
        };

        idle = {
          enabled = true;
          screenOffTimeout = 600; # 10 mins
          lockTimeout = 660;      # 11 mins
          suspendTimeout = 1800;  # 30 mins
        };
      };
    };
  };
}
