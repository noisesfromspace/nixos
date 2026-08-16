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
    maatwerk.pi.enable = true;
    maatwerk.sync.enable = true;
    maatwerk.s3.enable = true;

    age.secrets = {
      proton.file = "${inputs.secrets}/proton.age";
    };

    home.packages =
      with pkgs;
      with pkgs.kdePackages;
      [
        wvkbd-desktop # osk
        gnupg
        devenv

        # file support
        zathura # pdf
        imv # image
        mousepad # gui-notepad
        imagemagick # convert images
        nurl # nix fetchUrl
        nix-init # build packages

        # developement
        python313
        nodejs_22
        cloc # count-lines-of-code

        # work
        citrix-workspace

        # networking
        wireguard-tools # wg-quick

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
        whatweb # web tech detection
        xca # certs

        # message utilities
        strawberry

        # messaging
        signal-desktop
        stable.fractal # matrix-client
      ];

    # Power notifications
    services.poweralertd.enable = true;

    programs.mpv = {
      enable = true;
      config = {
        vo = "dmabuf-wayland";
        hwdec = "auto-safe";
      };
    };
  };
}
