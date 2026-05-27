{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
with lib;
let
  cfg = config.hosts.niri;
in
{
  imports = [ ./desktop.nix ];

  options.hosts.niri = {
    enable = mkEnableOption "Scrollable tiling desktop";
  };

  config = mkIf cfg.enable {
    hosts.desktop.enable = true;

    # Niri flake overlay provides niri-stable / niri-unstable
    nixpkgs.overlays = [ inputs.niri.overlays.niri ];

    programs.niri = {
      enable = true;
      package = pkgs.niri-stable;
    };

    # Niri module pulls in GNOME portals which enable gcr-ssh-agent.
    # We already have programs.ssh.startAgent enabled system-wide.
    services.gnome.gcr-ssh-agent.enable = lib.mkForce false;

    services.gnome.evolution-data-server.enable = true;

    # Portal configuration for Niri
    # xdg-desktop-portal-gnome and gnome-keyring are pulled in by the niri module.
    # We add xdg-desktop-portal-gtk as the fallback for file choosers and basic portals.
    xdg.portal = {
      extraPortals = with pkgs; [
        xdg-desktop-portal-gtk
      ];
      config.niri = {
        "org.freedesktop.impl.portal.FileChooser" = "gtk";
      };
    };

    environment.systemPackages = with pkgs; [
      file-roller # archive manager used by thunar
      xwayland-satellite # X11 app support (niri auto-integrates since 25.08)
      cliphist # Explicitly bind to standard path for clipboard history
    ];

    programs.thunar = {
      enable = true;
      plugins = with pkgs; [
        thunar-media-tags-plugin
        thunar-archive-plugin
        thunar-volman
      ];
    };

    services.tumbler.enable = true;
    services.gvfs.enable = true;

    services.greetd = {
      enable = true;
      settings = {
        # only first session auto-login
        initial_session = {
          command = "niri-session";
          user = "martijn";
        };
        default_session = {
          command = "${lib.getExe pkgs.tuigreet} --time --cmd niri-session";
          user = "martijn";
        };
      };
    };

    # protocol for unpriv proces to speak to become privileged
    security.polkit.enable = true;

    environment.sessionVariables = {
      QT_QPA_PLATFORMTHEME = "qt5ct";
    };
  };
}
