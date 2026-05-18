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
      with pkgs.python313Packages;
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

        # pi deps
        ddgr # cli ddg
        pandoc # read from docs
        bun # context-mode
        w3m # read from web
        trafilatura # gather text from articles
        fd # search pi uses

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
      PI_CODING_AGENT_DIR = "/opt/pi-agent-base";
      PI_CODING_AGENT_SESSION_DIR = "$HOME/.pi/agent/sessions";
      PI_ASK_USER_DISPLAY_MODE = "inline";
      PI_AUTH_JSON = "/run/agenix/worker-pi-auth";
    };

    home.sessionPath = [
      "$HOME/.local/bin"
      "/opt/pi-agent-base/npm/bin"
    ];

    home.file.".local/bin/pi" = {
      text = ''
        #!/usr/bin/env bash
        export NPM_CONFIG_PREFIX="/opt/pi-agent-base/npm"
        export npm_config_prefix="/opt/pi-agent-base/npm"
        exec /opt/pi-agent-base/npm/bin/pi "$@"
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
        "pi-agent" = {
          # NFS doesn't support inotify events
          commandOptions.repeat = "60";
          roots = [
            "/opt/pi-agent-base"
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
