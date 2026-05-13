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
        python314
        nodejs_22

        # work
        citrix_workspace

        # networking
        wireguard-tools # wg-quick
        podman-compose # replace for dud
        nyx # tor debugging

        # forensics
        magika-cli # recognize filetype
        sleuthkit # fls, icat
        exiftool # read metadata
        binwalk # firmware analysis
        tesseract # ocr
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
      PI_NPM_PREFIX = "$HOME/.pi/npm";
      NPM_CONFIG_PREFIX = "$HOME/.pi/npm";
    };

    home.sessionPath = [
      "$HOME/.local/bin"
      "$HOME/.pi/npm/bin"
    ];

    home.activation.piNpmDir = lib.hm.dag.entryAfter ["writeBoundary"] ''
      mkdir -p "$HOME/.pi/npm/bin"
    '';

    home.file.".local/bin/pi" = {
      text = ''
        #!/usr/bin/env bash
        export NPM_CONFIG_PREFIX="$HOME/.pi/npm"
        export PATH="$HOME/.pi/npm/bin:$PATH"
        exec /run/current-system/sw/bin/pi "$@"
      '';
      executable = true;
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
        "aichats" = {
          # NFS doesn't support inotify events
          commandOptions.repeat = "60";
          roots = [
            "/home/martijn/.pi"
            "/mnt/session/"
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
