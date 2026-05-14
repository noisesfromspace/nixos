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
      extraGroups = [ "code" "users" ];
      hashedPasswordFile = config.age.secrets.password.path; # reuse same password
    };

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
      "d  /opt                         0755 root    root - -"
      "d  /opt/code                    2775 worker  code - -"
      "d  /opt/pi-agent                2775 root    code - -"
      "z  /opt/nix                     2775 martijn users - -"
      "L+ /home/martijn/.pi/agent/auth.json - - - - /run/agenix/pi-auth"
      "L+ /home/worker/.pi/agent/auth.json  - - - - /run/agenix/pi-auth"
    ];

    system.activationScripts.pi-agent = {
      text = ''
        set -euo pipefail

        src=/home/martijn/.pi/agent
        dst=/opt/pi-agent

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

    nix.settings.allowed-users = [ "worker" ];

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

    home-manager.users.worker =
      { ... }:
      {
        home.username = "worker";
        home.homeDirectory = "/home/worker";
        home.stateVersion = "24.05";

        programs.home-manager.enable = true;

        home.packages = [ pkgs.nodejs_22 ];

        # ZSH with the same pi env wiring as martijn
        programs.zsh = {
          enable = true;
          enableCompletion = true;
          autosuggestion.enable = true;
          syntaxHighlighting.enable = true;

          sessionVariables = {
            NPM_CONFIG_PREFIX = "$HOME/.local/share/npm";
            EDITOR = "nvim";
            PI_CODING_AGENT_DIR = "/opt/pi-agent";
            PI_CODING_AGENT_SESSION_DIR = "$HOME/.pi/agent/sessions";
            PI_AUTH_JSON = "/run/agenix/pi-auth";
          };

          initExtra = ''
            # Source LLM API keys from system-level agenix secret (group: code)
            if [[ -r /run/agenix/llm ]]; then
              export $(cat /run/agenix/llm | xargs)
            fi

            # Drop into workspace on login
            if [[ $PWD == $HOME ]]; then
              cd /opt/code
            fi
          '';
        };

        # Ensure npm bin dir exists (HM creates parent dirs for home.file entries)
        home.file.".local/share/npm/bin/.keep".text = "";

        # pi wrapper — identical pattern to martijn
        home.file.".local/bin/pi" = {
          text = ''
            #!/usr/bin/env bash
            export NPM_CONFIG_PREFIX="$HOME/.local/share/npm"
            export PATH="$HOME/.local/share/npm/bin:$PATH"
            exec /run/current-system/sw/bin/pi "$@"
          '';
          executable = true;
        };

        home.sessionPath = [
          "$HOME/.local/bin"
          "$HOME/.local/share/npm/bin"
        ];
      };
  };
}
