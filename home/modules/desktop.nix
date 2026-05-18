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
in
{
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

        # pi deps
        (pkgs.symlinkJoin {
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
                ]
              }
          '';
        })

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

  };
}
