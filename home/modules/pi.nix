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
  srv = cfg.server;

  jail = inputs.jail-nix.lib.init pkgs;

  piWrapped = pkgs.symlinkJoin {
    name = "pi-coding-agent";
    buildInputs = [ pkgs.makeWrapper ];
    paths = [
      (pkgs.writeShellScriptBin "pi" ''
        exec ${pkgs.nodejs_22}/bin/node ${config.home.homeDirectory}/.pi/agent/node_modules/@earendil-works/pi-coding-agent/dist/cli.js "$@"
      '')
      pkgs.nodejs_22
    ];
    postBuild = ''
      wrapProgram $out/bin/pi \
        --set NPM_CONFIG_PREFIX ${config.home.homeDirectory}/.pi/npm/ \
        --prefix PATH : ${
          pkgs.lib.makeBinPath [
            pkgs.nodejs_22
            pkgs.python313
            pkgs.pandoc
            pkgs.playwright
            pkgs.uutils-coreutils-noprefix
            pkgs.fd
            pkgs.rtk
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
    server = {
      enable = mkEnableOption "Pi Signal server (always-on, receives Note-to-Self messages)";
    };
  };

  config = mkMerge [
    (mkIf cfg.enable {
      home.packages = [
        piWrapped
        piJailed
      ];
    })

    (mkIf srv.enable {
      home.packages = [
        pkgs.signal-cli
        pkgs.curl # extension uses curl for daemon JSON-RPC
      ];

      age.secrets.pi-signal-env = {
        file = "${inputs.secrets}/pi-signal-env.age";
        mode = "400";
      };

      systemd.user.services.signal-cli-daemon = {
        Unit = {
          Description = "Signal CLI daemon (single-account HTTP)";
          After = [ "network-online.target" ];
          Wants = [ "network-online.target" ];
        };
        Service = {
          Type = "simple";
          EnvironmentFile = "/run/user/1000/agenix/pi-signal-env";
          ExecStart = "${lib.getExe pkgs.signal-cli} -a $PI_SIGNAL_ACCOUNT daemon --http 127.0.0.1:47300";
          Restart = "always";
          RestartSec = 10;
        };
        Install.WantedBy = [ "default.target" ];
      };

      systemd.user.services.pi-agent = {
        Unit = {
          Description = "pi coding agent (Signal-connected)";
          After = [ "signal-cli-daemon.service" ];
        };
        Service = {
          Type = "simple";
          EnvironmentFile = "/run/user/1000/agenix/pi-signal-env";
          ExecStart = "${pkgs.bash}/bin/bash -c 'exec ${piWrapped}/bin/pi --mode rpc < <(${pkgs.coreutils}/bin/sleep infinity)'";
          Restart = "always";
          RestartSec = 10;
          WorkingDirectory = config.home.homeDirectory;
        };
        Install.WantedBy = [ "default.target" ];
      };
    })
  ];
}
