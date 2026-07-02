{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:
let
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

      ".config/noctalia/plugins/ip-monitor".source =
        pkgs.callPackage ../../pkgs/ip-monitor-patched.nix
          { };
    };

    home.packages = with pkgs; [
      grim # annotation
      slurp # region selection
      hyprpicker # color picker
      tesseract # ocr
      zbar # qr/barcode scanning
      translate-shell # ocr translation
      wl-screenrec # screen recording (primary)
      ffmpeg # video processing
      gifski # high-quality gif encoding
      python3Packages.pygobject3 # system file picker support
      oskToggle 
    ];

    # Screenshots
    programs.satty = {
      enable = true;
      settings = {
        general = {
          output-filename = "/home/martijn/Pictures/screenshot_%Y-%m-%d_%H:%M:%S.png";
          early-exit = false;
        };
      };
    };

    # Clipboard history
    services.cliphist.enable = true;

    programs.noctalia-shell = {
      enable = true;
      systemd.enable = true;

      plugins = {
        sources = [
          {
            enabled = true;
            name = "Noctalia Plugins";
            url = "https://github.com/noctalia-dev/noctalia-plugins";
          }
        ];
        states = {
          screen-toolkit = {
            enabled = true;
            sourceUrl = "https://github.com/noctalia-dev/noctalia-plugins";
          };
          ip-monitor = {
            enabled = true;
            sourceUrl = "https://github.com/noctalia-dev/noctalia-plugins";
          };
          port-monitor = {
            enabled = true;
            sourceUrl = "https://github.com/noctalia-dev/noctalia-plugins";
          };
          privacy-indicator = {
            enabled = true;
            sourceUrl = "https://github.com/noctalia-dev/noctalia-plugins";
          };
          usb-drive-manager = {
            enabled = true;
            sourceUrl = "https://github.com/noctalia-dev/noctalia-plugins";
          };
          display-settings = {
            enabled = true;
            sourceUrl = "https://github.com/noctalia-dev/noctalia-plugins";
          };
          mullvad = {
            enabled = true;
            sourceUrl = "https://github.com/noctalia-dev/noctalia-plugins";
          };
        };
        version = 2;
      };

      settings = {
        settingsVersion = 59;

        bar = {
          barType = "floating";
          position = "top";
          monitors = [ ];
          density = "default";
          showOutline = false;
          showCapsule = true;
          capsuleOpacity = lib.mkForce 0.68;
          capsuleColorKey = "none";
          widgetSpacing = 8;
          contentPadding = 4;
          fontScale = 1;
          enableExclusionZoneInset = true;
          backgroundOpacity = lib.mkForce 0.89;
          useSeparateOpacity = true;
          marginVertical = 6;
          marginHorizontal = 7;
          frameThickness = 8;
          frameRadius = 6;
          outerCorners = true;
          hideOnOverview = false;
          displayMode = "always_visible";
          autoHideDelay = 500;
          autoShowDelay = 150;
          showOnWorkspaceSwitch = true;
          widgets = {
            left = [
              {
                id = "SessionMenu";
                iconColor = "error";
              }
              {
                id = "Launcher";
                icon = "wave-saw-tool";
                useDistroLogo = false;
                colorizeSystemIcon = "none";
                colorizeSystemText = "none";
                customIconPath = "";
                enableColorization = false;
                iconColor = "none";
              }
              {
                id = "Workspace";
                characterCount = 2;
                colorizeIcons = false;
                emptyColor = "secondary";
                enableScrollWheel = true;
                focusedColor = "primary";
                followFocusedScreen = false;
                fontWeight = "bold";
                groupedBorderOpacity = 1;
                hideUnoccupied = false;
                iconScale = 0.8;
                labelMode = "index";
                occupiedColor = "secondary";
                pillSize = 0.6;
                showApplications = false;
                showApplicationsHover = false;
                showBadge = true;
                showLabelsOnlyWhenOccupied = true;
                unfocusedIconsOpacity = 1;
              }
              {
                id = "ActiveWindow";
                colorizeIcons = false;
                hideMode = "hidden";
                maxWidth = 400;
                scrollingMode = "hover";
                showIcon = true;
                showText = true;
                textColor = "none";
                useFixedWidth = false;
              }
            ];
            center = [
              {
                id = "KeepAwake";
                iconColor = "none";
                textColor = "none";
              }
              {
                defaultSettings = {
                  colorHistory = [ ];
                  detectedRecorder = "";
                  filenameFormat = "";
                  gifMaxSeconds = 30;
                  installedLangs = [
                    "eng"
                  ];
                  paletteColors = [ ];
                  recordCopyToClipboard = false;
                  recordSkipConfirmation = false;
                  screenshotPath = "";
                  selectedOcrLang = "eng";
                  transAvailable = false;
                  videoPath = "";
                };
                id = "plugin:screen-toolkit";
              }
              {
                id = "Clock";
                clockColor = "none";
                customFont = "";
                formatHorizontal = "HH:mm ddd, MMM dd";
                formatVertical = "HH mm - dd MM";
                tooltipFormat = "HH:mm ddd, MMM dd";
                useCustomFont = false;
              }
              {
                id = "plugin:privacy-indicator";
                defaultSettings = {
                  activeColor = "primary";
                  camFilterRegex = "wireplumber";
                  enableToast = true;
                  hideInactive = false;
                  iconSpacing = 4;
                  inactiveColor = "none";
                  micFilterRegex = "";
                  removeMargins = false;
                };
              }
            ];
            right = [
              {
                id = "plugin:ip-monitor";
                defaultSettings = {
                  errorIcon = "alert-circle";
                  iconColor = "primary";
                  loadingIcon = "loader";
                  refreshInterval = 300;
                  successIcon = "network";
                };
              }
              {
                id = "plugin:port-monitor";
                defaultSettings = {
                  hideSystemPorts = false;
                  hideWhenEmpty = false;
                  refreshInterval = 5;
                };
              }
              {
                id = "plugin:mullvad";
              }
              {
                id = "plugin:display-settings";
              }
              {
                id = "plugin:usb-drive-manager";
                defaultSettings = {
                  autoMount = false;
                  fileBrowser = "yazi";
                  hideWhenEmpty = false;
                  iconColor = "none";
                  showBadge = false;
                  showNotifications = true;
                  terminalCommand = "kitty";
                };
              }
              {
                id = "plugin:bluetooth";
              }
              {
                id = "Brightness";
                applyToAllMonitors = false;
                displayMode = "onhover";
                iconColor = "none";
                textColor = "none";
              }
              {
                id = "Volume";
                displayMode = "onhover";
                iconColor = "none";
                middleClickCommand = "pwvucontrol || pavucontrol";
                textColor = "none";
              }
              {
                id = "NotificationHistory";
                hideWhenZero = false;
                hideWhenZeroUnread = false;
                iconColor = "none";
                showUnreadBadge = true;
                unreadBadgeColor = "primary";
              }
              {
                id = "Battery";
                deviceNativePath = "__default__";
                displayMode = "graphic-clean";
                hideIfIdle = false;
                hideIfNotDetected = true;
                showNoctaliaPerformance = false;
                showPowerProfiles = false;
              }
              {
                id = "CustomButton";
                colorizeSystemIcon = "none";
                colorizeSystemText = "none";
                generalTooltipText = "";
                hideMode = "alwaysExpanded";
                icon = "keyboard";
                iconPosition = "left";
                ipcIdentifier = "";
                leftClickExec = "osk";
                leftClickUpdateText = false;
                maxTextLength = {
                  horizontal = 10;
                  vertical = 10;
                };
                middleClickExec = "";
                middleClickUpdateText = false;
                parseJson = false;
                rightClickExec = "osk";
                rightClickUpdateText = false;
                showExecTooltip = true;
                showIcon = true;
                showTextTooltip = true;
                textCollapse = "";
                textCommand = "";
                textIntervalMs = 3000;
                textStream = false;
                wheelDownExec = "";
                wheelDownUpdateText = false;
                wheelExec = "";
                wheelMode = "unified";
                wheelUpExec = "";
                wheelUpUpdateText = false;
                wheelUpdateText = false;
              }
            ];
          };
          mouseWheelAction = "none";
          reverseScroll = false;
          mouseWheelWrap = true;
          middleClickAction = "none";
          middleClickFollowMouse = false;
          middleClickCommand = "";
          rightClickAction = "controlCenter";
          rightClickFollowMouse = true;
          rightClickCommand = "";
          screenOverrides = [ ];
        };

        general = {
          avatarImage = "/home/martijn/.config/avatar.png";
          dimmerOpacity = 0.2;
          showScreenCorners = false;
          forceBlackScreenCorners = false;
          scaleRatio = 1;
          radiusRatio = 0.3;
          iRadiusRatio = 1;
          boxRadiusRatio = 1;
          screenRadiusRatio = 1;
          animationSpeed = 4;
          animationDisabled = false;
          compactLockScreen = true;
          lockScreenAnimations = true;
          lockOnSuspend = true;
          showSessionButtonsOnLockScreen = false;
          showHibernateOnLockScreen = false;
          enableLockScreenMediaControls = true;
          enableShadows = true;
          enableBlurBehind = true;
          shadowDirection = "bottom_right";
          shadowOffsetX = 2;
          shadowOffsetY = 3;
          language = "";
          allowPanelsOnScreenWithoutBar = true;
          showChangelogOnStartup = true;
          telemetryEnabled = false;
          enableLockScreenCountdown = true;
          lockScreenCountdownDuration = 10000;
          autoStartAuth = false;
          allowPasswordWithFprintd = false;
          clockStyle = "digital";
          clockFormat = "hh\nmm";
          passwordChars = true;
          lockScreenMonitors = [ ];
          lockScreenBlur = 0.38;
          lockScreenTint = 0.4;
          keybinds = {
            keyUp = [ "Up" ];
            keyDown = [ "Down" ];
            keyLeft = [ "Left" ];
            keyRight = [ "Right" ];
            keyEnter = [
              "Return"
              "Enter"
            ];
            keyEscape = [ "Esc" ];
            keyRemove = [ "Del" ];
          };
          reverseScroll = false;
          smoothScrollEnabled = true;
        };

        ui = {
          fontDefault = "Inter";
          fontFixed = "JetbrainsMono Nerd Font";
          fontDefaultScale = 1;
          fontFixedScale = 1;
          tooltipsEnabled = true;
          scrollbarAlwaysVisible = true;
          boxBorderEnabled = false;
          panelBackgroundOpacity = lib.mkForce 1;
          translucentWidgets = false;
          panelsAttachedToBar = true;
          settingsPanelMode = "attached";
          settingsPanelSideBarCardStyle = false;
        };

        location = {
          name = "The Hague, Netherlands";
          weatherEnabled = true;
          weatherShowEffects = true;
          weatherTaliaMascotAlways = false;
          useFahrenheit = false;
          use12hourFormat = false;
          showWeekNumberInCalendar = false;
          showCalendarEvents = true;
          showCalendarWeather = true;
          analogClockInCalendar = false;
          firstDayOfWeek = -1;
          hideWeatherTimezone = false;
          hideWeatherCityName = false;
          autoLocate = false;
        };

        calendar = {
          cards = [
            {
              enabled = true;
              id = "calendar-header-card";
            }
            {
              enabled = true;
              id = "calendar-month-card";
            }
            {
              enabled = true;
              id = "weather-card";
            }
          ];
        };

        wallpaper = {
          enabled = true;
          overviewEnabled = false;
          directory = "/home/martijn/Pictures/Wallpapers";
          monitorDirectories = [ ];
          enableMultiMonitorDirectories = false;
          showHiddenFiles = false;
          viewMode = "browse";
          setWallpaperOnAllMonitors = true;
          linkLightAndDarkWallpapers = true;
          fillMode = "crop";
          fillColor = "#000000";
          useSolidColor = false;
          solidColor = "#1a1a2e";
          automationEnabled = false;
          wallpaperChangeMode = "random";
          randomIntervalSec = 300;
          transitionDuration = 1500;
          transitionType = [
            "fade"
            "pixelate"
            "honeycomb"
          ];
          skipStartupTransition = false;
          transitionEdgeSmoothness = 0.05;
          panelPosition = "follow_bar";
          hideWallpaperFilenames = false;
          useOriginalImages = false;
          overviewBlur = 0.4;
          overviewTint = 0.6;
          useWallhaven = false;
          wallhavenQuery = "";
          wallhavenSorting = "relevance";
          wallhavenOrder = "desc";
          wallhavenCategories = "111";
          wallhavenPurity = "100";
          wallhavenRatios = "";
          wallhavenApiKey = "";
          wallhavenResolutionMode = "atleast";
          wallhavenResolutionWidth = "";
          wallhavenResolutionHeight = "";
          sortOrder = "name";
          favorites = [ ];
        };

        appLauncher = {
          enableClipboardHistory = true;
          autoPasteClipboard = false;
          enableClipPreview = true;
          clipboardWrapText = true;
          enableClipboardSmartIcons = true;
          enableClipboardChips = true;
          clipboardWatchTextCommand = "wl-paste --type text --watch cliphist store";
          clipboardWatchImageCommand = "wl-paste --type image --watch cliphist store";
          position = "center";
          pinnedApps = [
            "ghostty.desktop"
            "firefox.desktop"
          ];
          sortByMostUsed = true;
          terminalCommand = "ghostty -e";
          customLaunchPrefixEnabled = false;
          customLaunchPrefix = "";
          viewMode = "list";
          showCategories = true;
          iconMode = "native";
          showIconBackground = false;
          enableSettingsSearch = true;
          enableWindowsSearch = true;
          enableSessionSearch = true;
          ignoreMouseInput = false;
          screenshotAnnotationTool = "";
          overviewLayer = false;
          density = "default";
        };

        controlCenter = {
          position = "center";
          diskPath = "/";
          shortcuts = {
            left = [
              { id = "Network"; }
              { id = "Bluetooth"; }
              { id = "WallpaperSelector"; }
              { id = "NoctaliaPerformance"; }
              { id = "AirplaneMode"; }
            ];
            right = [
              { id = "Notifications"; }
              { id = "PowerProfile"; }
              { id = "KeepAwake"; }
              { id = "NightLight"; }
            ];
          };
          cards = [
            {
              enabled = true;
              id = "profile-card";
            }
            {
              enabled = true;
              id = "shortcuts-card";
            }
            {
              enabled = true;
              id = "audio-card";
            }
            {
              enabled = false;
              id = "brightness-card";
            }
            {
              enabled = true;
              id = "weather-card";
            }
            {
              enabled = true;
              id = "media-sysmon-card";
            }
          ];
        };

        systemMonitor = {
          cpuWarningThreshold = 80;
          cpuCriticalThreshold = 90;
          tempWarningThreshold = 80;
          tempCriticalThreshold = 90;
          gpuWarningThreshold = 80;
          gpuCriticalThreshold = 90;
          memWarningThreshold = 80;
          memCriticalThreshold = 90;
          swapWarningThreshold = 80;
          swapCriticalThreshold = 90;
          diskWarningThreshold = 80;
          diskCriticalThreshold = 90;
          diskAvailWarningThreshold = 20;
          diskAvailCriticalThreshold = 10;
          batteryWarningThreshold = 20;
          batteryCriticalThreshold = 5;
          enableDgpuMonitoring = false;
          useCustomColors = false;
          warningColor = "";
          criticalColor = "";
          externalMonitor = "resources || missioncenter || jdsystemmonitor || corestats || system-monitoring-center || gnome-system-monitor || plasma-systemmonitor || mate-system-monitor || ukui-system-monitor || deepin-system-monitor || pantheon-system-monitor";
        };

        noctaliaPerformance = {
          disableWallpaper = true;
          disableDesktopWidgets = true;
        };

        dock = {
          enabled = false;
        };

        network = {
          bluetoothRssiPollingEnabled = false;
          bluetoothRssiPollIntervalMs = 60000;
          networkPanelView = "wifi";
          wifiDetailsViewMode = "grid";
          bluetoothDetailsViewMode = "grid";
          bluetoothHideUnnamedDevices = false;
          disableDiscoverability = false;
          bluetoothAutoConnect = true;
        };

        sessionMenu = {
          enableCountdown = true;
          countdownDuration = 10000;
          position = "center";
          showHeader = true;
          showKeybinds = true;
          largeButtonsStyle = true;
          largeButtonsLayout = "single-row";
          powerOptions = [
            {
              action = "lock";
              enabled = true;
              keybind = "1";
            }
            {
              action = "suspend";
              enabled = true;
              keybind = "2";
            }
            {
              action = "hibernate";
              enabled = true;
              keybind = "3";
            }
            {
              action = "reboot";
              enabled = true;
              keybind = "4";
            }
            {
              action = "logout";
              enabled = true;
              keybind = "5";
            }
            {
              action = "shutdown";
              enabled = true;
              keybind = "6";
            }
            {
              action = "rebootToUefi";
              enabled = true;
              keybind = "7";
            }
          ];
        };

        notifications = {
          enabled = true;
          enableMarkdown = false;
          density = "default";
          monitors = [ ];
          location = "top_right";
          overlayLayer = true;
          backgroundOpacity = lib.mkForce 1;
          respectExpireTimeout = true;
          lowUrgencyDuration = 6;
          normalUrgencyDuration = 10;
          criticalUrgencyDuration = 20;
          clearDismissed = true;
          saveToHistory = {
            low = true;
            normal = true;
            critical = true;
          };
          sounds = {
            enabled = false;
            volume = 0.5;
            separateSounds = false;
            criticalSoundFile = "";
            normalSoundFile = "";
            lowSoundFile = "";
            excludedApps = "discord,firefox,chrome,chromium,edge";
          };
          enableMediaToast = false;
          enableKeyboardLayoutToast = true;
          enableBatteryToast = true;
        };

        osd = {
          enabled = true;
          location = "top_right";
          autoHideMs = 2000;
          overlayLayer = true;
          backgroundOpacity = lib.mkForce 1;
          enabledTypes = [
            0
            1
            2
          ];
          monitors = [ ];
        };

        audio = {
          volumeStep = 5;
          volumeOverdrive = true;
          spectrumFrameRate = 30;
          visualizerType = "linear";
          spectrumMirrored = true;
          mprisBlacklist = [ ];
          preferredPlayer = "";
          volumeFeedback = false;
          volumeFeedbackSoundFile = "";
        };

        brightness = {
          brightnessStep = 5;
          enforceMinimum = true;
          enableDdcSupport = false;
          backlightDeviceMappings = [ ];
        };

        colorSchemes = {
          useWallpaperColors = false;
          predefinedScheme = "Noctalia (default)";
          darkMode = true;
          schedulingMode = "off";
          manualSunrise = "06:30";
          manualSunset = "18:30";
          generationMethod = "tonal-spot";
          monitorForColors = "";
          syncGsettings = true;
        };

        templates = {
          activeTemplates = [ ];
          enableUserTheming = false;
        };

        nightLight = {
          enabled = true;
          forced = false;
          autoSchedule = true;
          nightTemp = "3200";
          dayTemp = "6500";
          manualSunrise = "06:30";
          manualSunset = "18:30";
        };

        hooks = {
          enabled = false;
          wallpaperChange = "";
          darkModeChange = "";
          screenLock = "";
          screenUnlock = "";
          performanceModeEnabled = "";
          performanceModeDisabled = "";
          startup = "";
          session = "";
          colorGeneration = "";
        };

        plugins = {
          autoUpdate = false;
          notifyUpdates = true;
        };

        idle = {
          enabled = true;
          screenOffTimeout = 600;
          lockTimeout = 660;
          suspendTimeout = 1800;
          fadeDuration = 5;
          screenOffCommand = "";
          lockCommand = "";
          suspendCommand = "";
          resumeScreenOffCommand = "";
          resumeLockCommand = "";

          # Dell shitstation fix
          resumeSuspendCommand = "sleep 1; niri msg output eDP-1 on";
          customCommands = "[]";
        };

        desktopWidgets = {
          enabled = false;
          overviewEnabled = true;
          gridSnap = false;
          gridSnapScale = false;
          monitorWidgets = [ ];
        };
      };
    };
  };
}
