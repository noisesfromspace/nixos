{ stdenv, fetchFromGitHub }:
stdenv.mkDerivation {
  name = "ip-monitor-patched";
  src = fetchFromGitHub {
    owner = "noctalia-dev";
    repo = "noctalia-plugins";
    rev = "f701942dc9fd4586a87f99c09e17bfcef7d8183a";
    hash = "sha256-A1fri5nav3U29BsesX/zgN2Sc3WAkf1x4dZAh1HpWY4=";
  };
  buildPhase = ''
    cp -r ip-monitor $out
    cp ${./patches/ip-monitor/Main.qml} $out/Main.qml
    cp ${./patches/ip-monitor/Panel.qml} $out/Panel.qml
    cp ${./patches/ip-monitor/BarWidget.qml} $out/BarWidget.qml
  '';
  dontInstall = true;
}
