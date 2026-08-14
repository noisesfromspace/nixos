{
  pkgs,
  lib,
}:
let
  beam = pkgs.beam.packages.erlang_27;
  elixir = beam.elixir_1_18;
  erlang = beam.erlang;
  gleam = pkgs.gleam;
  cacert = pkgs.cacert;

  src = pkgs.fetchFromGitHub {
    owner = "atuinsh";
    repo = "atuin-ai-server";
    rev = "4d582bc5ceea5b5edfdcf3abb49dc850400cda7c";
    sha256 = "1iiwdx3z9nrjl77df7xdgdz7srmkjr3isvkgkf976l5jbmvsm2pq";
  };

  # Fixed-output derivation: fetch the Elixir (hex + git) deps via mix, then
  # the Gleam deps of the atuin_ai_core git dependency via `gleam deps
  # download`. Also captures the mix archive cache (hex + rebar3) so the
  # sandboxed build below can compile fully offline.
  deps = pkgs.stdenvNoCC.mkDerivation {
    name = "atuin-ai-server-deps";
    inherit src;
    nativeBuildInputs = [
      elixir
      erlang
      gleam
      pkgs.git
      cacert
    ];
    outputHashMode = "recursive";
    outputHashAlgo = "sha256";
    outputHash = "sha256-7GNM51zSPr857hHK+jbH52f2T8FtNLOyQ3ZjTyxVbc4=";

    buildPhase = ''
      export HOME=$TMPDIR/home
      export MIX_ENV=prod
      export MIX_HOME=$TMPDIR/home/.mix
      export HEX_HOME=$TMPDIR/home/.hex
      export SSL_CERT_FILE=${cacert}/etc/ssl/certs/ca-bundle.crt
      mkdir -p $HOME

      mix local.hex --force
      mix local.rebar --force
      mix deps.get --only prod

      (cd deps/atuin_ai_core && gleam deps download)

      # gleam emits `packages.toml` with a non-deterministic key order
      # (map iteration order); sort the [packages] section so this
      # fixed-output derivation is reproducible.
      awk '
        BEGIN { inpkgs = 0; n = 0 }
        /^\[packages\]$/ { print; inpkgs = 1; next }
        inpkgs && /^\[/ { flush(); print; inpkgs = 0; next }
        inpkgs && /^[[:space:]]*[^[:space:]=]+[[:space:]]*=/ { pkg[n++] = $0; next }
        { flush(); print }
        function flush(  i, tmp) {
          if (n > 0) {
            for (i = 0; i < n; i++) tmp[i+1] = pkg[i]
            asort(tmp)
            for (i = 1; i <= n; i++) print tmp[i]
            n = 0
            delete pkg
            delete tmp
          }
        }
        END { flush() }
      ' deps/atuin_ai_core/build/packages/packages.toml \
        > deps/atuin_ai_core/build/packages/packages.toml.sorted
      mv deps/atuin_ai_core/build/packages/packages.toml.sorted \
        deps/atuin_ai_core/build/packages/packages.toml
    '';

    installPhase = ''
      # `.git/index` and `.git/logs` carry checkout timestamps (non-reproducible)
      # and `.git/hooks/*.sample` reference store paths (forbidden in a
      # fixed-output derivation). Drop all three but keep the rest of `.git` so
      # mix still recognises the git dependency as fetched.
      find . -name .git -type d -prune -exec rm -rf '{}/index' '{}/logs' '{}/hooks' \;
      mkdir -p $out
      cp -r . $out/
      mkdir -p $out/mix-home
      cp -r $HOME/.mix/. $out/mix-home/
    '';
  };
in
pkgs.stdenv.mkDerivation {
  pname = "atuin-ai-server";
  version = "0.1.0";

  dontUnpack = true;

  nativeBuildInputs = [
    elixir
    erlang
    gleam
    pkgs.git
    cacert
  ];

  buildPhase = ''
    cp -r ${deps} work
    chmod -R u+w work
    cd work

    export HOME=$TMPDIR/home
    export MIX_ENV=prod
    export MIX_HOME=$TMPDIR/home/.mix
    export HEX_HOME=$TMPDIR/home/.hex
    export HEX_OFFLINE=1
    export SSL_CERT_FILE=${cacert}/etc/ssl/certs/ca-bundle.crt
    mkdir -p $HOME
    cp -r mix-home $MIX_HOME
    chmod -R u+w $MIX_HOME

    # The rebar3 escript shipped by mix has a `#!/usr/bin/env escript`
    # shebang, but `/usr/bin/env` doesn't exist in the Nix sandbox. Point
    # it straight at the real escript binary.
    for f in "$MIX_HOME"/elixir/*/rebar3 "$MIX_HOME"/elixir/*/rebar; do
      [ -e "$f" ] && sed -i "1s|^#!.*|#!${erlang}/bin/escript|" "$f"
    done

    mix deps.compile
    mix compile
    mix release --overwrite

    mkdir -p $out
    cp -r _build/prod/rel/atuin_ai_server/* $out/
  '';

  installPhase = ":";

  meta = with lib; {
    description = "Self-hosted Atuin AI server (OpenAI-compatible backend bridge)";
    homepage = "https://github.com/atuinsh/atuin-ai-server";
    license = licenses.asl20;
    platforms = platforms.linux;
    maintainers = with maintainers; [ ];
  };
}
