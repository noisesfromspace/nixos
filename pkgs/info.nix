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
    rev = "bfe39e781eb408046e284f3822b4ee91d116aa10";
    hash = "sha256-nz1U7d5Mn/o77oCuoj0pMb14VuHiwhBthKgYhZehfqY=";
  };
  installPhase = ''
    mkdir -p $out
    cp -r ${builtins.toString publicPaths} $out/
  '';
}
