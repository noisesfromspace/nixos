{
  config,
  pkgs,
  lib,
  ...
}:
with lib;
let
  calendarRoot = "${config.home.homeDirectory}/.local/share/calendars";
  dcal = lib.getExe config.programs.dank-calendar.package;
  dcalAccountSetup = pkgs.writeShellScript "dcal-account-setup" ''
    set -euo pipefail

    calendar_root=${lib.escapeShellArg calendarRoot}
    ${pkgs.coreutils}/bin/mkdir -p "$calendar_root"

    if ${dcal} --json account list \
      | ${pkgs.jq}/bin/jq -e --arg root "$calendar_root" \
        'any(.[]; .kind == "local" and .settings.root == $root)' >/dev/null; then
      exit 0
    fi

    ${dcal} account add local "$calendar_root" --name Radicale
  '';
in
{
  config = mkIf config.maatwerk.niri.enable {
    home.file = {
      # Avatar image used by DankMaterialShell
      ".config/avatar.png" = {
        source = pkgs.fetchurl {
          url = "https://random.storage.boers.email/icon.png";
          hash = "sha256-YxJuLqQ4BpWKyMOTl+J09uRVuK4e0CVinXuNb5u/8aY=";
        };
      };

      "Pictures/Wallpapers/wallhaven_l3w6yr.jpg" = {
        source = pkgs.fetchurl {
          url = "https://random.storage.boers.email/wallhaven_l3w6yr.jpg";
          hash = "sha256-SDecGW6T5t0mxGcC3KqtfaQvCzfVEUVcMQ7E6RdgGwU=";
        };
      };
    };

    # dms-quick-capture deps
    home.packages = [
      pkgs.gpu-screen-recorder
      pkgs.ffmpeg
      pkgs.imagemagick
      pkgs.img2pdf
      pkgs.tesseract
      pkgs.zbar
    ];

    programs.dank-calendar = {
      enable = true;
      systemd.enable = true;
      settings.syncIntervalMinutes = 15;
    };

    systemd.user.services = {
      dcal-account-setup = {
        Unit = {
          Description = "Register the vdirsyncer calendars with DankCalendar";
          Before = [ "dcal.service" ];
          PartOf = [ config.programs.dank-calendar.systemd.target ];
        };
        Service = {
          Type = "oneshot";
          ExecStart = dcalAccountSetup;
          RemainAfterExit = true;
        };
      };

      dcal.Unit = {
        Requires = [ "dcal-account-setup.service" ];
        After = [ "dcal-account-setup.service" ];
      };
    };

    programs.dank-material-shell = {
      enable = true;
      enableAudioWavelength = true;
      session = {
        weatherCoordinates = "52.08103243276141,4.30674056600006";

        # Gradually warm the display between local sunset and sunrise.
        nightModeEnabled = true;
        nightModeAutoEnabled = true;
        nightModeAutoMode = "location";
        nightModeTemperature = 4500;
        nightModeHighTemperature = 6500;
        nightModeTransitionMinutes = 60;
        nightModeUseIPLocation = false;
        latitude = 52.08103243276141;
        longitude = 4.30674056600006;
      };
      niri = {
        enableSpawn = true;
        # Keep DMS compositor integration, but manage keybinds declaratively in niri.nix.
        includes.filesToInclude = [
          "alttab"
          "cursor"
          "layout"
          "outputs"
          "windowrules"
          "wpblur"
        ];
      };
      enableDynamicTheming = false;
      plugins = {
        dms-quick-capture = {
          src = pkgs.fetchFromGitHub {
            owner = "hthienloc";
            repo = "dms-quick-capture";
            rev = "f908845cb949be182257f77d88f21c53c3c38bce";
            hash = "sha256-iN7V9XfLXK/AsQzapuH07zWgBm3HZ1x0fDe3KWJqrEY=";
          };
        };
      };

      settings = {
        "currentThemeName" = "custom";
        "cornerRadius" = 10;
        "calendarBackend" = "dankcal";
        "acProfileName" = "1"; # Balanced
        "batteryProfileName" = "0"; # Power Saver
        "audioVisualizerEnabled" = true;
        "barElevationEnabled" = false;
        "privacyShowMicIcon" = true;
        "privacyShowCameraIcon" = true;
        "privacyShowScreenShareIcon" = true;
        "notificationTimeoutLow" = 3000;
        "notificationCompactMode" = true;
        "notificationShowTimeoutBar" = true;
        "notificationPopupPosition" = -1;

        "showWorkspaceApps" = true;
        "workspaceAppIconSizeOffset" = 3;
        "workspaceFollowFocus" = true;
        "workspaceActiveAppHighlightEnabled" = true;
        "connectedFrameBarStyleBackups" = {
          "default" = {
            "shadowIntensity" = 0;
            "squareCorners" = false;
            "attachToScreenEdge" = false;
            "gothCornersEnabled" = false;
            "borderEnabled" = false;
          };
        };
        "barConfigs" = [
          {
            "id" = "default";
            "name" = "Main Bar";
            "enabled" = true;
            "position" = 3;
            "screenPreferences" = [
              "all"
            ];
            "showOnLastDisplay" = true;
            "leftWidgets" = [
              {
                "id" = "powerMenuButton";
                "enabled" = true;
              }
              "workspaceSwitcher"
            ];
            "centerWidgets" = [
              {
                "enabled" = true;
                "id" = "idleInhibitor";
              }
              "clock"
              {
                "id" = "quickCapture";
                "enabled" = true;
              }
            ];
            "rightWidgets" = [
              "music"
              "cpuUsage"
              "memUsage"
              "battery"
              "controlCenterButton"
            ];
            "spacing" = 4;
            "innerPadding" = 4;
            "bottomGap" = 0;
            "transparency" = 1;
            "widgetTransparency" = 1;
            "squareCorners" = false;
            "noBackground" = false;
            "gothCornersEnabled" = false;
            "gothCornerRadiusOverride" = false;
            "gothCornerRadiusValue" = 12;
            "borderEnabled" = false;
            "borderColor" = "surfaceText";
            "borderOpacity" = 1;
            "borderThickness" = 1;
            "fontScale" = 1;
            "autoHide" = false;
            "autoHideDelay" = 250;
            "openOnOverview" = false;
            "visible" = true;
            "popupGapsAuto" = true;
            "popupGapsManual" = 4;
            "maximizeWidgetText" = false;
            "maximizeWidgetIcons" = true;
            "removeWidgetPadding" = false;
          }
        ];
        "desktopClockCustomColor" = {
          "r" = 1;
          "g" = 1;
          "b" = 1;
          "a" = 1;
          "hsvHue" = -1;
          "hsvSaturation" = 0;
          "hsvValue" = 1;
          "hslHue" = -1;
          "hslSaturation" = 0;
          "hslLightness" = 1;
          "valid" = true;
        };
        "systemMonitorCustomColor" = {
          "r" = 1;
          "g" = 1;
          "b" = 1;
          "a" = 1;
          "hsvHue" = -1;
          "hsvSaturation" = 0;
          "hsvValue" = 1;
          "hslHue" = -1;
          "hslSaturation" = 0;
          "hslLightness" = 1;
          "valid" = true;
        };
        "builtInPluginSettings" = {
          "dms_settings_search" = {
            "trigger" = "?";
          };
          "dms_clipboard_search" = {
            "trigger" = "cb";
          };
          "dms_power" = {
            "trigger" = "pw";
          };
        };
        "frameEnabled" = true;
        "frameThickness" = 8;
        "frameRounding" = 15;
        "frameBarSize" = 39;
        "frameBarInsetPadding" = 12;
        "configVersion" = 18;
      };
    };
  };
}
