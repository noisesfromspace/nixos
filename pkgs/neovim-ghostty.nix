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
    rev = "2873168321aaa8666bd55c7eabdf27151228480b";
    sha256 = "sha256-ButzMy40dznJ8QVMGvHxaY+3GgaTIlISp/zisj4gN6w=";
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

    postPatch = ''
      # is_aucmd_win() is referenced but never defined in the PR fork.
      # Remove the check; it's a minor optimization that skips autocmd windows.
      sed -i 's/!is_aucmd_win(wp) \&\& //' src/nvim/terminal.c
    '';

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
