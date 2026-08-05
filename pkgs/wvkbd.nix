{
  stdenv,
  lib,
  fetchFromGitHub,
  wayland-scanner,
  wayland,
  pango,
  glib,
  harfbuzz,
  cairo,
  pkg-config,
  libxkbcommon,
  scdoc,
}:
let
  layout = "deskintl";
in
stdenv.mkDerivation {
  pname = "wvkbd";
  version = "master";

  src = fetchFromGitHub {
    owner = "jjsullivan5196";
    repo = "wvkbd";
    rev = "master";
    hash = "sha256-Et1k3M8L/r5WnoNOuiCzVVgJrpXtWSbIUI+2/njiwj0=";
  };

  postPatch = ''
    substituteInPlace Makefile \
      --replace-fail "pkg-config" "$PKG_CONFIG"
  '';

  nativeBuildInputs = [
    pkg-config
    scdoc
    wayland-scanner
  ];
  buildInputs = [
    cairo
    glib
    harfbuzz
    libxkbcommon
    pango
    wayland
  ];

  makeFlags = [ "LAYOUT=${layout}" ];
  installFlags = [ "PREFIX=$(out)" ];

  postInstall = ''
    mv $out/bin/wvkbd-${layout} $out/bin/wvkbd
  '';

  strictDeps = true;

  meta = with lib; {
    homepage = "https://github.com/jjsullivan5196/wvkbd";
    description = "On-screen keyboard for wlroots with a '${layout}' layout";
    platforms = platforms.linux;
    license = licenses.gpl3Plus;
    mainProgram = "wvkbd";
  };
}
