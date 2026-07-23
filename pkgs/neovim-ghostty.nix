# neovim with libghostty-vt terminal backend
# https://github.com/neovim/neovim/pull/39773
#
# Returns { neovim-unwrapped = ... } so it can be used as an overlay
# that replaces neovim-unwrapped. pkgs.neovim then auto-picks it up.
{
  lib,
  stdenv,
  fetchFromGitHub,
  pkgs,
  callPackage,
  zig_0_15,
}:

let
  # neovim fork with ghostty terminal backend (PR #39773)
  neovim-src = fetchFromGitHub {
    owner = "noib3";
    repo = "neovim";
    rev = "e3c8bcad52986d8d85b21a0518a314d15c38d992";
    sha256 = "sha256-gbSWDqvMdNmsM1+snOpV5uk6u/Ykvwz72fEgT5BfXQ0=";
  };

  # ghostty fork pinned by neovim's cmake.deps/deps.txt
  ghostty-src = fetchFromGitHub {
    owner = "noib3";
    repo = "ghostty";
    rev = "4522e74b83061ad7b5525a6078389434779e3152";
    sha256 = "03d60m8yilh03xym26m7l5m4f7zkij3g0q6n9ssgq5h4n874dzhh";
  };

  libghostty-vt = callPackage (ghostty-src + "/nix/libghostty-vt.nix") {
    inherit zig_0_15;
    optimize = "ReleaseSafe";
    revision = "4522e74b83061ad7b5525a6078389434779e3152";
  };
in

{
  neovim-unwrapped = pkgs.neovim-unwrapped.overrideAttrs (old: {
    pname = "neovim-ghostty";
    version = "0.13.0-dev";

    src = neovim-src;

    patches = [ ];

    buildInputs =
      builtins.filter (x: x.pname or "" != "libvterm") old.buildInputs
      ++ [ libghostty-vt ];

    cmakeFlags =
      builtins.filter (
        f: !(builtins.isString f && lib.hasInfix "USE_BUNDLED" f)
      )
      old.cmakeFlags
      ++ [
        "-DUSE_BUNDLED:BOOL=FALSE"
        "-DUSE_BUNDLED_GHOSTTY:BOOL=FALSE"
      ];

    doCheck = false;
    nativeInstallCheckInputs = [ ];
    doInstallCheck = false;

    preBuild = ''
      mkdir -p $out/share/applications
      touch $out/share/applications/nvim.desktop
    '';
  });
}
