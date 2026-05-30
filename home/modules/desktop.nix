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
  imports = [ ];

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
    maatwerk.pi.enable = true;
    maatwerk.sync.enable = true;

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
        nmap # portscan
        xca # certs

        # message utilities
        strawberry

        # messaging
        signal-desktop
        fractal # matrix-client

        # DE utilities
        pavucontrol # audio
        playerctl
        wl-clipboard # clipboard
        cliphist # manager
      ];

    # DBus secret service
    services.pass-secret-service.enable = true;

    # Power notifications
    services.poweralertd.enable = true;

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

    programs.satty = {
      enable = true;
      settings = {
        general = {
          output-filename = "/home/martijn/Pictures/screenshot_%Y-%m-%d_%H:%M:%S.png";
          early-exit = false;
        };
      };
    };

    services.cliphist.enable = true;

  };
}
