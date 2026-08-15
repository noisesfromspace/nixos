{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
with lib;
let
  cfg = config.maatwerk.pi;
  jail = inputs.jail-nix.lib.init pkgs;

  piWrapped = pkgs.symlinkJoin {
    name = "pi-coding-agent";
    buildInputs = [ pkgs.makeWrapper ];
    paths = [
      (pkgs.writeShellScriptBin "pi" ''
        if [ -f "${config.age.secrets.pi-api-keys.path}" ]; then
          set -a
          . "${config.age.secrets.pi-api-keys.path}"
          set +a
        fi
        export PI_ASK_USER_DISPLAY_MODE=inline
        exec ${pkgs.nodejs_22}/bin/node ${config.home.homeDirectory}/.pi/agent/node_modules/@earendil-works/pi-coding-agent/dist/cli.js "$@"
      '')
      pkgs.nodejs_22
    ];
    postBuild = ''
      wrapProgram $out/bin/pi \
        --prefix PATH : ${
          pkgs.lib.makeBinPath [
            pkgs.nodejs_22
            pkgs.python313
            pkgs.playwright
            pkgs.uutils-coreutils-noprefix
            pkgs.fd
          ]
        }
    '';
  };

  piJailed = jail "pi-jailed" "${piWrapped}/bin/pi" (
    with jail.combinators;
    [
      network
      mount-cwd
      (rw-bind (noescape "~/.pi") (noescape "~/.pi"))
    ]
  );
in
{
  options.maatwerk.pi = {
    enable = mkEnableOption "Pi coding agent";
  };
  config = mkIf cfg.enable {
    home.packages = [
      piWrapped
      piJailed
    ];

    age.secrets.pi-api-keys = {
      file = "${inputs.secrets}/worker-pi-auth.age";
      mode = "400";
    };
  };
}
