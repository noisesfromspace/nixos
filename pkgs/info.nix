{
  pkgs,
}:

pkgs.stdenv.mkDerivation {
  pname = "boers-info";
  version = "1";
  src = pkgs.fetchFromRadicle {
    seed = "seed.boers.email";
    repo = "z2r9euHZW161kfQNxdF4apHddD3mm";
    rev = "936c086d7436e797b1c0d0badf01bd3d5ff20c04";
    hash = "sha256-Q42RFCgnDlGaXRAg/RSD4rnhjYYDWs2MT5EoQmqo/z0=";
  };
  installPhase = "cp -r . $out";
}
