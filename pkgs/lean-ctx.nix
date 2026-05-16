{
  lib,
  fetchFromGitHub,
  rustPlatform,
  pkg-config,
}:

rustPlatform.buildRustPackage rec {
  pname = "lean-ctx";
  version = "3.6.0";

  src = fetchFromGitHub {
    owner = "yvgude";
    repo = "lean-ctx";
    tag = "v${version}";
    hash = "sha256-ztzF/qQ+QXXvur1tcFF25lA7e/0biLn6nmFwe266AUw=";
  };

  cargoHash = "sha256-Fa/fCjoS0iCSPOqq55YGcLCKbkjOncmundm0eUa8qmg=";
  sourceRoot = "source/rust";
  doCheck = false;

  nativeBuildInputs = [
    pkg-config
  ];

  meta = {
    description = "The Context OS for AI Development. Reduce token waste";
    homepage = "https://github.com/yvgude/lean-ctx";
    license = with lib.licenses; [
      asl20
      mit
    ];
    mainProgram = "lean-ctx";
    platforms = lib.platforms.all;
  };
}
