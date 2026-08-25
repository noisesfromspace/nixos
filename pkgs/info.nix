{
  pkgs,
}:

let
  # Only these paths end up in the public web root.
  # Excludes: wasm/ (Rust sources), devenv files, .git, .direnv
  publicPaths = [
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
    rev = "5dbeefe252fbb5eccea11bfb6e668f9d8dfe1d91";
    hash = "sha256-CIDj+u9Izq0rS9C8eqKaJ6ag8omRKGSeqGJa4lRdNWo=";
  };
  installPhase = ''
    mkdir -p $out
    cp -r ${builtins.toString publicPaths} $out/
  '';
}
