{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:
with lib;
let
  cfg = config.hosts.worker;
in
{
  options.hosts.worker = {
    enable = mkEnableOption "worker user for isolated pi coding agent sessions";
  };

  config = mkIf cfg.enable {
    users.groups.code = { };
    users.users.worker = {
      isNormalUser = true;
      shell = pkgs.zsh;
      description = "Isolated pi coding agent user";
      extraGroups = [
        "code"
        "users"
      ];
      hashedPasswordFile = config.age.secrets.password.path; # reuse same password
    };

    security.unprivilegedUsernsClone = true;

    users.users.martijn.extraGroups = [ "code" ];

    security.sudo-rs.extraRules = [
      {
        users = [ "martijn" ];
        runAs = "worker";
        commands = [
          {
            command = "ALL";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];

    systemd.tmpfiles.rules = [
      "d  /home/worker                          0755 worker  users - -"
      "d  /home/worker/.pi                      0755 worker  users - -"
      "d  /home/worker/.pi/worker-sandbox       0755 worker  users - -"
      "d  /home/worker/.pi/worker-sandbox/agent 0755 worker  users - -"
      "d  /home/worker/.pi/worker-sandbox/agent/sessions 0755 worker users - -"
      "L+ /home/worker/.pi/worker-sandbox/agent/auth.json - - - - /run/agenix/pi-auth"

      "d  /opt                         0755 root    root - -"
      "d  /opt/code                    2775 worker  code - -"
      "d  /opt/pi-agent-base           2775 root    code - -"
      "z  /opt/nix                     2775 martijn users - -"
      "L+ /home/martijn/.pi/agent/auth.json - - - - /run/agenix/pi-auth"
    ];

    hosts.borg.paths = [
      "/opt/nix"
      "/opt/code"
      "/opt/pi-agent-base"
    ];

    system.activationScripts.piAgentBaseSync = {
      deps = [ "groups" ];
      text = ''
        set -euo pipefail

        src=/home/martijn/.pi/agent
        dst=/opt/pi-agent-base

        if [ -d "$src" ]; then
          mkdir -p "$dst"
          chmod 2775 "$dst"

          ${pkgs.rsync}/bin/rsync -a --delete \
            --exclude 'sessions' \
            "$src"/ "$dst"/

          chown -R root:code "$dst"
          find "$dst" -type d -exec chmod 2775 {} +
          find "$dst" -type f -exec chmod g+rw {} +
          find "$dst" -type f -perm -u+x -exec chmod g+rx {} +
          chmod 2775 "$dst"
        fi
      '';
    };

    age.secrets.llm = {
      file = "${inputs.secrets}/llm.age";
      owner = "root";
      group = "code";
      mode = "0440";
    };

    age.secrets.pi-auth = {
      file = "${inputs.secrets}/worker-pi-auth.age";
      owner = "root";
      group = "code";
      mode = "0440";
    };

  };
}
