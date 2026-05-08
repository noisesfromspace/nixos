{
  pkgs,
}:

pkgs.stdenv.mkDerivation {
  pname = "boers-resume";
  version = "1";
  src = fetchGit {
    url = "https://seed.boers.email/zb1FuXow3wJemDDPFWGFa49rNA4z.git";
    rev = "250ae2e044718a126f407c98cb4a498637704d7d";
    submodules = true;
  };
  nativeBuildInputs = [ pkgs.hugo ];
  buildPhase = "hugo --gc --minify -d public";
  installPhase = "cp -r public $out";
}
