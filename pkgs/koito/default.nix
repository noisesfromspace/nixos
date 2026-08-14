{
  lib,
  stdenv,
  buildGoModule,
  fetchFromGitHub,
  runCommand,
  yarn-berry,
  nodejs,
  pkg-config,
  vips,
  makeWrapper,
}:

let
  pname = "koito";
  version = "0-unstable-2026-06-18";

  src = fetchFromGitHub {
    owner = "noisesfromspace";
    repo = "koito";
    rev = "be2a2e311d37fb55be875b8f9ab0e837477ef66c";
    hash = "sha256-dJPPk3U1iGr3qR2pRGsa2hjhlbC2AZtdnJ32ppgIjlc=";
  };

  clientSrc = runCommand "koito-client-src" { } ''
    mkdir -p $out
    cp -r ${src}/client/. $out/
  '';

  # Separate derivation for the frontend build
  frontend = stdenv.mkDerivation {
    pname = "${pname}-frontend";
    inherit version;
    src = clientSrc;

    offlineCache = yarn-berry.fetchYarnBerryDeps {
      src = clientSrc;
      missingHashes = ./missing-hashes.json;
      hash = "sha256-VIlWld21GScJ/2UUkKQISM9jyU9wCVwwDNKkge+K044=";
    };

    missingHashes = ./missing-hashes.json;

    nativeBuildInputs = [
      nodejs
      yarn-berry
      yarn-berry.yarnBerryConfigHook
    ];

    buildPhase = ''
      runHook preBuild
      export HOME=$(mktemp -d)
      BUILD_TARGET=docker yarn run build
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -r build $out/
      runHook postInstall
    '';
  };
in
buildGoModule {
  inherit pname version src;

  vendorHash = "sha256-W/+ByBlEPd4yIUD/E28q93fz6wYgvhwyBvJL8Fm1lNY=";

  nativeBuildInputs = [
    pkg-config
    makeWrapper
  ];
  buildInputs = [ vips ];

  ldflags = [
    "-s"
    "-w"
    "-X main.Version=${version}"
  ];

  postPatch = ''
    mkdir -p client/build/client
    cp -r ${frontend}/build/client/. client/build/client/
  '';

  postInstall = ''
    mkdir -p $out/share/koito/client
    cp -r client/build $out/share/koito/client/
    cp -r client/public $out/share/koito/client/

    makeWrapper $out/bin/api $out/bin/koito \
      --run "cd $out/share/koito"
  '';

  meta = with lib; {
    description = "Self-hosted ListenBrainz-compatible music scrobbler";
    homepage = "https://github.com/gabehf/Koito";
    license = licenses.mit;
    maintainers = [ ];
    mainProgram = "koito";
    platforms = platforms.linux;
  };
}
