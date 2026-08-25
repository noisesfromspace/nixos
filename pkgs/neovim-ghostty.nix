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
  zig_0_16,
}:

let
  # neovim fork with ghostty terminal backend (PR #39773)
  neovim-src = fetchFromGitHub {
    owner = "noib3";
    repo = "neovim";
    rev = "b2026f2248b187da70512a6067e41ecb37089c48";
    sha256 = "sha256-DePS0X3ZgLW4U/VZVKen79dXc2N705Q8vQjfVjdnpIo=";
  };

  # ghostty pinned by neovim's cmake.deps/deps.txt (upstream, fork no longer needed)
  ghostty-src = fetchFromGitHub {
    owner = "ghostty-org";
    repo = "ghostty";
    rev = "4133c6e48c4b99d19f5885478a19db4868994d07";
    sha256 = "sha256-vbaq8fp2Y32aTnqpH8DWXjAiq7qydwsBzDnTTCo5COI=";
  };

  libghostty-vt = callPackage (ghostty-src + "/nix/libghostty-vt.nix") {
    inherit zig_0_16;
    optimize = "ReleaseSafe";
    revision = "4133c6e48c4b99d19f5885478a19db4868994d07";
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
