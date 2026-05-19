{ pkgs, ... }:

let
  # https://git.eisfunke.com/config/nixos/-/tree/main/packages/mastodon
  glitch-soc-src = pkgs.fetchgit {
    url = "https://git.eisfunke.com/config/nixos.git";
    rev = "e3963eeb6021a85cdc4bd1a0427f89c2d8959642";
    sha256 = "sha256-hbSgTwm0RlMCm4XUqBlc+JmZNnFq0LMo00zC2gl7vmc=";
  };
  nym-libwg = pkgs.callPackage ./nym-libwg.nix { };

  # Pin yarn-berry to 4.13.0 to work around 4.14.1 regression
  # https://github.com/NixOS/nixpkgs/pull/512685
  # https://github.com/yarnpkg/berry/issues/7089
  yarn-berry = pkgs.yarn-berry.overrideAttrs (old: {
    version = "4.13.0";
    src = pkgs.fetchFromGitHub {
      owner = "yarnpkg";
      repo = "berry";
      tag = "@yarnpkg/cli/4.13.0";
      hash = "sha256-FP15a2ueihDm6f/GdXsnqI5drVHo0EtbmrhCZfRdugQ=";
    };
  });
in
{
  inherit nym-libwg;
  adguard-exporter = pkgs.callPackage ./adguard-exporter.nix { };
  smtp-gotify = pkgs.callPackage ./smtp-gotify.nix { };
  dnscrypt = pkgs.callPackage ./dnscrypt.nix { };
  fluid-calendar = pkgs.callPackage ./fluid-calendar.nix { };
  tormon-exporter = pkgs.callPackage ./tormon-exporter.nix { };
  wvkbd-desktop = pkgs.callPackage ./wvkbd.nix { };
  karlender-dev = pkgs.callPackage ./karlender.nix { };
  geonet = pkgs.callPackage ./geonet.nix { };
  ladder = pkgs.callPackage ./ladder.nix { };
  flowmark = pkgs.callPackage ./flowmark.nix { };
  unaware = pkgs.callPackage ./unaware.nix { };
  gettit = pkgs.callPackage ./gettit.nix { };
  hyprtasking = pkgs.callPackage ./hyprtasking.nix { };
  hyprspace-custom = pkgs.callPackage ./hyprspace.nix { };
  scooter = pkgs.callPackage ./scooter.nix { };
  lean-ctx = pkgs.callPackage ./lean-ctx.nix { };
  mq = pkgs.callPackage ./mq.nix { };
  rustfs = pkgs.callPackage ./rustfs.nix { };
  blog = pkgs.callPackage ./blog.nix { };
  info = pkgs.callPackage ./info.nix { };
  resume = pkgs.callPackage ./resume.nix { };
  stalwart-custom = pkgs.callPackage ./stalwart.nix { };
  glitch-soc = pkgs.callPackage "${glitch-soc-src}/packages/mastodon" { inherit yarn-berry; };
  nym-vpnd = pkgs.callPackage ./nym-vpnd.nix { inherit nym-libwg; };
  durdraw = pkgs.callPackage ./durdraw.nix { };
}
