# Neovim built from the current upstream master branch.
#
# Returns { neovim-unwrapped = ...; } so it can be used as an overlay
# that replaces neovim-unwrapped. pkgs.neovim then auto-picks it up.
{ fetchFromGitHub, pkgs }:

{
  neovim-unwrapped = pkgs.neovim-unwrapped.overrideAttrs {
    pname = "neovim-nightly";
    version = "0.13.0-dev";

    src = fetchFromGitHub {
      owner = "neovim";
      repo = "neovim";
      rev = "06bff279296d8692f5ed514f5edb6e879fac6dc8";
      hash = "sha256-sMUzwkWXJdg9g17pls93v0ishNIbIuEnzf5G9511LNE=";
    };

    # nixvim's wrapper removes this before installing its own desktop file.
    preBuild = ''
      mkdir -p $out/share/applications
      touch $out/share/applications/nvim.desktop
    '';
  };
}
