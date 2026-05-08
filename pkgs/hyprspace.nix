{
  gcc14Stdenv,
  pkgs,
  fetchFromGitHub,
}:
# Build from local PR branch with 0.54 support fixes
gcc14Stdenv.mkDerivation rec {
  pname = "Hyprspace";
  # version = "support_hyprland_0_54_0";
  version = "main";

  # src = /home/martijn/Code/Hyprspace;

  src = fetchFromGitHub {
    owner = "0xl30";
    repo = "Hyprspace";
    rev = "${version}";
    hash = "sha256-JBwdu/U5ZpS40g9sq+kbXMG+mFHpY6p1kwhmIcmar4w=";
  };

  # src = fetchFromGitHub {
  #   owner = "douglas";
  #   repo = "Hyprspace";
  #   rev = "${version}";
  #   hash = "sha256-hRDz5u0LHlKf4K6FDmKnhdAY0fttQmJJanvXMFjgvKY=";
  # };

  nativeBuildInputs = pkgs.hyprland.nativeBuildInputs;
  buildInputs = [ pkgs.hyprland ] ++ pkgs.hyprland.buildInputs;
  dontUseCmakeConfigure = true;

  installFlags = [ "PREFIX=$(out)" ];

  postInstall = ''
    mv $out/lib/Hyprspace.so $out/lib/libHyprspace.so
  '';

  meta = with pkgs.lib; {
    homepage = "https://github.com/KZDKM/Hyprspace";
    description = "Workspace overview plugin for Hyprland (0.54 PR branch)";
    license = licenses.gpl2Only;
    platforms = platforms.linux;
  };
}
