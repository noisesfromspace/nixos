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
    paths = [ pkgs.pi-coding-agent ];
    postBuild = ''
      wrapProgram $out/bin/pi \
        --set NPM_CONFIG_PREFIX ${config.home.homeDirectory}/.pi/npm/ \
        --prefix PATH : ${
          pkgs.lib.makeBinPath [
            pkgs.nodejs_22
            pkgs.python313
            pkgs.pandoc # read from docs
            pkgs.playwright # run browser
            pkgs.uutils-coreutils-noprefix # grep etc
            pkgs.fd # search pi uses
            pkgs.rtk # context memmory
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
      (ro-bind "/run/agenix/pi-auth" "/run/agenix/pi-auth")
    ]
  );
in
{
  options.maatwerk.pi = {
    enable = mkEnableOption "Pi coding agent";
  };

  config = mkIf cfg.enable {
    home.packages = [
      # pi (normal — full filesystem access)
      piWrapped
      # pi (jailed — sandboxed)
      piJailed
    ];

    services.unison = {
      enable = true;
      pairs = {
        "pi-agent" = {
          commandOptions.repeat = "60";
          roots = [
            "/home/martijn/.pi/agent/sessions"
            "/mnt/session/pi-agent/sessions"
          ];
        };
      };
    };
  };
}
