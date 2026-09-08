# Packing nextjs projects is a nightmare, take this with a grain of salt
{
  pkgs ? import <nixpkgs> { },
  lib ? pkgs.lib,

  buildNpmPackage ? pkgs.buildNpmPackage,
  nodejs_20 ? pkgs.nodejs_20,
  makeWrapper ? pkgs.makeWrapper,
  prisma ? pkgs.prisma,
  prisma-engines ? pkgs.prisma-engines,
  python3 ? pkgs.python3,
  gnumake ? pkgs.gnumake,
  cacert ? pkgs.cacert,
  openssl ? pkgs.openssl_3,
  fetchFromGitHub ? pkgs.fetchFromGitHub,
}:

let
  pname = "fluid-calendar";
  version = "1.4.0";

  src = fetchFromGitHub {
    owner = "dotnetfactory";
    repo = "fluid-calendar";
    rev = "v${version}";
    hash = "sha256-iwXYCzlHuO2YtduAKRdFVazQCXV3glSmt02WaCsm6fM=";
  };

  npmDepsHash = "sha256-xCWD4cE9WulIgXlfSd4hTkWz5aF/wzcOsUwEe+LKeEg=";
  defaultListenAddress = "0.0.0.0";
  defaultPort = 3000;

in
buildNpmPackage {
  inherit
    pname
    version
    src
    npmDepsHash
    ;
  nodejs = nodejs_20;

  nativeBuildInputs = [
    python3
    gnumake
    prisma
    prisma-engines
    openssl
    cacert
    makeWrapper
    nodejs_20
  ];

  buildInputs = [
    openssl
  ];

  npmFlags = [
    "--legacy-peer-deps"
    "--build-from-source"
  ];

  env = lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
    PYTHON = lib.getExe python3;
  };

  preBuild = ''
    runHook preConfigure

    export NODE_ENV=production
    export NEXT_TELEMETRY_DISABLED=1
    export DO_NOT_TRACK=1
    export DATABASE_URL="postgresql://user:password@host:5432/database" # Dummy for build

    export PRISMA_SCHEMA_ENGINE_BINARY="${prisma-engines}/bin/schema-engine"
    export PRISMA_QUERY_ENGINE_BINARY="${prisma-engines}/bin/query-engine"
    export PRISMA_QUERY_ENGINE_LIBRARY="${prisma-engines}/lib/libquery_engine.node"
    export PRISMA_INTROSPECTION_ENGINE_BINARY="${prisma-engines}/bin/introspection-engine"
    export PRISMA_FMT_BINARY="${prisma-engines}/bin/prisma-fmt"
    export PRISMA_ENGINES_CHECKSUM_IGNORE_MISSING="1"
    export PRISMA_SKIP_BINARY_DOWNLOADS="true"

    # Patch prisma/schema.prisma to ensure client output path (necessary as schema doesn't specify it)
    sed -i '/generator client {/,/}/ { /^[[:space:]]*output[[:space:]]*=.*/d; }' prisma/schema.prisma
    sed -i '/provider[[:space:]]*=[[:space:]]*"prisma-client-js"/a \  output   = "../node_modules/.prisma/client"' prisma/schema.prisma

    ${prisma}/bin/prisma generate --schema=./prisma/schema.prisma
  '';

  installPhase = ''
    runHook preInstall
    local appdir="$out/share/${pname}"
    mkdir -p "$appdir" "$out/bin"

    cp -a .next/standalone/* "$appdir/"
    rm -rf "$appdir/.next"
    cp -a .next "$appdir/"
    cp -a public "$appdir/public"
    cp -a prisma "$appdir/prisma"
    mkdir -p "$appdir/node_modules/.prisma"
    cp -a node_modules/.prisma/client "$appdir/node_modules/.prisma/"
    chmod +x "$appdir/server.js"

    makeWrapper "${nodejs_20}/bin/node" "$out/bin/${pname}" \
      --chdir "$appdir" \
      --add-flags "server.js" \
      --set-default HOST "${defaultListenAddress}" \
      --set-default PORT "${toString defaultPort}" \
      --set NODE_ENV "production" \
      --set NEXT_TELEMETRY_DISABLED "1" \
      --set PRISMA_SCHEMA_ENGINE_BINARY "${prisma-engines}/bin/schema-engine" \
      --set PRISMA_QUERY_ENGINE_BINARY "${prisma-engines}/bin/query-engine" \
      --set PRISMA_QUERY_ENGINE_LIBRARY "${prisma-engines}/lib/libquery_engine.node" \
      --set PRISMA_INTROSPECTION_ENGINE_BINARY "${prisma-engines}/bin/introspection-engine" \
      --set PRISMA_FMT_BINARY "${prisma-engines}/bin/prisma-fmt"

    runHook postInstall
  '';

  passthru = {
    inherit defaultListenAddress defaultPort;
  };

  meta = with lib; {
    description = "An open-source alternative to Motion, designed for intelligent task scheduling and calendar management";
    homepage = "https://github.com/dotnetfactory/fluid-calendar";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = pname;
  };
}
