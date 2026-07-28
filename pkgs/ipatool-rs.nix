{
  lib,
  rustPlatform,
  fetchFromGitHub,
  nix-update-script,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "ipatool-rs";
  version = "0.1.5";
  __structuredAttrs = true;

  src = fetchFromGitHub {
    owner = "Kosthi";
    repo = "ipatool-rs";
    tag = "v${finalAttrs.version}";
    hash = "sha256-4iOj4dWrSSM/oSj6vSB2jCNqwGWxrItnorfE1PJ9uJQ=";
  };

  cargoHash = "sha256-UThRNuSnCeSw1Bba/D1CzckgUiIFCwIbSbh/I95v/dk=";

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "A terminal UI for searching, purchasing, and downloading iOS App Store IPA files, written in Rust";
    homepage = "https://github.com/Kosthi/ipatool-rs";
    changelog = "https://github.com/Kosthi/ipatool-rs/blob/${finalAttrs.src.rev}/CHANGELOG.md";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ ];
    mainProgram = "ipatool-rs";
  };
})
