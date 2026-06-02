{ lib, rustPlatform }:

rustPlatform.buildRustPackage {
  pname = "deceive";
  version = "0.1.0";

  src = /opt/code/deceive;

  cargoHash = "sha256-fYXwfnQ0anwplibSBJ9nHjeiRz1IdqBHHaolz5nJHC4=";

  doCheck = false;

  meta = with lib; {
    description = "TUI for managing Sieve scripts via JMAP";
    mainProgram = "deceive";
  };
}
