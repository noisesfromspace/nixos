{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  nodejs_22,
  makeWrapper,
}:
let
  version = "4.0.1";
in
buildNpmPackage {
  pname = "kurczak";
  inherit version;

  src = fetchFromGitHub {
    owner = "c0m4r";
    repo = "kurczak";
    # Using commit hash because GitHub archive for tag v4.0.1 returns 404
    rev = "3297738eab334af5d5f95c912118d63a2c273398";
    hash = "sha256-iq9oynrP3A5nxHvEzas9+YLWFqxxadn6t3a/+9vAHtc=";
  };

  npmDepsHash = "sha256-KHF+hl154y+1ok3PaElDxkk4yU7+KaysbPefy+dj34Y=";

  nodejs = nodejs_22;

  # No build step — vanilla JS served directly
  dontBuild = true;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/kurczak $out/bin

    # Copy runtime files
    cp server.js $out/lib/kurczak/
    cp package.json $out/lib/kurczak/
    cp config.json $out/lib/kurczak/
    cp -r public $out/lib/kurczak/
    cp -r prompts $out/lib/kurczak/
    cp -r node_modules $out/lib/kurczak/

    # Create data directory placeholder (real data lives in /var/lib/kurczak)
    mkdir -p $out/lib/kurczak/data/history

    # Wrapper script
    makeWrapper ${nodejs_22}/bin/node $out/bin/kurczak \
      --chdir $out/lib/kurczak \
      --add-flags "server.js"

    runHook postInstall
  '';

  passthru = {
    defaultPort = 1234;
  };

  meta = with lib; {
    description = "Minimal Ollama chat UI — no login, no heavy features, built for coding";
    homepage = "https://github.com/c0m4r/kurczak";
    license = licenses.agpl3Only;
    platforms = platforms.linux;
    mainProgram = "kurczak";
  };
}
