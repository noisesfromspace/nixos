{
  config,
  pkgs,
  lib,
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

      "Pictures/Wallpapers/default_wallpaper.jpg" = {
        source = pkgs.fetchurl {
          url = "https://random.storage.boers.email/wallpaper_optimized.jpg";
          hash = "sha256-7tCkOYseY4Oayw+WHxn+fK45BdOjRaELYPp33m9+UYI=";
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

    programs.dank-material-shell = {
      enable = true;
      systemd.enable = true;
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
        "calendarBackend" = "khal";
        "barElevationEnabled" = false;
        "privacyShowMicIcon" = true;
        "privacyShowCameraIcon" = true;
        "privacyShowScreenShareIcon" = true;
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
              "systemTray"
              "music"
              "cpuUsage"
              "memUsage"
              "notificationButton"
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
