{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
with lib;
let
  cfg = config.maatwerk.desktop;

  jail = inputs.jail-nix.lib.init pkgs;

  piWrapped = pkgs.symlinkJoin {
    name = "pi-coding-agent";
    buildInputs = [ pkgs.makeWrapper ];
    paths = [ pkgs.pi-coding-agent ];
    postBuild = ''
      wrapProgram $out/bin/pi \
        --set NPM_CONFIG_PREFIX ${config.home.homeDirectory}/.pi/npm/ \
        --prefix PATH : ${
          pkgs.lib.makeBinPath [
            pkgs.nodejs_22
            pkgs.ddgr # cli ddg
            pkgs.pandoc # read from docs
            pkgs.bun # context-mode
            pkgs.w3m # read from web
            pkgs.python313Packages.trafilatura # gather text from articles
            pkgs.fd # search pi uses
            pkgs.uutils-coreutils-noprefix # grep etc
          ]
        }
    '';
  };

  piJailed = jail "pi-jailed" "${piWrapped}/bin/pi" (
    with jail.combinators;
    [
      network
      mount-cwd
      (rw-bind (noescape "~/.pi") (noescape "~/.pi"))
      # auth.json inside ~/.pi is a symlink to /run/agenix/pi-auth
      (ro-bind "/run/agenix/pi-auth" "/run/agenix/pi-auth")
      (fwd-env "PI_ASK_USER_DISPLAY_MODE")
    ]
  );
in
{
  imports = [ ./waybar.nix ];

  options.maatwerk.desktop = {
    enable = mkEnableOption "Enable default desktop packages + configuration";
  };

  config = mkIf cfg.enable {
    maatwerk.browser.enable = true;
    maatwerk.ghostty.enable = true;
    maatwerk.stylix.enable = true;
    maatwerk.attic.enable = true;
    maatwerk.aerc.enable = true;
    maatwerk.khal.enable = true;
    maatwerk.nixvim.enable = true;

    age.secrets = {
      proton.file = "${inputs.secrets}/proton.age";
    };

    home.packages =
      with pkgs;
      with pkgs.kdePackages;
      [
        cheese # webcam
        localsend # airdrop
        wvkbd-desktop # osk
        gnupg
        devenv

        # file support
        zathura # pdf
        imv # image
        mpv # video
        mousepad # gui-notepad
        imagemagick # convert images
        nurl # nix fetchUrl
        nix-init # build packages

        # developement
        python313

        # pi (normal — full filesystem access)
        piWrapped
        # pi (jailed — sandboxed)
        piJailed

        # work
        citrix_workspace

        # networking
        wireguard-tools # wg-quick
        podman-compose # replace for dud
        nyx # tor debugging

        # forensics
        magika-cli # recognize filetype
        sleuthkit # fls, icat
        tesseract # ocr
        exiftool # read metadata
        binwalk # firmware analysis
        gettit # download full website
        ent # test entropy files
        mat2 # remove metadata
        nmap
        xca

        # music
        strawberry

        # messaging
        signal-desktop
        fractal # matrix-client

        # DE utilities
        blueman # bluetooth
        pavucontrol # audio
        playerctl
        wlogout
        wl-clipboard # clipboard
        cliphist
        iwgtk # wifi applet
      ];

    home.sessionVariables = {
      PI_ASK_USER_DISPLAY_MODE = "inline";
    };

    # DBus secret service
    services.pass-secret-service.enable = true;

    # Power notifications
    services.poweralertd.enable = true;

    services.unison = {
      enable = true;
      pairs = {
        "notes" = {
          # NFS doesn't support inotify events
          commandOptions.repeat = "60";
          roots = [
            "/home/martijn/Notes"
            "/mnt/notes/"
          ];
        };
        "pi-agent" = {
          # NFS doesn't support inotify events
          commandOptions.repeat = "60";
          roots = [
            "/home/martijn/.pi/agent"
            "/mnt/session/pi-agent/"
          ];
        };
      };
    };

    programs.gpg = {
      enable = true;
      scdaemonSettings = {
        # Use system PCSC driver
        disable-ccid = true;
        # Allow OpenSC to touch the card
        pcsc-shared = true;
        # Stop GPG from blocking Firefox
        disable-application = "piv";
        # card-timeout = "5";
      };
    };
    services.gpg-agent = {
      enable = true;
      enableSshSupport = false;
      pinentry.package = pkgs.pinentry-qt;
      defaultCacheTtl = 43200;
      maxCacheTtl = 43200;
    };

    # Escalate privileges
    services.hyprpolkitagent.enable = true;

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
      # Avatar image
      ".config/avatar.png" = {
        source = pkgs.fetchurl {
          url = "https://random.storage.boers.email/icon.png";
          hash = "sha256-YxJuLqQ4BpWKyMOTl+J09uRVuK4e0CVinXuNb5u/8aY=";
        };
      };
    };

    services.wlsunset = {
      enable = true;
      latitude = "52.081038939033604";
      longitude = "4.306721564001391";
      temperature.night = 3000;
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
            color = "rgba(29, 28, 25, 0.5)";
            position = "0, 0";
            halign = "center";
            valign = "center";
            zindex = 0;

            shadow_passes = 2;
            shadow_size = 5;
            shadow_color = "rgba(13, 12, 12, 0.4)";
          }
        ];

        image = [
          {
            path = "${config.home.homeDirectory}/.config/avatar.png";
            size = 90;
            rounding = -1;
            border_size = 3;
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
            font_color = "rgb(197, 201, 197)";
            inner_color = "rgb(40, 39, 39)";
            outer_color = "rgb(197, 201, 197)";
            outline_thickness = 3;
            placeholder_text = "Rara...";
            rounding = 6;
            fail_color = "rgb(196, 116, 110)";
            fail_text = "<i>$FAIL <b>($ATTEMPTS)</b></i>";
            check_color = "rgb(135, 169, 135)";
            capslock_color = "rgb(185, 141, 123)";
          }
        ];
      };
    };
  };
}
