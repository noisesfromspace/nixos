{
  pkgs,
}:

let
  # Only these paths end up in the public web root.
  # Excludes: wasm/ (Rust sources), devenv files, .git, .direnv
  publicPaths = [
    "assets"
    "css"
    "favicon.ico"
    "fonts"
    "index.html"
    "js"
    "robots.txt"
  ];
in
pkgs.stdenv.mkDerivation {
  pname = "boers-info";
  version = "1";
  src = pkgs.fetchFromRadicle {
    seed = "seed.boers.email";
    repo = "z2r9euHZW161kfQNxdF4apHddD3mm";
    rev = "c4cb713f4d71ca4be04a7b39101b3a05c170786a";
    hash = "sha256-3mCxNt4oh2SGOOAkk4ugTuqKypv6w9AAFp/Vx3Q4bjo=";
  };
  installPhase = ''
    mkdir -p $out
    cp -r ${builtins.toString publicPaths} $out/
  '';
}
