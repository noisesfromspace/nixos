{
  inputs,
  lib,
  config,
  ...
}:
{
  home.username = "martijn";
  home.homeDirectory = "/home/martijn";
  home.stateVersion = "24.05";

  imports = [
    ./modules/nixvim.nix
    ./modules/stylix.nix
    ./modules/attic.nix
    ./modules/aerc.nix
    ./modules/khal.nix
    ./modules/zsh.nix
    ./modules/git.nix

    # Packaged home manager modules
    inputs.nixvim.homeModules.nixvim
    inputs.stylix.homeModules.stylix

    # Quickly lookup and run programs
    inputs.nix-index-database.homeModules.nix-index

    # Secrets manager
    inputs.agenix.homeManagerModules.default

    # Desktop only
    ./modules/hyprland.nix
    ./modules/browser.nix
    ./modules/ghostty.nix
  ];

  age = {
    identityPaths = [
      "${config.home.homeDirectory}/.ssh/id_ed25519"
    ];
  };

  xdg = {
    enable = true;
    mime.enable = true;
    mimeApps = {
      enable = true;
      associations.removed = {
        "application/zip" = "org.pwmt.zathura-cb.desktop";
      };
      defaultApplications =
        let
          mkMimeAssoc = mimeTypes: desktopFile: lib.attrsets.genAttrs mimeTypes (mimeType: desktopFile);
          imageMimeTypes = [
            "image/jpeg"
            "image/png"
            "image/gif"
            "image/bmp"
            "image/tiff"
            "image/webp"
            "image/x-icon"
            "image/heif"
            "image/heic"
            "image/avif"
          ];
          htmlTypes = [
            "x-scheme-handler/http"
            "x-scheme-handler/https"
            "text/html"
          ];
        in
        {
          # ls ~/.nix-profile/share/applications
          "text/plain" = "org.xfce.mousepad.desktop";
          "application/pdf" = "org.pwmt.zathura.desktop";
          "inode/directory" = "thunar.desktop";
          "text/calendar" = "khal.desktop";
        }
        // mkMimeAssoc imageMimeTypes "imv.desktop"
        // mkMimeAssoc htmlTypes "librewolf.desktop";
    };
  };

  # Let nix-index handle command-not-found
  programs.nix-index.enable = true;

  # Run programs with , cowsay
  programs.nix-index-database.comma.enable = true;

  # Get ZSH by default
  maatwerk.zsh.enable = lib.mkDefault true;
  maatwerk.nixvim.enable = lib.mkDefault false;

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";
  # Let home Manager install and manage itself.
  programs.home-manager.enable = true;
}
