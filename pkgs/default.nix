{ pkgs, ... }:

let
  # https://git.eisfunke.com/config/nixos/-/tree/main/packages/mastodon
  glitch-soc-src = pkgs.fetchgit {
    url = "https://git.eisfunke.com/config/nixos.git";
    rev = "395331d51ad64b670aa4053b5c29dc81d3911f27";
    sha256 = "sha256-8erij6w7S6aQMBNpPLNokKTXZrdhVGV4cduKCC118nk=";
  };
  nym-libwg = pkgs.callPackage ./nym-libwg.nix { };
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
  mq = pkgs.callPackage ./mq.nix { };
  rustfs = pkgs.callPackage ./rustfs.nix { };
  blog = pkgs.callPackage ./blog.nix { };
  info = pkgs.callPackage ./info.nix { };
  resume = pkgs.callPackage ./resume.nix { };
  stalwart-custom = pkgs.callPackage ./stalwart.nix { };
  glitch-soc = pkgs.callPackage "${glitch-soc-src}/packages/mastodon" { };
  nym-vpnd = pkgs.callPackage ./nym-vpnd.nix { inherit nym-libwg; };
  durdraw = pkgs.callPackage ./durdraw.nix {};
  worker-sandbox = pkgs.callPackage ./worker-sandbox.nix { };
}
