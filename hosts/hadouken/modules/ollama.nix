{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.hosts.ollama;
in
{
  options.hosts.ollama = {
    enable = lib.mkEnableOption "Ollama LLM server for AI-powered spam filtering";
  };

  config = lib.mkIf cfg.enable {
    services.ollama = {
      enable = true;
      # CPU-only: hadouken has Intel graphics, no dedicated GPU.
      # llama3.2:3b runs ~2s/query on CPU — fine for spam classification volume.
      package = pkgs.ollama;

      modelsDir = "/mnt/zwembad/games/ollama-models";

      # Listen on localhost only; Caddy reverse-proxies for external access
      host = "127.0.0.1";
      port = 11434;

      # llama3.2:3b for rspamd's spam classification
      # qwen3:1.7b for Atuin AI (tool-calling, CPU-friendly)
      loadModels = [
        "llama3.2:3b"
        "phi4-mini"
        "qwen3:1.7b"
      ];
    };

    # Reverse-proxy Ollama API via Caddy on ollama.thuis
    services.caddy.virtualHosts = {
      "ollama.thuis" = {
        extraConfig = ''
          import headscale
          handle @internal {
            reverse_proxy http://127.0.0.1:11434
          }
        '';
      };
      "chat.thuis" = {
        extraConfig = ''
          import headscale
          handle @internal {
            reverse_proxy http://127.0.0.1:1234
          }
        '';
      };
    };

    # Kurczak — minimal chat UI for Ollama
    systemd.services.kurczak = {
      description = "Kurczak — minimal Ollama chat UI";
      after = [
        "network.target"
        "ollama.service"
      ];
      wants = [ "ollama.service" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        Restart = "on-failure";
        RestartSec = 5;
        StateDirectory = "kurczak";
        WorkingDirectory = "/var/lib/kurczak";
        ExecStartPre = [
          # Copy application files into writable state directory so data/ is writable
          "${pkgs.writeShellScript "kurczak-init" ''
            set -e
            cp -rn ${pkgs.kurczak}/lib/kurczak/. /var/lib/kurczak/ 2>/dev/null || true
            chmod u+w /var/lib/kurczak/config.json
            mkdir -p /var/lib/kurczak/data/history
          ''}"
        ];
        ExecStart = "${pkgs.nodejs_22}/bin/node server.js";

        # Security hardening
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = "/var/lib/kurczak";
      };
    };
  };
}
