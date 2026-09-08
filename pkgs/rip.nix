{
  rustPlatform,
  fetchFromGitHub,
  pkgs,
  lib,
}:

rustPlatform.buildRustPackage rec {
  pname = "rip-cli";
  version = "v0.5.0";
  src = fetchFromGitHub {
    owner = "cesarferreira";
    repo = "rip";
    rev = version;
    hash = "sha256-1igqpG2c2RivP+kgwPauiEb67kMOqgCA+MiS62JqrzM=";
  };

  cargoHash = "sha256-eme58UrgqFnzHbRgXvwvML1MeqBZfcWjJGXNZ1Rd/9c=";

  nativeBuildInputs = with pkgs; [
    pkg-config
  ];

  buildInputs =
    [ ]
    ++ pkgs.lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
      pkgs.darwin.apple_sdk.frameworks.Security
      pkgs.darwin.apple_sdk.frameworks.SystemConfiguration
    ];

  # Metadata shown in nix
  meta = with pkgs.lib; {
    description = "Fuzzy find and kill processes from your terminal";
    homepage = "https://github.com/cesarferreira/rip";
    license = licenses.mit;
    maintainers = [ ];
    mainProgram = "rip";
  };
}
